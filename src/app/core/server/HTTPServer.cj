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
        running = true
        logger.info("HTTP Server starting on ${host}:${port}")

        let libRouter = LibRouter()

        let allRoutes = router.getRoutes()
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
            logger.info("Removed ${dupCount} duplicate routes")
        }

        let staticRoutes = ArrayList<Route>()
        let wildcardRoutes = ArrayList<Route>()
        for (route in routes) {
            if (route.path.contains(":")) {
                wildcardRoutes.add(route)
            } else {
                staticRoutes.add(route)
            }
        }
        logger.info("Static routes: ${staticRoutes.size}, Wildcard routes: ${wildcardRoutes.size}")

        for (route in staticRoutes) {
            try {
                registerRouteOnLibRouter(libRouter, route)
            } catch (ex: Exception) {
                logger.error("Failed to register route ${route.path}: ${ex.message}")
            }
        }

        for (route in wildcardRoutes) {
            try {
                registerRouteOnLibRouter(libRouter, route)
            } catch (ex: Exception) {
                logger.error("Failed to register route ${route.path}: ${ex.message}")
            }
        }

        try {
            libRouter.get("/hello", { req: LibHttpRequest =>
                LibHttpResponse.json(LibHttpStatus.OK, "{\"message\":\"AgentSkills-runtime,Hello World\"}")
            })
        } catch (ex: Exception) {
            logger.error("Failed to register /hello: ${ex.message}")
        }

        for ((wsPath, wsHandler) in _webSocketRoutes) {
            try {
                libRouter.get(wsPath, wsHandler)
            } catch (ex: Exception) {
                logger.error("Failed to register WS route ${wsPath}: ${ex.message}")
            }
        }

        logger.info("All routes registered successfully")

        let config = HttpServerConfig()
        config.readTimeout = _requestTimeout
        config.writeTimeout = _requestTimeout
        config.idleTimeout = _requestTimeout

        if (isHttps) {
            match (_certPath) {
                case Some(cert) =>
                    match (_keyPath) {
                        case Some(key) =>
                            let tlsConfig = TlsConfig()
                            tlsConfig.serverCertPath = cert
                            tlsConfig.serverKeyPath = key
                            tlsConfig.enableDiagnostics = false
                            tlsConfig.nextProtos = ["http/1.1"]
                            tlsConfig.autoLoadSystemCerts = true
                            config.tlsConfig = Some(tlsConfig)
                            config.enableHttp2 = false
                            config.tcpNoDelay = true
                            config.autoCompress = true
                            config.concurrent = true
                        case None =>
                            logger.error("HTTPS server but key path not set")
                            throw Exception("HTTPS server requires key path")
                    }
                case None =>
                    logger.error("HTTPS server but cert path not set")
                    throw Exception("HTTPS server requires cert path")
            }
        } else {
            config.enableHttp2 = false
            config.tcpNoDelay = true
        }

        let routerHandler = libRouter.handler()

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

        logEndpoints()

        try {
            if (isHttps) {
                libServer.listenAndServeTls(host, UInt16(port))
            } else {
                libServer.listenAndServe(host, UInt16(port))
            }
        } catch (ex: Exception) {
            ex.printStackTrace()
            logger.error("Failed to start API server: ${ex.message}")
            throw ex
        }
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
            corsResp
        } else {
            let resp = routerHandler(req)
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
            let appReq = convertRequest(req)
            let appRes = AppHttpResponse()

            try {
                let finalHandler = { =>
                    routeHandler(appReq, appRes)
                }
                chain.execute(appReq, appRes, finalHandler)

                if (appReq.takenOver) {
                    LibHttpResponse.empty(LibHttpStatus.OK)
                } else {
                    convertResponse(appRes)
                }
            } catch (ex: Exception) {
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
        libRouter.handle(libMethod, routePath, handler)
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

        appReq.connection = req.connection

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
            return body
        } catch (ex: Exception) {
            logger.error("Error reading request body: ${ex.message}")
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
