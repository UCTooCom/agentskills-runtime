package magic.app.core.server

import std.collection.{HashMap, ArrayList}
import std.fs.*
import std.io.*
import stdx.net.http.{Server, ServerBuilder, HttpContext, HttpRequest, HttpResponse, HttpResponseBuilder, FuncHandler, HttpRequestDistributor, HttpRequestHandler}
import stdx.net.tls.TlsServerConfig
import stdx.crypto.x509.{X509Certificate, PrivateKey}
import magic.app.core.http.{HttpRequest as AppHttpRequest, HttpResponse as AppHttpResponse, HttpMethod, HttpHeader}
import magic.app.core.router.{Router, Route}
import magic.app.core.middleware.{Middleware, MiddlewareChain}
import magic.app.core.log.{LoggerFactory, Logger}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

private class DefaultHttpRequestDistributor <: HttpRequestDistributor {
    private let _routes: HashMap<String, HttpRequestHandler>
    private let _dynamicRoutes: ArrayList<(String, HttpRequestHandler)>
    
    public init() {
        _routes = HashMap<String, HttpRequestHandler>()
        _dynamicRoutes = ArrayList<(String, HttpRequestHandler)>()
    }
    
    public func register(path: String, handler: HttpRequestHandler): Unit {
        if (path.contains(":")) {
            _dynamicRoutes.add((path, handler))
        } else {
            _routes.add(path, handler)
        }
    }
    
    public func distribute(path: String): HttpRequestHandler {
        let handlerOption = _routes.get(path)
        if (handlerOption.isSome()) {
            return handlerOption.getOrThrow()
        }
        
        for ((registeredPath, handler) in _dynamicRoutes) {
            if (this.matchesDynamicRoute(path, registeredPath)) {
                return handler
            }
        }
        
        return createNotFoundHandler()
    }
    
    private func matchesDynamicRoute(actualPath: String, registeredPath: String): Bool {
        let actualParts = actualPath.split("/")
        let registeredParts = registeredPath.split("/")
        
        if (actualParts.size != registeredParts.size) {
            return false
        }
        
        for (i in 0..actualParts.size) {
            let registeredPart = registeredParts[i]
            if (!registeredPart.startsWith(":") && actualParts[i] != registeredPart) {
                return false
            }
        }
        
        return true
    }
    
    private func createNotFoundHandler(): HttpRequestHandler {
        return FuncHandler({ context =>
            let responseObj = JsonObject()
            responseObj.put("error", JsonString("Not Found"))
            responseObj.put("path", JsonString(context.request.url.path))
            
            context.responseBuilder.status(404)
            context.responseBuilder.header("Content-Type", "application/json")
            context.responseBuilder.body(responseObj.toString())
        })
    }
}

public class HTTPServer {
    private let _server: Any
    private let _distributor: HttpRequestDistributor
    private var router: Router = Router()
    private var middlewareChain: MiddlewareChain = MiddlewareChain()
    private let port: Int32
    private let host: String
    private var running: Bool = false
    private let logger: Logger
    private let isHttps: Bool
    
    public init(port: Int32, host: String) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = false
        _distributor = DefaultHttpRequestDistributor()
        
        let builder = ServerBuilder()
        builder.addr(host)
        builder.port(UInt16(port))
        builder.distributor(_distributor)
        _server = builder.build()
        
        logger.info("HTTP Server initialized on ${host}:${port}")
    }
    
    public init() {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = 8080
        this.host = "127.0.0.1"
        this.isHttps = false
        _distributor = DefaultHttpRequestDistributor()
        
        let builder = ServerBuilder()
        builder.addr(host)
        builder.port(UInt16(port))
        builder.distributor(_distributor)
        _server = builder.build()
        
        logger.info("HTTP Server initialized on ${host}:${port}")
    }
    
    /// HTTPS构造函数 - 使用证书文件路径
    public init(port: Int32, host: String, certPath: String, keyPath: String) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = true
        _distributor = DefaultHttpRequestDistributor()
        
        try {
            // 加载证书和私钥
            let certFile = File(certPath, OpenMode.Read)
            let certContent = readToEnd(certFile)
            let certPem = String.fromUtf8(certContent)
            
            let keyFile = File(keyPath, OpenMode.Read)
            let keyContent = readToEnd(keyFile)
            let keyPem = String.fromUtf8(keyContent)
            
            // 配置TLS
            let tlsConfig = TlsServerConfig(
                X509Certificate.decodeFromPem(certPem),
                PrivateKey.decodeFromPem(keyPem)
            )
            
            let builder = ServerBuilder()
            builder.addr(host)
            builder.port(UInt16(port))
            builder.tlsConfig(tlsConfig)
            builder.distributor(_distributor)
            _server = builder.build()
            
            logger.info("HTTPS Server initialized on ${host}:${port}")
        } catch (e: Exception) {
            logger.error("Failed to initialize HTTPS server: ${e.message}")
            throw Exception("Failed to load SSL certificate: ${e.message}")
        }
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
    
    public func registerWebSocketRoute(path: String, handler: (HttpContext) -> Unit): HTTPServer {
        _distributor.register(path, FuncHandler({ context => handler(context) }))
        return this
    }
    
    public func start() {
        eprintln("=== HTTPServer.start() called ===")
        running = true
        logger.info("HTTP Server starting on ${host}:${port}")
        eprintln("=== HTTP Server starting on ${host}:${port} ===")
        
        eprintln("=== Calling setupRoutes() ===")
        setupRoutes()
        eprintln("=== setupRoutes() completed ===")
        
        eprintln("=== Matching _server as Server ===")
        match (_server as Server) {
            case Some(server) =>
                eprintln("=== Server instance found, calling startWithServer() ===")
                this.startWithServer(server)
            case None =>
                eprintln("=== Server instance is None! ===")
                logger.error("Server instance is None!")
                this.handleErrorInStart()
        }
        eprintln("=== HTTPServer.start() exited ===")
    }
    
    private func setupRoutes(): Unit {
        let routes = router.getRoutes()
        logger.info("Found ${routes.size} routes to register")
        
        for (route in routes) {
            logger.info("Registering route: ${route.path}")
            let handler = createRouteHandler(route.path, route.handler)
            _distributor.register(route.path, handler)
        }
        
        // 只注册未被 Router 覆盖的默认路由
        // /api/v1/health 和 /api/v1/info 已在 main.cj 中通过 router 注册
        _distributor.register("/hello", FuncHandler({ context => this.handleHello(context) }))
        
        logger.info("All routes registered successfully")
    }
    
    private func createRouteHandler(routePath: String, appHandler: (AppHttpRequest, AppHttpResponse) -> Unit): HttpRequestHandler {
        return FuncHandler({ context =>
            eprintln("=== createRouteHandler: Processing request to ${routePath} ===")
            let req = context.request
            let appReq = convertRequest(req)

            // 提取路径参数
            extractPathParams(req.url.path, routePath, appReq)

            let appRes = AppHttpResponse()

            try {
                eprintln("=== Executing middleware chain ===")
                // 先执行中间件链,最后执行业务handler
                let finalHandler = { => 
                    eprintln("=== Executing final handler ===")
                    appHandler(appReq, appRes)
                }
                middlewareChain.execute(appReq, appRes, finalHandler)
                eprintln("=== Middleware chain completed ===")

                context.responseBuilder.status(UInt16(appRes.getStatusCode()))
                for ((key, value) in appRes.getHeaders()) {
                    context.responseBuilder.header(key, value)
                }
                context.responseBuilder.body(appRes.getBody())
                eprintln("=== Response: status=${appRes.getStatusCode()}, body=${appRes.getBody()} ===")
            } catch (ex: Exception) {
                eprintln("=== Exception in createRouteHandler: ${ex.message} ===")
                ex.printStackTrace()
                logger.error("Error handling request: ${ex.message}")
                context.responseBuilder.status(500)
                context.responseBuilder.header("Content-Type", "application/json")
                let errorObj = JsonObject()
                errorObj.put("error", JsonString("Internal Server Error"))
                errorObj.put("message", JsonString(ex.message))
                context.responseBuilder.body(errorObj.toString())
            }
        })
    }
    
    private func extractPathParams(actualPath: String, routePath: String, appReq: AppHttpRequest): Unit {
        let actualParts = actualPath.split("/")
        let routeParts = routePath.split("/")
        
        if (actualParts.size != routeParts.size) {
            return
        }
        
        for (i in 0..actualParts.size) {
            let routePart = routeParts[i]
            if (routePart.startsWith(":") && routePart.size > 1) {
                // 去掉第一个字符（冒号）得到参数名
                // 例如 ":id" -> "id"
                let paramName = routePart[1..routePart.size]
                appReq.pathParams[paramName] = actualParts[i]
            }
        }
    }
    
    private func convertRequest(req: HttpRequest): AppHttpRequest {
        let appReq = AppHttpRequest()
        
        appReq.method = convertMethod(req.method)
        appReq.uri.path = req.url.path
        appReq.uri.query = req.url.query.getOrDefault({=>""})
        appReq.body = readRequestBody(req)
        
        // 转换headers
        for ((name, values) in req.headers) {
            // 取第一个值
            for (value in values) {
                let header = HttpHeader(name, value)
                appReq.headers.add(header)
                break  // 只取第一个值
            }
        }
        
        return appReq
    }
    
    private func convertMethod(method: String): HttpMethod {
        if (method == "GET") {
            return HttpMethod.GET
        } else if (method == "POST") {
            return HttpMethod.POST
        } else if (method == "PUT") {
            return HttpMethod.PUT
        } else if (method == "DELETE") {
            return HttpMethod.DELETE
        } else if (method == "PATCH") {
            return HttpMethod.PATCH
        } else {
            return HttpMethod.GET
        }
    }
    
    private func readRequestBody(req: HttpRequest): String {
        try {
            let bodySizeOpt = req.bodySize
            if (bodySizeOpt.isNone()) {
                return ""
            }
            
            let bodySize = bodySizeOpt.getOrThrow()
            let buffer = Array<UInt8>(bodySize, repeat: 0)
            req.body.read(buffer)
            return String.fromUtf8(buffer)
        } catch (ex: Exception) {
            return ""
        }
    }
    
    private func startWithServer(server: Server): Unit {
        try {
            logger.info("API server started successfully on http://${host}:${port}")
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
            logger.info("   ")
            logger.info("Calling server.serve()...")
            
            server.serve()
            
            logger.info("server.serve() returned (unexpected - server should block)")
        } catch (ex: Exception) {
            logger.error("Failed to start API server: ${ex.message}")
            ex.printStackTrace()
            throw ex
        }
    }
    
    private func handleErrorInStart(): Unit {
        logger.error("Failed to get server instance in start()")
        throw Exception("Failed to start API server: server not initialized")
    }
    
    public func stop() {
        running = false
        logger.info("HTTP Server stopping...")
        
        match (_server as Server) {
            case Some(server) => this.stopWithServer(server)
            case None => logger.error("No server instance to stop")
        }
    }
    
    private func stopWithServer(server: Server): Unit {
        try {
            server.close()
            logger.info("API server stopped successfully")
        } catch (ex: Exception) {
            logger.error("Failed to stop API server: ${ex.message}")
        }
    }
    
    private func handleHealth(context: HttpContext): Unit {
        let responseObj = JsonObject()
        responseObj.put("status", JsonString("ok"))
        responseObj.put("version", JsonString("4.0.0"))
        
        context.responseBuilder.status(200)
        context.responseBuilder.header("Content-Type", "application/json")
        context.responseBuilder.body(responseObj.toString())
    }
    
    private func handleInfo(context: HttpContext): Unit {
        let responseObj = JsonObject()
        responseObj.put("name", JsonString("uctoo-backend-v4"))
        responseObj.put("version", JsonString("4.0.0"))
        responseObj.put("language", JsonString("cangjie"))
        
        context.responseBuilder.status(200)
        context.responseBuilder.header("Content-Type", "application/json")
        context.responseBuilder.body(responseObj.toString())
    }
    
    private func handleHello(context: HttpContext): Unit {
        let responseObj = JsonObject()
        responseObj.put("message", JsonString("AgentSkills-runtime，Hello World"))
        
        context.responseBuilder.status(200)
        context.responseBuilder.header("Content-Type", "application/json")
        context.responseBuilder.body(responseObj.toString())
    }
}
