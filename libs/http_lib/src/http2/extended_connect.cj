/**
 * RFC 8441 Extended CONNECT 与 WebSocket over HTTP/2 隧道支持。
 *
 * 扩展 CONNECT 使用 :protocol 伪头部指定隧道协议（如 websocket）。
 * 在 HTTP/2 流上建立双向隧道用于非 HTTP 协议通信。
 */
package http_lib.http2
import http_lib.message.HttpRequest
import http_lib.core.{HttpMethod, HttpStatus}
import http_lib.connection.AbstractConnection
import http_lib.buffer.ByteBuffer
import std.collection.ArrayList

/**
 * RFC 8441 Extended CONNECT 支持。
 *
 * 扩展 CONNECT 使用 :protocol 伪头部指定隧道协议。
 * 例如 WebSocket over HTTP/2 使用 :protocol = "websocket"。
 */

/**
 * 扩展 CONNECT 协议常量。
 */
public let EXTENDED_CONNECT_PROTOCOL_PSEUDO_HEADER = ":protocol"

/**
 * 已知的 :protocol 值。
 * WebSocket over HTTP/2 (RFC 8441 §4)
 */
public let PROTOCOL_WEBSOCKET = "websocket"
    /**
     * 通过隧道发送 WebSocket 数据。
     * 数据以 HTTP/2 DATA 帧形式在隧道流上发送。
     */


/**
 * WebSocket over HTTP/2 tunnel (RFC 8441).
 *
 * After the extended CONNECT handshake (CONNECT + :protocol + 200 response),
 * this tunnel manages bidirectional WebSocket frame exchange over the H2 stream.
    /**
     * 从隧道接收 WebSocket 数据。
     * 阻塞直到 DATA 帧到达或隧道关闭。
     * @return (数据字节, 关闭标志)
     */
 *
 * Usage:
 *   let tunnel = H2WebSocketTunnel(h2conn, streamId)
 *   tunnel.send(wsFrameBytes)
 *   let (data, closed) = tunnel.recv()
 */
public class H2WebSocketTunnel {
    private var h2conn: Http2Connection
    private var streamId: UInt32
    private var closed: Bool

    public init(h2conn: Http2Connection, streamId: UInt32) {
        this.h2conn = h2conn
        this.streamId = streamId
        this.closed = false
    }

    /**
     * Send WebSocket data over the tunnel.
     * Data is sent as HTTP/2 DATA frames on the tunnel stream.
     */
    public func send(data: Array<UInt8>): Unit {
        if (closed) { throw Exception("WebSocket tunnel is closed") }
        h2conn.sendTunnelData(streamId, data)
    }

    /**
     * Receive WebSocket data from the tunnel.
     * Blocks until a DATA frame arrives or the tunnel is closed.
     *
     * @return (data, closed) Received data and close flag
     */
    public func recv(): (Array<UInt8>, Bool) {
        if (closed) { return ([], true) }
        let (data, endStream) = h2conn.readStreamDataFrame(streamId)
        if (endStream) { closed = true }
        (data, endStream)
    }

    /**
     * Close the tunnel by sending RST_STREAM.
     */
    public func close(): Unit {
        if (closed) { return }
        closed = true
        h2conn.cancelPush(streamId, errorCode: Http2ErrorCode.CANCEL)
    }

    /**
     * Check if the tunnel has been closed.
     */
    public func isClosed(): Bool { closed }
}

public func establishWebSocketTunnel(h2conn: Http2Connection, targetHost: String, targetPort: UInt16): H2WebSocketTunnel {
    let request = HttpRequest(method: HttpMethod.CONNECT, url: "${targetHost}:${targetPort}")
    request.headers.set(":protocol", "websocket")
    let streamId = h2conn.sendRequest(request)
    let response = h2conn.recvResponse(streamId)
    if (response.status.code != 200) {
        throw Exception("WebSocket tunnel establishment failed: ${response.status.code}")
    }
    H2WebSocketTunnel(h2conn, streamId)
}




/**
 * H2WebSocketConnection — 将 H2WebSocketTunnel 适配为 Connection 接口。
 *
 * 允许服务端处理器使用 WebSocketConn（基于 Connection 接口）处理
 * 通过 HTTP/2 扩展 CONNECT（RFC 8441）建立的 WebSocket 隧道。
 *
 * 用法（服务端）：
 *   let tunnel = req.metadata.getOrThrow() as H2WebSocketTunnel
 *   let wsConn = WebSocketConn(H2WebSocketConnection(tunnel))
 *   let msg = wsConn.readMessage()
 *
 * Connection.read() 从隧道接收数据帧，Connection.write() 通过
 * 隧道 DATA 帧发送数据。
 */
public class H2WebSocketConnection <: AbstractConnection {
    private var tunnel: H2WebSocketTunnel
    private var recvBuf: Array<UInt8>
    private var recvOffset: Int64
    private var wsClosed: Bool

    public init(tunnel: H2WebSocketTunnel) {
        this.tunnel = tunnel
        this.recvBuf = []
        this.recvOffset = 0
        this.wsClosed = false
    }

    public override func read(buf: Array<UInt8>): Int64 {
        // 先消费缓冲中的数据
        if (recvOffset < recvBuf.size) {
            let avail = recvBuf.size - recvOffset
            let toRead = if (avail < buf.size) { avail } else { buf.size }
            var i: Int64 = 0
            while (i < toRead) {
                buf[i] = recvBuf[recvOffset + i]
                i += 1
            }
            recvOffset += toRead
            if (recvOffset >= recvBuf.size) {
                recvBuf = []
                recvOffset = 0
            }
            updateActivity()
            return toRead
        }
        // 从隧道接收数据
        let (data, closed) = tunnel.recv()
        if (data.size == 0) {
            if (closed) { wsClosed = true }
            return 0
        }
        let toRead = if (data.size < buf.size) { data.size } else { buf.size }
        var i: Int64 = 0
        while (i < toRead) {
            buf[i] = data[i]
            i += 1
        }
        // 剩余部分存入缓冲
        if (toRead < data.size) {
            let remaining = Array<UInt8>(data.size - toRead, repeat: 0)
            var j: Int64 = 0
            while (j < remaining.size) {
                remaining[j] = data[toRead + j]
                j += 1
            }
            recvBuf = remaining
            recvOffset = 0
        }
        updateActivity()
        toRead
    }

    public override func write(data: Array<UInt8>): Unit {
        if (!tunnel.isClosed()) {
            tunnel.send(data)
        }
        updateActivity()
    }

    public override func close(): Unit {
        tunnel.close()
        wsClosed = true
    }

    public func isClosed(): Bool { wsClosed }

    public override func canReuseTransport(): Bool {
        false
    }

    public override func read(buf: Array<UInt8>, offset: Int64, length: Int64): Int64 {
        let tmp = Array<UInt8>(length, repeat: 0)
        let n = read(tmp)
        if (n > 0 && offset + n <= buf.size) {
            tmp[0..n].copyTo(buf, offset, 0, n)
        }
        n
    }

    public override func write(data: Array<UInt8>, offset: Int64, length: Int64): Unit {
        if (offset + length <= data.size) {
            let slice = data[offset..offset + length]
            write(slice)
        }
    }

    public override func isReadable(timeout: ?Duration): Bool {
        !wsClosed
    }

    public override func isWritable(timeout: ?Duration): Bool {
        !wsClosed
    }

    public override func writeBuffers(buffers: ArrayList<Array<UInt8>>): Unit {
        for (b in buffers) {
            write(b)
        }
    }
}
