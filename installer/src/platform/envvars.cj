package uc_installer.platform

import std.env.{getVariable, setVariable}
import std.collection.{ArrayList, HashMap}

// 环境变量读写（Phase 1 / T008）
//
// 目标 trio：`CANGJIE_HOME` / `CANGJIE_STDX_PATH` / `PATH` 的用户级与系统级读写，
// 并满足 AC-161「写入后必须在**新的进程**中验证编译器命令可被解析，验证失败不得标记成功」。
//
// ⚠️ Windows 上有一处极易踩空的地方，`setx` 与 `setVariable` 必须**成对使用**：
//   - `setx` 写的是注册表（持久化），**不改变当前进程已加载的环境块**；
//   - installer 自身是常驻进程，它 spawn 的子进程默认继承 installer 的环境块，
//     因此**只调 setx 的话，紧接着起来的子进程根本看不到新变量**；
//   - 所以每次写都要：setx（持久化）+ setVariable（让当前进程环境与之一致）。
//
// 配套地，子进程环境在 T006 的 `buildChildEnv` 里是每次重新 `HashMap(getVariables())`
// 构造的（而非启动时缓存），这套组合才能保证「刚写的值，下一个子进程立刻可读」。

/// 环境变量作用域。
public enum EnvScope {
    | USER    // 用户级（HKCU\Environment），默认，无需提权
    | SYSTEM  // 系统级（HKLM\...\Environment），需要管理员权限
}

/// 环境变量写入结果。
///
/// 不用 `(Bool, String)` 元组而是具名 struct，是为了让调用侧必须显式看 `detail` ——
/// 环境变量写失败往往静默（权限不足时 setx 仍可能返回内容的后半段），
/// 只判 Bool 的话排查成本极高。
public struct EnvWriteResult {
    public let ok: Bool
    public let detail: String

    public init(ok: Bool, detail: String) {
        this.ok = ok
        this.detail = detail
    }
}

/// 用户级 PATH 在注册表中的位置（供 reg query 使用）。
private let REG_USER_ENV = "HKCU\\Environment"

/// 读取环境变量（当前进程视角）。
///
/// - name: 变量名
/// - returns: 存在则为 `Some(值)`，否则 `None`
public func readEnv(name: String): Option<String> {
    getVariable(name)
}

/// 写出环境变量并同步当前进程环境。
///
/// 步骤：① `setx` 落注册表（持久）→ ② `setVariable` 同步当前进程（即时可见）
/// → ③ 读回校验。任一步失败都返回 `ok=false` 并写明原因。
///
/// - name: 变量名
/// - value: 变量值
/// - scope: 用户级 / 系统级
/// - returns: 写入结果与说明
public func writeEnv(name: String, value: String, scope!: EnvScope = EnvScope.USER): EnvWriteResult {
    let args = ArrayList<String>()
    args.add(name)
    args.add(value)
    match (scope) {
        case EnvScope.SYSTEM => args.add("/M")
        case EnvScope.USER => ()
    }

    let writeBack = runCapped("setx", args.toArray(), cap: Duration.second * 10)
    if (writeBack.timedOut) {
        return EnvWriteResult(false, "setx 执行超时，环境变量 ${name} 未确认为已写入")
    }
    if (writeBack.exitCode != 0) {
        let why = decodeOutput(writeBack.stderr)
        return EnvWriteResult(false, "setx 写入 ${name} 失败（退出码 ${writeBack.exitCode}）：${why}")
    }

    // setx 只改注册表；必须用这一步让当前进程环境与之一致，
    // 否则后续 spawn 的子进程继承的是旧环境块，验证环节必然失败。
    try {
        setVariable(name, value)
    } catch (_: Exception) {
        return EnvWriteResult(false, "已写入注册表，但同步当前进程环境失败，${name} 在本进程内不可用")
    }

    let verified = readEnv(name)
    match (verified) {
        case Some(v) =>
            if (v == value) {
                EnvWriteResult(true, "")
            } else {
                EnvWriteResult(false, "写入后读回不一致：期望 ${value}，实际 ${v}")
            }
        case None => EnvWriteResult(false, "写入后无法读回 ${name}")
    }
}

/// 读取用户级 PATH 的原始值（不含系统级 PATH）。
///
/// 为什么要单独读：向 PATH 追加前必须先拿到「用户级 PATH」本身的值。
/// 若直接用 `getVariable("PATH")`，拿到的是**用户级与系统级合并后**的结果，
/// 把它整体写回用户级会把系统 PATH 复制一份进用户级 —— 短期能跑，
/// 但后续清理/升级时会出现重复项与优先级错乱，是很难查的慢性问题。
///
/// - returns: 用户级 PATH；读取失败或该值不存在时返回空串
public func readUserPath(): String {
    let r = runCapped("reg", ["query", REG_USER_ENV, "/v", "Path"], cap: Duration.second * 10)
    if (r.timedOut || r.exitCode != 0) {
        return ""
    }
    return parseRegQueryValue(decodeOutput(r.stdout))
}

/// 解析 `reg query <key> /v <name>` 的输出，取出值部分。
///
/// 输出形如：
/// ```
/// <空行>
///     Path    REG_EXPAND_SZ    C:\foo;C:\bar
/// ```
/// 值名与类型、类型与值之间由若干空白分隔；值本身**可以包含空格**，
/// 因此不能用整行 split 后取第 3 段，必须跳到类型标记之后整体取剩余部分。
private func parseRegQueryValue(output: String): String {
    for (rawLine in splitLines(output)) {
        let line = rawLine.trimAscii()
        if (line.startsWith("Path") || line.startsWith("PATH") || line.startsWith("Path ")) {
            // 跳到 REG_ 类型标记之后，取剩余部分作为值
            let typeIdx = indexOfRegType(line)
            if (typeIdx < 0) {
                continue
            }
            let rest = line[typeIdx..line.size]
            for (seg in rest.split(" ", 2)) {
                // split 的第 0 段是类型名本身，第 1 段起才是值
                if (seg.startsWith("REG_")) {
                    continue
                }
                return seg.trimAscii()
            }
        }
    }
    return ""
}

/// 在行内定位注册表类型标记（REG_SZ / REG_EXPAND_SZ 等）的起始下标，找不到返回 -1。
private func indexOfRegType(line: String): Int64 {
    if (line.contains("REG_EXPAND_SZ")) {
        return lineIndexOfMarker(line, "REG_EXPAND_SZ")
    }
    if (line.contains("REG_SZ")) {
        return lineIndexOfMarker(line, "REG_SZ")
    }
    return -1
}

/// 返回 marker 在 line 中的起始列（按字节），未出现返回 -1。
///
/// ⚠️ 仓颉 `String` 是 UTF-8，`indexof` 系列只接受单个字节，
/// 拿子串去查会编译失败，因此这里用逐字节滑窗自己对齐。
private func lineIndexOfMarker(line: String, marker: String): Int64 {
    let lineBytes = line.toArray()
    let markerBytes = marker.toArray()
    if (markerBytes.size == 0 || lineBytes.size < markerBytes.size) {
        return -1
    }
    var i = 0
    while (i <= lineBytes.size - markerBytes.size) {
        var matched = true
        var j = 0
        while (j < markerBytes.size) {
            if (lineBytes[i + j] != markerBytes[j]) {
                matched = false
                break
            }
            j = j + 1
        }
        if (matched) {
            return i
        }
        i = i + 1
    }
    return -1
}

/// 向用户级 PATH 追加一条（幂等：已存在则不再追加）。
///
/// - entry: 待追加的目录
/// - returns: 写入结果与说明
public func appendToPath(entry: String): EnvWriteResult {
    if (entry.isEmpty()) {
        return EnvWriteResult(false, "待追加的 PATH 条目为空")
    }
    let current = readUserPath()
    let normalizedEntry = stripTrailingSep(entry)

    for (part in current.split(";")) {
        if (stripTrailingSep(part.trimAscii()).toAsciiLower() == normalizedEntry.toAsciiLower()) {
            // 已存在即视为成功 —— 追加是幂等操作，重复跑安装不该产生重复项。
            return EnvWriteResult(true, "")
        }
    }

    let merged = if (current.isEmpty()) {
        normalizedEntry
    } else {
        current + ";" + normalizedEntry
    }
    return writeEnv("Path", merged)
}

/// 去掉路径末尾的反斜杠，用于路径等价性比较（C:\foo 与 C:\foo\ 应当视为同一条）。
private func stripTrailingSep(p: String): String {
    var s = p
    while (s.size > 1 && (s.endsWith("\\") || s.endsWith("/"))) {
        s = s[0..s.size - 1]
    }
    return s
}

/// 在新的进程中验证某个命令可被解析出来（AC-161）。
///
/// 用 `cmd /c where <cmd>`：`where` 是 cmd 的内置命令，直接 exec 找不到可执行文件，
/// 必须经由 cmd。这也是「新进程」要求的落点 —— 它检验的是
/// **写入的环境变量在全新进程里确实生效**，而不是当前进程的缓存。
///
/// - cmd: 待验证的可执行文件名，如 `cjc`
/// - returns: 可解析且执行成功返回 true
public func verifyCommandResolvable(cmd: String): Bool {
    let r = runCapped("cmd", ["/c", "where", cmd], cap: Duration.second * 10)
    succeeded(r)
}

/// 组合验证：某环境变量指向的目录下，可执行文件可被新进程解析到。
///
/// 这是 AC-161「写入后必须新进程验证」的标准收口：环境变量本身写成功不算成功，
/// 必须落到「编译器命令能被找到」这个可观测事实上。
///
/// - varName: 环境变量名（用于诊断文案）
/// - cmd: 需要能被解析的命令
/// - returns: 命令可解析返回 true；否则 false（调用方据此不得标记成功）
public func verifyEnvResolvesCommand(varName: String, cmd: String): Bool {
    let present = readEnv(varName)
    match (present) {
        case Some(v) =>
            if (v.isEmpty()) {
                false
            } else {
                verifyCommandResolvable(cmd)
            }
        case None => false
    }
}
