package uc_installer.platform

import std.convert.Parsable
import std.fs.Path
import std.process.{findProcess, launch, ProcessRedirect}
import std.collection.{ArrayList, HashMap}

// 进程表查询（Phase 1 / T007）
//
// 用途：判定 runtime 进程是否存活，并为**最小权限的进程治理**（AC-011）提供依据 ——
// 停止/重启 runtime 时只允许终止「PID 文件有记录 **且** 进程镜像名校验通过」的目标进程，
// 不得终止任何其它同名进程。因此本文件的核心对外能力是 `verifyProcessImage`，
// 而不是单纯的“按名字找进程”。
//
// 同 package 跨文件无需 import —— 直接复用本包 subprocess_timeout.cj 的 runCapped /
// decodeOutput。工程实证：宿主里同包跨文件直接引用符号且不 import 本包的文件有 328 个
// （如 magic.agent.base 包的 base_agent.cj 直接引用同包 abs_agent.cj 的 AbsAgent）。

/// 进程表中的一条记录。
///
/// 字段取自 `tasklist /FO CSV` 的输出列序：
/// Image Name, PID, Session Name, Session#, Mem Usage
public struct ProcEntry {
    public let imageName: String
    public let pid: Int64
    public let sessionName: String
    public let sessionNumber: String
    public let memUsage: String

    public init(imageName: String, pid: Int64, sessionName: String,
                sessionNumber: String, memUsage: String) {
        this.imageName = imageName
        this.pid = pid
        this.sessionName = sessionName
        this.sessionNumber = sessionNumber
        this.memUsage = memUsage
    }
}

/// `tasklist` 找不到匹配进程时输出的提示行特征子串（中英文系统均有此行的英文版）。
private let TASKLIST_EMPTY_HINT = "No tasks are running"

/// 按 CSV 规则切分一行，**引号感知**。
///
/// 为什么不能简单地 `line.split(",")`：tasklist 的 Mem Usage 列形如 `20,240 K`，
/// 千位分隔符本身就是逗号，好在 CSV 格式会给该字段加上引号；只有感知引号才能正确切分。
/// 这与本期后续 Seed 导出需要的“引号感知扫描”是同源问题（详见 Phase 7 / T040）。
///
/// - line: 原始一行 CSV 文本
/// - returns: 切分后的字段列表（已去掉外层引号，保留字段内部字符）
private func csvFields(line: String): ArrayList<String> {
    let fields = ArrayList<String>()
    let runes = line.toRuneArray()
    var cur = StringBuilder()
    var inQuotes = false
    var pendingContent = false
    var i = 0
    while (i < runes.size) {
        let c = runes[i]
        if (inQuotes) {
            if (c == r'"') {
                inQuotes = false
            } else {
                cur.append(c)
                pendingContent = true
            }
        } else if (c == r'"') {
            inQuotes = true
            pendingContent = true
        } else if (c == r',') {
            fields.add(cur.toString())
            cur = StringBuilder()
            pendingContent = false
        } else {
            cur.append(c)
            pendingContent = true
        }
        i = i + 1
    }
    // 最后一个字段：即便本行是空的也要产出，否则列数会整体错位。
    if (pendingContent || !fields.isEmpty()) {
        fields.add(cur.toString())
    }
    return fields
}

/// 解析 `tasklist /FO CSV` 的输出。
///
/// 容错原则：解析不出 PID 的行一律跳过 —— 典型的就是“没有匹配进程”的提示行，
/// 以及一些系统会在 CSV 头部插入的本地化信息行。**跳过必须静默但不冒充成功**，
/// 是否成功由调用方看返回的列表是否为空来判定。
///
/// - csvText: tasklist 的原始 stdout（已解码为字符串）
/// - returns: 成功解析出的进程记录列表；无匹配进程时为空列表
public func parseTasklistCsv(csvText: String): ArrayList<ProcEntry> {
    let result = ArrayList<ProcEntry>()
    if (csvText.isEmpty()) {
        return result
    }
    for (rawLine in splitLines(csvText)) {
        let line = rawLine.trimAscii()
        if (line.isEmpty()) {
            continue
        }
        if (line.contains(TASKLIST_EMPTY_HINT)) {
            continue
        }
        let fields = csvFields(line)
        if (fields.size < 5) {
            continue
        }
        let pidText = fields[1].trimAscii()
        let pid = try {
            Some(Int64.parse(pidText))
    } catch (_: Exception) {
        None<Int64>
    }
        match (pid) {
            case Some(p) =>
                result.add(ProcEntry(fields[0].trimAscii(), p, fields[2].trimAscii(),
                                     fields[3].trimAscii(), fields[4].trimAscii()))
            case None => ()
        }
    }
    return result
}

/// 查询进程表中镜像名匹配的进程。
///
/// 一律经由 `runCapped` 执行（自带等待上限），不经 `executeWithOutput` ——
/// tasklist 在极端负载下也可能卡住，这条路径不能成为安装器 hang 的来源。
///
/// - imageName: 镜像名，如 `agentskills-runtime.exe`（大小写不敏感）
/// - cap: 等待上限
/// - returns: 子进程执行结果；`timedOut` 为真时 stdout 不可信
public func listProcessesByImage(imageName: String,
                                 cap!: Duration = Duration.second * 5): RunResult {
    let filter = "IMAGENAME eq ${imageName}"
    return runCapped("tasklist", ["/FI", filter, "/FO", "CSV", "/NH"], cap: cap)
}

/// 取镜像名匹配的全部 PID。
///
/// - imageName: 镜像名
/// - returns: PID 列表；查询失败或超时一律返回空列表
///   （不返回 Option：调用方拿到空列表就该按“查不到”处理，语义等价且更好用）
public func findPidsByImage(imageName: String): ArrayList<Int64> {
    let pids = ArrayList<Int64>()
    let r = listProcessesByImage(imageName)
    if (r.timedOut || runCappedFailed(r)) {
        return pids
    }
    let text = decodeOutput(r.stdout)
    let wanted = imageName.toAsciiLower()
    for (e in parseTasklistCsv(text)) {
        if (e.imageName.toAsciiLower() == wanted) {
            pids.add(e.pid)
        }
    }
    return pids
}

/// 判断一次子进程结果是否为失败（统一口径，避免各处自行判断漏掉 timedOut）。
private func runCappedFailed(r: RunResult): Bool {
    (!r.timedOut) && r.exitCode != 0
}

/// 判定某个 PID 当前是否存活。
///
/// 用 `tasklist /FI "PID eq <pid>"` 而不是去比对进程列表：
/// 前者由系统按 PID 精确过滤，避免为了一次判定去拉取并解析整张进程表。
///
/// - pid: 待判定进程的 PID
/// - returns: 存活为 true；查询失败或超时返回 **false**（查不到即按不存活处理）
public func isPidAlive(pid: Int64): Bool {
    let r = runCapped("tasklist", ["/FI", "PID eq ${pid}", "/FO", "CSV", "/NH"])
    if (r.timedOut || runCappedFailed(r)) {
        return false
    }
    let entries = parseTasklistCsv(decodeOutput(r.stdout))
    for (e in entries) {
        if (e.pid == pid) {
            return true
        }
    }
    return false
}

/// PID 与镜像名的双重校验 —— 进程治理的最小权限依据（AC-011）。
///
/// 为什么必须同时校验两者：PID 会被操作系统回收复用。若只认 PID，
/// 目标进程退出后该 PID 可能被任意新进程复用，届时“停止 runtime”会误杀无辜进程。
/// 叠加镜像名校验后，即便 PID 被复用，也几乎不可能同时撞上同名镜像。
///
/// - pid: 来自 PID 文件记录的进程号
/// - expectedImageName: 期望的进程镜像名（大小写不敏感）
/// - returns: 该 PID 存活且其镜像名与期望一致时为 true
public func verifyProcessImage(pid: Int64, expectedImageName: String): Bool {
    let r = runCapped("tasklist", ["/FI", "PID eq ${pid}", "/FO", "CSV", "/NH"])
    if (r.timedOut || runCappedFailed(r)) {
        return false
    }
    let entries = parseTasklistCsv(decodeOutput(r.stdout))
    let wanted = expectedImageName.toAsciiLower()
    for (e in entries) {
        if (e.pid == pid && e.imageName.toAsciiLower() == wanted) {
            return true
        }
    }
    return false
}

/// 按 PID 精确查询单条进程记录（供 service-status 返回内存/镜像信息）。
///
/// 与 `findPidsByImage` 不同：此处按 PID 精确过滤，不依赖镜像名；
/// 用于已持有 PID（来自运行时 PID 文件）的场景。查询失败/超时/查不到一律返回 None。
public func queryProcess(pid: Int64): ?ProcEntry {
    let r = runCapped("tasklist", ["/FI", "PID eq ${pid}", "/FO", "CSV", "/NH"])
    if (r.timedOut || runCappedFailed(r)) {
        return None<ProcEntry>
    }
    let entries = parseTasklistCsv(decodeOutput(r.stdout))
    for (e in entries) {
        if (e.pid == pid) {
            return Some(e)
        }
    }
    return None<ProcEntry>
}

/// 精确终止某个 PID（最小权限进程治理，AC-011）。
///
/// 直接对给定 PID 调用 `std.process.findProcess(pid).terminate`，不波及任何其它进程；
/// 与 `killProcessTree` 的区别：本函数不递归杀子进程、也不回退到 taskkill。
/// 失败（进程已退出 / 权限不足）静默忽略 —— 由调用方按 `isPidAlive` 自行判定结果。
public func terminateProcess(pid: Int64, force: Bool): Unit {
    try {
        let proc = findProcess(pid)
        proc.terminate(force: force)
    } catch (_: Exception) {
        ()
    }
}

/// 启动 runtime 可执行文件（detached，由安装器后台托管）。
///
/// 经由 `std.process.launch` 直接拉起，标准流统一 Discard 避免管道死锁
/// （runtime 自身会写日志，不需要父进程接管其输出）。
/// 返回子进程 PID；任何异常均返回 None（由调用方按 None 判启动失败）。
public func launchRuntime(exe: Path, cwd: Path): ?Int64 {
    try {
        let p = launch(
            exe.toString(),
            Array<String>(),
            workingDirectory: Some(cwd),
            environment: fullEnv(HashMap<String, String>()),
            stdIn: ProcessRedirect.Discard,
            stdOut: ProcessRedirect.Discard,
            stdErr: ProcessRedirect.Discard
        )
        return Some(p.pid)
    } catch (_: Exception) {
        return None<Int64>
    }
}
