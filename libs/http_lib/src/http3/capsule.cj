/**
 * HTTP/3 Capsule Protocol（RFC 9297）与 HTTP Datagrams 支持。
 *
 * Capsule Protocol 用于在 HTTP/3 流上传输非 HTTP 数据，如 UDP 数据报和 WebSocket 帧。
 * 在 HTTP/3 中，胶囊帧通过 DATA 帧传输。
 *
 * 胶囊格式：
 *   Capsule Type（QUIC varint）+ Capsule Length（QUIC varint）+ Capsule Data
 *
 * 与 HTTP/2 胶囊（RFC 9298）采用相同的编码格式。
 *
 * @see https://www.rfc-editor.org/rfc/rfc9297
 */
package http_lib.http3

import std.collection.ArrayList
import http_lib.core.ProtocolException
import http_lib.http2.{encodeQuicVarint, decodeQuicVarint}
import http_lib.buffer.ByteBuffer
import http_lib.connection.{AbstractConnection, concatBuffers}
import http_lib.message.HttpRequest
import http_lib.core.HttpMethod

// ======== 胶囊类型（RFC 9297 §3.2）========

/**
 * 胶囊类型枚举。
 */
public enum H3CapsuleType <: ToString & Equatable<H3CapsuleType> {
    | DATA          // 0x00（数据流）
    | DATAGRAM      // 0x01（HTTP 数据报）
    | DATAGRAM_WITH_CONTEXT  // 0x02（带上下文的 HTTP 数据报）
    | CLOSE         // 0x03（关闭流）

    public func toUInt64(): UInt64 {
        match (this) {
            case DATA => 0x00u64
            case DATAGRAM => 0x01u64
            case DATAGRAM_WITH_CONTEXT => 0x02u64
            case CLOSE => 0x03u64
        }
    }

    public static func fromUInt64(v: UInt64): ?H3CapsuleType {
        match (v) {
            case 0x00 => Some(DATA)
            case 0x01 => Some(DATAGRAM)
            case 0x02 => Some(DATAGRAM_WITH_CONTEXT)
            case 0x03 => Some(CLOSE)
            case _ => None
        }
    }

    public func toString(): String {
        match (this) {
            case DATA => "DATA"
            case DATAGRAM => "DATAGRAM"
            case DATAGRAM_WITH_CONTEXT => "DATAGRAM_WITH_CONTEXT"
            case CLOSE => "CLOSE"
        }
    }

    public operator func ==(that: H3CapsuleType): Bool {
        match ((this, that)) {
            case (DATA, DATA) => true
            case (DATAGRAM, DATAGRAM) => true
            case (DATAGRAM_WITH_CONTEXT, DATAGRAM_WITH_CONTEXT) => true
            case (CLOSE, CLOSE) => true
            case _ => false
        }
    }

    public operator func !=(that: H3CapsuleType): Bool { !(this == that) }
}

// ======== 胶囊帧 ========

/**
 * 单个胶囊帧。
 */
public class H3Capsule {
    public let capsuleType: H3CapsuleType
    public let payload: Array<UInt8>

    public init(capsuleType: H3CapsuleType, payload: Array<UInt8>) {
        this.capsuleType = capsuleType
        this.payload = payload
    }

    public func toString(): String {
        "H3Capsule(type: ${capsuleType.toString()}, payload: ${payload.size} bytes)"
    }
}

// ======== 胶囊编解码 ========

/**
 * 编码胶囊帧（类型 + 长度 + 载荷，使用 QUIC varint 编码）。
 */
public func encodeH3Capsule(capsule: H3Capsule): Array<UInt8> {
    let payload = capsule.payload
    let result = ArrayList<UInt8>()
    let typeBytes = encodeQuicVarint(capsule.capsuleType.toUInt64())
    for (b in typeBytes) { result.add(b) }
    let lenBytes = encodeQuicVarint(UInt64(payload.size))
    for (b in lenBytes) { result.add(b) }
    for (b in payload) { result.add(b) }
    result.toArray()
}

/**
 * 解码胶囊帧。
 */
public func decodeH3Capsule(data: Array<UInt8>): H3Capsule {
    var offset: Int64 = 0
    let (typeVal, typeLen) = decodeQuicVarint(data, offset)
    offset += typeLen
    if (offset >= data.size) {
        throw ProtocolException("capsule: missing length field")
    }
    let (payloadLen, lenLen) = decodeQuicVarint(data, offset)
    offset += lenLen
    if (offset + Int64(payloadLen) > data.size) {
        throw ProtocolException("capsule: payload truncated")
    }
    let capsuleType = match (H3CapsuleType.fromUInt64(typeVal)) {
        case Some(ct) => ct
        case None => throw ProtocolException("unknown capsule type: ${typeVal}")
    }
    let payloadEnd = offset + Int64(payloadLen)
    let payload = data[offset..payloadEnd]
    H3Capsule(capsuleType, payload)
}

/**
 * 创建 HTTP Datagram 胶囊。
 * RFC 9298 §5：DATAGRAM 胶囊包含一个完整的 UDP 数据报。
 */
public func buildDatagramCapsule(datagramData: Array<UInt8>): H3Capsule {
    H3Capsule(H3CapsuleType.DATAGRAM, datagramData)
}

/**
 * 创建带上下文的 HTTP Datagram 胶囊。
 */
public func buildDatagramWithContextCapsule(contextId: UInt64, datagramData: Array<UInt8>): H3Capsule {
    let contextBytes = ArrayList<UInt8>()
    let high = UInt8((contextId >> 8) & 0xFF)
    let low = UInt8(contextId & 0xFF)
    contextBytes.add(high)
    contextBytes.add(low)
    for (b in datagramData) { contextBytes.add(b) }
    H3Capsule(H3CapsuleType.DATAGRAM_WITH_CONTEXT, contextBytes.toArray())
}

/**
 * 创建 CLOSE 胶囊（流关闭通知）。
 */
public func buildCloseCapsule(): H3Capsule {
    H3Capsule(H3CapsuleType.CLOSE, [])
}

// ======== WebSocket over HTTP/3 Tunnel（RFC 9220 + RFC 9297）========

/**
 * WebSocket over HTTP/3 隧道。
 *
 * 使用 Extended CONNECT（RFC 9220）建立隧道，
 * 通过胶囊协议（RFC 9297）传输 WebSocket 帧。
 *
 * 用法：
 *   let conn = H3Connection(quicConn, config, isServer: true)
 *   conn.sendSettings()
 *   let req = conn.acceptRequest()
 *   if (conn.isExtendedConnectRequest(req)) {
 *       let tunnel = H3WebSocketTunnel(conn, streamId)
 *       tunnel.send(wsFrame)
 *       let (data, closed) = tunnel.recv()
 *   }
 */
public class H3WebSocketTunnel {
    private var h3Conn: H3Connection
    private var streamId: UInt64
    private var closed: Bool = false
    private var recvBuf: ArrayList<UInt8> = ArrayList<UInt8>()

    public init(h3Conn: H3Connection, streamId: UInt64) {
        this.h3Conn = h3Conn
        this.streamId = streamId
    }

    /**
     * 通过隧道发送 WebSocket 数据。
     * 数据以 DATAGRAM 胶囊形式发送。
     */
    public func send(data: Array<UInt8>): Unit {
        if (closed) { throw Exception("WebSocket tunnel is closed") }
        let capsule = buildDatagramCapsule(data)
        let rawData = encodeH3Capsule(capsule)
        h3Conn.sendTunnelData(streamId, rawData)
    }

    /**
     * 从隧道接收 WebSocket 数据。
     * 阻塞直到 DATAGRAM 胶囊到达或隧道关闭。
     *
     * @return (数据字节, 关闭标志)
     */
    public func recv(): (Array<UInt8>, Bool) {
        if (closed) { return ([], true) }
        // 先消费缓冲区中的数据
        if (recvBuf.size > 0) {
            let data = recvBuf.toArray()
            recvBuf = ArrayList<UInt8>()
            return (data, false)
        }
        ([], closed)
    }

    /**
     * 接收下一段数据，进行胶囊解析。
     * 由 H3Connection 的隧道数据回调调用。
     */
    public func onDataReceived(rawData: Array<UInt8>): Unit {
        try {
            let capsule = decodeH3Capsule(rawData)
            match (capsule.capsuleType) {
                case H3CapsuleType.DATAGRAM =>
                    for (b in capsule.payload) { recvBuf.add(b) }
                case H3CapsuleType.CLOSE =>
                    closed = true
                case H3CapsuleType.DATAGRAM_WITH_CONTEXT =>
                    // 跳过 2 字节的上下文 ID
                    if (capsule.payload.size > 2) {
                        let pd = capsule.payload[2..]
                        for (b in pd) { recvBuf.add(b) }
                    }
                case _ => ()
            }
        } catch (_: Exception) {}
    }

    /**
     * 关闭隧道。
     */
    public func close(): Unit {
        if (closed) { return }
        closed = true
        try {
            let closeCapsule = buildCloseCapsule()
            let rawData = encodeH3Capsule(closeCapsule)
            h3Conn.sendTunnelData(streamId, rawData)
        } catch (_: Exception) {}
        h3Conn.closeTunnel(streamId)
    }

    /**
     * 检查隧道是否已关闭。
     */
    public func isClosed(): Bool { closed }
}


/**
 * 将 H3WebSocketTunnel 适配为 AbstractConnection 接口。
 * 允许服务端处理器使用 WebSocketConn（基于 Connection 接口）处理
 * 通过 HTTP/3 Extended CONNECT（RFC 9220）建立的 WebSocket 隧道。
 *
 * H3WebSocketConnection 包装 H3WebSocketTunnel，将其对 WebSocket
 * 数据的双向收发（send/onDataReceived）适配为标准 Connection 接口
 *（read/write），使得现有的 WebSocket 处理器可以直接在 HTTP/3
 * Extended CONNECT 隧道上工作。
 *
 * 用法：
 *   let tunnel = H3WebSocketTunnel(h3Conn, streamId)
 *   let wsConn = H3WebSocketConnection(tunnel)
 *   wsConn.write(myData)       // 通过 DATAGRAM 胶囊发送
 *   let data = wsConn.read(buf)  // 从胶囊解析中读取
 */
public class H3WebSocketConnection <: AbstractConnection {
    private var tunnel: H3WebSocketTunnel
    private var recvBuf: Array<UInt8> = []
    private var recvOffset: Int64 = 0
    private var closed: Bool = false
    private var eof: Bool = false

    public init(tunnel: H3WebSocketTunnel) {
        this.tunnel = tunnel
        this.connected = true
    }

    /**
     * 实现 Connection.read：从 WebSocket 隧道读取数据。
     * 内部从 H3WebSocketTunnel.recv() 获取 DATAGRAM 胶囊载荷，
     * 缓存后按 read(buf) 语义返回。
     */
    public override func read(buf: Array<UInt8>): Int64 {
        if (closed || eof) { return 0 }
        // 填充接收缓冲区
        if (recvBuf.size == 0 || recvOffset >= recvBuf.size) {
            let (data, isClosed) = tunnel.recv()
            if (isClosed) {
                eof = true
                return 0
            }
            if (data.size == 0) {
                return 0
            }
            recvBuf = data
            recvOffset = 0
        }
        let available = recvBuf.size - recvOffset
        let toRead = if (buf.size < available) { buf.size } else { available }
        var i: Int64 = 0
        while (i < toRead) {
            buf[i] = recvBuf[recvOffset + i]
            i += 1
        }
        recvOffset += toRead
        updateActivity()
        toRead
    }

    /**
     * 实现 Connection.read(buf, offset, length)。
     */
    public override func read(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        if (offset + length > buf.size) {
            throw Exception("read: buffer overflow")
        }
        let slice = buf[offset..offset + length]
        read(slice)
    }

    /**
     * 实现 Connection.write：通过 DATAGRAM 胶囊向隧道写数据。
     */
    public override func write(data: Array<UInt8>): Unit {
        if (closed) { throw Exception("write: connection is closed") }
        tunnel.send(data)
        updateActivity()
    }

    /**
     * 实现 Connection.write(data, offset, length)。
     */
    public override func write(data: Array<UInt8>, offset: Int64, length: Int64): Unit {
        if (offset + length > data.size) {
            throw Exception("write: buffer overflow")
        }
        let slice = data[offset..offset + length]
        write(slice)
    }

    /**
     * 实现 Connection.close：关闭 WebSocket 隧道。
     */
    public override func close(): Unit {
        if (closed) { return }
        closed = true
        eof = true
        connected = false
        tunnel.close()
    }

    /**
     * 实现 Connection.isConnected。
     */
    public override func isConnected(): Bool { connected && !eof }

    /**
     * 实现 Resource.isClosed（由 Connection/IOStream 链继承）。
     */
    public override func isClosed(): Bool { closed || eof }

    /**
     * 实现 Connection.canReuseTransport。
     */
    public override func canReuseTransport(): Bool { false }

    /**
     * 实现 Connection.isReadable。
     */
    public override func isReadable(timeout: ?Duration): Bool {
        isConnected()
    }

    /**
     * 实现 Connection.isWritable。
     */
    public override func isWritable(timeout: ?Duration): Bool {
        isConnected()
    }

    /**
     * 实现 Connection.localAddress。
     */
    public func getLocalAddress(): String { localAddr }

    /**
     * 实现 Connection.remoteAddress。
     */
    public func getRemoteAddress(): String { remoteAddr }

    /**
     * 实现 Connection.writeBuffers：批量写入多个缓冲区。
     */
    public override func writeBuffers(buffers: ArrayList<Array<UInt8>>): Unit {
        let merged = concatBuffers(buffers)
        write(merged)
    }

    /**
     * 设置本端地址。
     */
    public func setLocalAddress(addr: String): Unit { localAddr = addr }

    /**
     * 设置对端地址。
     */
    public func setRemoteAddress(addr: String): Unit { remoteAddr = addr }
}


// ======== CONNECT-UDP Tunnel (RFC 9298) ========

/**
 * CONNECT-UDP tunnel.
 *
 * Uses Extended CONNECT (RFC 9220) to establish a UDP proxy tunnel,
 * transmitting UDP datagrams via DATAGRAM capsules (RFC 9297).
 *
 * RFC 9298 Section 3.1: CONNECT-UDP requests use :protocol = "connect-udp",
 * successful responses use 200 status code. All UDP datagrams are
 * then transmitted via HTTP Datagrams.
 */
public class ConnectUdpTunnel {
    private var h3Conn: H3Connection
    private var streamId: UInt64
    private var closed: Bool = false
    private var recvBuf: ArrayList<UInt8> = ArrayList<UInt8>()
    /// CONNECT-UDP context ID (RFC 9298 Section 3.2), default 0
    private var contextId: UInt64 = 0

    public init(h3Conn: H3Connection, streamId: UInt64, contextId!: UInt64 = 0) {
        this.h3Conn = h3Conn
        this.streamId = streamId
        this.contextId = contextId
    }

    /**
     * Send a UDP datagram through the tunnel.
     * Data is sent as a DATAGRAM capsule.
     */
    public func send(data: Array<UInt8>): Unit {
        if (closed) { throw Exception("CONNECT-UDP tunnel is closed") }
        let capsule = buildDatagramCapsule(data)
        let rawData = encodeH3Capsule(capsule)
        h3Conn.sendTunnelData(streamId, rawData)
    }

    /**
     * Receive a UDP datagram from the tunnel.
     * Non-blocking: returns data if available, empty buffer otherwise.
     *
     * @return (data bytes, closed flag)
     */
    public func recv(): (Array<UInt8>, Bool) {
        if (closed) { return ([], true) }
        if (recvBuf.size > 0) {
            let data = recvBuf.toArray()
            recvBuf = ArrayList<UInt8>()
            return (data, false)
        }
        ([], false)
    }

    /**
     * Process received data from the stream (capsule format).
     * Called by the upper layer when a DATA frame is received.
     */
    public func onDataReceived(data: Array<UInt8>): Unit {
        if (data.size == 0) { return }
        try {
            let capsule = decodeH3Capsule(data)
            match (capsule.capsuleType) {
                case H3CapsuleType.DATAGRAM =>
                    for (b in capsule.payload) { recvBuf.add(b) }
                case H3CapsuleType.DATAGRAM_WITH_CONTEXT =>
                    if (capsule.payload.size >= 8) {
                        let (ctxId, ctxLen) = decodeQuicVarint(capsule.payload, 0)
                        _ = ctxId
                        var i = ctxLen
                        while (i < capsule.payload.size) {
                            recvBuf.add(capsule.payload[i])
                            i += 1
                        }
                    } else {
                        for (b in capsule.payload) { recvBuf.add(b) }
                    }
                case H3CapsuleType.CLOSE =>
                    closed = true
                case _ => ()
            }
        } catch (_: ProtocolException) {}
    }

    /**
     * Close the tunnel.
     */
    public func close(): Unit {
        if (closed) { return }
        closed = true
        try {
            let closeCapsule = buildCloseCapsule()
            h3Conn.sendTunnelData(streamId, encodeH3Capsule(closeCapsule))
        } catch (_: Exception) {}
    }

    /**
     * Check if the tunnel is closed.
     */
    public func isClosed(): Bool { closed }
}
