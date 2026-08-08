/**
 * HTTP/3 服务器（RFC 9114）。
 *
 * 基于 QUIC 传输层接受 HTTP/3 连接并提供请求处理能力。
 * 需要外部 QUIC 实现来提供实际的 QUIC 传输层。
 *
 * 用法：
 *   let handler: (HttpRequest) -> HttpResponse = {req => HttpResponse.json(HttpStatus.OK, "{\"ok\": true}")}
 *   let server = Http3Server(handler, config: Http3Config())
 *   // 需要设置 QUIC 传输工厂
 *   server.setTransportFactory(myQuicFactory)
 *   server.listenAndServe("0.0.0.0", 443)
 *
 * @see https://www.rfc-editor.org/rfc/rfc9114
 */
package http_lib.http3

import http_lib.core.{HttpStatus, HttpHeaders, HttpVersion}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Handler
import std.collection.{ArrayList, HashMap}

/**
 * HTTP/3 请求处理器类型。
 * 接受 HttpRequest 返回 HttpResponse。
 */
/**
 * HTTP/3 服务器配置。
 */
public class Http3ServerConfig {
    public var serverName: String = "http_lib_h3/0.1"
    public var readTimeout: Duration = Duration.second * 30
    public var writeTimeout: Duration = Duration.second * 30
    public var maxFieldSectionSize: Int64 = 65536
    public var qpackMaxTableCapacity: Int64 = 4096
    public var qpackBlockedStreams: Int64 = 100
    public var enableConnectProtocol: Bool = true
    public var enableServerPush: Bool = false
    public var zeroRttPriorSettings: ?HashMap<UInt16, UInt64> = None

    public init() {}

    public func toH3ConnectionConfig(): H3ConnectionConfig {
        let c = H3ConnectionConfig()
        c.maxFieldSectionSize = maxFieldSectionSize
        c.qpackMaxTableCapacity = qpackMaxTableCapacity
        c.qpackBlockedStreams = qpackBlockedStreams
        c.enableConnectProtocol = enableConnectProtocol
        c.zeroRttPriorSettings = zeroRttPriorSettings
        c.serverName = serverName
        c.readTimeout = readTimeout
        c.writeTimeout = writeTimeout
        c
    }

    public func toHttp3Config(): Http3Config {
        let c = Http3Config()
        c.maxFieldSectionSize = maxFieldSectionSize
        c.qpackMaxTableCapacity = qpackMaxTableCapacity
        c.qpackBlockedStreams = qpackBlockedStreams
        c.maxPushId = if (enableServerPush) { 100 } else { 0 }
        c.enableConnectProtocol = enableConnectProtocol
        c.zeroRttPriorSettings = zeroRttPriorSettings
        c
    }
}

/**
 * HTTP/3 服务器。
 *
 * 监听 QUIC 连接并将传入的 HTTP/3 请求转发给处理器。
 * 使用 QuicTransportFactory 创建实际的 QUIC 监听器。
 */
public class Http3Server {
    private var handler: (HttpRequest) -> HttpResponse
    private var config: Http3ServerConfig
    private var transportFactory: ?QuicTransportFactory = None
    private var listener: ?QuicListener = None
    private var tlsConfig: H3TlsConfig = H3TlsConfig()
    private var running: Bool = false
    private var pushHandler: ?(HttpRequest) -> ArrayList<HttpRequest> = None
    private var quicServerDriver: ?QuicServerDriver = None

    public init(handler: (HttpRequest) -> HttpResponse, config!: Http3ServerConfig = Http3ServerConfig()) {
        this.handler = handler
        this.config = config
    }

    /**
     * 设置 QUIC 传输工厂。
     * 必须在使用 listenAndServe 前调用。
     */
    public func setTransportFactory(factory: QuicTransportFactory): Unit {
        this.transportFactory = Some(factory)
    }

    /**
     * 设置服务器 TLS 配置。
     */
    public func setTlsConfig(tlsConfig: H3TlsConfig): Unit {
        this.tlsConfig = tlsConfig
    }

    /**
     * 设置 HTTP/3 服务端推送处理器。
     * 推送处理器接收客户端请求，返回应推送的资源请求列表。
     */
    public func setPushHandler(handler: (HttpRequest) -> ArrayList<HttpRequest>): Unit {
        this.pushHandler = Some(handler)
    }


    /**
     * 在指定地址上监听并提供 HTTP/3 服务。
     *
     * @param host 监听地址
     * @param port 监听端口
     */
    public func listenAndServe(host: String, port: UInt16): Unit {
        match (transportFactory) {
            case Some(f) =>
                let quicListener = f.listen(host, port, tlsConfig)
                match (quicListener) {
                    case Some(l) =>
                        this.listener = Some(l)
                        this.running = true
                        serve(l)
                    case None =>
                        throw Http3Exception(Http3ErrorCode.H3_INTERNAL_ERROR,
                            "无法在 ${host}:${port} 上创建 QUIC 监听器")
                }
            case None =>
                // 使用内置 QuicServerDriver 作为 QUIC 传输层
                let driver = QuicServerDriver(host, port, handler, config: config)
                this.quicServerDriver = Some(driver)
                this.running = true
                driver.serve()
        }
    }

    /**
     * 服务 QUIC 连接。
     */
    private func serve(listener: QuicListener): Unit {
        let h3Config = config.toHttp3Config()
        let connConfig = config.toH3ConnectionConfig()

        while (running) {
            let quicConn = listener.accept()
            match (quicConn) {
                case Some(conn) =>
                    spawn {
                        try {
                            handleConnection(conn, connConfig)
                        } catch (e: Exception) {
                            // 连接处理错误，静默忽略
                        }
                    }
                case None =>
                    if (running) {
                        running = false
                    }
            }
        }
    }

    /**
     * 处理单个 QUIC 连接上的 HTTP/3 请求。
     */
    private func handleConnection(quicConn: QuicConnection, connConfig: H3ConnectionConfig): Unit {
        let h3Conn = H3Connection(quicConn, config: connConfig, isServer: true)
        h3Conn.setRequestHandler(handler)
        h3Conn.sendSettings()
        let ph = pushHandler

        while (h3Conn.isConnected()) {
            // Check for WebTransport sessions first
            match (h3Conn.acceptWebTransport()) {
                case Some(wtSession) =>
                    // WebTransport session already handled internally (200 sent, session registered)
                    // Application can retrieve the session via acceptWebTransport() if needed
                    continue
                case None =>
                    match (h3Conn.acceptRequest()) {
                        case Some(req) =>
                            // ... existing handler code follows
                            let resp = handler(req)
                            // 提取流 ID 并发送响应
                            let sid: UInt64 = match (req.metadata) {
                                case Some(streamIdObj) =>
                                    match (streamIdObj) {
                                        case sv: UInt64 => sv
                                        case _ => 0u64
                                    }
                                case None => 0u64
                            }
                            // HTTP/3 服务端推送
                            match (ph) {
                                case Some(pushFn) =>
                                    let pushRequests = try {
                                        pushFn(req)
                                    } catch (_: Exception) {
                                        ArrayList<HttpRequest>()
                                    }
                                    for (pushReq in pushRequests) {
                                        match (h3Conn.sendPushPromise(sid, pushReq)) {
                                            case Some(pushId) =>
                                                let pushResp = try {
                                                    handler(pushReq)
                                                } catch (_: Exception) {
                                                    continue
                                                }
                                                h3Conn.sendPushResponse(pushId, pushResp)
                                            case None => ()
                                        }
                                    }
                                case None => ()
                            }
                            h3Conn.sendResponse(sid, resp)
                        case None =>
                            h3Conn.gracefulShutdown()
                            return
                    }
            }
        }
    }

    /**
     * 停止服务器。
     */
    public func stop(): Unit {
        running = false
        match (listener) {
            case Some(l) => try { l.close() } catch (_: Exception) {}
            case None => ()
        }
        match (quicServerDriver) {
            case Some(d) => try { d.stop() } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 服务器是否在运行。
     */
    public func isRunning(): Bool { running }
}
