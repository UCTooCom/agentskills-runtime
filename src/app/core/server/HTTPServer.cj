package magic.app.core.server

import std.collection.{HashMap, ArrayList}
import http_lib.server.{HttpServer as LibHttpServer, HttpServerConfig}
import http_lib.router.{Router as LibRouter, Handler as LibHandler}
import http_lib.message.{HttpRequest as LibHttpRequest, HttpResponse as LibHttpResponse}
import http_lib.core.{HttpMethod as LibHttpMethod, HttpStatus as LibHttpStatus, ConnState}
import http_lib.connection.TlsConfig
import http_lib.buffer.ByteBuffer
import magic.app.core.http.{HttpRequest as AppHttpRequest, HttpResponse as AppHttpResponse, HttpMethod, HttpHeader}
import magic.app.core.router.{Router, Route}
import magic.app.core.middleware.{Middleware, MiddlewareChain}
import magic.app.core.log.{LoggerFactory, Logger}
import magic.config.Config

public class HTTPServer {
    private var _libServer: ?LibHttpServer = None
    private var router: Router = Router()
    private var middlewareChain: MiddlewareChain = MiddlewareChain()
    private let port: Int32
    private let host: String
    private var running: Bool = false
    private let logger: Logger
    private let isHttps: Bool
    private let _requestTimeout: Duration
    private let _certPath: ?String
    private let _keyPath: ?String
    private var _webSocketRoutes: HashMap<String, LibHandler> = HashMap<String, LibHandler>()

    private static var DEFAULT_REQUEST_TIMEOUT: Duration = Duration.second * 120

    public init(port: Int32, host: String) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = false
        this._requestTimeout = DEFAULT_REQUEST_TIMEOUT
        this._certPath = None
        this._keyPath = None
        logger.info("HTTP Server initialized on ${host}:${port} with timeout=${_requestTimeout.toSeconds()}s")
    }

    public init() {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = 8080
        this.host = "127.0.0.1"
        this.isHttps = false
        this._requestTimeout = DEFAULT_REQUEST_TIMEOUT
        this._certPath = None
        this._keyPath = None
        logger.info("HTTP Server initialized on ${host}:${port} with timeout=${_requestTimeout.toSeconds()}s")
    }

    public init(port: Int32, host: String, certPath: String, keyPath: String) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = true
        this._requestTimeout = DEFAULT_REQUEST_TIMEOUT
        this._certPath = Some(certPath)
        this._keyPath = Some(keyPath)
        logger.info("HTTPS Server initialized on ${host}:${port} with timeout=${_requestTimeout.toSeconds()}s")
    }

    public init(port: Int32, host: String, requestTimeout: Duration) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = false
        this._requestTimeout = requestTimeout
        this._certPath = None
        this._keyPath = None
        logger.info("HTTP Server initialized on ${host}:${port} with timeout=${requestTimeout.toSeconds()}s")
    }

    public init(port: Int32, host: String, certPath: String, keyPath: String, requestTimeout: Duration) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = true
        this._requestTimeout = requestTimeout
        this._certPath = Some(certPath)
        this._keyPath = Some(keyPath)
        logger.info("HTTPS Server initialized on ${host}:${port} with timeout=${requestTimeout.toSeconds()}s")
    }

    public func setPort(port: Int32): HTTPServer {
        return this
    }

    public func setHost(host: String): HTTPServer {
        return this
    }

    public func getPort(): Int32 {
        return port
    }

    public func getHost(): String {
        return host
    }

    public func setRouter(router: Router): HTTPServer {
        this.router = router
        return this
    }

    public func use(middleware: Middleware): HTTPServer {
        middlewareChain.use(middleware)
        return this
    }

    public func registerWebSocketRoute(path: String, handler: LibHandler): HTTPServer {
        _webSocketRoutes.add(path, handler)
        return this
    }

    public func start() {
        eprintln("=== HTTPServer.start() called ===")
        running = true
        logger.info("HTTP Server starting on ${host}:${port}")
        eprintln("=== HTTP Server starting on ${host}:${port} ===")

        eprintln("=== Creating http_lib Router ===")
        let libRouter = LibRouter()

        eprintln("=== Registering routes ===")
        let allRoutes = router.getRoutes()
        eprintln("=== Found ${allRoutes.size} routes to register ===")
        logger.info("Found ${allRoutes.size} routes to register")

        // 去重：多个 Route 文件的 register() 内部调用 registerCustomRoutes()，
        // 而 AutoRouteConfig 又显式调用 registerCustomRoutes()，
        // 导致同一 (method, path) 被注册两次，引发基数树结构异常。
        // 此处按 "METHOD|PATH" 键去重，仅保留首次出现的路由。
        let seen = HashMap<String, Bool>()
        let routes = ArrayList<Route>()
        var dupCount = 0
        for (route in allRoutes) {
            let key = "${route.method.toString()}|${route.path}"
            if (seen.contains(key)) {
                dupCount++
            } else {
                seen[key] = true
                routes.add(route)
            }
        }
        if (dupCount > 0) {
            eprintln("=== Removed ${dupCount} duplicate routes ===")
            logger.info("Removed ${dupCount} duplicate routes")
        }
        eprintln("=== Unique routes to register: ${routes.size} ===")

        let staticRoutes = ArrayList<Route>()
        let wildcardRoutes = ArrayList<Route>()
        for (route in routes) {
            if (route.path.contains(":")) {
                wildcardRoutes.add(route)
            } else {
                staticRoutes.add(route)
            }
        }
        eprintln("=== Static routes: ${staticRoutes.size}, Wildcard routes: ${wildcardRoutes.size} ===")

        for (route in staticRoutes) {
            try {
                registerRouteOnLibRouter(libRouter, route)
            } catch (ex: Exception) {
                eprintln("=== Failed to register route ${route.path}: ${ex.message} ===")
                logger.error("Failed to register route ${route.path}: ${ex.message}")
            }
        }
        eprintln("=== Static routes registered ===")

        for (route in wildcardRoutes) {
            try {
                registerRouteOnLibRouter(libRouter, route)
            } catch (ex: Exception) {
                eprintln("=== Failed to register route ${route.path}: ${ex.message} ===")
                logger.error("Failed to register route ${route.path}: ${ex.message}")
            }
        }
        eprintln("=== All app routes registered ===")

        // 最终验证：对所有注册的关键路由进行二次验证
        eprintln("=== FINAL VERIFICATION: checking key routes ===")
        let verifyMethods = [
            LibHttpMethod.GET, LibHttpMethod.POST, LibHttpMethod.PUT,
            LibHttpMethod.DELETE, LibHttpMethod.PATCH
        ]
        let verifyPaths = [
            "/api/v1/uctoo/tasks/public/home-stats",
            "/api/v1/uctoo/webmcp/mcp",
            "/api/v1/health",
            "/api/v1/uctoo/tasks/public/1/10"
        ]
        for (vMethod in verifyMethods) {
            for (vPath in verifyPaths) {
                let vResult = libRouter.find(vMethod, vPath)
                if (vResult.handler.isSome()) {
                    eprintln("=== FINAL: ${vMethod} ${vPath} => FOUND ===")
                }
            }
        }

        try {
            libRouter.get("/hello", { req: LibHttpRequest =>
                eprintln("=== /hello handler called: method=${req.method}, path=${req.path}, url=${req.url} ===")
                LibHttpResponse.json(LibHttpStatus.OK, "{\"message\":\"AgentSkills-runtime,Hello World\"}")
            })
            eprintln("=== /hello route registered ===")
        } catch (ex: Exception) {
            eprintln("=== Failed to register /hello: ${ex.message} ===")
        }

        for ((wsPath, wsHandler) in _webSocketRoutes) {
            try {
                eprintln("=== Registering WebSocket route: ${wsPath} ===")
                libRouter.get(wsPath, wsHandler)
                eprintln("=== WebSocket route registered: ${wsPath} ===")
            } catch (ex: Exception) {
                eprintln("=== Failed to register WS route ${wsPath}: ${ex.message} ===")
            }
        }

        logger.info("All routes registered successfully")

        eprintln("=== Creating HttpServerConfig ===")
        let config = HttpServerConfig()
        config.readTimeout = _requestTimeout
        config.writeTimeout = _requestTimeout
        config.idleTimeout = _requestTimeout
        eprintln("=== HttpServerConfig created ===")

        if (isHttps) {
            eprintln("=== Configuring TLS ===")
            match (_certPath) {
                case Some(cert) =>
                    match (_keyPath) {
                        case Some(key) =>
                            let tlsConfig = TlsConfig()
                            tlsConfig.serverCertPath = cert
                            tlsConfig.serverKeyPath = key
                            // TLS 诊断日志：生产/正式环境必须关闭，避免大量 println 输出
                            // 阻塞并发TLS握手协程，导致浏览器报 net::ERR_SSL_PROTOCOL_ERROR
                            tlsConfig.enableDiagnostics = false
                            // 仅协商 HTTP/1.1，jinguissl TLS 实现暂不支持 HTTP/2 over TLS
                            tlsConfig.nextProtos = ["http/1.1"]
                            tlsConfig.autoLoadSystemCerts = true
                            config.tlsConfig = Some(tlsConfig)
                            // HTTP/2 over TLS 需要 jinguissl 支持，当前仅用 HTTP/1.1
                            config.enableHttp2 = false
                            config.tcpNoDelay = true
                            config.autoCompress = true
                            // 显式启用并发连接处理：每个连接独立协程，
                            // 避免 accept() 循环被单个 TLS 握手阻塞，
                            // 导致浏览器并行发起的多个连接排队超时
                            config.concurrent = true
                            eprintln("=== TLS configured: cert=${cert}, key=${key}, http/1.1 only ===")
                        case None =>
                            logger.error("HTTPS server but key path not set")
                            throw Exception("HTTPS server requires key path")
                    }
                case None =>
                    logger.error("HTTPS server but cert path not set")
                    throw Exception("HTTPS server requires cert path")
            }
        } else {
            // HTTP 模式：禁用 HTTP/2 h2c 升级检测
            // tryPeek 会消费 socket 字节，可能导致 HTTP/1.1 请求解析异常
            config.enableHttp2 = false
            config.tcpNoDelay = true
            eprintln("=== HTTP mode: enableHttp2 disabled, tcpNoDelay enabled ===")
        }

        eprintln("=== Creating LibHttpServer with handler ===")
        let routerHandler = libRouter.handler()
        eprintln("=== Router handler created ===")

        // CORS 顶层包装层：在路由分发之前拦截 OPTIONS 预检请求
        // 原因：应用层 CORSMiddleware 只在路由匹配时执行，而 OPTIONS
        // 请求未注册路由，预检返回 404，浏览器因此阻止所有跨域 API 调用。
        // 此包装层确保 OPTIONS 预检直接返回 200 + CORS 头，
        // 并为所有其他响应补充 CORS 头。
        let handler: LibHandler = { req: LibHttpRequest =>
            // WebSocket 升级检测：如果请求带有 Upgrade: websocket 头，
            // 且该路径有注册的 WebSocket 处理器，则直接委托给 WebSocket 处理器。
            // 这解决了 WebSocket 路由注册失败（路径已被应用路由占用）的问题：
            // 应用路由先注册了 GET /api/v1/uctoo/webmcp/mcp，
            // 导致 WebSocket 路由无法再次注册同一路径，
            // 前端 WebSocket 升级请求被错误路由到返回 JSON 的普通处理器，
            // 浏览器收到 HTTP 200 而非 101 Switching Protocols，报 ERR_SSL_PROTOCOL_ERROR。
            let upgradeHeader = req.headers.get("Upgrade")
            if (upgradeHeader.isSome() && upgradeHeader.getOrThrow() == "websocket") {
                let wsHandlerOpt = _webSocketRoutes.get(req.path)
                if (wsHandlerOpt.isSome()) {
                    eprintln("=== WebSocket upgrade detected: ${req.path} ===")
                    let wsHandler = wsHandlerOpt.getOrThrow()
                    wsHandler(req)
                } else {
                    handleCorsRequest(req, routerHandler)
                }
            } else {
                handleCorsRequest(req, routerHandler)
            }
        }
        config.connState = { s =>
            let name = match (s) {
                case ConnState.STATE_NEW => "NEW"
                case ConnState.STATE_ACTIVE => "ACTIVE"
                case ConnState.STATE_IDLE => "IDLE"
                case ConnState.STATE_HIJACKED => "HIJACKED"
                case ConnState.STATE_CLOSED => "CLOSED"
            }
            logger.info("conn state: ${name}")
        }
        config.errorLog = { msg => logger.error("http: ${msg}") }
        let libServer = LibHttpServer(handler: handler, config: config)
        _libServer = Some(libServer)
        eprintln("=== LibHttpServer created ===")

        logEndpoints()

        try {
            if (isHttps) {
                eprintln("=== Calling listenAndServeTls on ${host}:${port} ===")
                libServer.listenAndServeTls(host, UInt16(port))
                eprintln("=== listenAndServeTls returned (server should block) ===")
            } else {
                eprintln("=== Calling listenAndServe on ${host}:${port} ===")
                libServer.listenAndServe(host, UInt16(port))
                eprintln("=== listenAndServe returned (server should block) ===")
            }
        } catch (ex: Exception) {
            eprintln("=== FATAL: Server failed to start: ${ex.message} ===")
            ex.printStackTrace()
            logger.error("Failed to start API server: ${ex.message}")
            throw ex
        }
        eprintln("=== HTTPServer.start() exited normally ===")
    }

    private func handleCorsRequest(req: LibHttpRequest, routerHandler: LibHandler): LibHttpResponse {
        let origin = match (req.headers.get("Origin")) {
            case Some(o) => if (o.size > 0) { o } else { "*" }
            case None => "*"
        }

        if (req.method == LibHttpMethod.OPTIONS) {
            let corsResp = LibHttpResponse(status: LibHttpStatus.OK)
            corsResp.headers.set("Access-Control-Allow-Origin", origin)
            corsResp.headers.set("Access-Control-Allow-Credentials", "true")
            corsResp.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
            let requestedHeaders = match (req.headers.get("Access-Control-Request-Headers")) {
                case Some(h) => if (h.size > 0) { h } else {
                    "Origin, X-Requested-With, Content-Type, Accept, Authorization, x-lang, mcp-protocol-version, mcp-session-id, last-event-id, x-request-id"
                }
                case None => "Origin, X-Requested-With, Content-Type, Accept, Authorization, x-lang, mcp-protocol-version, mcp-session-id, last-event-id, x-request-id"
            }
            corsResp.headers.set("Access-Control-Allow-Headers", requestedHeaders)
            corsResp.headers.set("Access-Control-Max-Age", "86400")
            corsResp.headers.set("Vary", "Origin")
            eprintln("=== CORS preflight: ${req.method} ${req.path}, requestedHeaders=${requestedHeaders} ===")
            corsResp
        } else {
            if (req.path.contains("tasks") || req.path.contains("webmcp")) {
                eprintln("=== DISPATCH: ${req.method} ${req.path} (host=${req.headers.get("Host")}) ===")
            }
            let resp = routerHandler(req)
            if (req.path.contains("tasks") || req.path.contains("webmcp")) {
                eprintln("=== DISPATCH result: ${req.method} ${req.path} => status=${resp.status} ===")
            }
            resp.headers.set("Access-Control-Allow-Origin", origin)
            resp.headers.set("Access-Control-Allow-Credentials", "true")
            resp.headers.set("Access-Control-Expose-Headers", "mcp-session-id, mcp-protocol-version, x-request-id, content-type")
            if (origin != "*") {
                resp.headers.set("Vary", "Origin")
            }
            resp
        }
    }

    private func registerRouteOnLibRouter(libRouter: LibRouter, route: Route): Unit {
        let routePath = route.path
        let routeHandler = route.handler
        let chain = middlewareChain
        let log = logger

        let handler: LibHandler = { req: LibHttpRequest =>
            eprintln("=== Handling request to ${routePath} ===")

            let appReq = convertRequest(req)
            let appRes = AppHttpResponse()

            try {
                eprintln("=== Executing middleware chain ===")
                let finalHandler = { =>
                    eprintln("=== Executing final handler ===")
                    routeHandler(appReq, appRes)
                }
                chain.execute(appReq, appRes, finalHandler)
                eprintln("=== Middleware chain completed ===")

                let libRes = convertResponse(appRes)
                eprintln("=== Response: status=${appRes.getStatusCode()}, bodySize=${appRes.getBody().size.toString()} ===")
                libRes
            } catch (ex: Exception) {
                eprintln("=== Exception in handler: ${ex.message} ===")
                ex.printStackTrace()
                log.error("Error handling request: ${ex.message}")
                LibHttpResponse.json(LibHttpStatus.INTERNAL_SERVER_ERROR,
                    "{\"error\":\"Internal Server Error\",\"message\":\"${ex.message}\"}")
            }
        }

        // 直接使用原始路径注册，不做任何转换。
        // http_lib 的 Router.handle() 内部已调用 translateBraceParams 将 {param} 转为 :param 语法。
        // normalizeRoutePath 曾错误地重命名 :param 参数名（如 :id → :p0），
        // 导致 req.pathParams 中的键名与应用层期望的不一致。
        let libMethod = convertToLibMethod(route.method)
        // 诊断日志：记录 tasks/webmcp/health 相关路由的注册
        if (routePath.contains("tasks") || routePath.contains("webmcp") || routePath.contains("health") || routePath.contains("home-stats")) {
            eprintln("=== REG: method=${libMethod}, orig='${routePath}' ===")
        }
        libRouter.handle(libMethod, routePath, handler)
        // 注册后立即验证：对关键路由检查 find 结果
        if (routePath.contains("tasks") || routePath.contains("webmcp") || routePath.contains("health")) {
            let verifyResult = libRouter.find(libMethod, routePath)
            eprintln("=== VERIFY: after register ${libMethod} ${routePath} => handler=${verifyResult.handler.isSome()}, tsr=${verifyResult.tsr} ===")
        }
    }

    private func convertToLibMethod(method: HttpMethod): LibHttpMethod {
        match (method) {
            case HttpMethod.GET => LibHttpMethod.GET
            case HttpMethod.POST => LibHttpMethod.POST
            case HttpMethod.PUT => LibHttpMethod.PUT
            case HttpMethod.DELETE => LibHttpMethod.DELETE
            case HttpMethod.PATCH => LibHttpMethod.PATCH
            case HttpMethod.HEAD => LibHttpMethod.HEAD
            case HttpMethod.OPTIONS => LibHttpMethod.OPTIONS
        }
    }

    private func convertRequest(req: LibHttpRequest): AppHttpRequest {
        let appReq = AppHttpRequest()

        appReq.method = convertMethod(req.method)
        appReq.uri.path = req.path

        let queryString = match (req.url.indexOf("?")) {
            case Some(idx) => req.url[idx + 1..]
            case None => ""
        }
        appReq.uri.query = queryString

        for ((name, value) in req.headers.entries()) {
            appReq.headers.add(HttpHeader(name, value))
        }

        appReq.body = readRequestBody(req)

        for ((key, value) in req.pathParams) {
            appReq.pathParams[key] = value
        }

        if (!queryString.isEmpty()) {
            let params = queryString.split("&")
            for (param in params) {
                let parts = param.split("=")
                if (parts.size == 2) {
                    appReq.queryParams[parts[0]] = parts[1]
                }
            }
        }

        return appReq
    }

    private func convertMethod(method: LibHttpMethod): HttpMethod {
        match (method) {
            case LibHttpMethod.GET => HttpMethod.GET
            case LibHttpMethod.POST => HttpMethod.POST
            case LibHttpMethod.PUT => HttpMethod.PUT
            case LibHttpMethod.DELETE => HttpMethod.DELETE
            case LibHttpMethod.PATCH => HttpMethod.PATCH
            case LibHttpMethod.HEAD => HttpMethod.HEAD
            case LibHttpMethod.OPTIONS => HttpMethod.OPTIONS
            case LibHttpMethod.CONNECT => HttpMethod.GET
            case LibHttpMethod.TRACE => HttpMethod.GET
        }
    }

    private func readRequestBody(req: LibHttpRequest): String {
        try {
            let body = req.bodyAsString()
            if (body.isEmpty()) {
                return ""
            }
            let previewLength = if (body.size > 200) { 200 } else { body.size }
            eprintln("=== readRequestBody: got ${body.size} chars: [${body[0..previewLength]}] ===")
            return body
        } catch (ex: Exception) {
            logger.error("Error reading request body: ${ex.message}")
            eprintln("=== readRequestBody exception: ${ex.message} ===")
            return ""
        }
    }

    private func convertResponse(appRes: AppHttpResponse): LibHttpResponse {
        let status = LibHttpStatus(UInt16(appRes.getStatusCode()))
        let libRes = LibHttpResponse(status: status)

        for ((key, value) in appRes.getHeaders()) {
            libRes.headers.set(key, value)
        }

        let bodyStr = appRes.getBody()
        if (!bodyStr.isEmpty()) {
            let data = unsafe { bodyStr.rawData() }
            libRes.body = ByteBuffer.fromOwned(data)
        }

        return libRes
    }

    private func logEndpoints(): Unit {
        let scheme = if (isHttps) { "https" } else { "http" }
        logger.info("API server started successfully on ${scheme}://${host}:${port}")
        logger.info("Available endpoints:")
        logger.info("   GET  /hello                    - Health check")
        logger.info("   GET  /api/v1/health            - Health check")
        logger.info("   GET  /api/v1/info              - Service info")
        logger.info("   ")
        logger.info("   Skills Management API:")
        logger.info("   GET  /api/v1/uctoo/skills      - Get runtime skills")
        logger.info("   POST /api/v1/uctoo/skills/install - Install skill")
        logger.info("   POST /api/v1/uctoo/skills/execute - Execute skill")
        logger.info("   POST /api/v1/uctoo/skills/search - Search skills")
        logger.info("   ")
        logger.info("   Agent Skills CRUD API:")
        logger.info("   GET  /api/v1/uctoo/agent_skills - List skills")
        logger.info("   GET  /api/v1/uctoo/agent_skills/:id - Get skill")
        logger.info("   POST /api/v1/uctoo/agent_skills/add - Add skill")
        logger.info("   POST /api/v1/uctoo/agent_skills/edit - Edit skill")
        logger.info("   POST /api/v1/uctoo/agent_skills/del - Delete skill")
        logger.info("   ")
        logger.info("   Entity CRUD API:")
        logger.info("   GET  /api/v1/uctoo/entity      - List entities")
        logger.info("   GET  /api/v1/uctoo/entity/:id  - Get entity")
        logger.info("   POST /api/v1/uctoo/entity/add  - Add entity")
        logger.info("   POST /api/v1/uctoo/entity/edit - Edit entity")
        logger.info("   POST /api/v1/uctoo/entity/del  - Delete entity")
    }

    public func stop() {
        running = false
        logger.info("HTTP Server stopping...")

        match (_libServer) {
            case Some(server) =>
                try {
                    server.close()
                    logger.info("API server stopped successfully")
                } catch (ex: Exception) {
                    logger.error("Failed to stop API server: ${ex.message}")
                }
            case None =>
                logger.error("No server instance to stop")
        }
    }
}
