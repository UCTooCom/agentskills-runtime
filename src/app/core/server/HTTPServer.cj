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
import magic.config.Config
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import charset4cj.charset.{Charsets}
import std.core.Duration

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
    private let _requestTimeout: Duration  // 请求超时时间
    
    // 默认超时时间：120秒（2分钟）
    private static var DEFAULT_REQUEST_TIMEOUT: Duration = Duration.second * 120
    
    /**
     * 配置服务器超时时间
     */
    private static func configureTimeout(builder: ServerBuilder, timeout: Duration): Unit {
        // 设置读取超时时间
        builder.readTimeout(timeout)
        // 设置写入超时时间
        builder.writeTimeout(timeout)
    }
    
    public init(port: Int32, host: String) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = false
        this._requestTimeout = DEFAULT_REQUEST_TIMEOUT
        _distributor = DefaultHttpRequestDistributor()
        
        let builder = ServerBuilder()
        builder.addr(host)
        builder.port(UInt16(port))
        builder.distributor(_distributor)
        HTTPServer.configureTimeout(builder, _requestTimeout)
        _server = builder.build()
        
        logger.info("HTTP Server initialized on ${host}:${port} with timeout=${_requestTimeout.toSeconds()}s")
    }
    
    public init() {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = 8080
        this.host = "127.0.0.1"
        this.isHttps = false
        this._requestTimeout = DEFAULT_REQUEST_TIMEOUT
        _distributor = DefaultHttpRequestDistributor()
        
        let builder = ServerBuilder()
        builder.addr(host)
        builder.port(UInt16(port))
        builder.distributor(_distributor)
        HTTPServer.configureTimeout(builder, _requestTimeout)
        _server = builder.build()
        
        logger.info("HTTP Server initialized on ${host}:${port} with timeout=${_requestTimeout.toSeconds()}s")
    }
    
    /// HTTPS构造函数 - 使用证书文件路径
    public init(port: Int32, host: String, certPath: String, keyPath: String) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = true
        this._requestTimeout = DEFAULT_REQUEST_TIMEOUT
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
            HTTPServer.configureTimeout(builder, _requestTimeout)
            _server = builder.build()
            
            logger.info("HTTPS Server initialized on ${host}:${port} with timeout=${_requestTimeout.toSeconds()}s")
        } catch (e: Exception) {
            logger.error("Failed to initialize HTTPS server: ${e.message}")
            throw Exception("Failed to load SSL certificate: ${e.message}")
        }
    }
    
    /// 带超时配置的构造函数
    public init(port: Int32, host: String, requestTimeout: Duration) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = false
        this._requestTimeout = requestTimeout
        _distributor = DefaultHttpRequestDistributor()
        
        let builder = ServerBuilder()
        builder.addr(host)
        builder.port(UInt16(port))
        builder.distributor(_distributor)
        HTTPServer.configureTimeout(builder, _requestTimeout)
        _server = builder.build()
        
        logger.info("HTTP Server initialized on ${host}:${port} with timeout=${requestTimeout.toSeconds()}s")
    }
    
    /// HTTPS构造函数 - 使用证书文件路径和超时配置
    public init(port: Int32, host: String, certPath: String, keyPath: String, requestTimeout: Duration) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.http")
        this.port = port
        this.host = host
        this.isHttps = true
        this._requestTimeout = requestTimeout
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
            HTTPServer.configureTimeout(builder, _requestTimeout)
            _server = builder.build()
            
            logger.info("HTTPS Server initialized on ${host}:${port} with timeout=${requestTimeout.toSeconds()}s")
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
            let handler = createRouteHandler(route)
            _distributor.register(route.path, handler)
        }
        
        // 只注册未被 Router 覆盖的默认路由
        // /api/v1/health 和 /api/v1/info 已在 main.cj 中通过 router 注册
        _distributor.register("/hello", FuncHandler({ context => this.handleHello(context) }))
        
        logger.info("All routes registered successfully")
    }
    
    private func createRouteHandler(route: Route): HttpRequestHandler {
        let routePath = route.path
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
                    route.handler(appReq, appRes)
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
        
        // 解析查询参数
        let queryString = appReq.uri.query
        if (!queryString.isEmpty()) {
            let params = queryString.split("&")
            for (param in params) {
                let parts = param.split("=")
                if (parts.size == 2) {
                    let key = parts[0]
                    let value = parts[1]
                    appReq.queryParams[key] = value
                }
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
        } else if (method == "OPTIONS") {
            return HttpMethod.OPTIONS
        } else {
            return HttpMethod.GET
        }
    }
    
    private func readRequestBody(req: HttpRequest): String {
        try {
            let bodySizeOpt = req.bodySize
            let bodySize = if (bodySizeOpt.isNone()) {
                eprintln("=== readRequestBody: bodySize is None, will try to read anyway ===")
                0
            } else {
                let size = bodySizeOpt.getOrThrow()
                eprintln("=== readRequestBody: bodySize=${size} ===")
                size
            }
            
            let maxBodySize = 10 * 1024 * 1024
            if (bodySize > maxBodySize) {
                logger.warn("Too large body size: ${bodySize}, ignoring body")
                return ""
            }
            
            // 尝试从请求体读取所有字节
            let buf = ByteBuffer()
            let copied = copy(req.body, to: buf)
            eprintln("=== readRequestBody: copy returned ${copied} bytes ===")
            
            if (copied == 0) {
                logger.warn("Empty body read, bodySize was: ${bodySize}")
                return ""
            }
            
            // 读取 ByteBuffer 中的所有字节
            buf.seek(Begin(0))
            let bodyBytes = readToEnd(buf)
            eprintln("=== readRequestBody: got ${bodyBytes.size} bytes ===")
            
            if (bodyBytes.isEmpty()) {
                logger.warn("Empty body byte array despite ${copied} bytes copied")
                return ""
            }
            
            // 使用字节数组转换为字符串
            let decoded = tryDecodeBody(bodyBytes)
            if (!decoded.isEmpty()) {
                let previewLength = if (decoded.size > 200) { 200 } else { decoded.size }
                eprintln("=== readRequestBody: decoded body (${decoded.size} chars): [${decoded[0..previewLength]}] ===")
                return decoded
            }
            
            return ""
        } catch (ex: Exception) {
            logger.error("Error reading request body: ${ex.message}")
            eprintln("=== readRequestBody exception: ${ex.message} ===")
            ex.printStackTrace()
            return ""
        }
    }
    
    // 安全地尝试解码请求体字节数组
    private func tryDecodeBody(bytes: Array<Byte>): String {
        // 方法1：使用 charset4cj 的健壮解码器
        try {
            let decoder = Charsets.forName("UTF-8").getOrThrow()
            return decoder.newDecoder().decode(bytes)
        } catch (ex1: Exception) {
            eprintln("=== tryDecodeBody: charset4cj decode failed: ${ex1.message} ===")
        }
        
        // 方法2：尝试检测并跳过 BOM
        if (bytes.size >= 3 && 
            (Int64(bytes[0]) & 0xFF) == 0xEF && 
            (Int64(bytes[1]) & 0xFF) == 0xBB && 
            (Int64(bytes[2]) & 0xFF) == 0xBF) {
            try {
                let withoutBom = bytes[3..bytes.size]
                let decoder = Charsets.forName("UTF-8").getOrThrow()
                return decoder.newDecoder().decode(withoutBom)
            } catch (ex2: Exception) {
                eprintln("=== tryDecodeBody: BOM removal + decode failed: ${ex2.message} ===")
            }
        }
        
        // 方法3：标准库宽松解码（替换无效字符）
        return lossyDecode(bytes)
    }
    
    // 宽松解码：将无效 UTF-8 字节替换为替换字符
    private func lossyDecode(bytes: Array<Byte>): String {
        var result = StringBuilder()
        var i = 0
        while (i < bytes.size) {
            let b = Int64(bytes[i]) & 0xFF
            if (b < 0x80) {
                // ASCII 字符
                result.append(Rune(b))
                i += 1
            } else if (b >= 0xC0 && b < 0xE0) {
                // 2 字节 UTF-8 序列的首字节
                if (i + 1 < bytes.size && (Int64(bytes[i + 1]) & 0xFF) >= 0x80 && (Int64(bytes[i + 1]) & 0xFF) < 0xC0) {
                    result.append('\u{FFFD}')  // 替换字符
                    i += 2
                } else {
                    result.append('\u{FFFD}')
                    i += 1
                }
            } else if (b >= 0xE0 && b < 0xF0) {
                // 3 字节 UTF-8 序列的首字节
                if (i + 2 < bytes.size) {
                    result.append('\u{FFFD}')
                    i += 3
                } else {
                    result.append('\u{FFFD}')
                    i += 1
                }
            } else if (b >= 0xF0 && b < 0xF8) {
                // 4 字节 UTF-8 序列的首字节
                if (i + 3 < bytes.size) {
                    result.append('\u{FFFD}')
                    i += 4
                } else {
                    result.append('\u{FFFD}')
                    i += 1
                }
            } else {
                // 无效字节
                result.append('\u{FFFD}')
                i += 1
            }
        }
        return result.toString()
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
        responseObj.put("message", JsonString("AgentSkills-runtime,Hello World"))
        
        context.responseBuilder.status(200)
        context.responseBuilder.header("Content-Type", "application/json")
        context.responseBuilder.body(responseObj.toString())
    }
}
