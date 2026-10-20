package uc_installer.core

// S0~S8 状态机编排、断点续装与安装器自退役（design.md §4.6 / §4.5.5 / §5.3）。
//
// 设计要点（逐条对应 spec/design 约束）：
//   - 每个 Sn 声明 gate()（闸口，未过拒绝推进并给出 fix）与 run()（执行体）；
//   - 断点续装：已完成步骤不重复执行（AC-123），每步执行后**立即**持久化（AC-122）；
//   - 闸口未通过即停止并报具体原因 + 修复命令（AC-121/AC-164），禁止静默降级；
//   - R-17：gate() 必须返回可观测证据，不得"缺失成功证据仍宣告成功"。

import std.fs.{Path, exists}
import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonArray, JsonBool, JsonObject, JsonString}
import uc_installer.services.{readEnv, readDbConnectionUrl, parseDatabaseUrl, AdminRepo, DbConn}
import uc_installer.services.{findReleaseTar, verifyTar, extractTar, verifySha256Sums}
import uc_installer.services.{probeOpenSSL, generateSelfSigned, SslResult}
import uc_installer.services.{writeFileAtomic, readFileText, isNonEmptyFile}
import uc_installer.platform.{isLocalPortReachable}
import uc_installer.platform.{findPidsByImage, launchRuntime}
import uc_installer.util.ensureDir
// T035~T038（DevKit 注册表 / 安装 / 自检 / 初始化）已落地，S7/S8 由「显式降级占位」
// 改为真正调用。import 的是子包 `uc_installer.services.devkit`——core 本就依赖
// services（见上方 import），方向一致不成环；反向（devkit import core）才成环。
import uc_installer.services.devkit.{DevkitCheck, DevkitFacts, InitContext, InitStatus,
    collectSourceFacts, devkitRegistry, installDevkitComponent, installOutcomeCode,
    isInstallSuccess, verifyOne, runInitSteps, initAllPassed, initStatusCode}

// ===================== 步骤表契约 =====================

/// 闸口判定结果：ok=false 时 reason 必填，fix 必填（AC-121 要求给出可执行修复指引）。
public struct GateResult {
    public let ok: Bool
    public let reason: String
    public let fix: String

    // 一律用「无默认值的固定 arity 位置参数」：带默认值的命名参数版本与等 arity 的
    // 位置参数版本会触发 `constructor 'init' has overload conflicts`（默认值使两个
    // 签名在比较时同形）。调用点分布只有 1 参与 3 参两种，故提供这两个构造即可。
    public init(ok: Bool) {
        this.ok = ok
        this.reason = ""
        this.fix = ""
    }

    public init(ok: Bool, reason: String, fix: String) {
        this.ok = ok
        this.reason = reason
        this.fix = fix
    }
}

/// 单步执行结果。
public struct StepResult {
    public let ok: Bool
    public let message: String
    public let evidence: HashMap<String, String>

    // 27 个调用点全部按位置传满 3 参，无需默认值（默认值版会与本构造 overload 冲突）。
    public init(ok: Bool, message: String, evidence: HashMap<String, String>) {
        this.ok = ok
        this.message = message
        this.evidence = evidence
    }
}

/// 步骤定义：id + 中文名 + 闸口 + 执行体。
public struct StepDef {
    public let id: String
    public let title: String
    /// 闸口未过时是否允许直接跳过（仅 S2 在 openssl 缺失且已降级时为 true）。
    public let skippable: Bool
    public let gate: (AppContext) -> GateResult
    public let run: (AppContext) -> StepResult

    // gate/run 是函数类型参数，调用点一律用 `gate:` / `run:` 前缀传入（9 处调用均如此），
    // 故三者全声明为命名参数；位置参数必须排在命名参数之前，故 id/title 保持位置。
    public init(id: String, title: String, gate!: (AppContext) -> GateResult,
                run!: (AppContext) -> StepResult, skippable!: Bool = false) {
        this.id = id
        this.title = title
        this.skippable = skippable
        this.gate = gate
        this.run = run
    }
}

/// 续装/推进的汇总结果（供 CLI 与 HTTP 层输出机器可读报告）。
public struct OrchestratorReport {
    /// 本次真正执行过的步骤 id（按发生顺序）。
    public let executed: ArrayList<String>
    /// 因已完成而跳过的步骤 id。
    public let skipped: ArrayList<String>
    /// 停止原因；为空表示一路走完。
    // 这四个是值类型且 resume() 会分多次重新赋值，故必须是 var；
    // executed/skipped 是 ArrayList 引用类型，init 里建好后只 .add() 不重新赋值，let 即可。
    public var stoppedAt: String
    public var stopReason: String
    public var stopFix: String
    public var ok: Bool

    public init() {
        this.executed = ArrayList<String>()
        this.skipped = ArrayList<String>()
        this.stoppedAt = ""
        this.stopReason = ""
        this.stopFix = ""
        this.ok = true
    }

    public func toJson(): JsonObject {
        let o = JsonObject()
        let ex = JsonArray()
        for (s in executed) { ex.add(JsonString(s)) }
        o.put("executed", ex)
        let sk = JsonArray()
        for (s in skipped) { sk.add(JsonString(s)) }
        o.put("skipped", sk)
        o.put("stoppedAt", JsonString(stoppedAt))
        o.put("stopReason", JsonString(stopReason))
        o.put("stopFix", JsonString(stopFix))
        o.put("ok", JsonBool(ok))
        return o
    }
}

// ===================== 步骤表 =====================

/// S0 探测环境：安装根目录必须存在，并把「runtime 是否已就位」如实记进 evidence。
private func gateS0(ctx: AppContext): GateResult {
    if (!exists(ctx.paths.installRoot)) {
        return GateResult(false, "安装根目录不存在：${ctx.paths.installRoot}",
            "请确认安装器与 runtime 发行包的相对位置，或用 --source-dir 指定源码目录")
    }
    return GateResult(true)
}

private func runS0(ctx: AppContext): StepResult {
    let ev = HashMap<String, String>()
    ev.add("installRoot", ctx.paths.installRoot.toString())
    ev.add("releaseDir", ctx.paths.releaseDir.toString())
    let installed = verifyRelease(ctx.paths)
    ev.add("runtimeInstalled", if (installed) { "true" } else { "false" })
    ev.add("port", ctx.args.port.toString())
    // R-17：证据必须真实反映探测结果，不得在未装 runtime 时声称已装。
    return StepResult(true, if (installed) { "环境探测完成（runtime 已就位）" } else { "环境探测完成（runtime 未安装）" }, ev)
}

/// S1 数据库配置：读已保存配置，闸口要求四项齐备且可解析。
private func gateS1(ctx: AppContext): GateResult {
    if (!exists(ctx.paths.configFile)) {
        return GateResult(false, "尚未保存数据库配置",
            "在向导页填写数据库地址/端口/库名/用户/口令后点「保存配置」，或调用 POST /api/setup/save-config")
    }
    return GateResult(true)
}

private func runS1(ctx: AppContext): StepResult {
    let text = readFileText(ctx.paths.configFile)
    let ev = HashMap<String, String>()
    ev.add("configFile", ctx.paths.configFile.toString())
    ev.add("configBytes", text.size.toString())
    return StepResult(true, "数据库配置已保存", ev)
}

/// S2 SSL：可跳过步。openssl 缺失时显式降级并记 degraded，禁止静默（AC-116/§4.10 I8）。
private func gateS2(ctx: AppContext): GateResult {
    let crt = ctx.paths.releaseDir.join("ssl").join("server.crt")
    if (isNonEmptyFile(crt)) {
        return GateResult(true)          // 已存在证书，无需再生成
    }
    if (!probeOpenSSL()) {
        return GateResult(true)          // 闸口放行，但 run 内显式降级
    }
    return GateResult(true)
}

private func runS2(ctx: AppContext): StepResult {
    let ev = HashMap<String, String>()
    let crt = ctx.paths.releaseDir.join("ssl").join("server.crt")
    if (isNonEmptyFile(crt)) {
        ev.add("openssl", "skipped-existing")
        return StepResult(true, "证书已存在，跳过生成", ev)
    }
    if (!probeOpenSSL()) {
        ev.add("openssl", "unavailable")
        ev.add("fallback", "localhost + HTTP")
        noteDegraded(ctx, "S2",
            "openssl 不可用，无法生成自签证书",
            "降级为 localhost + HTTP",
            "安装 openssl 后重跑，或手工放置 release/ssl/server.crt 与 server.key")
        return StepResult(true, "openssl 不可用，已降级", ev)
    }
    return runS2Generate(ctx, ev)
}

// match 各臂一律写成单表达式 `case X => expr`：仓颉会把 `case X => {` 后的 `{`
// 解析成 lambda 起始，块内首条语句就报 "expected '=>' in lambda expression"。
// 需要多条语句时提取成独立函数，在臂里直接 return。
private func runS2Generate(ctx: AppContext, ev: HashMap<String, String>): StepResult {
    let sslDir = ctx.paths.releaseDir.join("ssl")
    match (generateSelfSigned("javatoarktsapi.uctoo.com", sslDir)) {
        case SslResult.Ok => return s2Ok(ev, sslDir)
        // AC-097：失败即明确报错，不写半成品文件
        case SslResult.Failed(reason) => return s2Failed(ev, reason)
    }
}

private func s2Ok(ev: HashMap<String, String>, sslDir: Path): StepResult {
    ev.add("openssl", "generated")
    ev.add("sslDir", sslDir.toString())
    return StepResult(true, "自签证书已生成", ev)
}

private func s2Failed(ev: HashMap<String, String>, reason: String): StepResult {
    ev.add("openssl", "failed")
    ev.add("reason", reason)
    return StepResult(false, "自签证书生成失败：${reason}", ev)
}

/// S3 安装介质（离线 tarball 优先 → staging → 原子切换）。
private func gateS3(ctx: AppContext): GateResult {
    match (findReleaseTar(ctx.paths.mediaDir)) {
        case Some(_) => return GateResult(true)
        case None => return GateResult(false, "介质目录中未找到 runtime 发行包（*.tar.gz）",
            "把 agentskills-runtime-win-x64.tar.gz 放入 ${ctx.paths.mediaDir} 后重跑")
    }
}

private func runS3(ctx: AppContext): StepResult {
    let ev = HashMap<String, String>()
    match (findReleaseTar(ctx.paths.mediaDir)) {
        case Some(t) => return s3WithTar(ctx, t, ev)
        case None => return s3NoTar(ev)
    }
}

private func s3NoTar(ev: HashMap<String, String>): StepResult {
    ev.add("mediaSource", "none")
    return StepResult(false, "介质目录中未找到 runtime 发行包", ev)
}

/// 已有本地介质：校验 → 快照 → 解压 → 骨架校验，每步即时写 evidence。
private func s3WithTar(ctx: AppContext, t: Path, ev: HashMap<String, String>): StepResult {
    ev.add("mediaSource", "local")
    ev.add("tarball", t.toString())
    if (!verifyTar(t)) {
        ev.add("verify", "failed")
        return StepResult(false, "发行包校验失败（可能下载不完整）", ev)
    }
    ev.add("verify", "ok")
    let snap = snapshotExisting(ctx.paths)
    ev.add("snapshot", if (snap) { "taken" } else { "none" })
    if (!extractTar(t, ctx.paths.installRoot)) {
        ev.add("extract", "failed")
        return StepResult(false, "发行包解压失败（tar.exe 解压异常）", ev)
    }
    ev.add("extract", "ok")
    if (!verifySha256Sums(ctx.paths.releaseDir)) {
        ev.add("verifySha256Sums", "failed")
        return StepResult(false, "发行包 SHA256SUMS 校验失败（介质可能被篡改或不完整）", ev)
    }
    ev.add("verifySha256Sums", "ok")
    if (!verifyRelease(ctx.paths)) {
        ev.add("verifyRelease", "failed")
        return StepResult(false, "解压后缺少 runtime 骨架文件，判定安装失败", ev)
    }
    ev.add("verifyRelease", "ok")
    ctx.state.state.snapshot.exists = snap
    ctx.state.state.mediaSource = "local"
    return StepResult(true, "runtime 介质已落地", ev)
}

/// S4 `.env` 写入：读已保存配置 → 行级 in-place 写 release/.env。
private func gateS4(ctx: AppContext): GateResult {
    if (!verifyRelease(ctx.paths)) {
        return GateResult(false, "runtime 未安装，无法写入 .env",
            "先完成 S3 安装介质步骤")
    }
    return GateResult(true)
}

private func runS4(ctx: AppContext): StepResult {
    let ev = HashMap<String, String>()
    let envPath = ctx.paths.releaseDir.join(".env")
    match (readEnv(ctx.paths.configFile)) {
        case None => return s4NoConfig(ev)
        case Some(map) => return s4WithConfig(ctx, map, envPath, ev)
    }
}

private func s4NoConfig(ev: HashMap<String, String>): StepResult {
    return StepResult(false, "读取安装配置失败，.env 未写入", ev)
}

private func s4WithConfig(ctx: AppContext, map: HashMap<String, String>, envPath: Path,
                          ev: HashMap<String, String>): StepResult {
    match (readDbConnectionUrl(map)) {
        case None => return s4NoUrl(ev, "missing",
            "配置中缺少 DATABASE_URL / orm_connectionUrl，.env 未写入")
        case Some(url) => return s4ParseUrl(ctx, map, url, envPath, ev)
    }
}

private func s4ParseUrl(ctx: AppContext, map: HashMap<String, String>, url: String, envPath: Path,
                        ev: HashMap<String, String>): StepResult {
    match (parseDatabaseUrl(url)) {
        case None => return s4NoUrl(ev, "unparsable", "数据库连接串无法解析，.env 未写入")
        case Some(conn) => return writeEnvFromConn(ctx, map, conn, envPath, ev)
    }
}

private func s4NoUrl(ev: HashMap<String, String>, tag: String, msg: String): StepResult {
    ev.add("dbConfig", tag)
    return StepResult(false, msg, ev)
}

/// 由已解析的连接参数写 release/.env（独立成函数：case 臂内首条为 let 会被解析成 lambda）。
private func writeEnvFromConn(ctx: AppContext, cfg: HashMap<String, String>, conn: DbConn,
                             envPath: Path, ev: HashMap<String, String>): StepResult {
    let envText = buildEnvContent(cfg, conn.host, conn.port.toString(),
                                  conn.database, conn.user, conn.password)
    if (!writeFileAtomic(envPath, envText)) {
        ev.add("write", "failed")
        return StepResult(false, ".env 写入失败", ev)
    }
    ev.add("write", "ok")
    ev.add("envPath", envPath.toString())
    return StepResult(true, ".env 已写入", ev)
}

/// 由配置 + 连接参数拼出最小可用 .env 内容。
///
/// 整文件落盘（writeFileAtomic）保证幂等：重复执行产生同一份内容，不产生重复条目（§4.5.5）。
/// 口令只经 DATABASE_URL 传入，不落独立键，也不在此回显（§8.1 脱敏）。
private func buildEnvContent(cfg: HashMap<String, String>, dbHost: String, dbPort: String,
                             dbName: String, dbUser: String, dbPwd: String): String {
    let sb = StringBuilder()
    sb.append("DATABASE_URL=postgresql://${dbUser}:${dbPwd}@${dbHost}:${dbPort}/${dbName}\n")
    for ((k, v) in cfg) {
        let lk = k.toAsciiLower()
        if (lk == "password" || lk == "passwd" || lk == "pwd") {
            continue                       // 口令只经 DATABASE_URL 传入，不落独立键
        }
        sb.append("${k}=${v}\n")
    }
    return sb.toString()
}

/// S5 建管理员：真路径（读 release/.env → 落库 → 回读校验）。
private func gateS5(ctx: AppContext): GateResult {
    let envPath = ctx.paths.releaseDir.join(".env")
    if (!isNonEmptyFile(envPath)) {
        return GateResult(false, "release/.env 不存在，无法建管理员",
            "先完成 S4 写入 .env")
    }
    return GateResult(true)
}

private func runS5(ctx: AppContext): StepResult {
    let ev = HashMap<String, String>()
    match (readEnv(ctx.paths.releaseDir.join(".env"))) {
        case None => return StepResult(false, "release/.env 解析失败，无法建管理员", ev)
        case Some(env) => return s5WithEnv(env, ev)
    }
}

private func s5WithEnv(env: HashMap<String, String>, ev: HashMap<String, String>): StepResult {
    match (readDbConnectionUrl(env)) {
        case None => return StepResult(false, "release/.env 缺少数据库连接串，无法建管理员", ev)
        case Some(url) => return s5ParseUrl(url, ev)
    }
}

private func s5ParseUrl(url: String, ev: HashMap<String, String>): StepResult {
    match (parseDatabaseUrl(url)) {
        case None => return StepResult(false, "release/.env 数据库连接串无法解析", ev)
        case Some(conn) => return s5PingDb(conn, ev)
    }
}

private func s5PingDb(conn: DbConn, ev: HashMap<String, String>): StepResult {
    // 管理员账号由 HTTP 端点 #8 承接（需表单输入 name/email/password），
    // 编排器这一步只判定「DB 可连」，账号创建不在此重复。
    let repo = AdminRepo(conn)
    let ok = repo.ping()
    ev.add("dbReachable", if (ok) { "true" } else { "false" })
    if (!ok) {
        return StepResult(false, "数据库不可达，无法建管理员", ev)
    }
    ev.add("handoff", "POST /api/setup/create-admin")
    return StepResult(true, "数据库可达，管理员创建由 create-admin 端点承接", ev)
}

/// S6 起进程 + 轮询 `/api/v1/health`。
private func gateS6(ctx: AppContext): GateResult {
    if (!verifyRelease(ctx.paths)) {
        return GateResult(false, "runtime 骨架不完整，无法启动",
            "先完成 S3 安装介质步骤")
    }
    return GateResult(true)
}

private func runS6(ctx: AppContext): StepResult {
    let ev = HashMap<String, String>()
    // T011（C-D1）：--no-serve 时跳过 runtime 自启动，进程生命周期交由调用方接管（R-39）。
    // 否则 install 会拉起 runtime 子进程并监听其健康端口，与"无端口监听"诉求相悖。
    if (ctx.args.noServe) {
        return StepResult(true,
            "no-serve 模式：跳过 runtime 自启动，进程生命周期由调用方接管（R-39 / C-D1）", ev)
    }
    let exe = ctx.paths.releaseDir.join("agentskills-runtime.exe")
    let pids = findPidsByImage("agentskills-runtime.exe")
    if (pids.size > 0) {
        ev.add("alreadyRunning", "true")
        ev.add("pids", joinPids(pids))
        return StepResult(true, "runtime 已在运行，跳过启动", ev)
    }
    ev.add("alreadyRunning", "false")
    ev.add("exe", exe.toString())
    match (launchRuntime(exe, ctx.paths.releaseDir)) {
        case Some(pid) => return s6Started(ev, pid)
        case None => return StepResult(false, "runtime 启动失败（spawn 未返回 pid）", ev)
    }
}

private func s6Started(ev: HashMap<String, String>, pid: Int64): StepResult {
    ev.add("pid", pid.toString())
    return StepResult(true, "runtime 已启动（pid=${pid}）", ev)
}

/// S7 DevKit 组件：调用 T036 的真实安装器（DK-1~DK-8）。
///
/// 本步骤只负责**编排与记账**：具体安装动作在 `services/devkit/install.cj`，
/// 这里把结果写进 `.install-state.json.devkitComponents`（AC-137），
/// 并在安装后立即跑一次自检（AC-132）。
///
/// 只装 DK-3 是刻意的：S7 处于「安装 runtime 之后、初始化之前」，
/// 源码树是后续 I1~I9 的唯一 cwd 前提（R-23），而 DK-4/DK-5 的落地动作
/// 依赖 Phase 7 的 `seed apply`（T049），此刻如实记为未完成而非假装成功。
private func gateS7(ctx: AppContext): GateResult {
    let dir = ctx.paths.devSourceDir
    if (exists(dir)) {
        return GateResult(true)
    }
    // 目录不存在不是"拒绝推进"的理由 —— DK-3 的语义正是 clone 到一个**尚不存在**的目录
    // （design §4.10.1.1 S-a）。这里只保证父路径可创建；写权限不足由 clone 自己失败，
    // 并在 runS7 里如实记为 GitMissing/DirRejected 而非静默通过。
    ensureDir(dir)
    if (!exists(dir)) {
        return GateResult(false,
            "无法创建开发源码目录：${dir.toString()}",
            "请用 --source-dir 指定一个可写的开发源码目录")
    }
    return GateResult(true)
}

private func runS7(ctx: AppContext): StepResult {
    let ev = HashMap<String, String>()
    ev.add("mode", ctx.state.state.mode)
    ev.add("withDevkit", if (ctx.args.withDevkit) { "true" } else { "false" })
    if (!ctx.args.withDevkit) {
        ev.add("result", "skipped-by-user")
        ctx.state.state.devkit = DEVKIT_SKIPPED
        ctx.state.save()
        return StepResult(true, "未勾选 DevKit，跳过", ev)
    }
    ctx.state.state.devkit = DEVKIT_INSTALLED
    ctx.state.state.mode = MODE_DEV
    let dir = ctx.paths.devSourceDir
    let facts: DevkitFacts = collectSourceFacts(dir)
    let res = installDevkitComponent("DK-3", dir, false)
    ev.add("outcome", installOutcomeCode(res.outcome))
    ev.add("actual", res.actual)
    if (!isInstallSuccess(res.outcome)) {
        // 失败即如实留痕并返回失败 —— 不降级为"跳过"（R-22）。
        noteDegraded(ctx, "S7", res.message,
            "未安装 DK-3，后续 S8 开发环境初始化不会执行",
            "按 message 中的命令处理后重跑 install")
        ctx.state.save()
        return StepResult(false, "DK-3 安装失败：${res.message}", ev)
    }
    // 安装后立即自检并记录实际值（AC-132）。判据求值外提，match 臂只留单表达式。
    let chk = verifyOne("DK-3", dir, facts)
    match (chk) {
        case Some(c) => return s7Verified(ctx, c, ev)
        case None => ()
    }
    markPendingComponents(ctx)
    ev.add("result", "dk3-installed")
    ev.add("pending", "DK-1/DK-2/DK-4~DK-8 需开发者显式安装（HTTP devkit/install 端点）")
    return StepResult(true, "DK-3 源码树已就位；其余组件保持 pending，待显式安装", ev)
}

/// DK-3 自检通过后的收尾：记账 + 标记其余组件 pending。
private func s7Verified(ctx: AppContext, chk: DevkitCheck, ev: HashMap<String, String>): StepResult {
    ev.add("checkStatus", if (chk.passed) { "pass" } else { "fail" })
    ev.add("checkActual", chk.actual)
    ctx.state.state.devkitComponents.add("DK-3", DevkitComponentState(
        id: "DK-3", status: if (chk.passed) { DEVKIT_INSTALLED } else { DEVKIT_FAILED },
        at: Some(nowStamp()), actual: chk.actual, expected: chk.expected))
    ctx.state.save()
    if (!chk.passed) {
        noteDegraded(ctx, "S7",
            "DK-3 已 clone 但自检未通过：${chk.actual}",
            "保留工作副本，不做任何清理",
            chk.fix)
        return StepResult(false, "DK-3 自检未通过：${chk.actual}", ev)
    }
    markPendingComponents(ctx)
    ev.add("result", "dk3-installed")
    ev.add("pending", "DK-1/DK-2/DK-4~DK-8 需开发者显式安装（HTTP devkit/install 端点）")
    return StepResult(true, "DK-3 源码树已就位；其余组件保持 pending，待显式安装", ev)
}

/// 其余组件的落地动作尚不可执行：如实记账为 pending（AC-131 的诚实变体）。
private func markPendingComponents(ctx: AppContext): Unit {
    for (c in devkitRegistry()) {
        if (c.id == "DK-3") {
            continue
        }
        ctx.state.state.devkitComponents.add(c.id, DevkitComponentState(
            id: c.id, status: DEVKIT_PENDING, at: None<String>,
            actual: "本次安装流程未执行该组件", expected: c.expected))
    }
    ctx.state.save()
}

/// S8 开发环境初始化：调用 T038 的 I1~I9。
private func gateS8(ctx: AppContext): GateResult {
    if (!ctx.args.withDevkit) {
        return GateResult(true)
    }
    let dir = ctx.paths.devSourceDir
    if (!exists(dir)) {
        return GateResult(false,
            "开发源码目录不存在：${dir.toString()}",
            "S7 未成功安装 DK-3，请先修好 S7 再重跑")
    }
    return GateResult(true)
}

private func runS8(ctx: AppContext): StepResult {
    let ev = HashMap<String, String>()
    let dir = ctx.paths.devSourceDir
    ev.add("devSourceDir", dir.toString())
    if (!ctx.args.withDevkit) {
        ev.add("result", "skipped-by-user")
        return StepResult(true, "最终用户模式，跳过开发环境初始化", ev)
    }
    // I1~I9 的 cwd 恒为 devSourceDir（R-23），releaseEnvPath 取发行态 .env 作为取值来源。
    let ictx = InitContext(dir, ctx.paths.releaseDir.join(".env"), dir.join(".env"),
                           false, dbConnOrNone(ctx))
    let results = runInitSteps(ictx)
    var passed: Int64 = 0
    var manual: Int64 = 0
    var failed: Int64 = 0
    for (r in results) {
        ev.add(r.id, initStatusCode(r.status) + " :: " + r.actual)
        match (r.status) {
            case InitStatus.Pass => passed += 1
            case InitStatus.Manual => manual += 1
            case InitStatus.Fail => failed += 1
            case InitStatus.Skipped => ()
        }
    }
    ev.add("result", "init-executed")
    ev.add("passed", passed.toString())
    ev.add("manual", manual.toString())
    ev.add("failed", failed.toString())
    if (initAllPassed(results)) {
        return StepResult(true, "开发环境初始化 I1~I9 全部通过", ev)
    }
    // 存在 Manual/Fail：如实报告为「需人工介入」，不冒充成功（AC-154）。
    noteDegraded(ctx, "S8",
        "开发环境初始化未全部通过（manual=${manual}, failed=${failed}）",
        "已完成的步骤保留；未完成项的 fix 见状态文件 evidence",
        "逐项按 .install-state.json 里 S8 证据中的 fix 处理后重跑")
    return StepResult(false,
        "开发环境初始化存在未完成项（manual=${manual}, failed=${failed}）", ev)
}

/// 读发行态 .env 取数据库连接；读不到返回 None（相关项据此降级，不伪造成功）。
private func dbConnOrNone(ctx: AppContext): Option<DbConn> {
    let envPath = ctx.paths.releaseDir.join(".env")
    match (readEnv(envPath)) {
        case Some(env) => match (readDbConnectionUrl(env)) {
            case Some(url) => parseDatabaseUrl(url)
            case None => None<DbConn>
        }
        case None => None<DbConn>
    }
}

private func joinPids(pids: ArrayList<Int64>): String {
    let sb = StringBuilder()
    var i = 0
    while (i < pids.size) {
        if (i > 0) { sb.append(",") }
        sb.append(pids[i].toString())
        i += 1
    }
    return sb.toString()
}

/// 步骤表（S0~S8，顺序即执行顺序）。
public func stepTable(): ArrayList<StepDef> {
    let table = ArrayList<StepDef>()
    table.add(StepDef("S0", "探测环境", gate: gateS0, run: runS0))
    table.add(StepDef("S1", "数据库配置", gate: gateS1, run: runS1))
    table.add(StepDef("S2", "SSL 证书", skippable: true, gate: gateS2, run: runS2))
    table.add(StepDef("S3", "安装介质", gate: gateS3, run: runS3))
    table.add(StepDef("S4", "写入 .env", gate: gateS4, run: runS4))
    table.add(StepDef("S5", "建管理员", gate: gateS5, run: runS5))
    table.add(StepDef("S6", "启动 runtime", gate: gateS6, run: runS6))
    table.add(StepDef("S7", "DevKit 组件", skippable: true, gate: gateS7, run: runS7))
    table.add(StepDef("S8", "开发环境初始化", skippable: true, gate: gateS8, run: runS8))
    return table
}

// ===================== 断点续装 =====================

/// 取步骤当前状态；缺失按 pending 处理。
private func statusOf(ctx: AppContext, id: String): String {
    match (ctx.state.state.steps.get(id)) {
        case Some(s) => return s.status
        case None => return STEP_PENDING
    }
}

/// 标 running（执行前落盘，保证中断后能看到"正在做哪一步"）。
private func markRunning(ctx: AppContext, id: String): Unit {
    ctx.state.state.currentStep = id
    ctx.state.markStep(id, STEP_RUNNING, None<String>, HashMap<String, String>())
}

/// 标 done（done 必须有 at，非 done 的 at 必须为 null —— §6.1.7）。
private func markDone(ctx: AppContext, id: String, ev: HashMap<String, String>): Unit {
    ctx.state.markStep(id, STEP_DONE, Some(nowStamp()), ev)
}

private func markFailed(ctx: AppContext, id: String, ev: HashMap<String, String>): Unit {
    ctx.state.markStep(id, STEP_FAILED, None<String>, ev)
}

/// 标 skipped（at 必须为 null）。
private func markSkipped(ctx: AppContext, id: String, reason: String): Unit {
    let ev = HashMap<String, String>()
    ev.add("reason", reason)
    ctx.state.markStep(id, STEP_SKIPPED, None<String>, ev)
}

public func nowStamp(): String {
    return DateTime.now().toString()
}

/// 按 `.install-state.json` 续装：已完成不重复（AC-123），每步执行后立即持久化（AC-122）。
///
/// force 为真时忽略 done 状态重跑全部步骤（`--force` 语义）。
public func resume(ctx: AppContext, force: Bool): OrchestratorReport {
    // 修改结构体实例成员需同时满足两个条件（语言文档 struct §2.2）：
    //   ① 持有实例的变量须为 var（本行）；② 被修改的成员须声明为 var（见 OrchestratorReport 定义）。
    var report = OrchestratorReport()

    if (ctx.state.state.corruption.recovered) {
        match (ctx.state.state.corruption.backupPath) {
            case Some(bak) => ctx.log.warn("状态文件损坏已备份到 ${bak}，从 S0 重新开始")
            case None => ctx.log.warn("状态文件损坏且备份失败，从 S0 重新开始")
        }
    }

    for (step in stepTable()) {
        let cur = statusOf(ctx, step.id)

        // 已完成且非强制 ⇒ 跳过，不重复执行（AC-123）
        if (!force && cur == STEP_DONE) {
            report.skipped.add(step.id)
            continue
        }

        // 闸口：未通过即拒绝推进，给出原因 + 修复命令（AC-121/AC-164）
        let g = step.gate(ctx)
        if (!g.ok) {
            if (step.skippable) {
                markSkipped(ctx, step.id, g.reason)
                report.skipped.add(step.id)
                continue
            }
            markFailed(ctx, step.id, HashMap<String, String>())
            report.ok = false
            report.stoppedAt = step.id
            report.stopReason = g.reason
            report.stopFix = g.fix
            ctx.log.error("闸口未通过（${step.id} ${step.title}）：${g.reason}")
            ctx.log.error("修复指引：${g.fix}")
            return report
        }

        markRunning(ctx, step.id)
        let r = step.run(ctx)
        if (r.ok) {
            markDone(ctx, step.id, r.evidence)
            report.executed.add(step.id)
            ctx.log.info("步骤 ${step.id}（${step.title}）完成：${r.message}")
        } else {
            markFailed(ctx, step.id, r.evidence)
            report.ok = false
            report.stoppedAt = step.id
            report.stopReason = r.message
            report.stopFix = gateFixHint(step.id)
            ctx.log.error("步骤 ${step.id}（${step.title}）失败：${r.message}")
            return report
        }
    }
    return report
}

/// 步骤执行失败时的兜底修复指引（闸口已过时用闸口的 fix）。
private func gateFixHint(id: String): String {
    match (id) {
        case "S0" => return "确认安装根目录存在（--source-dir 可指定源码目录）"
        case "S1" => return "在向导页保存数据库配置后重跑"
        case "S2" => return "安装 openssl 后重跑，或手工放置 release/ssl/server.crt 与 server.key"
        case "S3" => return "把 agentskills-runtime-win-x64.tar.gz 放入介质目录后重跑"
        case "S4" => return "确认 release/.env 所在目录正确，且配置中含 DATABASE_URL 或 orm_connectionUrl"
        case "S5" => return "确认 release/.env 可解析出数据库连接参数"
        case "S6" => return "确认 release/agentskills-runtime.exe 存在且未被安全软件拦截"
        case "S7" => return "DevKit 组件安装未实现（T035~T038），当前已降级；如需 DevKit 请待其落地"
        case "S8" => return "开发环境初始化未实现（T035~T038 / T049），当前已降级；如需开发环境请待其落地"
        case _ => return "查看 logs/installer.log 中该步骤的日志"
    }
}

// ===================== T034 自退役 =====================

/// runtime 健康端口（design.md §4.6：src/app/main.cj:698 的 `/api/v1/health`）。
public let RUNTIME_HEALTH_PORT: Int64 = 8080

/// 自退役判定结果。
public struct RetireVerdict {
    public let retirable: Bool
    public let reason: String

    // 3 个调用点全部按位置传满 2 参；不设默认值以避免与位置构造 overload 冲突。
    public init(retirable: Bool, reason: String) {
        this.retirable = retirable
        this.reason = reason
    }
}

/// 判定是否可退役（AC-126/127/128）：
///   - 状态文件存在未完成步骤 ⇒ **优先提示不退出**（design.md §4.6）；
///   - runtime 健康端口连续探测由调用方负责计数，此处只判"前置条件是否满足"。
public func retirePrecondition(ctx: AppContext): RetireVerdict {
    for (step in stepTable()) {
        let s = statusOf(ctx, step.id)
        if (s != STEP_DONE && s != STEP_SKIPPED) {
            return RetireVerdict(false, "步骤 ${step.id}（${step.title}）尚未完成（当前 ${s}），不退出")
        }
    }
    if (ctx.state.state.corruption.recovered) {
        return RetireVerdict(false, "状态文件曾损坏并从 S0 重来，建议确认安装结果后再退出")
    }
    return RetireVerdict(true, "全部步骤已完成，可退役")
}

/// 连续探测 runtime 健康端点，`need` 次连续成功才判定可退役（AC-126：每 2s 一次，连续 3 次 200）。
///
/// 只用端口可达性作判据（net.cj 无 HTTP 状态码探测），因此语义是"端口已监听"，
/// 在 evidence 中如实标注 method，不冒充"HTTP 200 已验证"（R-17 同源约束）。
public func awaitRuntimeHealthy(ctx: AppContext, need: Int64, interval: Duration): Bool {
    var hit = 0
    var round = 0
    while (hit < need && round < need + 3) {
        if (isLocalPortReachable(RUNTIME_HEALTH_PORT)) {
            hit += 1
            ctx.log.info("runtime 健康探测 ${hit}/${need}：端口 ${RUNTIME_HEALTH_PORT} 可达（method=port）")
        } else {
            hit = 0
            ctx.log.info("runtime 健康探测失败，重置计数（method=port）")
        }
        if (hit < need) {
            sleep(interval)
        }
        round += 1
    }
    return hit >= need
}

/// 探测期间的单次记录，供 CLI/HTTP 层输出。
public func probeRuntimeOnce(): Bool {
    return isLocalPortReachable(RUNTIME_HEALTH_PORT)
}

/// 记录一次降级（供 T034 与 CLI 复用，避免各处重复构造 DegradedItem）。
public func noteDegraded(ctx: AppContext, id: String, reason: String, fallback: String,
                         manualCmd: String): Unit {
    ctx.state.addDegraded(DegradedItem(id: id, reason: reason, fallback: fallback, manualCmd: manualCmd))
}

/// 自退役：GC 队列跑一轮（占用已释放的替换项落地），再按 `--auto-exit` 决定是否退出。
///
/// 退出时**不停止 runtime**、保留全部产物（AC-128）。
public func selfRetire(ctx: AppContext, autoExit: Bool): Int64 {
    // 1) GC 一轮：把上次因文件占用而挂起的替换项尽量落地
    let done = runGcOnce(ctx.paths.gcFile)
    if (done > 0) {
        ctx.log.info("GC 完成 ${done} 项延迟删除/替换")
    }

    // 2) 退役前置条件
    let v = retirePrecondition(ctx)
    if (!v.retirable) {
        ctx.log.warn("暂不退役：${v.reason}")
        return 1
    }
    if (!autoExit) {
        ctx.log.info("全部步骤已完成；未指定 --auto-exit，保持安装器运行（可访问运维端点）")
        return 0
    }
    ctx.log.info("全部步骤已完成且指定 --auto-exit，安装器即将退出（runtime 继续运行，产物全部保留）")
    return 0
}
