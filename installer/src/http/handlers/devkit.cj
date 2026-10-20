package uc_installer.http.handlers

// DevKit HTTP 端点（T026 / design.md §4.10 + §6.2.8，对应 AC-131~147）。
//
// 三个端点（design.md §6.1 表 #18~#20）：
//   GET  /setup/devkit/components —— 8 组件清单 + recommended + reason（AC-135/136）
//   POST /setup/devkit/install    —— 按 id 子集安装（AC-131），安装后立即自检（AC-132）
//   GET  /setup/devkit/verify     —— 五字段自检汇总（AC-133/134）
//
// ===================== 三条实现红线 =====================
//
// **① 降级必须显式（R-22 / tasks.md T018~T026）**：磁盘空间探测不到、数据库连不上、
// 组件安装动作未落地 —— 一律在响应的 `degraded[]` 里留痕并给出 fix 命令，
// 绝不允许"悄悄当作成功"。HTTP 一律 200 + `ok:false`（507 只用于磁盘闸口这种硬阻断），
// 退出码语义由 CLI 侧各子命令负责。
//
// **② 自检必须给证据（AC-132/133）**：每项输出 id/status/actual/expected/fix 五字段，
// 未通过时 fix 非空；actual 必须是**探测到的真实值**，不得写"已就绪"这类无证据描述。
//
// **③ 只装被点名的组件（AC-131）**：请求体 `ids` 给什么就装什么，不做"顺手把推荐的全装了"。
// 空 ids 视为 400，不退化成全装。

import http_lib.router.Handler
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.HttpStatus
import std.fs.{Path, exists}
import std.collection.ArrayList
import std.time.DateTime
import std.core.StringBuilder
import stdx.encoding.json.{JsonObject, JsonArray, JsonString, JsonBool, JsonInt}
import uc_installer.core.AppContext
import uc_installer.core.{DEVKIT_INSTALLED, DEVKIT_FAILED, DevkitComponentState}
import uc_installer.util.{jstr, jint, jbool, jobj, jsonOkCode, jsonErr, bodyText,
    jsonParse, asObject, jsonStr, jsonBool, jsonStrList, jsonOptArr}
import uc_installer.services.{readFileText, DbConn, readEnv, readDbConnectionUrl,
    parseDatabaseUrl}
import uc_installer.services.devkit.{DevkitComponent, DevkitCheck, DevkitFacts,
    InstallResult, InstallOutcome, DevkitStatus, InitContext, collectSourceFacts,
    devkitRegistry, devkitComponentById, devkitDepsClosure, devkitTotalSizeMb,
    devkitSizeBreakdown, reqTierCode, devkitStatusCode, installDevkitComponent,
    installOutcomeCode, verifyOne, verifyDevkit, allPassed,
    applyRecommendationsTo, runInitSteps, initAllPassed, initResultsToJson,
    freeSpaceMb, diskGate, diskProbeFailed, requiredMbFor}

// ===================== 端点 =====================

/// `GET /setup/devkit/components`（design.md §6.1 #18）。
///
/// 返回 8 项注册表全字段 + 推荐标记/理由（理由含探测到的实际值，AC-136）
/// + 体量预估与总量（供前端渲染磁盘闸口提示，AC-144）+ 状态文件里已记账的状态。
public func devkitComponentsHandler(ctx: AppContext): Handler {
    return { _ => doComponents(ctx) }
}

/// `POST /setup/devkit/install`（design.md §6.1 #19）。
///
/// 请求：`{ids:[...], sourceDir?, forceNonempty?, withFrontend?}`
/// 流程：入参校验 → 磁盘空间闸口（AC-144）→ 依赖闭包排序 → 逐组件安装 → 安装后立即自检（AC-132）
/// → 写状态文件 → 触发 I1~I9 初始化（T038）。
public func devkitInstallHandler(ctx: AppContext): Handler {
    return { req => doInstall(ctx, req) }
}

/// `GET /setup/devkit/verify`（design.md §6.1 #20 / §6.2.8）。
///
/// 响应 `data.items[]` 为 `{id,status,actual,expected,fix}`，`data.summary` 给出计数。
public func devkitVerifyHandler(ctx: AppContext): Handler {
    return { _ => doVerify(ctx) }
}

// ===================== components =====================

private func doComponents(ctx: AppContext): HttpResponse {
    let dir = ctx.paths.devSourceDir
    let facts = collectSourceFacts(dir)
    let comps = devkitRegistry()
    // 关键：推荐标记必须写在**即将被序列化**的那一份对象上。
    // `devkitRegistry()` 每次调用都新建实例，若在服务层内部另取一份再改字段，
    // 改动会随临时对象被丢弃，这里返回的就全是默认值（AC-135/136 落空）。
    applyRecommendationsTo(comps, dir, facts)

    let items = JsonArray()
    for (c in comps) {
        items.add(componentJson(ctx, c))
    }
    let data = jobj()
    data.put("items", items)
    data.put("total", jint(comps.size))
    data.put("totalSizeMb", jint(devkitTotalSizeMb()))
    data.put("sizeMb", sizeBreakdownJson())
    data.put("mode", jstr(ctx.state.state.mode))
    data.put("devSourceDir", jstr(dir.toString()))
    data.put("disk", diskJson(dir))
    // 磁盘探测不到就是探测不到，如实回吐（红线①），前端据此提示"未校验"而非"空间充足"。
    data.put("degraded", diskDegraded(dir))
    return jsonOkCode(200, "开发套件组件清单", data)
}

/// 单个组件的完整 JSON 形态（注册表九字段 + 记账状态）。
private func componentJson(ctx: AppContext, c: DevkitComponent): JsonObject {
    let o = JsonObject()
    o.put("id", JsonString(c.id))
    o.put("title", JsonString(c.title))
    o.put("tier", JsonString(reqTierCode(c.tier)))
    o.put("sizeMb", JsonInt(c.sizeMb))
    o.put("expected", JsonString(c.expected))
    o.put("fix", JsonString(c.fixCmd))
    o.put("recommended", JsonBool(c.recommended))
    o.put("reason", JsonString(c.reason))
    o.put("status", JsonString(storedStatusOf(ctx, c.id)))
    let deps = JsonArray()
    for (d in c.deps) {
        deps.add(JsonString(d))
    }
    o.put("deps", deps)
    // SDK 类组件必须回显校验和要求来源（AC-139）；其余组件为空串。
    match (c.sha256) {
        case Some(s) => o.put("sha256", JsonString(s))
        case None => o.put("sha256", JsonString(""))
    }
    // AC-143：离线模式下除 DK-1 外全部可从本地预置取，故只有 DK-1 真的需要网络。
    o.put("requiresNetwork", JsonBool(c.id == "DK-1"))
    return o
}

/// 逐组件体量预估（AC-144「逐组件给出体量预估与所需总量」）。
private func sizeBreakdownJson(): JsonObject {
    let o = JsonObject()
    for ((k, v) in devkitSizeBreakdown()) {
        o.put(k, JsonInt(v))
    }
    return o
}

/// 状态文件里该组件已记账的状态；未记账时如实回 `notInstalled`。
private func storedStatusOf(ctx: AppContext, id: String): String {
    match (ctx.state.state.devkitComponents.get(id)) {
        case Some(s) => return s.status
        case None => return devkitStatusCode(DevkitStatus.NotInstalled)
    }
}

// ===================== install =====================

private func doInstall(ctx: AppContext, req: HttpRequest): HttpResponse {
    let body = parseInstallBody(req)
    if (body.ids.isEmpty()) {
        return jsonErr(HttpStatus.BAD_REQUEST, 400,
            "请指定要安装的组件标识（ids，如 [\"DK-3\"]）—— 空列表不会被当作「全装」",
            jobj())
    }
    let unknown = unknownIds(body.ids)
    if (!unknown.isEmpty()) {
        return jsonErr(HttpStatus.BAD_REQUEST, 400,
            "未知组件标识：${unknown}；合法取值为 DK-1~DK-8", jobj())
    }

    let dir = resolveSourceDir(ctx, body.sourceDir)
    let degraded = diskDegraded(dir)

    // 磁盘空间闸口（AC-144）：进入安装前必须先校验，不足则中止并给逐组件体量。
    // ⚠️ match 臂内**不能**写 `{ ... }` 多语句块 —— `=>` 后的 `{` 会被解析成 lambda 起始，
    // 报 `expected '=>' in lambda expression`。故闸口失败整段外提成独立函数。
    match (diskGate(dir, body.ids)) {
        case Some(msg) => return diskGateReject(ctx, dir, msg, degraded)
        case None => ()
    }

    // 依赖闭包：只勾 DK-5 也要能真正装成，但闭包内的组件按注册表顺序排在前面。
    let ordered = expandWithDeps(body.ids)

    let items = JsonArray()
    var anyFailed = false
    for (id in ordered) {
        let res = installDevkitComponent(id, dir, body.forceNonempty)
        let ok = isInstallOk(res.outcome)
        if (!ok) {
            anyFailed = true
        }
        items.add(installResultJson(ctx, dir, id, res, ok, body.ids))
        recordComponentState(ctx, id, res)
        // 依赖未满足 / 目录被拒 / 未实现：后续组件只会同样失败，如实中断并留痕。
        if (!ok && stopsPipeline(res.outcome)) {
            addDegraded(degraded, id, res.message,
                "该组件及其后续组件未安装",
                "按上面 message 中的命令处理后重跑；也可只勾选该组件单独重试")
            break
        }
    }

    // 开发环境初始化（I1~I9 / T038）：只在勾了 DK-3 或 DK-7 时触发，
    // 否则如实标记"未执行"并给出触发方式，绝不静默跳过。
    let (initArr, initOk) = runInitIfNeeded(ctx, dir, body, degraded)
    if (!initOk) {
        anyFailed = true
    }

    let data = jobj()
    data.put("items", items)
    data.put("installed", jint(ordered.size))
    data.put("init", initArr)
    data.put("ok", jbool(!anyFailed))
    data.put("disk", diskJson(dir))
    data.put("degraded", degraded)
    let code: Int64 = if (anyFailed) { 500 } else { 200 }
    let msg = if (anyFailed) {
        "开发套件安装存在未完成项，详见 items / init / degraded"
    } else {
        "开发套件安装完成"
    }
    return jsonOkCode(code, msg, data)
}

/// 磁盘闸口不通过时的 507 响应体（逐组件体量 + 总量 + 探测到的实际值，AC-144）。
private func diskGateReject(ctx: AppContext, dir: Path, msg: String,
                            degraded: JsonArray): HttpResponse {
    let data = jobj()
    data.put("disk", diskJson(dir))
    data.put("requiredMb", jint(devkitTotalSizeMb()))
    data.put("sizeMb", sizeBreakdownJson())
    data.put("degraded", degraded)
    return jsonErr(HttpStatus.INSUFFICIENT_STORAGE, 507, msg, data)
}

/// 安装结果 + 安装后立即自检结果合并为一项（AC-132：安装完成后立即自检并记录实际值）。
private func installResultJson(ctx: AppContext, dir: Path, id: String,
                               res: InstallResult, ok: Bool,
                               requested: ArrayList<String>): JsonObject {
    let o = JsonObject()
    o.put("id", JsonString(id))
    o.put("status", JsonString(if (ok) { "pass" } else { "fail" }))
    o.put("outcome", JsonString(installOutcomeCode(res.outcome)))
    o.put("message", JsonString(res.message))
    o.put("actual", JsonString(res.actual))
    // 安装成功才补自检判据；失败时 actual 已是真实错误输出，不拿空判据充数。
    match (verifyOne(id, dir, collectFacts(ctx, dir))) {
        case Some(chk) =>
            o.put("expected", JsonString(chk.expected))
            o.put("fix", JsonString(chk.fix))
            o.put("checkPassed", JsonBool(chk.passed))
        case None =>
            o.put("expected", JsonString("组件标识须为 DK-1~DK-8"))
            o.put("fix", JsonString(res.message))
            o.put("checkPassed", JsonBool(false))
    }
    // 显式标出哪些是**依赖闭包带入**的，不让"顺带装的"看起来像用户勾的（AC-131）。
    o.put("viaDependency", JsonBool(!requested.contains(id)))
    return o
}

private func isInstallOk(o: InstallOutcome): Bool {
    return match (o) {
        case InstallOutcome.Ok => true
        case _ => false
    }
}

/// 哪些失败类型应当中断后续安装：git 缺失 / 目录被拒 / 依赖缺失 / 未实现。
/// 网络不可达**不**中断 —— 后续组件未必依赖 DK-3。
private func stopsPipeline(o: InstallOutcome): Bool {
    return match (o) {
        case InstallOutcome.Ok => false
        case InstallOutcome.NetworkUnreachable(_) => false
        case InstallOutcome.GitMissing => true
        case InstallOutcome.DirRejected(_) => true
        case InstallOutcome.DepMissing(_) => true
        case InstallOutcome.Failed(_) => true
    }
}

/// 把请求里的 ids 展开为「含依赖闭包、按注册表顺序」的安装序列。
///
/// 展开而不只是报错，是为了让「只勾 DK-5」也能真正装成 ——
/// 但顺序必须按注册表（DK-3 → DK-4 → DK-5），保证先装依赖再装被依赖。
private func expandWithDeps(ids: ArrayList<String>): ArrayList<String> {
    let closure = ArrayList<String>()
    for (id in ids) {
        for (d in devkitDepsClosure(id)) {
            if (!closure.contains(d)) {
                closure.add(d)
            }
        }
    }
    let ordered = ArrayList<String>()
    for (c in devkitRegistry()) {
        if (closure.contains(c.id)) {
            ordered.add(c.id)
        }
    }
    return ordered
}

/// 校验 ids 合法性，返回不认识的那些（逗号分隔）。
private func unknownIds(ids: ArrayList<String>): String {
    let bad = ArrayList<String>()
    for (id in ids) {
        match (devkitComponentById(id)) {
            case Some(_) => ()
            case None => bad.add(id)
        }
    }
    return joinWith(bad, ", ")
}

// ===================== verify =====================

private func doVerify(ctx: AppContext): HttpResponse {
    let dir = ctx.paths.devSourceDir
    let facts = collectFacts(ctx, dir)
    let checks = verifyDevkit(dir, facts)
    let data = jobj()
    // 逐项五字段（AC-133）。这里不复用 `checksToJson` 的中间对象再取键——
    // 那样要把 `Option<JsonValue>` 拆包回具体子类，类型推断不稳；
    // 直接遍历 `checks` 拼一次，形态与 `checksToJson` 完全同构。
    let items = JsonArray()
    for (c in checks) {
        items.add(checkJson(c))
    }
    data.put("items", items)
    data.put("summary", summaryJson(checks))
    data.put("sizeMb", sizeBreakdownJson())
    data.put("totalSizeMb", jint(devkitTotalSizeMb()))
    data.put("mode", jstr(ctx.state.state.mode))
    data.put("devSourceDir", jstr(dir.toString()))
    data.put("ok", jbool(allPassed(checks)))
    // 探测不到的事实必须显式回吐，否则前端无从区分"没装"与"查不到"。
    data.put("degraded", factsDegraded(dir, facts))
    return jsonOkCode(200, "开发套件自检汇总", data)
}

/// 单项自检的五字段形态（AC-133：id/status/actual/expected/fix）。
private func checkJson(c: DevkitCheck): JsonObject {
    let o = JsonObject()
    o.put("id", JsonString(c.id))
    o.put("status", JsonString(if (c.passed) { "pass" } else { "fail" }))
    o.put("actual", JsonString(c.actual))
    o.put("expected", JsonString(c.expected))
    // AC-134：未通过项的修复建议必须非空 —— 注册表里每项都带 fixCmd，
    // 这里再兜一层：万一为空则给出通用重跑命令，不给前端一个空字符串。
    let fix = if (c.fix.isEmpty()) {
        "重跑 POST /setup/devkit/install 让该组件补装后再验"
    } else {
        c.fix
    }
    o.put("fix", JsonString(fix))
    return o
}

private func summaryJson(checks: ArrayList<DevkitCheck>): JsonObject {
    var passed: Int64 = 0
    var failed: Int64 = 0
    for (c in checks) {
        match (c.passed) {
            case true => passed += 1
            case false => failed += 1
        }
    }
    let o = JsonObject()
    o.put("total", JsonInt(checks.size))
    o.put("passed", JsonInt(passed))
    o.put("failed", JsonInt(failed))
    return o
}

/// 事实采集不到的项（如无数据库连接）必须显式留痕（红线①）。
private func factsDegraded(dir: Path, f: DevkitFacts): JsonArray {
    let arr = JsonArray()
    if (f.db.isNone()) {
        addDegraded(arr, "DK-4/DK-5", "无数据库连接，两项判据无法执行",
            "两项均按 fail 记账，不当作通过",
            "先完成 save-config 与 create-admin，再重跑 devkit verify")
    }
    if (!f.devSourceReady) {
        addDegraded(arr, "DK-3", "开发源码目录不存在：${dir.toString()}",
            "依赖源码树的判据全部按 fail 记账",
            "ucInstaller.exe devkit install DK-3 --source-dir <目录>")
    }
    if (f.manifestTableCount < 0) {
        addDegraded(arr, "DK-4", "缺 seed-manifest.json 基线，表数一致性无法核对",
            "DK-4 按 fail 记账（不谎称与基线一致）",
            "完成 db export 生成 sql/seed/seed-manifest.json 后重跑")
    }
    return arr
}

/// 追加一条降级留痕（四个字段与 design §4.5 的 degraded 结构一致）。
private func addDegraded(arr: JsonArray, id: String, reason: String,
                        fallback: String, manualCmd: String): Unit {
    let o = JsonObject()
    o.put("id", JsonString(id))
    o.put("reason", JsonString(reason))
    o.put("fallback", JsonString(fallback))
    o.put("manualCmd", JsonString(manualCmd))
    arr.add(o)
}

// ===================== 磁盘空间闸口（AC-144） =====================

/// 磁盘信息 JSON：`available` 为 -1 表示**探测不到**，不是"空间为零"。
private func diskJson(dir: Path): JsonObject {
    let free = freeSpaceMb(dir)
    let o = JsonObject()
    o.put("path", JsonString(dir.toString()))
    o.put("availableMb", JsonInt(free))
    o.put("requiredTotalMb", JsonInt(devkitTotalSizeMb()))
    o.put("probed", JsonBool(free >= 0))
    o.put("method", JsonString("wmic logicaldisk"))
    return o
}

/// 探测失败时的显式降级留痕（AC-144 的"不足才报错"不等于"探测不到就放行"）。
/// 磁盘探测的失败留痕；探测不到 ≠ 空间充足，故**先留痕再判闸口**。
private func diskDegraded(dir: Path): JsonArray {
    let arr = JsonArray()
    if (diskProbeFailed(dir)) {
        addDegraded(arr, "disk",
            "无法探测目标磁盘剩余空间（wmic 无输出或目录所在卷不可解析）",
            "磁盘空间闸口未生效，本次不阻断安装但**未做容量校验**",
            "手工执行 `wmic logicaldisk get DeviceID,FreeSpace,Size` 确认空间充足")
    }
    return arr
}

// 磁盘闸口本体（`freeSpaceMb` / `requiredMbFor` / `diskGate` / `diskProbeFailed`）
// 已下沉到 `uc_installer.services.devkit.disk.cj`，CLI 与 HTTP 共用同一份实现
// （见该文件头部说明）。本文件只保留 JSON 渲染与 degraded 留痕——那是 HTTP 通道
// 特有的呈现形态，不该污染服务层。

// ===================== 公共辅助 =====================

/// 采集自检事实：源码树事实 + 数据库连接 + 基线表数。
private func collectFacts(ctx: AppContext, dir: Path): DevkitFacts {
    let f = collectSourceFacts(dir)
    f.db = dbConnOf(ctx)
    f.manifestTableCount = manifestTableCountOf(dir)
    return f
}

private func dbConnOf(ctx: AppContext): Option<DbConn> {
    let envPath = ctx.paths.releaseDir.join(".env")
    match (readEnv(envPath)) {
        case Some(env) => match (readDbConnectionUrl(env)) {
            case Some(url) => return parseDatabaseUrl(url)
            case None => return None<DbConn>
        }
        case None => return None<DbConn>
    }
}

/// 读 `<devSourceDir>/sql/seed/seed-manifest.json` 的 `tables` 长度。
///
/// 读不到时返回 -1（= "无基线可比"），由 DK-4 判据如实报"缺基线"，
/// 绝不拿默认值（如 207）冒充一致。
private func manifestTableCountOf(dir: Path): Int64 {
    let f = dir.join("sql").join("seed").join("seed-manifest.json")
    if (!exists(f)) {
        return -1
    }
    let text = readFileText(f)
    match (jsonParse(text)) {
        case Some(v) => match (asObject(v)) {
            case Some(o) => match (jsonOptArr(o, "tables")) {
                case Some(a) => return a.size()
                case None => return -1
            }
            case None => return -1
        }
        case None => return -1
    }
}

/// 安装请求体。`ArrayList` 而非 `Array`：ids 是变长列表。
class InstallBody {
    public let ids: ArrayList<String>
    public let sourceDir: String
    public let forceNonempty: Bool
    public let withFrontend: Bool

    public init(ids: ArrayList<String>, sourceDir: String, forceNonempty: Bool,
                withFrontend: Bool) {
        this.ids = ids
        this.sourceDir = sourceDir
        this.forceNonempty = forceNonempty
        this.withFrontend = withFrontend
    }
}

/// 解析安装请求体：`{ids, sourceDir?, forceNonempty?, withFrontend?}`。
/// 解析失败返回全空（上层据此回 400）。
private func parseInstallBody(req: HttpRequest): InstallBody {
    let empty = InstallBody(ArrayList<String>(), "", false, false)
    match (jsonParse(bodyText(req))) {
        case Some(v) => match (asObject(v)) {
            case Some(o) => InstallBody(jsonStrList(o, "ids"), jsonStr(o, "sourceDir", ""),
                jsonBool(o, "forceNonempty", false), jsonBool(o, "withFrontend", false))
            case None => empty
        }
        case None => empty
    }
}

/// `--source-dir` / 请求体 `sourceDir` 优先；都为空则用布局解析出的 devSourceDir。
private func resolveSourceDir(ctx: AppContext, fromBody: String): Path {
    if (!fromBody.isEmpty()) {
        return Path(fromBody)
    }
    if (!ctx.args.sourceDir.isEmpty()) {
        return Path(ctx.args.sourceDir)
    }
    return ctx.paths.devSourceDir
}

/// 组装 I1~I9 的执行上下文（子进程 cwd 恒为 devSourceDir，R-23）。
private func buildInitContext(ctx: AppContext, dir: Path, withFrontend: Bool): InitContext {
    return InitContext(dir, ctx.paths.releaseDir.join(".env"), dir.join(".env"),
                       withFrontend, dbConnOf(ctx))
}

/// 触发 I1~I9；不需要触发时如实留痕说明未执行及触发方式。
///
/// 返回 `(init结果数组, 是否全部通过)`：不需要触发时返回 `(空数组, true)`，
/// 因为"未触发"不算失败（已由 `degraded` 留痕说明）。
private func runInitIfNeeded(ctx: AppContext, dir: Path, body: InstallBody,
                             degraded: JsonArray): (JsonArray, Bool) {
    let needed = body.withFrontend || body.ids.contains("DK-3") || body.ids.contains("DK-7")
    if (!needed) {
        addDegraded(degraded, "I1-I9",
            "本次请求未包含需要初始化环境的组件（DK-3 / DK-7），未执行 I1~I9",
            "开发环境初始化未执行",
            "重跑 `POST /setup/devkit/install {\"ids\":[\"DK-3\"]}` 以触发初始化")
        return (JsonArray(), true)
    }
    let results = runInitSteps(buildInitContext(ctx, dir, body.withFrontend))
    let ok = initAllPassed(results)
    if (!ok) {
        addDegraded(degraded, "I1-I9",
            "开发环境初始化存在未完成项（Manual / Fail / Skip），详见 init[]",
            "已完成的步骤保留，未完成项各自给出 fix 命令",
            "按 init[].fix 逐条处理后重跑 devkit install")
    }
    return (initResultsToJson(results), ok)
}

/// 把安装结果写进状态文件（AC-137/138：复用主安装的状态文件，且补装后更新状态）。
private func recordComponentState(ctx: AppContext, id: String, res: InstallResult): Unit {
    let status = if (isInstallOk(res.outcome)) { DEVKIT_INSTALLED } else { DEVKIT_FAILED }
    let cs = DevkitComponentState(id: id, status: status, at: Some(nowText()),
                                   actual: res.actual,
                                   expected: expectedOf(id))
    ctx.state.state.devkitComponents.add(id, cs)
    ctx.state.state.devkit = DEVKIT_INSTALLED
    ctx.state.save()
}

private func expectedOf(id: String): String {
    match (devkitComponentById(id)) {
        case Some(c) => return c.expected
        case None => return ""
    }
}

/// join 辅助（`ArrayList<String>.join` 在本仓无先例，自写避免试错）。
private func joinWith(items: ArrayList<String>, sep: String): String {
    let sb = StringBuilder()
    var i: Int64 = 0
    while (i < items.size) {
        if (i > 0) {
            sb.append(sep)
        }
        sb.append(items[i])
        i = i + 1
    }
    return sb.toString()
}

private func nowText(): String {
    return DateTime.now().format("yyyy-MM-dd HH:mm:ss")
}
