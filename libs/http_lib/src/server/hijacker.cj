package http_lib.server
/**
 * 连接劫持：允许处理器接管底层 TCP 连接。
 * 用于 WebSocket 升级、HTTP 隧道等协议升级场景。
 */

import http_lib.connection.Connection
import http_lib.core.ProtocolException
import http_lib.message.HttpRequest

/**
 * ConnectionController 允许 HTTP 处理器接管底层连接
 * 劫持成功后，服务器不再管理该连接，
 * 处理器完全接管所有权并负责关闭它。
 *
连接劫持器。
 *
 * 从 Handler（接收 HttpRequest）使用的用法：
 *
 *   func wsHandler(req: HttpRequest): HttpResponse {
 *       // 从请求中获取底层连接
 *       let conn = match (req.connection) {
 *           case Some(c) => c
 *           case None =>
 *               return HttpResponse.text(
 *                   HttpStatus.INTERNAL_SERVER_ERROR,
 *                   "不支持劫持"
 *               )
 *       }
 *
 *       // 验证 WebSocket 升级请求
 *       let wsKey = match (req.headers.get("sec-websocket-key")) {
 *           case Some(k) => k
 *           case None =>
 *               return HttpResponse.text(HttpStatus.BAD_REQUEST,
 *                   "缺少 Sec-WebSocket-Key")
 *       }
 *
 *       // 手动发送 101 Switching Protocols 响应
 *       let accept = computeWebSocketAcceptKey(wsKey)
 *       let resp = "HTTP/1.1 101 Switching Protocols\r\n" +
 *                   "Upgrade: websocket\r\n" +
 *                   "Connection: Upgrade\r\n" +
 *                   "Sec-WebSocket-Accept: ${accept}\r\n\r\n"
 *       conn.write(unsafe { resp.rawData() })
 *
 *       // 通知服务器连接已被劫持
 *       req.takenOver = true
 *
 *       // 执行原始 WebSocket I/O（阻塞直到会话结束）
 *       let buf = Array<UInt8>(4096, repeat: 0)
 *       while (true) {
 *           let n = conn.read(buf)
 *           if (n <= 0) { break }
 *           conn.write(buf[0..n])  // 回声（回显数据）
 *       }
 *
 *       return HttpResponse.empty()  // 劫持后服务器丢弃此响应
 *   }
 */
public class ConnectionController {
    private var conn: Connection
    private var takenOver: Bool = false
    private var pmd: PerMessageDeflate

    public init(conn: Connection, pmd !: PerMessageDeflate = PerMessageDeflate()) {
        this.conn = conn
        this.pmd = pmd
    }

    /**
     * Hijack the underlying connection from the HTTP 服务器.
     *
     * 返回用于直接读/写操作的 Connection。
     * 调用 takeover() 后，调用者拥有该连接，并且
     * 必须在使用完后关闭它。
     *
     * HTTP 服务器将不再对此连接执行任何 I/O 操作
     * 调用 takeover() 后的连接。
     */
    public func takeover(): Connection {
        takenOver = true
        conn
    }

    /**
     * 如果在此实例上调用了 takeover()，则返回 true。
     */
    public func isTakenOver(): Bool {
        takenOver
    }

    /**
     * 获取协商后的 Per-Message Deflate 实例。
     * 仅在升级到 WebSocket 后有效。
     */
    public func getPmd(): PerMessageDeflate {
        pmd
    }

    /**
     * 便捷方法：将原始数据写入底层连接。
     * 相当于 takeover().write(data) 但不改变状态。
     */
    public func write(data: Array<UInt8>): Unit {
        conn.write(data)
    }

    /**
     * 便捷方法：从底层连接读取原始数据。
     * 相当于 takeover().read(buf) 但不改变状态。
     */
    public func read(buf: Array<UInt8>): Int64 {
        conn.read(buf)
    }

    /**
     * 便捷方法：关闭底层连接。
     */
    public func close(): Unit {
        conn.close()
    }

    /**
     * 便捷方法：为 WebSocket 升级发送 HTTP 101 Switching Protocols 响应
     * 并将连接标记为已劫持。
     *
     * 执行 RFC 6455 第 4.2.1 节定义的 WebSocket 握手：
     * - 计算 Sec-WebSocket-Accept = base64(sha1(key + magic_guid))
     * - 写入带有必需头部的 101 响应
     * - 将连接标记为已劫持
     *
     * 用法：
     *   let h = ConnectionController(conn)
     *   h.upgradeToWebSocket("dGhlIHNhbXBsZSBub25jZQ==")
     * // 连接现已劫持，执行原始 WebSocket I/O
     *
     * @param secWebSocketKey Sec-WebSocket-Key 请求头部的值
     */
    public func upgradeToWebSocket(secWebSocketKey: String): Unit {
        let acceptKey = computeWebSocketAcceptKey(secWebSocketKey)
        let response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${acceptKey}\r\n\r\n"
        conn.write(unsafe { response.rawData() })
        takenOver = true
    }

    /**
     * 便捷方法：使用完整请求执行 WebSocket 升级。
     *
     * 从请求中提取 Sec-WebSocket-Key 头部，发送
     * 101 Switching Protocols 响应，并将此 ConnectionController 和请求
     * 都标记为已劫持（这样服务器就停止管理该连接）。
     * 连接）。
     *
     * 用法：
     *   func wsHandler(req: HttpRequest): HttpResponse {
     *       match (req.connection) {
     *           case Some(conn) =>
     *               let h = ConnectionController(conn)
     *               try { h.upgradeToWebSocket(req) } catch {
     *                   return HttpResponse.text(HttpStatus.BAD_REQUEST, e.message)
     *               }
     * // 连接已被劫持，执行原始 WebSocket I/O
     *               ...
     *               return HttpResponse.empty()
     *           case None =>
     *               HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, "takeover not supported")
     *       }
     *   }
     *
     * @throws 如果 Sec-WebSocket-Key 头部缺失则抛出 ProtocolException
     */
    public func upgradeToWebSocket(req: HttpRequest): Unit {
        let wsKey = match (req.headers.get("sec-websocket-key")) {
            case Some(k) => k
            case None => throw ProtocolException("missing Sec-WebSocket-Key header")
        }
        upgradeToWebSocket(wsKey)
        req.takenOver = true
    }
}
