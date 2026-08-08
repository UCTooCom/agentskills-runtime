/**
 * HTTP/3 客户端（RFC 9114）。
 *
 * 基于 QUIC 传输层发送 HTTP/3 请求并接收响应。
 * 需要外部 QUIC 实现提供实际的 QUIC 传输层。
 *
 * 用法：
 *   let client = Http3Client()
 *   client.setTransportFactory(myQuicFactory)
 *   client.connect("example.com", 443)
 *   let resp = client.get("/api/data")
 *   println(resp.bodyAsString())
 *   client.close()
 *
 * @see https://www.rfc-editor.org/rfc/rfc9114
 */
package http_lib.http3

import std.sync.Mutex
import quic_cj.protocol.{Version, VERSION_1, VERSION_2}
import http_lib.core.{HttpStatus, HttpMethod, HttpHeaders, HttpVersion}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.buffer.ByteBuffer
import std.collection.{ArrayList, HashMap}

/**
 * HTTP/3 客户端配置。
 */
public class Http3ClientConfig {
    /// QUIC 协议版本列表（RFC 9369），默认支持 V1 和 V2。
    public var versions: Array<Version> = [VERSION_1, VERSION_2]
    public var connectTimeout: Duration = Duration.second * 10
    public var readTimeout: Duration = Duration.second * 30
    public var maxFieldSectionSize: Int64 = 65536
    public var qpackMaxTableCapacity: Int64 = 4096
    public var followRedirects: Bool = true
    public var maxRedirects: Int64 = 10
    public var enableConnectProtocol: Bool = true
    public var zeroRttPriorSettings: ?HashMap<UInt16, UInt64> = None

    public init() {}

    public func toH3ConnectionConfig(): H3ConnectionConfig {
        let c = H3ConnectionConfig()
        c.maxFieldSectionSize = maxFieldSectionSize
        c.qpackMaxTableCapacity = qpackMaxTableCapacity
        c.enableConnectProtocol = enableConnectProtocol
        c.zeroRttPriorSettings = zeroRttPriorSettings
        c.readTimeout = readTimeout
        c
    }
}

/**
 * HTTP/3 客户端。
 *
 * 支持 GET、POST、PUT、DELETE 等常见 HTTP 方法的便捷调用。
 * 连接复用：同一客户端可发送多个请求，共享一个 QUIC 连接。
 */
public class Http3Client {
    private var config: Http3ClientConfig
    private var transportFactory: ?QuicTransportFactory = None
    private var quicConn: ?QuicConnection = None
    private var h3Conn: ?H3Connection = None
    private var tlsConfig: H3TlsConfig = H3TlsConfig()
    private var connected: Bool = false
    private var quicDriver: ?QuicClientDriver = None
    private var connMu: Mutex = Mutex()

    public init(config!: Http3ClientConfig = Http3ClientConfig()) {
        this.config = config
    }

    /**
     * 设置 QUIC 传输工厂。
     * 必须在使用 connect 前调用。
     */
    public func setTransportFactory(factory: QuicTransportFactory): Unit {
        this.transportFactory = Some(factory)
    }

    /**
     * 设置客户端 TLS 配置。
     */
    public func setTlsConfig(tlsConfig: H3TlsConfig): Unit {
        this.tlsConfig = tlsConfig
    }

    /**
     * 连接到远程 HTTP/3 服务器。
     *
     * @param host 服务器主机名
     * @param port 服务器端口
     */
    public func connect(host: String, port: UInt16): Bool {

        match (transportFactory) {
            case Some(f) =>
                let conn = f.dial(host, port, tlsConfig)
                match (conn) {
                    case Some(c) =>
                        this.quicConn = Some(c)
                        let connConfig = config.toH3ConnectionConfig()
                        let h3Conn = H3Connection(c, config: connConfig, isServer: false)
                        h3Conn.sendSettings()
                        this.h3Conn = Some(h3Conn)
                        this.connected = true
                    true
                case None => false
                }
            case None =>
                // 使用内置 QuicClientDriver 作为 QUIC 传输层
                match (QuicClientDriver.dial(host, port, version: config.versions[0])) {
                    case Some(driver) =>
                        let quicConn = driver.getQuicConnection()
                        let connConfig = config.toH3ConnectionConfig()
                        let h3Conn = H3Connection(quicConn, config: connConfig, isServer: false)
                        h3Conn.sendSettings()
                        this.h3Conn = Some(h3Conn)
                        this.quicConn = Some(quicConn)
                        this.quicDriver = Some(driver)
                        this.connected = true
                        // 在后台启动 I/O 循环
                        spawn {
                            driver.run(-1)
                        }
                        true
                    case None => false
                }
        }
    }

    /**
     * 发送 GET 请求。
     */
    public func get(url: String): ?HttpResponse {
        let req = HttpRequest(method: HttpMethod.GET, url: url)
        return doRequest(req)
    }

    /**
     * 发送 POST 请求。
     */
    public func post(url: String, body!: String = "", contentType!: String = "text/plain"): ?HttpResponse {
        let req = HttpRequest(method: HttpMethod.POST, url: url)
        if (body.size > 0) {
            req.setBody(unsafe { body.rawData() })
            req.headers.set("Content-Type", contentType)
        }
        return doRequest(req)
    }

    /**
     * 发送 PUT 请求。
     */
    public func put(url: String, body!: String = "", contentType!: String = "text/plain"): ?HttpResponse {
        let req = HttpRequest(method: HttpMethod.PUT, url: url)
        if (body.size > 0) {
            req.setBody(unsafe { body.rawData() })
            req.headers.set("Content-Type", contentType)
        }
        return doRequest(req)
    }

    /**
     * 发送 DELETE 请求。
     */
    public func delete(url: String): ?HttpResponse {
        let req = HttpRequest(method: HttpMethod.DELETE, url: url)
        return doRequest(req)
    }

    /**
     * 发送 HEAD 请求。
     */
    public func head(url: String): ?HttpResponse {
        let req = HttpRequest(method: HttpMethod.HEAD, url: url)
        return doRequest(req)
    }

    /**
     * 发送 OPTIONS 请求。
     */
    public func options(url: String): ?HttpResponse {
        let req = HttpRequest(method: HttpMethod.OPTIONS, url: url)
        return doRequest(req)
    }

    /**
     * 发送自定义请求。
     */
    public func doRequest(request: HttpRequest): ?HttpResponse {
        connMu.lock()
        let h3 = this.h3Conn
        connMu.unlock()

        match (h3) {
            case Some(conn) =>
                // 发送请求
                match (conn.sendRequest(request)) {
                    case Some(streamId) =>
                        // 接收响应
                        let response = conn.recvResponse(streamId)
                        match (response) {
                            case Some(resp) =>
                                // 处理重定向
                                if (config.followRedirects && config.maxRedirects > 0 &&
                                    resp.isRedirect()) {
                                    match (resp.headers.get("location")) {
                                        case Some(location) =>
                                            let redirectReq = HttpRequest(method: HttpMethod.GET, url: location)
                                            return doRequest(redirectReq)
                                        case None => ()
                                    }
                                }
                                Some(resp)
                            case None => None
                        }
                    case None => None
                }
            case None => None
        }
    }

    /**
     * 关闭客户端连接。
     */
    public func close(): Unit {
        connected = false
        match (h3Conn) {
            case Some(conn) =>
                try {
                    conn.gracefulShutdown()
                    conn.close()
                } catch (_: Exception) {}
            case None => ()
        }
        match (quicConn) {
            case Some(conn) =>
                try { conn.close() } catch (_: Exception) {}
            case None => ()
        }
        match (quicDriver) {
            case Some(d) =>
                try { d.stop() } catch (_: Exception) {}
            case None => ()
        }
        h3Conn = None
        quicConn = None
        quicDriver = None
    }

    /**
     * 客户端是否已连接。
     */
    public func isConnected(): Bool { connected }

    /**
     * 设置推送响应处理器。
     * 当收到服务端推送的响应时调用。
     */
    public func setPushResponseHandler(handler: (UInt64, HttpResponse) -> Unit): Unit {
        connMu.lock()
        match (h3Conn) {
            case Some(conn) => conn.setPushResponseHandler(handler)
            case None => ()
        }
        connMu.unlock()
    }

    /**
     * 获取已完成的推送响应列表。
     */
    public func getCompletedPushes(): ArrayList<(UInt64, HttpResponse)> {
        connMu.lock()
        let result = match (h3Conn) {
            case Some(conn) => conn.getCompletedPushes()
            case None => ArrayList<(UInt64, HttpResponse)>()
        }
        connMu.unlock()
        result
    }

    /**
     * 建立 Extended CONNECT 隧道（RFC 9220）。
     * 在已建立的连接上创建双向数据隧道。
     */
    public func establishTunnel(request: HttpRequest, onData: (Array<UInt8>) -> Unit): ?UInt64 {
        connMu.lock()
        let h3 = this.h3Conn
        connMu.unlock()
        match (h3) {
            case Some(conn) =>
                match (conn.sendRequest(request)) {
                    case Some(streamId) =>
                        let established = conn.establishTunnel(streamId, request, onData)
                        if (established) { Some(streamId) } else { None }
                    case None => None
                }
            case None => None
        }
    }

    /**
     * 通过 Extended CONNECT 隧道发送数据。
     */
    public func sendTunnelData(streamId: UInt64, data: Array<UInt8>): Unit {
        connMu.lock()
        match (h3Conn) {
            case Some(conn) => conn.sendTunnelData(streamId, data)
            case None => ()
        }
        connMu.unlock()
    }

    /**
     * 关闭 Extended CONNECT 隧道。
     */
    public func closeTunnel(streamId: UInt64): Unit {
        connMu.lock()
        match (h3Conn) {
            case Some(conn) => conn.closeTunnel(streamId)
            case None => ()
        }
        connMu.unlock()
    }
}
