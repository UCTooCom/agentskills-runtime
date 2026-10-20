package uc_installer.services.devkit

// DK-1~DK-8 的安装动作（任务 T036；判据声明在 registry.cj）。
//
// **红线 R-22（源码级）**：本文件只允许对git 工作副本做 `clone` 与 `fetch`。
// 开发者的工作副本**绝不可**被安装器丢弃改动，因此禁止出现任何会重置/清理工作树的
// git 子命令，也禁止任何"离线复制兜底"路径——单路径已由用户拍板（2026-10-07）。
// 同理禁止在安装器里记录/依赖来源标记文件来冒充"可提交上游的工作副本"。
//
// 失败即终点：git 不可用或两处地址都不可达时，**不写任何源码文件、不留残缺目录**
// （design.md §4.10.1.1(2)）。理由是残缺的无历史源码树比明确失败更糟——
// 开发者会以为装好了，等要提 PR 时才发现没有历史。

import std.fs.{Path, exists, Directory, FileInfo}
import std.collection.{ArrayList, HashMap}
import uc_installer.platform.{runCapped, succeeded, decodeOutput, splitLines, RunResult}
import uc_installer.services.readFileText
// registry.cj / verify.cj 与本文件同属 `uc_installer.services.devkit` 包，
// 同包跨文件免 import（仓颉以 package 为编译单元，不是以目录）。
// 切勿写成 `uc_installer.services.devkit.registry.{…}` —— 那会被当成子包解析并报
// "can not find the following dependencies"。

/// 单个组件的安装结果。
///
/// 区分 gitMissing / networkUnreachable 是 AC 的明确要求（`--json` 报告须可区分），
/// 故用枚举而非裸字符串。
public enum InstallOutcome {
    | Ok
    | GitMissing
    | NetworkUnreachable(String)
    | DirRejected(String)
    | DepMissing(ArrayList<String>)
    | Failed(String)
}

public func installOutcomeCode(o: InstallOutcome): String {
    match (o) {
        case InstallOutcome.Ok => return "ok"
        case InstallOutcome.GitMissing => return "gitMissing"
        case InstallOutcome.NetworkUnreachable(_) => return "networkUnreachable"
        case InstallOutcome.DirRejected(_) => return "dirRejected"
        case InstallOutcome.DepMissing(_) => return "depMissing"
        case InstallOutcome.Failed(_) => return "failed"
    }
}

/// 安装结果是否成功（供 HTTP handler 与编排器共用，避免各处重复 match）。
public func isInstallSuccess(o: InstallOutcome): Bool {
    return match (o) {
        case InstallOutcome.Ok => true
        case _ => false
    }
}

/// 安装结果 + 人类可读详情（`--json` 与文本两种输出的共同来源）。
public struct InstallResult {
    public let id: String
    public let outcome: InstallOutcome
    public let message: String
    /// 该组件安装后可立即执行的自检结果（AC-132：安装完成后立即自检并记录实际值）。
    public let actual: String

    public init(id: String, outcome: InstallOutcome, message: String, actual: String) {
        this.id = id
        this.outcome = outcome
        this.message = message
        this.actual = actual
    }
}

// ===================== git 环境 =====================

/// git 是否可用（`git --version` 成功即算可用）。
public func gitAvailable(): Bool {
    let r = runCapped("git", ["--version"], cap: Duration.second * 5)
    return succeeded(r)
}

/// git 版本串，供推荐理由引用实际值（AC-136 要求理由含探测到的实际值）。
public func gitVersionText(): String {
    let r = runCapped("git", ["--version"], cap: Duration.second * 5)
    if (succeeded(r)) {
        return decodeOutput(r.stdout).trimAscii()
    }
    return ""
}

/// 探测目标目录属于三分状态中的哪一种（design.md §4.10.1.1 (3)）。
///
/// 判据严格按spec：目录项数为 0 → Empty；`git rev-parse` 成功再看remote 是否属预期集合。
public func classifyDevSource(dir: Path): DevSourceState {
    if (!exists(dir)) {
        return DevSourceState.Absent
    }
    if (!FileInfo(dir).isDirectory()) {
        // 路径存在但不是目录（是文件）⇒按非 git 目录处理，调用方会拒绝并要求换目录。
        return DevSourceState.NotARepo
    }
    if (dirEntryCount(dir) == 0) {
        return DevSourceState.Empty
    }
    // 非空：问 git 这是不是仓库
    let rr = runCapped("git", ["rev-parse", "--is-inside-work-tree"], cap: Duration.second * 5, cwd: dir)
    if (!succeeded(rr)) {
        return DevSourceState.NotARepo
    }
    let ru = runCapped("git", ["remote", "get-url", "origin"], cap: Duration.second * 5, cwd: dir)
    if (!succeeded(ru)) {
        // 是仓库但没有 origin remote，视为非预期仓库 ⇒ 拒绝，不覆盖。
        return DevSourceState.ForeignRepo
    }
    return remoteMatches(decodeOutput(ru.stdout))
}

/// remote 是否属预期地址集合（主地址或镜像）。
private func remoteMatches(url: String): DevSourceState {
    let u = url.trimAscii()
    if (u == DEVKIT_REPO_PRIMARY || u == DEVKIT_REPO_PRIMARY + ".git") {
        return DevSourceState.Reusable
    }
    if (u == DEVKIT_REPO_MIRROR) {
        return DevSourceState.Reusable
    }
    return DevSourceState.ForeignRepo
}

/// 统计目录下的直接子项数（用于判"存在且为空"）。
///
/// 遍历写法用 `Directory.readFrom`——与 services/media.cj:13 同一形态（已验证可编译）。
private func dirEntryCount(dir: Path): Int64 {
    var n = 0
    try {
        for (_ in Directory.readFrom(dir)) {
            n += 1
        }
    } catch (_: Exception) {
        return 0
    }
    return n
}

// ===================== DK-3 clone / fetch =====================

/// 禁止 git 弹凭据交互导致卡死死等（design.md §4.10.1.1 (4)）。
///
/// 走 runCapped 的 `env` 形参即可——它内部已以 `HashMap(getVariables())` 为基底
/// 再叠加（见 platform/subprocess_timeout.cj 的 fullEnv / buildChildEnv），
/// 不会因为 environment 整体替换而丢 PATH（R-04）。
private func gitEnv(): HashMap<String, String> {
    let e = HashMap<String, String>()
    e["GIT_TERMINAL_PROMPT"] = "0"
    e["GIT_ASKPASS"] = "echo"
    e["GCM_INTERACTIVE"] = "never"
    return e
}

/// git 长时间操作的等待上限：clone/fetch 是网络操作，5s 探测上限不适用。
private func gitCap(): Duration {
    return Duration.second * 180
}

/// 组装 `git clone` 参数。
///
/// 用 `ArrayList` 而非 `Array`——`Array<String>()` 是**定长**数组，没有 `add`；
/// 变长参数列表一律 ArrayList + `.toArray()`（与 platform/envvars.cj:62 同款）。
private func cloneArgs(url: String, target: String): Array<String> {
    let a = ArrayList<String>()
    a.add("clone")
    // Windows 长路径：仓内含深层路径，缺这一项在某些机器上会失败。
    a.add("--config")
    a.add("core.longpaths=true")
    a.add(url)
    a.add(target)
    return a.toArray()
}

/// 尝试一个地址；成功返回 Ok，失败返回该次执行结果供上层判定是否回落。
private func tryClone(url: String, target: Path, intoExisting: Bool): RunResult {
    if (intoExisting) {
        // 目标目录已存在且为空 ⇒ 语义是"clone 到当前目录"（design S-b）。
        let a = ArrayList<String>()
        a.add("clone")
        a.add("--config")
        a.add("core.longpaths=true")
        a.add(url)
        a.add(".")
        return runCapped("git", a.toArray(), cap: gitCap(), cwd: target, env: gitEnv())
    }
    // 不带 cwd：让 git 自己创建 target 目录。
    return runCapped("git", cloneArgs(url, target.toString()).toArray(), cap: gitCap(), env: gitEnv())
}

/// 对已存在且 remote 匹配的工作副本执行 fetch（**不**做任何会丢改动的操作）。
private func doFetch(dir: Path): Bool {
    let a = ArrayList<String>()
    a.add("fetch")
    a.add("--all")
    a.add("--prune")
    return succeeded(runCapped("git", a.toArray(), cap: gitCap(), cwd: dir, env: gitEnv()))
}

/// 工作副本是否 dirty（`git status --porcelain` 非空）。仅提示，不阻断（AC-166~187）。
public func devSourceDirty(dir: Path): Bool {
    let r = runCapped("git", ["status", "--porcelain"], cap: Duration.second * 10, cwd: dir, env: gitEnv())
    if (!succeeded(r)) {
        return false
    }
    return !decodeOutput(r.stdout).trimAscii().isEmpty()
}

/// DK-3 主入口：把开发者自选目录变成一份真正的 git 工作副本。
///
/// 单路径无兜底：git 不可用 → GitMissing；主地址失败 → 试镜像；两者皆失败 →
/// NetworkUnreachable。**任何失败都不创建目标目录**（clone 自身失败时 git 不会留下
/// 可用的工作树，这里额外确保目录只在 clone 成功后被记账）。
///
/// forceNonempty 对应 `--force-nonempty`：仅当用户显式指定时才允许在
/// S-c2/S-c3 目录下新建**子层**再 clone（不覆盖既有内容）。
public func installDevSource(dir: Path, forceNonempty: Bool): InstallResult {
    if (!gitAvailable()) {
        return InstallResult("DK-3", InstallOutcome.GitMissing,
            "未检测到 git —— 请先安装 git，然后重跑 `ucInstaller.exe devkit install DK-3 --source-dir ${dir.toString()}`",
            "git: not found")
    }
    return cloneInto(dir, forceNonempty)
}

private func cloneInto(dir: Path, forceNonempty: Bool): InstallResult {
    let st = classifyDevSource(dir)
    if (!devSourceStateAcceptable(st)) {
        if (!forceNonempty) {
            return InstallResult("DK-3",
                InstallOutcome.DirRejected(dirRejectMessage(st, dir)),
                "目标目录非空且不是本仓库工作副本，已拒绝（未改动该目录）",
                "dirState: ${devSourceStateCode(st)}")
        }
        return cloneIntoSubdir(dir)
    }
    match (st) {
        case DevSourceState.Reusable => return reuseExisting(dir)
        case _ => return freshClone(dir, st)
    }
}

/// 可接受状态下的两条实际路径：复用或全新 clone。
private func freshClone(dir: Path, st: DevSourceState): InstallResult {
    // 目标目录已存在且为空 ⇒ 语义是"clone 到当前目录"（design S-b）；
    // 其它可接受态（Absent）⇒ clone 到目录本身。
    let intoExisting = match (st) {
        case DevSourceState.Empty => true
        case _ => false
    }
    let primary = tryClone(DEVKIT_REPO_PRIMARY, dir, intoExisting)
    if (succeeded(primary)) {
        return cloneOk(dir, DEVKIT_REPO_PRIMARY)
    }
    // 主地址不可达 ⇒ 回落镜像。两次都失败才是终点。
    let mirror = tryClone(DEVKIT_REPO_MIRROR, dir, intoExisting)
    if (succeeded(mirror)) {
        return cloneOk(dir, DEVKIT_REPO_MIRROR)
    }
    return InstallResult("DK-3",
        InstallOutcome.NetworkUnreachable(diag(primary, mirror)),
        "主地址与镜像均不可达，未写入任何源码文件（请检查网络或代理后重跑）",
        "networkUnreachable: true")
}

private func cloneOk(dir: Path, usedUrl: String): InstallResult {
    let version = readCjcVersion(dir)
    let hasCordis = exists(dir.join("libs").join("cordis-cj"))
    return InstallResult("DK-3", InstallOutcome.Ok,
        "已从 ${usedUrl} clone 到 ${dir.toString()}",
        "cjc-version=${version}; cordis-cj=${hasCordis}")
}

private func reuseExisting(dir: Path): InstallResult {
    if (doFetch(dir)) {
        let dirty = devSourceDirty(dir)
        let suffix = if (dirty) { "；工作副本有本地改动，已保留（安装器不会丢弃改动）" } else { "" }
        let version = readCjcVersion(dir)
        return InstallResult("DK-3", InstallOutcome.Ok,
            "已复用既有工作副本并完成 fetch${suffix}",
            "reused; cjc-version=${version}; dirty=${dirty}")
    }
    // fetch 失败**不降级为 clone**：目录里已有开发者改动，强行 clone 会覆盖它们。
    return InstallResult("DK-3", InstallOutcome.Failed("git fetch 失败"),
        "既有工作副本 fetch 失败；已保留该目录原样，请手工执行 `git fetch` 排查",
        "fetch: failed")
}

/// --force-nonempty 下的行为：在既有目录下**新建子层**再 clone，不覆盖任何东西。
private func cloneIntoSubdir(dir: Path): InstallResult {
    let sub = dir.join("agentskills-runtime")
    let st2 = classifyDevSource(sub)
    if (!devSourceStateAcceptable(st2)) {
        return InstallResult("DK-3",
            InstallOutcome.DirRejected("子目录 ${sub.toString()} 同样非空且非本仓库"),
            "子目录也不可用，已拒绝（未改动任何内容）",
            "dirState: ${devSourceStateCode(st2)}")
    }
    return freshClone(sub, st2)
}

/// 构造拒绝原因文案。
///
/// match 两臂用**表达式**而非 `return`：若臂内`return`，第 300 行会变成不可达代码，
/// 编译器会在那里报出误导性的 "undeclared identifier"（Path.toString 本身是存在的，
/// 本工程已有 65 处同类调用）。
private func dirRejectMessage(st: DevSourceState, dir: Path): String {
    let kind = match (st) {
        case DevSourceState.ForeignRepo => "该目录已是另一个 git 仓库（remote 与本项目不符）"
        case _ => "该目录非空且不是 git 工作副本"
    }
    return "${kind}：${dir.toString()}。请换一个空目录，或加 --force-nonempty 在其下新建子层"
}

private func diag(primary: RunResult, mirror: RunResult): String {
    let p = decodeOutput(primary.stderr).trimAscii()
    let m = decodeOutput(mirror.stderr).trimAscii()
    return "primary: ${p} | mirror: ${m}"
}

/// 读工作副本 `cjpm.toml` 的 cjc-version（DK-3 自检判据之一）。
///
/// `String.indexOf` 返回 `Option`（不是 Int64），故用 match 判定——
/// 与 crontab/executor/AgentExecutionExecutor.cj:252 同一写法。
public func readCjcVersion(dir: Path): String {
    let f = dir.join("cjpm.toml")
    if (!exists(f)) {
        return ""
    }
    let text = readFileText(f)
    for (line in splitLines(text)) {
        let t = line.trimAscii()
        if (!t.startsWith("cjc-version")) {
            continue
        }
        let found = quoteValue(t)
        if (found.isEmpty()) {
            continue
        }
        return found
    }
    return ""
}

/// 取引号内的值；无引号或不成对时返回空串。
private func quoteValue(line: String): String {
    match (line.indexOf("\"")) {
        case None => return ""
        case Some(q1) =>
            let rest = line[q1 + 1..]
            match (rest.indexOf("\"")) {
                case None => return ""
                case Some(q2) => return rest[0..q2]
            }
    }
}

// ===================== 逐组件安装 =====================

/// 按标识安装单个组件。
///
/// 目前 T035~T038 范围内真正有落地动作的是 DK-3（源码树）；其余组件给出
/// **明确的未实现结论**而不是假装成功（R-22同源约束：不得静默降级）。
/// DK-1 的下载引导依赖 Phase 7 的 seed/校验基础设施，故同样如实标记。
public func installDevkitComponent(id: String, devSourceDir: Path,
                                   forceNonempty: Bool): InstallResult {
    match (devkitComponentById(id)) {
        case None => return InstallResult(id, InstallOutcome.Failed("未知组件标识"),
            "未知组件 ${id}，合法取值为 DK-1~DK-8", "unknown")
        case Some(c) => return dispatchInstall(c, devSourceDir, forceNonempty)
    }
}

private func dispatchInstall(c: DevkitComponent, devSourceDir: Path,
                             forceNonempty: Bool): InstallResult {
    // 前置依赖检查（spec.md §6.5-8）：缺依赖时必须报出缺哪些。
    let missing = devkitMissingDeps(defaultIsInstalled, c.id)
    if (!missing.isEmpty()) {
        return InstallResult(c.id, InstallOutcome.DepMissing(missing),
            "前置组件未安装：${joinIds(missing)}", "depMissing: ${joinIds(missing)}")
    }
    if (c.id == "DK-3") {
        return installDevSource(devSourceDir, forceNonempty)
    }
    return notYetImplemented(c)
}

/// 尚未落地的组件一律如实标记失败并给出修复路径，禁止谎报成功。
private func notYetImplemented(c: DevkitComponent): InstallResult {
    return InstallResult(c.id,
        InstallOutcome.Failed("该组件的安装动作尚未落地"),
        "组件 ${c.id}（${c.title}）的安装动作尚未实现；请手工执行：${c.fixCmd}",
        "notImplemented")
}

/// 依赖探测的默认实现：查某组件当前是否已安装。
///
/// 由上层（持有 StateStore 的verify / install 入口）覆盖为真实状态。
/// 本包不反向依赖 core —— core 的 orchestrator 已依赖 services，反向 import 会成环。
/// 默认实现只认 DK-3（它无依赖），其余一律报"未满足"，宁可拦住也不假装满足。
private func defaultIsInstalled(id: String): Bool {
    match (id) {
        case "DK-3" => return true
        case _ => return false
    }
}

private func joinIds(ids: ArrayList<String>): String {
    let sb = StringBuilder()
    var i = 0
    while (i < ids.size) {
        if (i > 0) {
            sb.append(", ")
        }
        sb.append(ids[i])
        i += 1
    }
    return sb.toString()
}
