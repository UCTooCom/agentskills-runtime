package http_lib.server

import std.net.{TcpServerSocket, TcpSocket}
import std.collection.{ArrayList, HashMap}
import std.collection.concurrent.ConcurrentHashMap
import std.sync.{AtomicBool, AtomicInt64, Mutex}
import std.time.DateTime
import std.runtime.getProcessorCount
import std.convert.Parsable
import http_lib.buffer.ByteBuffer
import http_lib.core.*
import http_lib.core.RequestContext
import http_lib.message.*
import http_lib.message.{selectContentEncoding, selectContentEncodingWithBrotli, brotliCompress, Compression, ResponseBuilder as msgResponseBuilder, StreamingHandler, wrapHandler}
import http_lib.router.{Handler, HandlerResult, Router}
import http_lib.connection.{TlsConfig, TlsConnection, TlsServerConnection, Connection, TcpConnection}
import http_lib.http2.{Http2Connection, HTTP2_CLIENT_PREFACE_BYTES, H2WebSocketTunnel}
import http_lib.utils.{arraysEqual, base64EncodeBytes, stringToBytes, findHeaderEnd, containsIgnoreCase as utilsContainsIgnoreCase, equalsIgnoreCaseBytesRunes as utilsEqualsIgnoreCase, containsIgnoreCaseBytes as utilsContainsIgnoreCaseBytes, equalsIgnoreCaseBytes as utilsEqualsIgnoreCaseBytes}
import jinguissl_core.crypto.digest.sha1

// 预计算的字节级常量，用于头值比较。
// 避免热路径中反复的 String.toRuneArray() 分配。
let KEEP_ALIVE_BYTES = unsafe { "Keep-Alive".rawData() }
let CLOSE_BYTES = unsafe { "close".rawData() }
let H2C_BYTES = unsafe { "h2c".rawData() }
let CONTINUE_BYTES = unsafe { "100-continue".rawData() }

/**
 * 通用 Upgrade 头部处理器类型。
 * 处理器接收原始 TCP 连接和 HTTP 请求，返回 true 表示已处理升级。
 */
public type UpgradeHandler = (TcpSocket, HttpRequest) -> Bool

/**
 * HTTP/2 服务端推送处理器类型。
 * 接收客户端请求，返回应主动推送的资源请求列表。
 * 服务器将为每个推送请求发送 PUSH_PROMISE 帧，
 * 再通过主路由处理器获取推送响应后在推送流上发送。
 */
public type ServerPushHandler = (HttpRequest) -> ArrayList<HttpRequest>

/**
 * HTTP 服务器配置。
 */
public class HttpServerConfig {
    public var readTimeout: Duration = Duration.second * 30
    public var writeTimeout: Duration = Duration.second * 30
    public var maxHeaderSize: Int64 = 65536
    public var maxBodySize: Int64 = 10485760  // 10 MB（最大请求体大小）
    public var keepAlive: Bool = true
    public var idleTimeout: Duration = Duration.second * 60  // Keep-Alive 连接的请求间最大空闲时间
    public var enablePipelining: Bool = false  // HTTP/1.1 管道复用（Pipelining），允许多个请求在同一连接上并行处理
    public var drainTimeout: Duration = Duration.second * 30  // Max wait for active requests during 优雅关闭
    public var tlsConfig: ?TlsConfig = None
    public var enableHttp2: Bool = true
    public var enableServerPush: Bool = false  // HTTP/2 服务端推送（RFC 9113 §8.2）
    public var serverName: String = "http_lib/0.1"
    public var autoDateHeader: Bool = true
    public var autoServerHeader: Bool = true
    public var autoCompress: Bool = true
    public var compressMinSize: Int64 = 1024  // 小于此大小的响应体不压缩
    public var concurrent: Bool = true  // 并发处理连接（每个连接独立协程）
    public var maxConcurrentConnections: Int64 = 0  // 最大并发连接数（0 = 无限制）
    public var tcpNoDelay: Bool = true  // 设置 TCP_NODELAY 以降低延迟
    /**
     * 可选的错误日志函数。若设置，服务器错误将报告到此
     * 而非被静默丢弃。
     * 若未设置，错误将被静默忽略。
     */
    public var errorLog: ?(String) -> Unit = None
    /**
     * 可选的连接状态钩子。设置后，当连接状态发生转换时调用。
     * 用于连接计数、监控和限流。
     * 对应 Go 标准库的 Server.ConnState。
     */
    public var connState: ?(ConnState) -> Unit = None

    /**
     * 可选的钩子函数，为每个连接创建根 RequestContext。
     * 若设置，每个新连接被接受时调用一次。用于创建基础上下文，
     * 每个请求上下文从中派生。若未设置则使用默认的 RequestContext。
     * 未设置时使用默认的 RequestContext 实例。
     */
    public var baseContext: ?() -> RequestContext = None

    /**
     * 可选的钩子函数，为每个新连接修改上下文。
     * 在 baseContext（或默认的 RequestContext）之后调用，
     * 为该连接设置根上下文。返回的上下文成为每请求上下文的父上下文。
     * 若未设置则直接使用 baseContext 的返回值。
     */
    public var connContext: ?(RequestContext) -> RequestContext = None

    /**
     * 可选的读取头超时。若 > 0，限制读取请求头所花费的时间。
     * 若在读取头期间超时，将返回 408 Request Timeout。
     * 若为 0（默认），则使用 readTimeout 代替。
     * 设为 0 表示不单独限制读取头的超时时间。
     */
    public var readHeaderTimeout: Duration = Duration.second * 0

    public init() {}
}

/**
 * 基于 TcpServerSocket 的 HTTP/1.x 服务器。
 *
 * 用法：
 *   let server = HttpServer(handler: myRouter)
 *   server.listenAndServe("0.0.0.0", 8080)
 */
public class HttpServer {
    private var handler: Handler
    private var config: HttpServerConfig
    private var socket: ?TcpServerSocket = None
    private var running: AtomicBool = AtomicBool(false)
    private var activeConnectionCount: AtomicInt64 = AtomicInt64(0)
    private var activeWebSocketConnections: AtomicInt64 = AtomicInt64(0)
    private var activeH2Connections: ConcurrentHashMap<Int64, Http2Connection> = ConcurrentHashMap<Int64, Http2Connection>()
    private var h2ConnMutex: Mutex = Mutex()
    private var onShutdown: ArrayList<() -> Unit> = ArrayList<() -> Unit>()
    private var pushHandler: ?ServerPushHandler = None  // HTTP/2 服务端推送处理器
    private var upgradeHandlers: HashMap<String, UpgradeHandler> = HashMap<String, UpgradeHandler>()

    public init(
        handler!: Handler,
        config!: HttpServerConfig = HttpServerConfig()
    ) {
        this.handler = handler
        this.config = config
    }

    /**
     * 使用 StreamingHandler 启动服务器，通过 ResponseBuilder
     * 增量写入响应，而非返回 HttpResponse。
     *
     * 这是流式响应（SSE、分块传输、WebSocket）的首选处理器风格。
     * large file downloads, 分块传输). Standard handlers are
     * 通过 wrapHandler() 自动适配。
     */
    public func listenAndServeStream(host: String, port: UInt16, streamHandler: StreamingHandler): Unit {
        // 将流式处理器包装为内部使用的标准 Handler
        let adaptedHandler: Handler = { req =>
            let rw = msgResponseBuilder(
                match (req.connection) {
                    case Some(c) => c
                    case None => throw ProtocolException("no connection available for 流式响应")
                },
                status: HttpStatus.OK,
                serverName: config.serverName
            )
            streamHandler(req, rw)
            rw.finish()
            HttpResponse(status: HttpStatus.OK)
        }
        // 临时替换处理器
        let originalHandler = this.handler
        this.handler = adaptedHandler
        listenAndServe(host, port)
        this.handler = originalHandler
    }

    /**
     * 启动服务器并在给定地址和端口上监听。
     */
    public func listenAndServe(host: String, port: UInt16): Unit {
        let sock = TcpServerSocket(bindAt: port)
        sock.bind()
        this.socket = Some(sock)
        running.store(true)

        while (running.load()) {
            let client = sock.accept()
            // 为 HTTP 连接设置 TCP_NODELAY 和超时，与 TLS 模式保持一致
            if (config.tcpNoDelay) {
                client.noDelay = true
            }
            client.readTimeout = config.readTimeout
            client.writeTimeout = config.writeTimeout
            try {
                if (config.concurrent) {
                    // 并发连接数节流（0 = 无限制）
                    if (config.maxConcurrentConnections > 0 &&
                        activeConnectionCount.load() >= config.maxConcurrentConnections) {
                        try { client.close() } catch (_: Exception) {}
                        continue
                    }
                    activeConnectionCount.fetchAdd(1)
                    // 为每个连接启动独立协程处理请求
                    let h = handler
                    let cfg = config
                    spawn {
                        try { handleConnection(client) } catch (e: Exception) {
                            logError("handleConnection error: ${e.message}")
                        }
                    }
                } else {
                    handleConnection(client)
                }
            } catch (e: Exception) {
                logError("accept error: ${e.message}")
                try { client.close() } catch (_: Exception) {}
            }
        }
    }

    /**
     * 在给定地址和端口上启动带 TLS 的 HTTPS 服务器。
     * 需要 certPath 和 keyPath 指向有效的 PEM 文件。th to be set in config.tlsConfig.
     * 支持 ALPN 协议协商（h2 vs http/1.1）。
     */
    public func listenAndServeTls(host: String, port: UInt16): Unit {
        let tlsConfig = match (config.tlsConfig) {
            case Some(tls) =>
                if (tls.serverCertPath.isEmpty()) {
                    throw HttpException("TLS server requires serverCertPath in TlsConfig")
                }
                tls
            case None =>
                throw HttpException("TLS server requires tlsConfig with serverCertPath")
        }

        let sock = TcpServerSocket(bindAt: port)
        sock.bind()
        this.socket = Some(sock)
        running.store(true)

        while (running.load()) {
            let client = sock.accept()
            // 为 TLS 连接设置 TCP_NODELAY 以避免 Windows 下的小包延迟问题
            // 特别是在 TLS 握手阶段，多个小包（ServerHello、Certificate、ServerKeyExchange）
            // 需要快速连续发送，Nagle 算法会导致延迟甚至触发 10053 错误
            if (config.tcpNoDelay) {
                client.noDelay = true
            }
            client.readTimeout = config.readTimeout
            client.writeTimeout = config.writeTimeout
            try {
                if (config.concurrent) {
                    // 将 TLS 握手和 HTTP 处理都放到独立协程中，
                    // 避免 accept() 循环被 TLS 握手阻塞。
                    // 否则当浏览器同时发起多个 TLS 连接时，
                    // 后面的连接在 TCP 队列中等待太久，
                    // 最终超时导致 net::ERR_SSL_PROTOCOL_ERROR。
                    spawn {
                        try {
                            let tlsConn = TlsServerConnection(client, tlsConfig)
                            tlsConn.handshake()
                            let negotiated = tlsConn.getNegotiatedAlpn()
                            if (config.enableHttp2 && negotiated == "h2") {
                                handleHttp2ConnectionOverConnection(tlsConn)
                            } else {
                                handleHttp1ConnectionOverConnection(tlsConn)
                            }
                        } catch (e: Exception) {
                            logError("TLS handler error: ${e.message}")
                            try { client.close() } catch (_: Exception) {}
                        }
                    }
                } else {
                    let tlsConn = TlsServerConnection(client, tlsConfig)
                    tlsConn.handshake()
                    let negotiated = tlsConn.getNegotiatedAlpn()
                    if (config.enableHttp2 && negotiated == "h2") {
                        handleHttp2ConnectionOverConnection(tlsConn)
                    } else {
                        handleHttp1ConnectionOverConnection(tlsConn)
                    }
                }
            } catch (e: Exception) {
                logError("TLS accept error: ${e.message}")
                try { client.close() } catch (_: Exception) {}
            }
        }
    }

    /**
     * 通过抽象 Connection 处理 HTTP/1.1（用于 TLS 包装的套接字）。
     */
    private func handleHttp1ConnectionOverConnection(conn: Connection): Unit {
        activeConnectionCount.fetchAdd(1)
        var keepAlive = true
        var prefetched: Array<UInt8> = []
        var lastRequestTime = DateTime.now()
        fireConnState(ConnState.STATE_NEW)

        // 为此连接创建根上下文
        // 若设置了 BaseContext 钩子则使用，否则默认为全新的 RequestContext
        let rootCtx = match (config.baseContext) {
            case Some(bc) => bc()
            case None => RequestContext()
        }
        // 若设置了 ConnContext 钩子则应用
        let effectiveRootCtx = match (config.connContext) {
            case Some(cc) => cc(rootCtx)
            case None => rootCtx
        }

        while (keepAlive && running.load()) {
            // 为头部读取阶段应用读取超时
            let effectiveReadTimeout = if (config.readHeaderTimeout > Duration.second * 0) { config.readHeaderTimeout } else { config.readTimeout }
            conn.setReadTimeout(effectiveReadTimeout)

            let request = try {
                readHttpRequestFromConnection(conn, prefetched)
            } catch (e: ProtocolException) {
                sendErrorResponseOverConnection(conn, HttpStatus.BAD_REQUEST, message: e.message)
        activeConnectionCount.fetchSub(1); return
            } catch (e: Exception) {
                logError("readHttpRequestFromConnection error: ${e.message}")
        activeConnectionCount.fetchSub(1); return
            }
            // 头部读取后恢复读取超时
            conn.setReadTimeout(config.readTimeout)
            prefetched = []

            match (request) {
                case Some(req) =>
                    keepAlive = shouldKeepAlive(req)

                    // 从有效的根上下文创建每请求上下文
                    req.ctx = effectiveRootCtx.createChild()
                    // 暴露底层连接供处理器劫持（WebSocket 等）
                    req.connection = Some(conn)

                    // RFC 7231 §5.1.2：Max-Forwards 头处理
                    if (req.method == HttpMethod.TRACE) {
                        handleMaxForwards(req)
                    }

                    // RFC 7230 §4.3：TE 头解析 — 声明愿意接收尾部头
                    handleTeHeader(req)

                    let response = try {
                        handler(req)
                    } catch (e: Exception) {
                        if (req.takenOver) { activeConnectionCount.fetchSub(1); return }
                        sendErrorResponseOverConnection(conn, HttpStatus.INTERNAL_SERVER_ERROR, message: e.message)
        activeConnectionCount.fetchSub(1); return
                    }

                    // 处理器完成后自动取消请求上下文
                    req.ctx.cancel(reason: "request completed")

                    // 若处理器劫持了连接，停止管理它
                    if (req.takenOver) {
        activeConnectionCount.fetchSub(1); fireConnState(ConnState.STATE_HIJACKED); return
                    }

                    // 根据 RFC 7231 §4.3.2：HEAD 响应不得有主体
                    if (req.method == HttpMethod.HEAD) {
                        let empty = ByteBuffer(capacity: 0)
                        response.body = empty
                    }

                    applyCompression(req, response)
                    finalizeResponse(response)
                    try {
                        response.writeTo(conn)
                    } catch (e: Exception) {
                        logError("write response over connection error: ${e.message}")
        activeConnectionCount.fetchSub(1); return
                    }
                    // 检查请求间的空闲超时
                    let now = DateTime.now()
                    if (now - lastRequestTime > config.idleTimeout) {
                        try { conn.close() } catch (e: Exception) { logError("close after idle timeout error: ${e.message}") }
        activeConnectionCount.fetchSub(1); return
                    }
                    lastRequestTime = now
                case None =>
        activeConnectionCount.fetchSub(1); return
            }
        }

        try { conn.close() } catch (_: Exception) {}
        activeConnectionCount.fetchSub(1)
    }

    private func readHttpRequestFromConnection(conn: Connection, prefix: Array<UInt8>): ?HttpRequest {
        let buffer = ByteBuffer(capacity: DEFAULT_BUFFER_SIZE)
        if (prefix.size > 0) {
            buffer.write(prefix)
        }
        let scratch = Array<UInt8>(DEFAULT_BUFFER_SIZE, repeat: 0)

        var headerEnd: Int64 = findHeaderEnd(buffer.getArray(), buffer.getLimit())
        var totalRead: Int64 = buffer.getLimit()

        while (headerEnd < 0) {
            let n = conn.read(scratch)
            if (n <= 0) {
                if (totalRead == 0) { return None }
                throw ProtocolException("connection closed before headers complete")
            }
            buffer.write(scratch, 0, n)
            totalRead += n
            if (totalRead > config.maxHeaderSize) {
                throw ProtocolException("request headers too large")
            }
            headerEnd = findHeaderEnd(buffer.getArray(), totalRead)
        }

        let data = buffer.getArray()
        let request = HttpRequestParser.parse(data[0..totalRead])
        finishRequestFromConnection(conn, request)
        Some(request)
    }

    private func finishRequestFromConnection(conn: Connection, request: HttpRequest): Unit {
        match (request.headers.get("content-length")) {
            case Some(cl) =>
                let contentLength = parseContentLength(cl)
                if (contentLength > config.maxBodySize) {
                    throw ProtocolException("request body too large")
                }
                let currentBody = request.body.getLimit()
                if (contentLength > currentBody) {
                    request.bodyRemaining = contentLength
                }
            case None => ()
        }
    }

    private func sendErrorResponseOverConnection(conn: Connection, status: HttpStatus, message!: String = ""): Unit {
        let bodyText = if (message.size > 0) { message } else { status.reasonPhrase }
        let response = HttpResponse.text(status, bodyText)
        try {
            response.writeTo(conn)
        } catch (_: Exception) {}
        try {
            conn.close()
        } catch (_: Exception) {}
    }

    /**
     * 立即停止服务器。
     */
    
    private func fireConnState(state: ConnState): Unit {
        match (config.connState) {
            case Some(cb) => cb(state)
            case None => ()
        }
    }

public func close(): Unit {
        running.store(false)
        // 关闭所有活跃的 HTTP/2 连接
        synchronized(h2ConnMutex) {
            for ((_, h2conn) in activeH2Connections) {
                try { h2conn.close() } catch (_: Exception) {}
            }
            activeH2Connections = ConcurrentHashMap<Int64, Http2Connection>()
        }
        match (socket) {
            case Some(s) =>
                try { s.close() } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * Register a callback to be called during 优雅关闭.
     * 回调在连接关闭前按注册顺序执行。
     */
    public func registerOnShutdown(callback: () -> Unit): Unit {
        onShutdown.add(callback)
    }

    /**
     * 注册一个 WebSocket 连接以在优雅关闭期间跟踪。
     * 返回一个清理函数，须在 WebSocket 关闭时调用。
     *
     * 在 shutdown() 期间，服务器将等待所有已跟踪的 WebSocket 连接
     * 关闭后再完成关闭序列。
     *
     * 用法：
     *   let wsCleanup = server.registerWebSocket()
     *   let ws = WebSocketConn(conn)
     *   // ... 处理 WebSocket ...
     *   try { ws.close() } catch (_: Exception) {}
     *   wsCleanup()
     */
    public func registerWebSocket(): () -> Unit {
        activeWebSocketConnections.fetchAdd(1)
        { => activeWebSocketConnections.fetchSub(1) }
    }

    /**
     * 获取活跃 WebSocket 连接数。
     */
    public func getActiveWebSocketCount(): Int64 {
        activeWebSocketConnections.load()
    }

    /**
     * 设置 HTTP/2 服务端推送处理器（RFC 9113 Section 8.2）。
     * 当服务器收到 HTTP/2 连接上的请求时，此处理器
     * 被调用以确定在发送主响应之前主动向客户端推送哪些资源。
     * 在主响应发送之前。
     *
     * 推送处理器接收客户端请求，应返回
     * 推送请求列表。每个推送请求通过 PUSH_PROMISE 在同一流上发送。
     * 
     *
     * 用法：
     *   server.setPushHandler({req => pushCssAndJs(req)})
     */
    public func setPushHandler(handler: ServerPushHandler): Unit {
        pushHandler = Some(handler)
    }

    /**
     * 优雅关闭服务器。
     *
     * 停止接受新连接，等待进行中的请求完成（最多等待 readTimeout）。
     * 对于 HTTP/2 连接，按 RFC 9113 Section 6.8 发送 GOAWAY。
     * 
     */

    /**
     * 注册通用 Upgrade 处理器。
     * 当服务器收到包含 Upgrade 头部的 HTTP 请求时，会按协议名查找已注册的处理器。
     * 协议名不区分大小写。
     *
     * @param protocol 协议名（如 "websocket", "custom-protocol"）
     * @param handler 升级处理函数，返回 true 表示已处理该升级
     */
    public func setUpgradeHandler(protocol: String, handler: UpgradeHandler): Unit {
        upgradeHandlers[protocol.toAsciiLower()] = handler
    }

    public func shutdown(): Unit {
        running.store(false)

        // 调用所有已注册的关闭回调
        for (callback in onShutdown) {
            try { callback() } catch (e: Exception) {
                logError("onShutdown callback error: ${e.message}")
            }
        }

        // 向所有活跃的 HTTP/2 连接发送 GOAWAY（RFC 9113 §6.8）
        synchronized(h2ConnMutex) {
            for ((_, h2conn) in activeH2Connections) {
                try { h2conn.gracefulShutdown() } catch (_: Exception) {}
            }
        }
        // 等待活跃连接排空（带可配置超时）
        let drainDeadline = DateTime.now() + config.drainTimeout
        while (activeConnectionCount.load() > 0 || activeWebSocketConnections.load() > 0) {
            if (DateTime.now() > drainDeadline) {
                logError("shutdown: drain timeout after ${config.drainTimeout}, forcing close")
                break
            }
            try { sleep(50 * Duration.millisecond) } catch (_: Exception) { break }
        }
        // 关闭活跃的 H2 连接
        synchronized(h2ConnMutex) {
            for ((_, h2conn) in activeH2Connections) {
                try { h2conn.close() } catch (_: Exception) {}
            }
            activeH2Connections = ConcurrentHashMap<Int64, Http2Connection>()
        }
        // 关闭套接字以拒绝新连接
        match (socket) {
            case Some(s) => try { s.close() } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 处理单个客户端连接。通过前言窥探检测 HTTP/2。
     */
    private func handleConnection(conn: TcpSocket): Unit {
        conn.noDelay = true
        conn.readTimeout = config.readTimeout
        conn.writeTimeout = config.writeTimeout
        activeConnectionCount.fetchAdd(1)

        // 窥探首字节以检测 HTTP/2 前言
        if (config.enableHttp2) {
            let peekBuf = Array<UInt8>(HTTP2_CLIENT_PREFACE_BYTES.size, repeat: 0)
            let peeked = tryPeek(conn, peekBuf)
            if (peeked && arraysEqual(peekBuf, HTTP2_CLIENT_PREFACE_BYTES)) {
                // 传递预读的前言字节，避免 Http2Connection 重复读取
                handleHttp2Connection(conn, peekBuf)
                activeConnectionCount.fetchSub(1)
                return
            }
            // 非 HTTP/2 —— 将窥探到的字节送入 HTTP/1.1 读取路径
            handleHttp1Connection(conn, peekBuf, peeked)
        } else {
            handleHttp1Connection(conn, [], false)
        }
        activeConnectionCount.fetchSub(1)
    }

    /**
     * Handle HTTP/2 连接 with concurrent stream multiplexing.
    
     *   - 循环读取帧
     *   - 为每个流生成一个处理器（并发处理）
     *   - Responses are sent through the 写入调度器 for priority-based ordering
     *   - 多个流的 DATA 帧可能在线缆上交错
     */
    private func handleHttp2Connection(conn: TcpSocket, prefaceData: Array<UInt8>): Unit {
        let tcpConn = TcpConnection(conn)
        let h2conn = Http2Connection(tcpConn, isServer: true)
        activeConnectionCount.fetchAdd(1)  // 在构造函数之后递增，避免失败时泄漏
        synchronized(h2ConnMutex) {
            activeH2Connections.add(activeH2Connections.size, h2conn)
        }
        try {
            h2conn.accept(prefaceData)  // 传递预读的 preface，避免从 socket 重复读取

            while (running.load() && h2conn.isConnected()) {
                let (streamId, request) = try {
                    h2conn.recvRequest()
                } catch (e: Exception) {
                    break
                }
                if (streamId == 0) { break }

                // 检测扩展 CONNECT（:method=CONNECT + :protocol）
                let isExtendedConnect = request.method == HttpMethod.CONNECT && request.headers.get(":protocol").isSome()
                if (isExtendedConnect) {
                    let protocol = match (request.headers.get(":protocol")) {
                        case Some(p) => p
                        case None => ""
                    }
                    let h2 = h2conn
                    let sid = streamId
                    let req = request
                    let h = handler
                    spawn {
                        try {
                            // 发送 200 响应，建立隧道
                            let tunnel = h2.acceptExtendedConnect(sid, protocol)
                            req.metadata = Some(tunnel)
                            h(req)
                        } catch (e: Exception) {
                            logError("extended connect handler error: ${e.message}")
                        }
                    }
                    continue
                }

                let h2 = h2conn
                let sid = streamId
                let req = request
                let h = handler
                let ph = pushHandler
                spawn {
                    let response = try {
                        h(req)
                    } catch (e: Exception) {
                        let errResp = HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, e.message)
                        try { h2.sendResponse(sid, errResp) } catch (_: Exception) {}
                        return
                    }

                    // HTTP/2 服务端推送：检查是否有推送处理器
                    match (ph) {
                        case Some(pushFn) =>
                            let pushRequests = try {
                                pushFn(req)
                            } catch (_: Exception) {
                                ArrayList<HttpRequest>()
                            }
                            for (pushReq in pushRequests) {
                                let pushStreamId = h2.pushPromise(sid, pushReq)
                                if (pushStreamId > 0) {
                                    let pushResp = try {
                                        h(pushReq)
                                    } catch (_: Exception) {
                                        continue
                                    }
                                    try {
                                        h2.sendPushResponse(pushStreamId, pushResp)
                                    } catch (_: Exception) {}
                                }
                            }
                        case None => ()
                    }

                    try {
                        h2.sendResponse(sid, response)
                    } catch (e: Exception) {
                        logError("h2 sendResponse error: ${e.message}")
                    }
                }
            }
        } catch (e: Exception) {
            logError("handleHttp2Connection loop error: ${e.message}")
        }
        try { h2conn.close() } catch (_: Exception) {}
        try { conn.close() } catch (_: Exception) {}
        activeConnectionCount.fetchSub(1)
    }

    /**
     * Handle HTTP/2 连接 over an abstract Connection (for TLS-wrapped sockets).
     * 当 ALPN 协商选择 h2 over HTTPS 时使用。
     */
    private func handleHttp2ConnectionOverConnection(conn: Connection): Unit {
        let h2conn = Http2Connection(conn, isServer: true)
        activeConnectionCount.fetchAdd(1)  // 在构造函数之后递增，避免失败时泄漏
        synchronized(h2ConnMutex) {
            activeH2Connections.add(activeH2Connections.size, h2conn)
        }
        try {
            h2conn.accept(None)  // 无预读 preface（ALPN 路径——TLS 处理帧边界）

            while (running.load() && h2conn.isConnected()) {
                let (streamId, request) = try {
                    h2conn.recvRequest()
                } catch (e: Exception) {
                    break
                }
                if (streamId == 0) { break }

                // 检测扩展 CONNECT（:method=CONNECT + :protocol）
                let isExtendedConnect = request.method == HttpMethod.CONNECT && request.headers.get(":protocol").isSome()
                if (isExtendedConnect) {
                    let protocol = match (request.headers.get(":protocol")) {
                        case Some(p) => p
                        case None => ""
                    }
                    let h2 = h2conn
                    let sid = streamId
                    let req = request
                    let h = handler
                    spawn {
                        try {
                            // 发送 200 响应，建立隧道
                            let tunnel = h2.acceptExtendedConnect(sid, protocol)
                            req.metadata = Some(tunnel)
                            h(req)
                        } catch (e: Exception) {
                            logError("extended connect handler error: ${e.message}")
                        }
                    }
                    continue
                }


                let h2 = h2conn
                let sid = streamId
                let req = request
                let h = handler
                let ph = pushHandler
                spawn {
                    let response = try {
                        h(req)
                    } catch (e: Exception) {
                        let errResp = HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, e.message)
                        try { h2.sendResponse(sid, errResp) } catch (_: Exception) {}
                        return
                    }

                    // HTTP/2 服务端推送：检查是否有推送处理器
                    match (ph) {
                        case Some(pushFn) =>
                            let pushRequests = try {
                                pushFn(req)
                            } catch (_: Exception) {
                                ArrayList<HttpRequest>()
                            }
                            for (pushReq in pushRequests) {
                                let pushStreamId = h2.pushPromise(sid, pushReq)
                                if (pushStreamId > 0) {
                                    let pushResp = try {
                                        h(pushReq)
                                    } catch (_: Exception) {
                                        continue
                                    }
                                    try {
                                        h2.sendPushResponse(pushStreamId, pushResp)
                                    } catch (_: Exception) {}
                                }
                            }
                        case None => ()
                    }

                    try {
                        h2.sendResponse(sid, response)
                    } catch (e: Exception) {
                        logError("h2 sendResponse error: ${e.message}")
                    }
                }
            }
        } catch (e: Exception) {
            logError("handleHttp2ConnectionOverConnection loop error: ${e.message}")
        }
        try { h2conn.close() } catch (_: Exception) {}
        try { conn.close() } catch (_: Exception) {}
        activeConnectionCount.fetchSub(1)
    }

    /**
     * 通过配置的 errorLog 回调记录错误。
     * 如果未配置 ErrorLog 则静默忽略。
     */
    private func logError(message: String): Unit {
        match (config.errorLog) {
            case Some(logFn) => logFn(message)
            case None => ()
        }
    }

    /**
     * 处理 HTTP/1.x 连接，可带预窥探数据。
     */
    private func handleHttp1Connection(conn: TcpSocket, prePeeked: Array<UInt8>, hasPrePeek: Bool): Unit {
        var keepAlive = true
        var prefetched: Array<UInt8> = if (hasPrePeek) { prePeeked } else { Array<UInt8>(0, repeat: 0) }
        var firstRequest = true
        var lastRequestTime = DateTime.now()
        // 创建支持劫持的连接包装器，供处理器劫持使用
        let takeoverConn = TcpConnection(conn)
        // 为此连接创建根上下文's request chain
        // 若设置了 BaseContext 钩子则使用，否则默认为全新的 RequestContext
        let rootCtx = match (config.baseContext) {
            case Some(bc) => bc()
            case None => RequestContext()
        }

        // 若设置了 ConnContext 钩子则应用
        // 若设置了 ConnContext 钩子则应用
        let effectiveRootCtx = match (config.connContext) {
            case Some(cc) => cc(rootCtx)
            case None => rootCtx
        }

        while (keepAlive && running.load()) {
            // 为头部读取阶段应用读取超时
            let effectiveReadTimeout = if (config.readHeaderTimeout > Duration.second * 0) { config.readHeaderTimeout } else { config.readTimeout }
            conn.readTimeout = effectiveReadTimeout

            let request = if (firstRequest) {
                try {
                    readHttpRequestWithPrefix(conn, prefetched)
                } catch (e: ProtocolException) {
                    sendErrorResponse(conn, HttpStatus.BAD_REQUEST, message: e.message)
                    return
                } catch (e: Exception) {
                    logError("readHttpRequestWithPrefix error: ${e.message}")
                    return
                }
            } else {
                try {
                    readHttpRequest(conn)
                } catch (e: ProtocolException) {
                    sendErrorResponse(conn, HttpStatus.BAD_REQUEST, message: e.message)
                    return
                } catch (e: Exception) {
                    logError("readHttpRequest error: ${e.message}")
                    return
                }
            }
            // 头部读取后恢复读取超时
            conn.readTimeout = config.readTimeout
            firstRequest = false
            prefetched = []

            match (request) {
                case Some(req) =>
                    keepAlive = shouldKeepAlive(req)

                    // 从有效的根上下文创建每请求上下文
                    req.ctx = effectiveRootCtx.createChild()
                    // 暴露底层连接供处理器劫持（WebSocket 等）
                    req.connection = Some(takeoverConn)

                    // 检查 h2c 升级请求（由服务器内部处理）
                    if (checkH2cUpgrade(conn, req)) {
                        return
                    }

                    // 检查通用 Upgrade 处理器
                    if (checkGenericUpgrade(conn, req)) {
                        return
                    }

                    // RFC 7231 §5.1.2：Max-Forwards 头处理
                    if (req.method == HttpMethod.TRACE) {
                        handleMaxForwards(req)
                    }

                    // RFC 7230 §4.3：TE 头解析 — 声明愿意接收尾部头
                    handleTeHeader(req)

                    fireConnState(ConnState.STATE_ACTIVE)
                    // 分发并异常恢复 — 捕获处理器异常并返回 500
                    let response = try {
                        handler(req)
                    } catch (e: Exception) {
                        // 若处理器已劫持，直接退出 —— 不发送错误
                        if (req.takenOver) { return }
                        sendErrorResponse(conn, HttpStatus.INTERNAL_SERVER_ERROR, message: e.message)
                        return
                    }

                    // 自动取消请求上下文
                    req.ctx.cancel(reason: "request completed")

                    // 若处理器劫持了连接，停止管理它
                    if (req.takenOver) {
                        return
                    }

                    // 根据 RFC 7231 §4.3.2：HEAD 响应不得有主体
                    if (req.method == HttpMethod.HEAD) {
                        let empty = ByteBuffer(capacity: 0)
                        response.body = empty
                    }

                    // RFC 7230 §6.1：HTTP/1.0 默认 Connection: close
                    if (req.version == HttpVersion.HTTP_1_0 && response.headers.get("connection").isNone()) {
                        response.headers.set("Connection", "close")
                    }

                    // 根据 Accept-Encoding 自动压缩
                    applyCompression(req, response)

                    try {
                        sendHttpResponse(conn, response)
                    } catch (e: Exception) {
                        logError("sendHttpResponse error: ${e.message}")
                        return
                    }
                    // 检查请求间的空闲超时 on Keep-Alive connections
                    let now = DateTime.now()
                    if (now - lastRequestTime > config.idleTimeout) {
                        try { conn.close() } catch (e: Exception) { logError("idle timeout close error: ${e.message}") }
                        return
                    }
                    lastRequestTime = now

                case None => return
            }
        }

        try { conn.close() } catch (_: Exception) {}
    }

    /**
     * 读取带预窥探前缀字节的 HTTP/1.1 请求。
     */
    private func readHttpRequestWithPrefix(conn: TcpSocket, prefix: Array<UInt8>): ?HttpRequest {
        let buffer = ByteBuffer(capacity: DEFAULT_BUFFER_SIZE)
        if (prefix.size > 0) {
            buffer.write(prefix)
        }
        let scratch = Array<UInt8>(DEFAULT_BUFFER_SIZE, repeat: 0)

        var headerEnd: Int64 = findHeaderEnd(buffer.getArray(), buffer.getLimit())
        var totalRead: Int64 = buffer.getLimit()

        while (headerEnd < 0) {
            let n = conn.read(scratch)
            if (n <= 0) {
                if (totalRead == 0) { return None }
                throw ProtocolException("connection closed before headers complete")
            }
            buffer.write(scratch, 0, n)
            totalRead += n
            if (totalRead > config.maxHeaderSize) {
                throw ProtocolException("request headers too large")
            }
            headerEnd = findHeaderEnd(buffer.getArray(), totalRead)
        }

        let data = buffer.getArray()
        let request = HttpRequestParser.parse(data[0..totalRead])
        finishRequest(conn, request)
        Some(request)
    }

    /**
     * 从连接读取并解析完整的 HTTP/1.1 请求。
     */
    private func readHttpRequest(conn: TcpSocket): ?HttpRequest {
        readHttpRequestWithPrefix(conn, Array<UInt8>(0, repeat: 0))
    }

    /**
     * 处理已解析请求的 Expect 头和主体读取。
     * 通过 bodyReader 设置延迟主体读取，而非急切缓冲整个主体。
     * 主体在首次访问 bodyAsBytes()/bodyAsString() 时从连接读取。
     * 
     */
    private func finishRequest(conn: TcpSocket, request: HttpRequest): Unit {
        match (request.headers.get("expect")) {
            case Some(ev) =>
                let evBytes = stringToBytes(ev)
                if (utilsContainsIgnoreCaseBytes(evBytes, CONTINUE_BYTES)) {
                    let continueBytes = unsafe { "HTTP/1.1 100 Continue\r\n\r\n".rawData() }
                    conn.write(continueBytes)
                } else {
                    throw ProtocolException("Unsupported Expect header: ${ev}")
                }
            case None => ()
        }

        // 设置惰性主体读取——主体在首次访问时读取，而非预读
        match (request.headers.get("content-length")) {
            case Some(cl) =>
                let contentLength = parseContentLength(cl)
                if (contentLength > config.maxBodySize) {
                    throw ProtocolException("request body too large")
                }
                let currentBody = request.body.getLimit()
                if (contentLength > currentBody) {
                    request.bodyRemaining = contentLength
                }
            case None => ()
        }
    }

    /**
     * Send an HTTP 响应 over the connection with auto-headers and 压缩.
     * 在支持的情况下使用 writeBuffers 实现单系统调用拼接写入。
     */
    private func sendHttpResponse(conn: TcpSocket, response: HttpResponse): Unit {
        finalizeResponse(response)
        let parts = ArrayList<Array<UInt8>>()
        parts.add(unsafe { response.buildStatusLine().rawData() })
        let headerBytes = response.headers.toBytes()
        if (headerBytes.size > 0) {
            parts.add(headerBytes)
        }
        parts.add(unsafe { "\r\n".rawData() })
        let bodyLen = response.body.getLimit()
        if (bodyLen > 0) {
            parts.add(response.body.getArray()[0..bodyLen])
        }
        // 合并所有部分，通过循环写入确保大响应完整发送
        var total: Int64 = 0
        for (p in parts) { total += p.size }
        let combined = Array<UInt8>(total, repeat: 0)
        var offset: Int64 = 0
        for (p in parts) {
            if (p.size > 0) { p.copyTo(combined, 0, offset, p.size); offset += p.size }
        }
        // 分批写入，确保大响应完整发送
        var written: Int64 = 0
        while (written < total) {
            let chunkSize = if (total - written > 8192) { 8192 } else { total - written }
            conn.write(combined[written..written + chunkSize])
            written += chunkSize
        }
    }

    /**
     * Apply automatic headers (Date, Server) and optional 压缩.
     */
    private func finalizeResponse(response: HttpResponse): Unit {
        // 自动设置 Date 头部
        if (config.autoDateHeader && response.headers.get("date").isNone()) {
            response.headers.set("Date", currentHttpDate())
        }
        // 自动设置 Server 头部
        if (config.autoServerHeader && response.headers.get("server").isNone()) {
            response.headers.set("Server", config.serverName)
        }
        // 自动设置 Content-Length 头部
        // 若响应未设置 Content-Length，且未使用 chunked 传输编码，
        // 则根据主体大小设置 Content-Length。
        // 没有此头部，浏览器在 HTTP/1.1 keep-alive 连接上无法确定
        // 响应主体何时结束，导致请求被取消（显示为"已取消"）。
        if (response.headers.get("content-length").isNone()) {
            let isChunked = match (response.headers.get("transfer-encoding")) {
                case Some(te) => te.toAsciiLower().contains("chunked")
                case None => false
            }
            if (!isChunked) {
                let bodySize = response.body.getLimit()
                response.headers.set("Content-Length", "${bodySize}")
            }
        }
    }

    /**
     * Apply 内容编码 压缩 based on Accept-Encoding header.
     * 在发送响应前由处理器链调用。
     */
    public func applyCompression(request: HttpRequest, response: HttpResponse): Unit {
        if (!config.autoCompress) { return }
        let bodySize = response.body.getLimit()
        if (bodySize < config.compressMinSize) { return }
        if (response.headers.get("content-encoding").isSome()) { return }

        let selected = selectContentEncodingWithBrotli(request.headers.get("accept-encoding"))

        if (selected == "br") {
            let compressed = brotliCompress(response.bodyAsBytes())
            if (compressed.size < bodySize) {
                let newBody = ByteBuffer(capacity: compressed.size)
                newBody.write(compressed)
                response.body = newBody
                response.headers.set("Content-Encoding", "br")
                response.headers.set("Content-Length", "${compressed.size}")
            }
        } else if (selected == "gzip") {
            let compressed = Compression.compressGzip(response.bodyAsBytes())
            let newBody = ByteBuffer(capacity: compressed.size)
            newBody.write(compressed)
            response.body = newBody
            response.headers.set("Content-Encoding", "gzip")
            response.headers.set("Content-Length", "${compressed.size}")
        } else if (selected == "deflate") {
            let compressed = Compression.compressDeflate(response.bodyAsBytes())
            let newBody = ByteBuffer(capacity: compressed.size)
            newBody.write(compressed)
            response.body = newBody
            response.headers.set("Content-Encoding", "deflate")
            response.headers.set("Content-Length", "${compressed.size}")
        }
    }

    /**
     * 为 405 发送带正确 Allow 头的错误响应。
     * 发送 HTTP 错误响应。
     */
    private func sendErrorResponse(conn: TcpSocket, status: HttpStatus, message!: String = ""): Unit {
        let bodyText = if (message.size > 0) { message } else { status.reasonPhrase }
        let response = HttpResponse.text(status, bodyText)
        // 自动为 405 Method Not Allowed 填充 Allow 响应头
        if (status.code == 405) {
            match (message.indexOf(":")) {
                case Some(idx) =>
                    response.headers.set("Allow", message[idx + 1..])
                case None => ()
            }
        }
        finalizeResponse(response)
        let data = response.toBytes()
        try {
            conn.write(data)
        } catch (_: Exception) {}
        try {
            conn.close()
        } catch (_: Exception) {}
    }

    /**
     * 判断连接是否应保持活跃。
     * HTTP/1.0 默认 Connection: close，除非显式设置为 Keep-Alive。
     * HTTP/1.1 默认 Keep-Alive，除非显式设置为 close。
     * HTTP 服务端连接处理。
     */
    private func shouldKeepAlive(request: HttpRequest): Bool {
        if (!config.keepAlive) { return false }

        // HTTP/1.0 默认 close；仅在明确请求时保持 Keep-Alive
        if (request.version == HttpVersion.HTTP_1_0) {
            match (request.headers.get("connection")) {
                case Some(v) =>
                    let bytes = stringToBytes(v)
                    if (utilsContainsIgnoreCaseBytes(bytes, KEEP_ALIVE_BYTES)) { return true }
                case None => ()
            }
            return false
        }

        // HTTP/1.1+ 默认 Keep-Alive
        match (request.headers.get("connection")) {
            case Some(v) =>
                let bytes = stringToBytes(v)
                if (utilsEqualsIgnoreCaseBytes(bytes, CLOSE_BYTES)) { return false }
                if (utilsEqualsIgnoreCaseBytes(bytes, KEEP_ALIVE_BYTES)) { return true }
            case None => ()
        }

        request.version.supportsPersistentConnection()
    }

    // ---- 升级处理 ----

    /**
     * 检查请求是否为 h2c 升级请求并处理。
     * 如果请求作为升级被处理则返回 true。
     *
     * WebSocket 升级不再在此处处理。处理器应
     * 使用 ConnectionController 模式：访问 req.connection 以获取原始
     * 连接，手动发送 101 响应，并设置 req.takenOver = true。
     */
    private func checkH2cUpgrade(conn: TcpSocket, request: HttpRequest): Bool {
        match (request.headers.get("upgrade")) {
            case Some(upgrade) =>
                let upBytes = stringToBytes(upgrade)
                if (utilsContainsIgnoreCaseBytes(upBytes, H2C_BYTES)) {
                    handleH2cUpgrade(conn, request)
                    return true
                }
                false
            case None => false
        }
    }

    /**
     * 检查通用 Upgrade 请求并调用注册的处理器。
     * 如果任何处理器处理了升级则返回 true。
     */
    private func checkGenericUpgrade(conn: TcpSocket, request: HttpRequest): Bool {
        match (request.headers.get("upgrade")) {
            case Some(upgrade) =>
                let protocols = upgrade.split(",")
                for (p in protocols) {
                    let lowerProtocol = p.toAsciiLower().trimAscii()
                    match (upgradeHandlers.get(lowerProtocol)) {
                        case Some(h) => return h(conn, request)
                        case None => ()
                    }
                }
                false
            case None => false
        }
    }

    private func handleH2cUpgrade(conn: TcpSocket, request: HttpRequest): Unit {
        match (request.headers.get("http2-settings")) {
            case Some(settings) =>
                let responseLine = "HTTP/1.1 101 Switching Protocols\r\n"
                let headers = HttpHeaders()
                headers.set("Connection", "Upgrade")
                headers.set("Upgrade", "h2c")

                // 使用流式写入发送 101 响应
                conn.write(unsafe { "HTTP/1.1 101 Switching Protocols\r\n".rawData() })
                conn.write(headers.toBytes())
                conn.write(unsafe { "\r\n".rawData() })

                if (config.enableHttp2) {
                    handleHttp2Connection(conn)
                }
            case None =>
                sendErrorResponse(conn, HttpStatus.BAD_REQUEST, message: "Missing HTTP2-Settings header")
        }
    }

    // ---- HTTP/1.x Max-Forwards 与 TE 辅助函数 ----

    /**
     * 处理 Max-Forwards 头（RFC 7231 §5.1.2）。
     * 若值为 0，本端直接响应 TRACE；否则递减后继续转发。
     */
    private func handleMaxForwards(req: HttpRequest): Unit {
        match (req.headers.get("max-forwards")) {
            case Some(mf) =>
                let maxForwards = parseMaxForwardsValue(mf)
                if (maxForwards == 0) {
                    let response = buildTraceResponse(req)
                    match (req.connection) {
                        case Some(conn) =>
                            try { response.writeTo(conn) } catch (_: Exception) {}
                        case None => ()
                    }
                } else if (maxForwards > 0) {
                    req.headers.set("Max-Forwards", Int64(maxForwards - 1).toString())
                }
            case None => ()
        }
    }

    /**
     * 解析 TE 头，检测客户端是否接受尾部头（RFC 7230 §4.3）。
     */
    private func handleTeHeader(req: HttpRequest): Unit {
        match (req.headers.get("te")) {
            case Some(te) =>
                if (te.indexOf("trailers").isSome() || te.indexOf("Trailers").isSome()) {
                    req.acceptsTrailers = true
                }
            case None => ()
        }
    }

    private static func parseMaxForwardsValue(value: String): Int64 {
        try { Int64.parse(value) } catch (_: Exception) { -1 }
    }

    /**
     * 构建 TRACE 响应（本端处理，不转发）。
     */
    private func buildTraceResponse(req: HttpRequest): HttpResponse {
        let bodyStr = "${req.method} ${req.url} ${req.version}\r\n" + headersToString(req.headers)
        let bodyBytes = unsafe { bodyStr.rawData() }
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        let resp = HttpResponse(status: HttpStatus.OK, body: body)
        resp.headers.set("Content-Type", "message/http")
        resp
    }

    private static func headersToString(headers: HttpHeaders): String {
        var result = ""
        for (name in headers.names()) {
            match (headers.get(name)) {
                case Some(value) => result += "${name}: ${value}\r\n"
                case None => ()
            }
        }
        result
    }
}

/**
 * 尝试从套接字窥探数据（尽最大努力读取完整缓冲区）。
 * 仅在读取到完整缓冲区大小时返回 true。
 */
private func tryPeek(conn: TcpSocket, buf: Array<UInt8>): Bool {
    try {
        let n = conn.read(buf)
        n == buf.size  // 仅完整读取时返回 true
    } catch (_: Exception) {
        false
    }
}

/**
 * 根据 RFC 6455 计算 Sec-WebSocket-Accept 值。
 * accept = base64(sha1(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
 */
public func computeWebSocketAcceptKey(key: String): String {
    let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let combined = key + magic
    let combinedBytes = stringToBytes(combined)
    let digest = sha1(combinedBytes)
    base64EncodeBytes(digest)
}
