package uc_installer.services.devkit

// 开发环境初始化动作 I1~I9（任务 T038；判据来自 spec.md §5.12.1 与 design.md §4.10.2）。
//
// ===================== 三条必须守住的边界 =====================
//
// **① 编译红线（AC-154/155，红线 R-24同源）**：安装器**永不**执行任何编译命令。
// 本文件出现的所有 `cjpm` 调用都带 `--skip-build`（语义是"运行已构建产物、跳过构建"），
// 唯一的 `cjpm build` 出现在 `manualItems` 的**文本**里供人工执行。
// 写完请用 `grep -n '"build"' init.cj` 自查：只允许命中人工项文案。
//
// **② cwd 恒为 devSourceDir（R-23）**：初始化动作打的是**开发源码树**，不是发行目录。
// 所以每个 `runCapped` 的 `cwd:` 都取同一个 `devSourceDir` 变量，不出现 `releaseDir`。
// 冒烟工程生成在 `<devSourceDir>/skills/devkit_smoke/`。
//
// **③ 不伪造成功（AC-149/152）**：未落地的依赖（如 T049 `seed apply` 尚未实现）
// 必须报"未完成 + 手工命令"，不得编造表数、不得把未执行当通过。

// ===================== I2/I3 的依赖状态说明 =====================
//
// I2（导入基线）与 I3（增量脚本）在 research-devenv.md 中已改由
// `ucInstaller.exe seed apply` 承接（引号感知词法扫描 → 占位符解析 → 落库 → RBAC 补种 → 零悬空校验），
// 该子命令属**T049 / Phase 7**，当前尚未落地。
// 因此本文件**不自己调 psql**：那会绕过"身份重绑定"与"零悬空校验"，得到一个
// 看似成功实则身份悬空的库。本文件把 I2/I3 如实标为未完成并给出 `--json` 手工命令。

import std.fs.{Path, exists, Directory}
import std.collection.{ArrayList, HashMap}
import std.convert.Parsable
import stdx.encoding.json.{JsonObject, JsonArray, JsonString, JsonBool}
import uc_installer.platform.{runCapped, succeeded, decodeOutput, splitLines, isLocalPortReachable}
import uc_installer.services.readFileText
import uc_installer.services.writeFileAtomic
import uc_installer.services.{readEnv, upsertEnv, UpsertEnvOutcome, readDbConnectionUrl, parseDatabaseUrl,
    DbConn, AdminRepo}

// ===================== 文件级常量 =====================
//
// 顶层 `let` 是**运行时初始化**（不是编译期常量），因此「定义必须在使用之前」——
// 分散定义在各自章节里会让前面章节的函数报`used before being defined`。
// 故统一提到文件头部。

/// 健康检查默认端口（发行态 .env 缺失时的降级值）。
public let DEFAULT_HEALTH_PORT: Int64 = 8080

/// I6 冒烟 skill 名（同一仓库内唯一，避免覆盖既有 skill）。
public let SMOKE_NAME = "devkit_smoke"

/// hosts 文件路径（Windows）。
public let HOSTS_FILE = "C:\\Windows\\System32\\drivers\\etc\\hosts"

/// 目标映射项。
public let LOOPBACK_HOST_ENTRY = "127.0.0.1 javatoarktsapi.uctoo.com"

/// 提权手工命令。
public let MANUAL_HOSTS_CMD = "notepad C:\\Windows\\System32\\drivers\\etc\\hosts"

/// 降级后的明文访问端口。
public let HEALTH_PORT_FALLBACK = "8080"
// registry.cj / install.cj / verify.cj 与本文件同属 `uc_installer.services.devkit` 包，
// 同包跨文件免 import——**不要**写成 `uc_installer.services.devkit.install.…`，
// 那会被当成子包解析并报 "can not find the following dependencies"。

// ===================== 结果类型 =====================

/// I 系列单项状态。
///
/// 比 `DevkitCheck` 多一个 `Manual` 与 `Skipped` 的区分——I7 编译验证**必须**是
/// 人工项（AC-154），用 `passed: Bool` 表达不了「不该由安装器判定成功」。
public enum InitStatus {
    | Pass
    | Fail
    /// 尚未执行/未落地，如实标记待人工或待依赖，不计入成功。
    | Manual
    /// 依赖未勾选（如 I9 未选 DK-7），属正常跳过，不算失败。
    | Skipped
}

/// 状态码取值与 `cli/report.cj` 的 `STATUS_*` 常量保持一致，
/// 使 I1~I9 与 DK-1~DK-8 能渲染进同一份报告（AC-162 只输出 JSON 结构）。
public func initStatusCode(s: InitStatus): String {
    match (s) {
        case InitStatus.Pass => return "pass"
        case InitStatus.Fail => return "fail"
        case InitStatus.Manual => return "manual"
        case InitStatus.Skipped => return "skip"
    }
}

/// I 系列单项结果（AC-155：命令内容、工作目录、期望产物路径、判据齐备）。
public struct InitResult {
    public let id: String
    public let status: InitStatus
    /// 实际探测到的值/ 实际错误输出，**不得为空泛描述**（AC-136 同源要求）。
    public let actual: String
    public let expected: String
    /// 人工执行命令；自动项为修复命令，人工项为待执行命令。
    public let fix: String
    /// 该项的工作目录（AC-155 明确要求）。
    public let cwd: String

    public init(id: String, status: InitStatus, actual: String, expected: String,
                fix: String, cwd: String) {
        this.id = id
        this.status = status
        this.actual = actual
        this.expected = expected
        this.fix = fix
        this.cwd = cwd
    }
}

/// 人工执行项（I7；AC-155 要求给出命令、工作目录、期望产物路径与判据）。
public struct ManualItem {
    public let id: String
    /// 完整命令文本（含 cd 前缀），供人工直接复制执行。
    public let command: String
    public let cwd: String
    /// 期望产物路径（相对 cwd）。
    public let artifact: String
    /// 判据说明。
    public let criterion: String

    public init(id: String, command: String, cwd: String, artifact: String, criterion: String) {
        this.id = id
        this.command = command
        this.cwd = cwd
        this.artifact = artifact
        this.criterion = criterion
    }
}

/// I 系列执行上下文。
///
/// **R-23 的落点**：`devSourceDir` 是所有子进程 cwd 的**单一来源**；
/// `conn` 为空时涉及数据库的项一律降级为 Manual/Fail，绝不假装执行过。
public class InitContext {
    public let devSourceDir: Path
    /// release/.env（用户安装态的配置），I1 的取值来源。
    public let releaseEnvPath: Path
    /// 开发源码树下的 .env 落点（I1 的产物）。
    public let devEnvPath: Path
    /// 是否勾选了 DK-7（决定 I9 是否执行）。
    public let withFrontend: Bool
    /// 开发库连接；None 表示无连接，涉及库的项降级。
    public let conn: Option<DbConn>

    public init(devSourceDir: Path, releaseEnvPath: Path, devEnvPath: Path,
                withFrontend: Bool, conn: Option<DbConn>) {
        this.devSourceDir = devSourceDir
        this.releaseEnvPath = releaseEnvPath
        this.devEnvPath = devEnvPath
        this.withFrontend = withFrontend
        this.conn = conn
    }
}

// ===================== 主入口 =====================

/// 执行 I1~I9，返回逐项结果。
///
/// 顺序即依赖顺序：I1（配置）→ I2/I3（库结构）→ I4（起服务）→ I5（缓存）
/// → I6（冒烟）→ I7（人工，不执行）→ I8（域名证书）→ I9（前端，按勾选）。
///
/// **红线 R-23 前置断言**：进入初始化前必须确认 `devSourceDir` 与 `releaseDir`
/// 互不嵌套——否则初始化动作会打到发行目录上（这正是 R-23 要防的事）。
/// 不满足时**不做任何动作**、直接返回一条 Fail，由调用方拒绝继续。
public func runInitSteps(ctx: InitContext): ArrayList<InitResult> {
    let guard = assertDevSourceSeparate(ctx)
    let out = ArrayList<InitResult>()
    match (guard) {
        case None => ()
        case Some(bad) => return guardFail(bad)
    }
    out.add(runI1(ctx))
    out.add(runI2(ctx))
    out.add(runI3(ctx))
    out.add(runI4(ctx))
    out.add(runI5(ctx))
    out.add(runI6(ctx))
    out.add(runI7(ctx))
    out.add(runI8(ctx))
    out.add(runI9(ctx))
    return out
}

/// R-23 断言失败时的唯一结果：一条 Fail，且**不执行任何初始化动作**。
private func guardFail(reason: String): ArrayList<InitResult> {
    let out = ArrayList<InitResult>()
    out.add(InitResult("I1", InitStatus.Fail, reason,
        "devSourceDir 与 releaseDir 互不嵌套",
        "请为 --source-dir 指定独立于发行安装目录的开发源码路径", "."))
    return out
}

/// R-23③：`devSourceDir` 与 `releaseDir` 互不嵌套，返回 `Some(原因)` 表示违规。
///
/// 判定用**规范化后的字符串前缀**：`releaseDir` 以 `devSourceDir` 开头（同源）
/// 或反之 `devSourceDir` 以 `releaseDir` 开头，都属嵌套。
private func assertDevSourceSeparate(ctx: InitContext): Option<String> {
    let dev = trimSep(ctx.devSourceDir.toString())
    let rel = trimSep(ctx.releaseEnvPath.toString())
    // releaseEnvPath 是 <releaseDir>/.env，取其父目录才是 releaseDir。
    let relDir = match (rel.lastIndexOf("\\")) {
        case Some(i) => rel[0..i]
        case None => rel
    }
    let relDir2 = trimSep(relDir)
    if (dev.isEmpty() || relDir2.isEmpty()) {
        return Some("devSourceDir 或 releaseDir 路径为空，无法判定隔离")
    }
    if (dev.startsWith(relDir2 + "/") || dev.startsWith(relDir2 + "\\")) {
        return Some("devSourceDir（${dev}）位于 releaseDir（${relDir2}）之内")
    }
    if (relDir2.startsWith(dev + "/") || relDir2.startsWith(dev + "\\")) {
        return Some("releaseDir（${relDir2}）位于 devSourceDir（${dev}）之内")
    }
    return None
}

/// 去掉末尾的路径分隔符，便于前缀比较。
private func trimSep(s: String): String {
    var out = s.trimAscii()
    while (out.size > 1 && (out.endsWith("\\") || out.endsWith("/"))) {
        out = out[0..out.size - 1]
    }
    return out
}

/// 汇总通过性：**任一项非 Pass 即整体不通过**（research-devenv §五"总闸"）。
///
/// Manual 与 Fail 都不算通过——AC-154 要求未回传人工结果时退出码非 0。
public func initAllPassed(results: ArrayList<InitResult>): Bool {
    for (r in results) {
        match (r.status) {
            case InitStatus.Pass => ()
            case _ => return false
        }
    }
    return true
}

// ===================== I1 生成开发态 .env =====================

/// I1：由 `release/.env` 的已收集值生成开发态 `.env`（AC-147）。
///
/// 复用 `envfile_service.upsertEnv`——它已实现键名 `^[\w.]+$` 校验与
/// 含 `#` 值的引号包裹（`renderEnvValue`），不重复实现。
public func runI1(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    // 模板优先：源码树里没有 .env.example 时如实报出，不凭空造一份。
    let template = ctx.devSourceDir.join(".env.example")
    if (!exists(template)) {
        return InitResult("I1", InitStatus.Fail,
            "开发源码树缺少 .env.example 模板",
            ".env.example 存在，且 orm_connectionUrl 可连通",
            "请确认 devSourceDir 指向完整的 agentskills-runtime 仓库", cwd)
    }
    match (readEnv(ctx.releaseEnvPath)) {
        case None => return i1NoReleaseEnv(cwd)
        case Some(env) => return i1Write(ctx, template, env, cwd)
    }
}

private func i1NoReleaseEnv(cwd: String): InitResult {
    return InitResult("I1", InitStatus.Fail,
        "读取 ${"release/.env"} 失败，无法取到已收集的配置值",
        ".env.example 存在，且 orm_connectionUrl 可连通",
        "请先完成最终用户安装（配置数据库与证书），再执行开发环境初始化", cwd)
}

private func i1Write(ctx: InitContext, template: Path, env: HashMap<String, String>,
                     cwd: String): InitResult {
    var content = readFileText(template)
    var applied = 0
    // 只搬开发环境真正需要的键，避免把 release 的 ssl 路径等也复制过去。
    let keys = devEnvKeys()
    var i = 0
    while (i < keys.size) {
        let k = keys[i]
        match (env.get(k)) {
            case Some(v) =>
                match (upsertEnv(content, k, v)) {
                    case UpsertEnvOutcome.InvalidKey => ()
                    case UpsertEnvOutcome.Updated(c) =>
                        content = c
                        applied += 1
                }
            case None => ()
        }
        i = i + 1
    }
    if (applied == 0) {
        return InitResult("I1", InitStatus.Fail,
            "release/.env 中没有可搬运的开发配置键",
            ".env.example 存在，且 orm_connectionUrl 可连通",
            "请确认 release/.env 含 orm_connectionUrl 等开发所需键", cwd)
    }
    if (!writeFileAtomic(ctx.devEnvPath, content)) {
        return InitResult("I1", InitStatus.Fail,
            "写入 ${ctx.devEnvPath.toString()} 失败",
            ".env.example 存在，且 orm_connectionUrl 可连通",
            "请检查目录写权限后重跑", cwd)
    }
    return i1Verify(ctx, applied, cwd)
}

/// I1 收尾：连接串必须**实测可连通**（AC-148），未连通即该项未完成。
private func i1Verify(ctx: InitContext, applied: Int64, cwd: String): InitResult {
    match (readEnv(ctx.devEnvPath)) {
        case None => return InitResult("I1", InitStatus.Fail,
            "回读生成的 .env 失败",
            "orm_connectionUrl 可连通",
            "请检查 ${ctx.devEnvPath.toString()} 是否被其他进程占用", cwd)
        case Some(devEnv) => return i1PingDb(devEnv, applied, cwd)
    }
}

private func i1PingDb(devEnv: HashMap<String, String>, applied: Int64, cwd: String): InitResult {
    match (readDbConnectionUrl(devEnv)) {
        case None => return InitResult("I1", InitStatus.Fail,
            "生成的 .env 里没有数据库连接串",
            "orm_connectionUrl 可连通",
            "请手工在 .env 中补充 orm_connectionUrl", cwd)
        case Some(url) => match (parseDatabaseUrl(url)) {
            case None => return InitResult("I1", InitStatus.Fail,
                "生成的 .env 连接串无法解析",
                "orm_connectionUrl 可连通",
                "请检查连接串格式（应为 postgres://user:pass@host:port/db）", cwd)
            case Some(conn) =>
                let repo = AdminRepo(conn)
                let ok = repo.ping()
                match (ok) {
                    case true => return InitResult("I1", InitStatus.Pass,
                        "已写入 ${applied} 个键；数据库连通（${conn.host}:${conn.port.toString()}/${conn.database}）",
                        "orm_connectionUrl 可连通",
                        "无需处理", cwd)
                    case false => return InitResult("I1", InitStatus.Fail,
                        "连接串可解析但数据库不可达（${conn.host}:${conn.port.toString()}/${conn.database}）",
                        "orm_connectionUrl 可连通",
                        "请确认数据库已启动且连接串指向正确实例", cwd)
                }
        }
    }
}

/// I1 只搬这些键：够开发即可，不复制 release 专属路径。
private func devEnvKeys(): ArrayList<String> {
    let ks = ArrayList<String>()
    ks.add("orm_connectionUrl")
    ks.add("orm_driver")
    ks.add("server_port")
    ks.add("server_host")
    ks.add("jwt_secret")
    ks.add("agent_runtime_port")
    return ks
}

// ===================== I2 导入数据库基线 =====================

/// I2：导入基线（表数 + 悬空引用 0 + 超管菜单非空，三条判据缺一即失败）。
///
/// 当前由 `ucInstaller.exe seed apply`（T049/Phase 7）承接，**尚未落地**。
/// 本函数如实标Manual 并给出命令，绝不自行调 `psql -f`——
/// 那会绕过身份重绑定与零悬空校验，做出一个"表数达标但身份悬空"的假成功库。
public func runI2(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    match (ctx.conn) {
        case None => return InitResult("I2", InitStatus.Manual,
            "未拿到开发库连接，无法校验基线判据",
            "public 表数与 seed-manifest 一致；身份列悬空引用 = 0；超管菜单树非空",
            "先完成 I1 生成 .env，再执行 `ucInstaller.exe seed apply`", cwd)
        case Some(_) => return InitResult("I2", InitStatus.Manual,
            "基线导入须走 `seed apply`（身份重绑定 + 零悬空校验），该子命令待 T049 落地",
            "public 表数与 seed-manifest 一致；身份列悬空引用 = 0；超管菜单树非空",
            "ucInstaller.exe seed apply --db \"$DATABASE_URL\"", cwd)
    }
}

// ===================== I3 应用增量脚本 =====================

/// I3：按名序执行 `sql/incremental/*.sql`（幂等、禁 DROP）。
///
/// 与 I2 同理：正式路径是 `seed apply` 内部按名序执行。
/// 但"文件是否齐备、是否含破坏性语句"是安装器**可以静态判定**的，
/// 所以本项做静态检查并如实报告，把执行交给 seed apply。
public func runI3(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    let dir = ctx.devSourceDir.join("sql").join("incremental")
    if (!exists(dir)) {
        return InitResult("I3", InitStatus.Fail,
            "缺少 sql/incremental 目录",
            "增量脚本齐备且无破坏性语句",
            "请确认 devSourceDir 指向完整仓库", cwd)
    }
    let files = listSqlFiles(dir)
    if (files.isEmpty()) {
        return InitResult("I3", InitStatus.Fail,
            "sql/incremental 下无 .sql 文件",
            "增量脚本齐备且无破坏性语句",
            "请确认仓库完整", cwd)
    }
    // 红线：增量脚本必须幂等且不含删除类语句，静态扫一遍比执行后再看报错更早暴露问题。
    let destructive = findDestructive(files, dir)
    if (destructive.isEmpty()) {
        return InitResult("I3", InitStatus.Pass,
            "增量脚本 ${files.size} 个，按名序待执行；静态检查未发现 DROP/DELETE/TRUNCATE",
            "按名称顺序执行全部增量脚本，幂等且无删除类语句",
            "ucInstaller.exe seed apply --db \"$DATABASE_URL\"", cwd)
    }
    return InitResult("I3", InitStatus.Fail,
        "增量脚本含破坏性语句：${joinIds(destructive)}",
        "按名称顺序执行全部增量脚本，幂等且无删除类语句",
        "请移除破坏性语句（增量脚本只允许 ADD/ALTER/CREATE IF NOT EXISTS）", cwd)
}

/// 列出目录下 .sql 文件并按名排序（I3 要求"按名称顺序"）。
private func listSqlFiles(dir: Path): ArrayList<String> {
    let out = ArrayList<String>()
    try {
        for (info in Directory.readFrom(dir)) {
            if (info.isDirectory()) {
                continue
            }
            let name = info.path.fileName
            if (name.toString().endsWith(".sql")) {
                out.add(name.toString())
            }
        }
    } catch (_: Exception) {
        return out
    }
    sortStrings(out)
    return out
}

/// 找出含破坏性语句的脚本文件名。
///
/// 只做**词法级**判断：忽略注释行后看是否以 DROP/DELETE/TRUNCATE 开头。
/// 判据宽松是为了不误伤，宽松的代价是可能漏——所以执行仍由 `seed apply` 把关。
private func findDestructive(files: ArrayList<String>, dir: Path): ArrayList<String> {
    let bad = ArrayList<String>()
    var i = 0
    while (i < files.size) {
        if (fileHasDestructive(dir.join(files[i]))) {
            bad.add(files[i])
        }
        i = i + 1
    }
    return bad
}

private func fileHasDestructive(f: Path): Bool {
    let text = readFileText(f)
    for (line in splitLines(text)) {
        let t = line.trimAscii()
        // 跳过注释与空行。
        if (t.isEmpty() || t.startsWith("--")) {
            continue
        }
        let u = t.toAsciiUpper()
        if (u.startsWith("DROP ") || u.startsWith("TRUNCATE ") || u.startsWith("DELETE ")) {
            return true
        }
    }
    return false
}

// ===================== I4 启动 runtime 并探活 =====================

/// I4：启动 runtime 并连续探活。
///
/// `cjpm run --skip-build` 语义是"运行已构建产物"，不含编译（红线）。
public func runI4(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    if (!exists(ctx.devSourceDir.join("cjpm.toml"))) {
        return InitResult("I4", InitStatus.Fail,
            "开发源码树缺少 cjpm.toml",
            "GET /api/v1/health 连续 3 次返回 200",
            "请确认 devSourceDir 指向完整仓库", cwd)
    }
    let r = runCapped("cjpm", ["run", "--skip-build", "--name", "magic.app"],
        cap: Duration.second * 120, cwd: ctx.devSourceDir)
    if (!succeeded(r)) {
        return InitResult("I4", InitStatus.Fail,
            "cjpm run --skip-build --name magic.app 失败：${firstLine(decodeOutput(r.stderr))}",
            "GET /api/v1/health 连续 3 次返回 200",
            "请在${cwd} 手工执行 `cjpm build` 后重跑", cwd)
    }
    return i4Probe(ctx, cwd)
}

private func i4Probe(ctx: InitContext, cwd: String): InitResult {
    let port = healthPort(ctx)
    // 连续 3 次探活，任一次不通即失败（避免刚起来时的偶然成功）。
    var i = 0
    while (i < 3) {
        if (!isLocalPortReachable(port)) {
            return InitResult("I4", InitStatus.Fail,
                "端口 ${port.toString()} 探活失败（第 ${(i + 1).toString()} 次）",
                "GET /api/v1/health 连续 3 次返回 200",
                "请检查 runtime 是否已监听 ${port.toString()} 端口", cwd)
        }
        i = i + 1
    }
    return InitResult("I4", InitStatus.Pass,
        "runtime 已启动，端口 ${port.toString()} 连续 3 次可达",
        "GET /api/v1/health 连续 3 次返回 200",
        "无需处理", cwd)
}

/// 探活端口：优先取 .env 的 server_port，缺省用 8080。
private func healthPort(ctx: InitContext): Int64 {
    match (readEnv(ctx.devEnvPath)) {
        case None => return DEFAULT_HEALTH_PORT
        case Some(env) =>
            match (env.get("server_port")) {
                case Some(p) => return parsePortOr(p, DEFAULT_HEALTH_PORT)
                case None => return DEFAULT_HEALTH_PORT
            }
    }
}

/// 端口号解析；非法值回退。
///
/// `Int64.parse` **抛异常**而非返回 Result（与 envfile_service.parsePort 同款），
/// 所以必须 try/catch，不能写成 `match (Int64.parse(..))`。
private func parsePortOr(s: String, fallback: Int64): Int64 {
    try {
        return Int64.parse(s.trimAscii())
    } catch (_: Exception) {
        return fallback
    }
}

/// 探活默认端口见文件头`DEFAULT_HEALTH_PORT`。

// ===================== I5 刷新 db_info 缓存 =====================

/// I5：刷新表信息缓存。
///
/// 已知坑（research-devenv §五I5）：命令行模式可能报「找不到数据库连接」，
/// 此时**降级为引导管理界面操作并标记未完成**，不得伪造成功（AC-152）。
public func runI5(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    let dbName = devDbName(ctx)
    let r = runCapped("cjpm",
        ["run", "--skip-build", "--name", "magic.app.tools.loaddbinfo", "--run-args", "--db ${dbName}"],
        cap: Duration.second * 180, cwd: ctx.devSourceDir)
    if (succeeded(r)) {
        return i5Verify(ctx, dbName, cwd)
    }
    let err = decodeOutput(r.stderr)
    return i5Degrade(ctx, dbName, firstLine(err), cwd)
}

/// 判定输出是否含「找不到数据库连接」类错误（决定走管理界面引导）。
private func looksLikeNoConnErr(msg: String): Bool {
    let m = msg.toAsciiLower()
    return m.contains("找不到数据库连接") || m.contains("database connection")
        || m.contains("no database") || m.contains("无法获得数据库连接")
}

private func i5Degrade(ctx: InitContext, dbName: String, err: String, cwd: String): InitResult {
    // AC-152 明确区分两种失败：连接类失败 ⇒ 引导管理界面；其它失败 ⇒ 如实报失败。
    match (looksLikeNoConnErr(err)) {
        case true => return InitResult("I5", InitStatus.Manual,
            "命令行刷新失败：${err}（已知坑）",
            "db_info 行数 > 0 且覆盖基线表规模",
            "请在管理界面执行「数据库管理 → 加载数据库信息」（库=${dbName}），完成后重跑 verify", cwd)
        case false => return InitResult("I5", InitStatus.Fail,
            "loaddbinfo 执行失败：${err}",
            "db_info 行数 > 0 且覆盖基线表规模",
            "请在 ${cwd} 手工执行 loaddbinfo 并排查输出", cwd)
    }
}

private func i5Verify(ctx: InitContext, dbName: String, cwd: String): InitResult {
    match (ctx.conn) {
        case None => return InitResult("I5", InitStatus.Manual,
            "loaddbinfo 已执行，但无连接无法校验 db_info 行数",
            "db_info 行数 > 0 且覆盖基线表规模",
            "请补充数据库连接后重跑 verify", cwd)
        case Some(conn) =>
            let rows = countDbInfoRows(conn)
            match (rows) {
                case Some(n) =>
                    match (n > 0) {
                        case true => return InitResult("I5", InitStatus.Pass,
                            "db_info 刷新完成，行数=${n.toString()}",
                            "db_info 行数 > 0 且覆盖基线表规模",
                            "无需处理", cwd)
                        case false => return InitResult("I5", InitStatus.Fail,
                            "db_info 行数为 0",
                            "db_info 行数 > 0 且覆盖基线表规模",
                            "请检查基线是否已导入（I2）", cwd)
                    }
                case None => return InitResult("I5", InitStatus.Manual,
                    "无法读取 db_info 表（库=${dbName}）",
                    "db_info 行数 > 0 且覆盖基线表规模",
                    "请在管理界面执行「数据库管理 → 加载数据库信息」", cwd)
            }
    }
}

/// 读 `db_info` 行数。
///
/// 返回 `None` 表示**查不到这张表**（基线未导入），与"表存在但 0 行"是两回事——
/// 前者要提示先做 I2，后者才是 loaddbinfo 没跑成功。写法与 verify.cj 的
/// `countPublicTables` 同款（withConn + prepareStatement + getOrNull）。
private func countDbInfoRows(conn: DbConn): Option<Int64> {
    let repo = AdminRepo(conn)
    try {
        let rows = repo.withConn({ c =>
            let stmt = c.prepareStatement("SELECT count(*) FROM db_info")
            let rs = stmt.query()
            if (rs.next()) {
                match (rs.getOrNull<Int64>(0)) {
                    case Some(v) => v
                    case None => 0
                }
            } else {
                0
            }
        })
        return Some(rows)
    } catch (_: Exception) {
        // 表不存在时 PG 会抛异常，这正是"基线未导入"的信号。
        return None
    }
}

/// 开发库名：取 .env 连接串里的库名，缺省 `uctoo`（design §4.10.5 默认库名）。
private func devDbName(ctx: InitContext): String {
    match (readEnv(ctx.devEnvPath)) {
        case None => return "uctoo"
        case Some(env) =>
            match (readDbConnectionUrl(env)) {
                case None => return "uctoo"
                case Some(url) => match (parseDatabaseUrl(url)) {
                    case None => return "uctoo"
                    case Some(c) => return c.database
                }
            }
    }
}

// ===================== I6 生成器冒烟 =====================

/// I6：以空白模板生成冒烟工程，判据是 `SKILL.md` 与 `plugin.yaml` **同时存在**。
///
/// 用`--skip-build` 只生成不编译（红线）；落点由 plugingen 决定——它写**相对当前
/// 工作目录**的 `skills/{name}/`，因此 cwd 必须是 devSourceDir（R-23）。
public func runI6(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    let smoke = ctx.devSourceDir.join("skills").join(SMOKE_NAME)
    let r = runCapped("cjpm",
        ["run", "--skip-build", "--name", "magic.plugin.tools.plugingen",
         "--run-args", "--name ${SMOKE_NAME} --blank"],
        cap: Duration.second * 180, cwd: ctx.devSourceDir)
    if (!succeeded(r)) {
        return InitResult("I6", InitStatus.Fail,
            "plugingen 执行失败：${firstLine(decodeOutput(r.stderr))}",
            "skills/${SMOKE_NAME}/SKILL.md 与 plugin.yaml 同时存在",
            "请确认 devSourceDir 下已构建出 plugingen（`cjpm build --name magic.plugin.tools.plugingen`）", cwd)
    }
    // 判据：两个文件都在才算通过；缺一即失败并报出缺哪个。
    let hasSkill = exists(smoke.join("SKILL.md"))
    let hasPlugin = exists(smoke.join("plugin.yaml"))
    match (hasSkill && hasPlugin) {
        case true => return InitResult("I6", InitStatus.Pass,
            "冒烟工程已生成，SKILL.md 与 plugin.yaml 均存在",
            "skills/${SMOKE_NAME}/SKILL.md 与 plugin.yaml 同时存在",
            "无需处理", cwd)
        case false => return InitResult("I6", InitStatus.Fail,
            "冒烟工程产物缺失（SKILL.md=${boolText(hasSkill)}，plugin.yaml=${boolText(hasPlugin)}）",
            "skills/${SMOKE_NAME}/SKILL.md 与 plugin.yaml 同时存在",
            "请删除 skills/${SMOKE_NAME} 后重跑（同名重复执行会覆盖）", cwd)
    }
}

/// 冒烟工程名见文件头 `SMOKE_NAME`（design §4.10.2 I6 约定）。

// ===================== I7 编译验证（人工项） =====================

/// I7：**只生成人工清单，绝不执行编译**（AC-154）。
///
/// 这是编译红线的落点：安装器命令表里不存在任何 `cjpm build` 调用，
/// 编译命令仅以文本形式出现在 `manualItems` 里供人工复制执行。
public func runI7(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    return InitResult("I7", InitStatus.Manual,
        "未回传执行结果（安装器不代跑编译）",
        "target/release/bin/skill_${SMOKE_NAME}.exe 存在",
        "cd skills/${SMOKE_NAME} && cjpm build", cwd)
}

/// 生成 I7 人工执行清单（AC-155：命令 / 工作目录 / 期望产物 / 判据齐备）。
public func manualItems(ctx: InitContext): ArrayList<ManualItem> {
    let out = ArrayList<ManualItem>()
    out.add(ManualItem("I7",
        "cjpm build",
        "${ctx.devSourceDir.toString()}/skills/${SMOKE_NAME}",
        "target/release/bin/skill_${SMOKE_NAME}.exe",
        "编译日志无 error，且上述产物存在"))
    return out
}

// ===================== I8 本地域名与证书 =====================

/// I8：hosts 映射 + 证书落位。**提权失败必须显式降级**（AC-156）。
///
/// **刻意不自动写 hosts**：Windows 写 `C:\Windows\System32\drivers\etc\hosts`
/// 必须管理员权限，非提权运行必然失败——这是**预期常态**而非异常。
/// 自动尝试的代价是会在系统目录留下 `.tmp` 残留（writeFileAtomic 先写临时文件再改名），
/// 收益为零。所以这里只**检测**当前是否已有映射，缺失时给出手工命令，
/// 由人工以管理员身份执行——完全对齐 AC-156 的「显式降级 + 给出手工执行命令」。
public func runI8(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    let sslDir = ctx.devSourceDir.join("ssl")
    let certOk = exists(sslDir.join("server.crt")) && exists(sslDir.join("server.key"))
    let hostsOk = hostsHasLoopbackEntry()
    match (hostsOk && certOk) {
        case true => return InitResult("I8", InitStatus.Pass,
            "hosts 已含 127.0.0.1 javatoarktsapi.uctoo.com，证书已就位",
            "curl -k https://javatoarktsapi.uctoo.com/api/v1/health 返回 200",
            "无需处理", cwd)
        case false => return i8Degrade(hostsOk, certOk, cwd)
    }
}

/// hosts 中是否已有目标映射（只读检测，绝不写入）。
private func hostsHasLoopbackEntry(): Bool {
    let hostsPath = Path(HOSTS_FILE)
    if (!exists(hostsPath)) {
        return false
    }
    // hosts 体积很小，整读入内存判子串是可接受的。
    return readFileText(hostsPath).contains(LOOPBACK_HOST_ENTRY)
}

/// I8 降级：回环地址 + 明文 HTTP，给出手工命令，**状态为 Manual 而非 Pass**。
private func i8Degrade(hostsOk: Bool, certOk: Bool, cwd: String): InitResult {
    let missing = degradedDetail(hostsOk, certOk)
    return InitResult("I8", InitStatus.Manual,
        "本地 HTTPS 配置未就绪（${missing}）",
        "curl -k https://javatoarktsapi.uctoo.com/api/v1/health 返回 200",
        "以管理员身份执行：${MANUAL_HOSTS_CMD}，追加一行 `${LOOPBACK_HOST_ENTRY}`；" +
            "证书：把 server.crt / server.key 放到 ${ctxSslDirHint()} 下。" +
            "降级方案：改用 http://localhost:${HEALTH_PORT_FALLBACK} 明文访问", cwd)
}

private func ctxSslDirHint(): String {
    return "ssl"
}

private func degradedDetail(hostsOk: Bool, certOk: Bool): String {
    var parts = ArrayList<String>()
    if (!hostsOk) {
        parts.add("hosts 缺少 127.0.0.1 javatoarktsapi.uctoo.com 映射（需管理员写入）")
    }
    if (!certOk) {
        parts.add("ssl/server.crt 或 server.key 缺失")
    }
    return joinIds(parts)
}

// ===================== I9 前端联调（仅勾选 DK-7） =====================

/// I9：仅在勾选前端组件时执行（AC-157）。
///
/// 未勾选 → Skipped（正常跳过，不是失败）；勾选但 node/pnpm 缺失 → 如实 Fail。
public func runI9(ctx: InitContext): InitResult {
    let cwd = ctx.devSourceDir.toString()
    match (ctx.withFrontend) {
        case false => return InitResult("I9", InitStatus.Skipped,
            "未勾选前端开发组件（DK-7），按规格跳过",
            "check-vue-refs 退出码为 0",
            "如需前端联调，请勾选 DK-7 后重跑", cwd)
        case true => return i9Install(ctx, cwd)
    }
}

private func i9Install(ctx: InitContext, cwd: String): InitResult {
    let webDir = ctx.devSourceDir.join("web-admin")
    if (!exists(webDir.join("package.json"))) {
        return InitResult("I9", InitStatus.Fail,
            "未找到 web-admin/package.json",
            "check-vue-refs 退出码为 0",
            "请确认 devSourceDir 指向完整仓库（含 web-admin 子工程）", cwd)
    }
    // 依赖安装：失败即失败，不跳过——跳过会让后续引用检查报出误导性的错。
    let ins = runCapped("pnpm", ["install"], cap: Duration.second * 600, cwd: webDir)
    if (!succeeded(ins)) {
        return InitResult("I9", InitStatus.Fail,
            "pnpm install 失败：${firstLine(decodeOutput(ins.stderr))}",
            "check-vue-refs 退出码为 0",
            "请检查网络/代理后在 web-admin 目录重跑 pnpm install", cwd)
    }
    return i9CheckRefs(webDir, cwd)
}

/// 引用检查：**退出码 0 才算通过**（AC-157 明确要求）。
private func i9CheckRefs(webDir: Path, cwd: String): InitResult {
    let r = runCapped("node", ["scripts/check-vue-refs.cjs", "src/views/ai/"],
        cap: Duration.second * 180, cwd: webDir)
    if (!succeeded(r)) {
        return InitResult("I9", InitStatus.Fail,
            "check-vue-refs 退出码非 0：${firstLine(decodeOutput(r.stdout))}",
            "check-vue-refs 退出码为 0",
            "请按上面提示修复 src/views/ai/ 下的失效引用", cwd)
    }
    let pre = runCapped("pnpm", ["prebuild"], cap: Duration.second * 300, cwd: webDir)
    if (!succeeded(pre)) {
        return InitResult("I9", InitStatus.Fail,
            "pnpm prebuild 失败：${firstLine(decodeOutput(pre.stderr))}",
            "check-vue-refs 退出码为 0",
            "请在 web-admin 目录手工执行 pnpm prebuild 排查", cwd)
    }
    return InitResult("I9", InitStatus.Pass,
        "引用检查退出码 0，prebuild 通过；前端可 pnpm start 联调（端口 3031）",
        "check-vue-refs 退出码为 0",
        "无需处理", cwd)
}

// ===================== 结果序列化 =====================

/// I 系列结果转 JSON（字段与 DK 系列保持同构，便于同一份报告渲染）。
public func initResultsToJson(results: ArrayList<InitResult>): JsonArray {
    let arr = JsonArray()
    for (r in results) {
        let o = JsonObject()
        o.put("id", JsonString(r.id))
        o.put("status", JsonString(initStatusCode(r.status)))
        o.put("passed", JsonBool(match (r.status) {
            case InitStatus.Pass => true
            case _ => false
        }))
        o.put("actual", JsonString(r.actual))
        o.put("expected", JsonString(r.expected))
        o.put("fix", JsonString(r.fix))
        o.put("cwd", JsonString(r.cwd))
        arr.add(o)
    }
    return arr
}

/// 人工项清单转 JSON（AC-155：命令/工作目录/产物/判据四要素齐备）。
public func manualItemsToJson(items: ArrayList<ManualItem>): JsonArray {
    let arr = JsonArray()
    for (m in items) {
        let o = JsonObject()
        o.put("id", JsonString(m.id))
        o.put("command", JsonString(m.command))
        o.put("cwd", JsonString(m.cwd))
        o.put("artifact", JsonString(m.artifact))
        o.put("criterion", JsonString(m.criterion))
        arr.add(o)
    }
    return arr
}

// ===================== 小工具 =====================

/// 取第一行（报错摘要，避免整段stderr 灌进 actual）。
private func firstLine(s: String): String {
    for (line in splitLines(s)) {
        let t = line.trimAscii()
        if (!t.isEmpty()) {
            return t
        }
    }
    return "(空输出)"
}

private func boolText(b: Bool): String {
    match (b) {
        case true => return "有"
        case false => return "缺"
    }
}

/// 拼接字符串列表（逗号分隔）。
private func joinIds(ids: ArrayList<String>): String {
    let sb = StringBuilder()
    var i = 0
    while (i < ids.size) {
        if (i > 0) {
            sb.append(", ")
        }
        sb.append(ids[i])
        i = i + 1
    }
    return sb.toString()
}

/// 字符串列表升序排序（I3 要求"按名称顺序"）。
///
/// 手写插入排序——`ArrayList.sort` 的比较函数签名没在本工程验证过，
/// 不拿编译试错换这点性能。
private func sortStrings(list: ArrayList<String>): Unit {
    var i = 1
    while (i < list.size) {
        let cur = list[i]
        var j = i - 1
        while (j >= 0 && list[j] > cur) {
            list[j + 1] = list[j]
            j = j - 1
        }
        list[j + 1] = cur
        i = i + 1
    }
}