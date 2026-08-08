/**
 * WebSocket 客户端（RFC 6455）。
 *
 * 通过 HTTP/1.1 Upgrade 握手建立 WebSocket 连接。
 * 支持 ws:// 和 wss:// URL。
 *
 * 用法：
 *   let client = WebSocketClient()
 *   client.connect("ws://echo.websocket.org")
 *   client.sendText("Hello!")
 *   let msg = client.readMessage()
 *   client.close()
 */
package http_lib.client

import std.convert.Parsable
import std.collection.ArrayList
import std.unicode.*
import std.sync.{Mutex, AtomicBool}
import std.random.Random
import http_lib.connection.{Connection, TcpConnection, TlsConnection, TlsConfig}
import http_lib.core.ProtocolException
import http_lib.server.{WebSocketConn, WebSocketMessage, computeWebSocketAcceptKey}
import http_lib.utils.{base64EncodeBytes, bytesToString, stringToBytes}
import http_lib.server.{PerMessageDeflate, PerMessageDeflateConfig, parsePmdExtensions, buildPmdExtensionHeader}

/**
 * WebSocket 客户端连接。
 *
 * 封装 WebSocket 握手和帧收发。
 * 连接成功后，通过 sendText/sendBinary/readMessage 进行通信。
 */
public class WebSocketClient {
    private var conn: ?WebSocketConn = None
    private var closed: Bool = false
    private var pmdEnabled: Bool = false
    private var pmdConfig: PerMessageDeflateConfig

    public init(pmdConfig !: PerMessageDeflateConfig = PerMessageDeflateConfig()) {
        this.pmdConfig = pmdConfig
    }

    /**
     * 连接 WebSocket 服务器。
     *
     * @param url WebSocket URL（ws:// 或 wss://）
     * @param origin 可选的 Origin 头
     * @param protocols 可选的子协议列表（Sec-WebSocket-Protocol）
     * @throws ProtocolException 握手失败时抛出
     */
    public func connect(url: String, origin!: String = "", protocols!: ArrayList<String> = ArrayList<String>()): Unit {
        if (closed) { throw ProtocolException("WebSocket client is closed") }

        // 解析 URL
        let useTls: Bool
        let host: String
        let port: UInt16
        let path: String

        if (url.startsWith("ws://")) {
            useTls = false
            let rest = url[5..]
            let (h, p, pa) = parseWebSocketUrl(rest, 80u16)
            host = h; port = p; path = pa
        } else if (url.startsWith("wss://")) {
            useTls = true
            let rest = url[6..]
            let (h, p, pa) = parseWebSocketUrl(rest, 443u16)
            host = h; port = p; path = pa
        } else {
            throw ProtocolException("invalid WebSocket URL: must start with ws:// or wss://")
        }

        // 创建 TCP/TLS 连接
        let tcpConn = TcpConnection.connect(host, port)
        let transportConn: Connection = if (useTls) {
            let tlsConfig = TlsConfig()
            // WebSocket 基于 HTTP/1.1 Upgrade，禁止 ALPN 协商 "h2"，
            // 否则服务器按 HTTP/2 帧解析 Upgrade 请求会强制断连（10054）。
            tlsConfig.nextProtos = ["http/1.1"]
            // serverName 通过 TlsConnection 构造器传入
            TlsConnection(tcpConn, host, tlsConfig)
        } else {
            tcpConn
        }

        // 生成 Sec-WebSocket-Key
        let key = generateWebSocketKey()

        // 构建 Upgrade 请求
        // 构建 Upgrade 请求（包含 Sec-WebSocket-Extensions）
        let requestBytes = buildUpgradeRequest(host, path, key, origin, protocols, pmdConfig_: pmdConfig)

        // 发送请求
        transportConn.write(requestBytes)

        // 读取响应
        let responseBytes = readResponse(transportConn)
        let responseStr = bytesToString(responseBytes)

        // 验证握手
        // 验证 Sec-WebSocket-Extensions 响应
        let negotiatedPmd = verifyUpgradeResponse(responseStr, key)
        // 如果服务器确认了 PMD，创建并激活压缩器
        if (negotiatedPmd) {
            let pmd = PerMessageDeflate(config: pmdConfig)
            pmd.activate(false)  // false = 客户端角色
            match (conn) {
                case Some(c) => c.setPmd(pmd)
                case None => ()
            }
        }

        // 创建 WebSocketConn
        let wsConn = WebSocketConn(transportConn)
        this.conn = Some(wsConn)
    }

    /**
     * 发送文本消息。
     */
    public func sendText(text: String): Unit {
        match (conn) {
            case Some(c) => c.writeText(text)
            case None => throw ProtocolException("WebSocket not connected")
        }
    }

    /**
     * 发送二进制消息。
     */
    public func sendBinary(data: Array<UInt8>): Unit {
        match (conn) {
            case Some(c) => c.writeBinary(data)
            case None => throw ProtocolException("WebSocket not connected")
        }
    }

    /**
     * 发送 Ping 帧。
     */
    public func sendPing(): Unit {
        sendPing(Array<UInt8>())
    }

    public func sendPing(data: Array<UInt8>): Unit {
        match (conn) {
            case Some(c) => c.writePing(data)
            case None => throw ProtocolException("WebSocket not connected")
        }
    }

    /**
     * 发送 Pong 帧。
     */
    public func sendPong(): Unit {
        sendPong(Array<UInt8>())
    }

    public func sendPong(data: Array<UInt8>): Unit {
        match (conn) {
            case Some(c) => c.writePong(data)
            case None => throw ProtocolException("WebSocket not connected")
        }
    }

    /**
     * 读取下一条 WebSocket 消息。
     * 返回 None 表示连接已关闭或发生错误。
     */
    public func readMessage(): ?WebSocketMessage {
        match (conn) {
            case Some(c) => c.readMessage()
            case None => None
        }
    }

    /**
     * 关闭 WebSocket 连接。
     */
    public func close(statusCode!: UInt16 = 1000): Unit {
        closed = true
        match (conn) {
            case Some(c) =>
                try { c.close(statusCode) } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 是否已关闭。
     */
    public func isClosed(): Bool { closed }

    // ======== 内部方法 ========

    /**
     * 解析 WebSocket URL 的 host、port、path 部分。
     */
    public func parseWebSocketUrl(rest: String, defaultPort: UInt16): (String, UInt16, String) {
        // 查找 path 起始位置（/）
        let pathIdx = rest.indexOf("/")

        let authorityPart = match (pathIdx) {
            case Some(idx) => rest[0..idx]
            case None => rest
        }
        let path = match (pathIdx) {
            case Some(idx) => rest[idx..]
            case None => "/"
        }

        // 解析 authority 中的 host:port
        let colonIdx = authorityPart.indexOf(":")
        match (colonIdx) {
            case Some(idx) =>
                let host = if (idx > 0) { authorityPart[0..idx] } else { authorityPart }
                let portStr = if (idx + 1 < authorityPart.size) { authorityPart[idx + 1..] } else { "" }
                let port = if (portStr.isEmpty()) { defaultPort } else {
                    try { UInt16(Int64.parse(portStr)) } catch (_: Exception) { defaultPort }
                }
                (host, port, path)
            case None =>
                (authorityPart, defaultPort, path)
        }
    }

    /**
     * 生成 WebSocket 握手用的 Sec-WebSocket-Key。
     * 生成 16 字节随机值，Base64 编码。
     */
    public func generateWebSocketKey(): String {
        let rand = Random()
        let randomBytes = Array<UInt8>(16, repeat: 0)
        var i: Int64 = 0
        while (i < 16) {
            randomBytes[i] = UInt8(rand.nextInt64() & 0xFF)
            i += 1
        }
        base64EncodeBytes(randomBytes)
    }

    /**
     * 构建 HTTP Upgrade 请求。
     */
    public func buildUpgradeRequest(host: String, path: String, key: String, origin: String, protocols: ArrayList<String>, pmdConfig_ !: PerMessageDeflateConfig = PerMessageDeflateConfig()): Array<UInt8> {
        let sb = StringBuilder()
        sb.append("GET ${path} HTTP/1.1\r\n")
        sb.append("Host: ${host}\r\n")
        sb.append("Upgrade: websocket\r\n")
        sb.append("Connection: Upgrade\r\n")
        sb.append("Sec-WebSocket-Key: ${key}\r\n")
        sb.append("Sec-WebSocket-Version: 13\r\n")
        // 协商 Per-Message Deflate 压缩
        sb.append("Sec-WebSocket-Extensions: ${buildPmdExtensionHeader(config_: pmdConfig_)}\r\n")
        if (!origin.isEmpty()) {
            sb.append("Origin: ${origin}\r\n")
        }
        if (protocols.size > 0) {
            sb.append("Sec-WebSocket-Protocol: ")
            for (i in 0..protocols.size) {
                if (i > 0) { sb.append(", ") }
                sb.append(protocols[i])
            }
            sb.append("\r\n")
        }
        sb.append("\r\n")
        stringToBytes(sb.toString())
    }

    /**
     * 读取 HTTP 响应。
     */
    public func readResponse(conn: Connection): Array<UInt8> {
        let buf = Array<UInt8>(4096, repeat: 0)
        let total = ArrayList<UInt8>()
        var foundEnd: Bool = false

        while (!foundEnd) {
            let n = conn.read(buf)
            if (n <= 0) { throw ProtocolException("WebSocket upgrade: connection closed") }
            var i: Int64 = 0
            while (i < n) { total.add(buf[i]); i += 1 }

            // 检查是否收到完整的 HTTP 头（\r\n\r\n）
            if (total.size >= 4) {
                let endIdx = total.size - 4
                if (total[endIdx] == 0x0Du8 && total[endIdx + 1] == 0x0Au8 &&
                    total[endIdx + 2] == 0x0Du8 && total[endIdx + 3] == 0x0Au8) {
                    foundEnd = true
                }
            }
        }

        total.toArray()
    }

    /**
     * 验证 WebSocket Upgrade 响应。
     */
    public func verifyUpgradeResponse(response: String, key: String): Bool {
        if (!response.contains(" 101 ")) {
            throw ProtocolException("WebSocket upgrade failed: expected 101 Switching Protocols")
        }
        if (!response.toLower().contains("upgrade: websocket")) {
            throw ProtocolException("WebSocket upgrade failed: missing Upgrade: websocket header")
        }
        if (!response.toLower().contains("connection: upgrade")) {
            throw ProtocolException("WebSocket upgrade failed: missing Connection: Upgrade header")
        }

        // 验证 Sec-WebSocket-Accept
        let expectedAccept = computeWebSocketAcceptKey(key)
        if (!response.contains(expectedAccept)) {
            throw ProtocolException("WebSocket upgrade failed: invalid Sec-WebSocket-Accept")
        }

        // 检查服务器是否确认了 permessage-deflate 扩展
        let pmdNegotiated = parsePmdExtensions(response)
        match (pmdNegotiated) {
            case Some(serverPmdConfig) =>
                // 服务器确认了 PMD 扩展
                if (serverPmdConfig.serverNoContextTakeover) {
                    pmdConfig.serverNoContextTakeover = serverPmdConfig.serverNoContextTakeover
                }
                if (serverPmdConfig.clientNoContextTakeover) {
                    pmdConfig.clientNoContextTakeover = serverPmdConfig.clientNoContextTakeover
                }
                if (serverPmdConfig.serverMaxWindowBits != 15 && serverPmdConfig.serverMaxWindowBits < pmdConfig.serverMaxWindowBits) {
                    pmdConfig.serverMaxWindowBits = serverPmdConfig.serverMaxWindowBits
                }
                if (serverPmdConfig.clientMaxWindowBits != 15 && serverPmdConfig.clientMaxWindowBits < pmdConfig.clientMaxWindowBits) {
                    pmdConfig.clientMaxWindowBits = serverPmdConfig.clientMaxWindowBits
                }
                return true
            case None =>
                // 服务器未确认压缩扩展，继续使用未压缩连接
                return false
        }
    }
}
