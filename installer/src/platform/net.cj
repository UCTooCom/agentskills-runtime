package uc_installer.platform

import std.convert.Parsable
import std.net.{SocketTimeoutException, TcpSocket}
import std.collection.{ArrayList, HashMap}

// 端口与网络探测（Phase 1 / T009）
//
// 两类能力，各有分工，不要混用：
//
// 1. **端口占用查询**（netstat 解析）——回答“谁占了”。除了能否绑定，还给出占用者 PID，
//    这是 check-environment 给运维看的 remediation 信息（AC-021 要求返回「实际值」）。
// 2. **连通性探测**（TcpSocket 真连）——回答“连得上吗”。是否被 LISTENING 占用
//    不等于可达（可能被防火墙拦、可能绑在特定网卡上），只有真连一次才算数。
//
// 端口-1 约定：解析不出合法端口时返回 -1（`-1` 不是合法 TCP 端口）。

/// 一条端口占用记录。
public struct PortOccupation {
    public let port: Int64
    public let pid: Int64
    public let protocolName: String
    public let localAddress: String
    public let state: String

    public init(port: Int64, pid: Int64, protocolName: String,
                localAddress: String, state: String) {
        this.port = port
        this.pid = pid
        this.protocolName = protocolName
        this.localAddress = localAddress
        this.state = state
    }
}

/// `netstat` 输出中表示正在监听的状态词。
private let STATE_LISTENING = "LISTENING"

/// 列出指定端口上的监听占用者。
///
/// 一律经由 `runCapped` 执行：`netstat -ano` 在连接数极多的机器上也可能拖慢，
/// 这条路径不能有 hang 风险。
///
/// - port: 目标端口号
/// - returns: 占用记录列表；无占用者、解析失败或查询超时均返回空列表
///   （查询超时返回空列表是刻意的保守：宁可判为“查不到”，也不要在不确定时
///    误导上游去占用一个其实已被占用的端口）
public func listPortListeners(port: Int64): ArrayList<PortOccupation> {
    let out = ArrayList<PortOccupation>()
    let r = runCapped("netstat", ["-ano", "-p", "TCP"], cap: Duration.second * 10)
    if (r.timedOut || r.exitCode != 0) {
        return out
    }
    let text = decodeOutput(r.stdout)
    let suffix = ":${port}"
    for (rawLine in splitLines(text)) {
        let tokens = whitespaceTokens(rawLine.trimAscii())
        // TCP 行固定 5 列：Proto / Local / Foreign / State / PID。
        // 列数不足说明是表头或提示行，直接跳过。
        if (tokens.size < 5) {
            continue
        }
        if (tokens[0] != "TCP") {
            continue
        }
        if (!tokens[1].endsWith(suffix)) {
            continue
        }
        if (tokens[3] != STATE_LISTENING) {
            continue
        }
        let pid = parsePidOrNeg1(tokens[4])
        if (pid < 0) {
            continue
        }
        out.add(PortOccupation(port, pid, tokens[0], tokens[1], tokens[3]))
    }
    return out
}

/// 端口是否空闲（没有 LISTENING 占用者）。
///
/// - port: 端口号
/// - returns: 无监听占用者为 true
public func isPortFree(port: Int64): Bool {
    listPortListeners(port).isEmpty()
}

/// 端口是否被占用。语义与 `isPortFree` 严格相反，仅为表达可读性提供。
public func isPortInUse(port: Int64): Bool {
    !isPortFree(port)
}

/// 批量检测多个端口的占用情况。
///
/// 一次 netstat 覆盖全部目标端口，避免为每个端口各起一次子进程 ——
/// check-environment 有三到五个端口要查，逐个起进程既慢又增加超时面。
///
/// - ports: 端口号列表
/// - returns: 每个端口的占用记录；空闲端口不出现在结果里（结果为空表示全部空闲）
public func checkPorts(ports: Array<Int64>): ArrayList<PortOccupation> {
    let out = ArrayList<PortOccupation>()
    if (ports.isEmpty()) {
        return out
    }
    let r = runCapped("netstat", ["-ano", "-p", "TCP"], cap: Duration.second * 10)
    if (r.timedOut || r.exitCode != 0) {
        return out
    }
    let text = decodeOutput(r.stdout)
    for (rawLine in splitLines(text)) {
        let tokens = whitespaceTokens(rawLine.trimAscii())
        if (tokens.size < 5 || tokens[0] != "TCP" || tokens[3] != STATE_LISTENING) {
            continue
        }
        var hit = -1
        for (p in ports) {
            if (tokens[1].endsWith(":${p}")) {
                hit = p
                break
            }
        }
        if (hit < 0) {
            continue
        }
        let pid = parsePidOrNeg1(tokens[4])
        if (pid < 0) {
            continue
        }
        out.add(PortOccupation(hit, pid, tokens[0], tokens[1], tokens[3]))
    }
    return out
}

/// 本地（回环地址）端口的 TCP 连通性探测 —— 真连一次，而不是看有没有在监听。
///
/// 为什么必须真连：Listening 只说明有进程占着端口，不代表对本机可达。
/// 典型反例是服务只绑在某个网卡地址上、或本机策略拦截了回环之外的访问，
/// 此时 netstat 说“占用”，但 installer 真正要连的时候却被拒。
///
/// 三种异常都按“连不上”处理，不向上抛 —— 探测失败就是失败，属于正常结果。
///
/// - port: 端口号
/// - timeout: 连接超时，默认 3s
/// - returns: 能建立 TCP 连接返回 true
public func isLocalPortReachable(port: Int64, timeout!: Duration = Duration.second * 3): Bool {
    if (port <= 0 || port > 65535) {
        return false
    }
    try {
        let socket = TcpSocket("127.0.0.1", UInt16(port))
        socket.connect(timeout: timeout)
        socket.close()
        return true
    } catch (_: SocketTimeoutException) {
        return false
    } catch (_: Exception) {
        return false
    }
}

/// 按空白切分一列 Sensing：连续的空格/制表符视为一个分隔符。
///
/// netstat 的列用不定长空格对齐（`TCP    0.0.0.0:3000   ...`），
/// 按单个空格 split 会产生大量空项，必须先压缩。
private func whitespaceTokens(line: String): ArrayList<String> {
    let out = ArrayList<String>()
    if (line.isEmpty()) {
        return out
    }
    let runes = line.toRuneArray()
    var cur = StringBuilder()
    var i = 0
    while (i < runes.size) {
        let c = runes[i]
        if (c == r' ' || c == r'\t') {
            if (cur.size > 0) {
                out.add(cur.toString())
                cur = StringBuilder()
            }
        } else {
            cur.append(c)
        }
        i = i + 1
    }
    if (cur.size > 0) {
        out.add(cur.toString())
    }
    return out
}

/// 把十进制 PID 文本解析为整数，失败返回 -1。
private func parsePidOrNeg1(text: String): Int64 {
    let parsed = try {
        Some(Int64.parse(text))
    } catch (_: Exception) {
        None<Int64>
    }
    match (parsed) {
        case Some(v) => v
        case None => -1
    }
}

