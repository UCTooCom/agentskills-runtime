package http_lib.server
/**
 * WebSocket 服务器端（RFC 6455）。
 * 提供 WebSocket 握手、帧收发和连接管理。
 */

import std.collection.ArrayList
import std.sync.{Mutex, AtomicBool}
import http_lib.connection.Connection

/**
 * WebSocket 连接处理器。
 */
public class WebSocketConn {
    private let conn: Connection
    private let closed: AtomicBool = AtomicBool(false)
    private var fragmentBuf: ArrayList<UInt8> = ArrayList<UInt8>()
    private var fragmentOpcode: ?WebSocketOpcode = None
    private var readBuf: ArrayList<UInt8> = ArrayList<UInt8>()

    private var pmd: PerMessageDeflate

    public init(conn: Connection, pmd !: PerMessageDeflate = PerMessageDeflate()) {
        this.conn = conn
        this.pmd = pmd
    }

    /**
     * 设置 Per-Message Deflate 压缩器。
     */
    public func setPmd(pmd: PerMessageDeflate): Unit {
        this.pmd = pmd
    }

    /**
     * 获取当前 PMD 压缩器。
     */
    public func getPmd(): PerMessageDeflate {
        pmd
    }

    /**
     * 读取下一个完整的 WebSocket 消息。
     * 自动组装分片消息并处理控制帧
     * （Ping/Pong/Close）内部处理。
     *
     * 如果连接关闭或发生错误，返回 None。
     */
    public func readMessage(): ?WebSocketMessage {
        while (!closed.load()) {
            let frame = try {
                // 确保至少有 2 字节帧头
                while (readBuf.size < 2) {
                    let tmp = Array<UInt8>(65536, repeat: 0)
                    let n = conn.read(tmp)
                    if (n <= 0) { return None }
                    var i: Int64 = 0
                    while (i < n) { readBuf.add(tmp[i]); i += 1 }
                }

                // 计算帧大小
                let b1 = readBuf[1]
                var payloadLen = Int64(b1 & 0x7f)
                var frameSize: Int64 = 2
                if (payloadLen == 126) { frameSize += 2 }
                else if (payloadLen == 127) { frameSize += 8 }
                if ((b1 & 0x80) != 0) { frameSize += 4 }
                frameSize += payloadLen

                // 确保完整帧在缓冲中
                while (readBuf.size < frameSize) {
                    let tmp = Array<UInt8>(4096, repeat: 0)
                    let n = conn.read(tmp)
                    if (n <= 0) { return None }
                    var i: Int64 = 0
                    while (i < n) { readBuf.add(tmp[i]); i += 1 }
                }

                // 提取并解析帧
                let frameData = Array<UInt8>(frameSize, repeat: 0)
                var i: Int64 = 0
                while (i < frameSize) { frameData[i] = readBuf[i]; i += 1 }
                parseWebSocketFrame(frameData)
            } catch (_: Exception) {
                return None
            }

            // 从缓冲中移除已处理的帧字节
            let b1 = readBuf[1]
            var payloadLen = Int64(b1 & 0x7f)
            var consumed: Int64 = 2
            if (payloadLen == 126) { consumed += 2 }
            else if (payloadLen == 127) { consumed += 8 }
            if ((b1 & 0x80) != 0) { consumed += 4 }
            consumed += payloadLen

            let remaining = readBuf.size - consumed
            if (remaining > 0) {
                let newBuf = ArrayList<UInt8>()
                var i = consumed
                while (i < readBuf.size) {
                    newBuf.add(readBuf[i])
                    i += 1
                }
                readBuf = newBuf
            } else {
                readBuf = ArrayList<UInt8>()
            }

            match (frame.opcode) {
                case WebSocketOpcode.Ping =>
                    // 根据 RFC 6455 第 5.5.2 节自动回复 Pong
                    try {
                        let pongFrame = encodeWebSocketFrame(WebSocketOpcode.Pong, frame.payloadData, false)
                        conn.write(pongFrame)
                        conn.flush()
                    } catch (_: Exception) {}
                    continue

                case WebSocketOpcode.Pong =>
                    // 收到 Pong — 可用于保活追踪
                    continue

                case WebSocketOpcode.Close =>
                    // 根据 RFC 6455 第 5.5.1 节回复携带负载回显的 Close 帧
                    try {
                        let closeFrame = encodeWebSocketFrame(WebSocketOpcode.Close, frame.payloadData, false)
                        conn.write(closeFrame)
                        conn.flush()
                    } catch (_: Exception) {}
                    closed.store(true)
                    return Some(WebSocketMessage(opcode: WebSocketOpcode.Close, data: frame.payloadData))

                case WebSocketOpcode.Continuation =>
                    // 累积连续帧数据
                    for (b in frame.payloadData) { fragmentBuf.add(b) }
                    if (frame.fin) {
                        // 最后分片 — 组装完整消息
                        let completeData = fragmentBuf.toArray()
                        fragmentBuf = ArrayList<UInt8>()
                        // 如果首帧 RSV1 置位，对完整消息解压
                        let decompressedData = if (pmd.isActive()) {
                            let doDecompress = match (fragmentOpcode) {
                                case Some(WebSocketOpcode.Text) => true
                                case Some(WebSocketOpcode.Binary) => true
                                case _ => false
                            }
                            if (doDecompress) {
                                    pmd.decompressPayload(completeData)
                            } else { completeData }
                        } else {
                            completeData
                        }
                        let opcode = match (fragmentOpcode) {
                            case Some(op) => op
                            case None => WebSocketOpcode.Binary
                        }
                        fragmentOpcode = None
                        return Some(WebSocketMessage(opcode: opcode, data: decompressedData))
                    }
                    continue

                case WebSocketOpcode.Text | WebSocketOpcode.Binary =>
                    // 第一帧（可能已分片）
                    if (frame.fin) {
                        let decompressed = if (pmd.isActive() && frame.rsv1) {
                            pmd.decompressPayload(frame.payloadData)
                        } else {
                            frame.payloadData
                        }
                        return Some(WebSocketMessage(opcode: frame.opcode, data: decompressed))
                    }
                    // 分片消息的开始
                    fragmentOpcode = Some(frame.opcode)
                    fragmentBuf = ArrayList<UInt8>()
                    for (b in frame.payloadData) { fragmentBuf.add(b) }
                    continue
            }
        }
        None
    }

    /**
     * 发送文本消息。
     */
    public func writeText(text: String): Unit {
        let payload = unsafe { text.rawData() }
        let (compressedPayload, useRsv1) = if (pmd.isActive()) {
            (pmd.compressPayload(payload), true)
        } else {
            (payload, false)
        }
        let frame = encodeWebSocketFrame(WebSocketOpcode.Text, compressedPayload, false, rsv1: useRsv1)
        conn.write(frame)
        conn.flush()
    }

    /**
     * 发送二进制消息。
     */
    public func writeBinary(data: Array<UInt8>): Unit {
        let (compressedData, useRsv1) = if (pmd.isActive()) {
            (pmd.compressPayload(data), true)
        } else {
            (data, false)
        }
        let frame = encodeWebSocketFrame(WebSocketOpcode.Binary, compressedData, false, rsv1: useRsv1)
        conn.write(frame)
        conn.flush()
    }

    /**
     * 发送 Ping 帧用于保活。
     */
    public func writePing(data: Array<UInt8>): Unit {
        let frame = encodeWebSocketFrame(WebSocketOpcode.Ping, data, false)
        conn.write(frame)
        conn.flush()
    }

    /**
     * 发送 Pong 帧（通常自动处理）。
     */
    public func writePong(data: Array<UInt8>): Unit {
        let frame = encodeWebSocketFrame(WebSocketOpcode.Pong, data, false)
        conn.write(frame)
        conn.flush()
    }

    /**
     * 发送带空负载的 Ping 帧用于保活。
     */
    public func writePing(): Unit {
        writePing([])
    }

    /**
     * 发送 Close 帧并关闭连接。
     */
    public func close(statusCode: UInt16): Unit {
        if (closed.load()) { return }
        closed.store(true)
        try {
            let statusBytes: Array<UInt8> = [UInt8((statusCode >> 8) & 0xff), UInt8(statusCode & 0xff)]
            let closeFrame = encodeWebSocketFrame(WebSocketOpcode.Close, statusBytes, false)
            conn.write(closeFrame)
            conn.flush()
        } catch (_: Exception) {}
        try { conn.close() } catch (_: Exception) {}
    }

    /**
     * 检查连接是否仍处于打开状态。
     */
    public func isClosed(): Bool { closed.load() }
}

/**
 * 完整的 WebSocket 消息。
 * 提供对文本和二进制负载的类型化访问。
 */
public class WebSocketMessage {
    public let opcode: WebSocketOpcode
    public let data: Array<UInt8>

    public init(opcode!: WebSocketOpcode, data!: Array<UInt8>) {
        this.opcode = opcode
        this.data = data
    }

    public func isText(): Bool { opcode == WebSocketOpcode.Text }
    public func isBinary(): Bool { opcode == WebSocketOpcode.Binary }
    public func isPing(): Bool { opcode == WebSocketOpcode.Ping }
    public func isPong(): Bool { opcode == WebSocketOpcode.Pong }
    public func isClose(): Bool { opcode == WebSocketOpcode.Close }

    /**
     * 以 UTF-8 字符串形式获取消息（用于文本消息）。
     */
    public func text(): String { String.fromUtf8(data) }
}
