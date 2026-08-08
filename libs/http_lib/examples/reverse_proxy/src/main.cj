package sample_reverse_proxy

import std.collection.{HashMap, ArrayList}
import http_lib.core.*
import http_lib.message.*
import http_lib.client.{HttpClient, HttpRequestBuilder, HttpClientConfig}
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig, loggingMiddleware}

/**
 * 反向代理服务器示例。
 *
 * 将传入的 HTTP 请求转发到后端服务器，并将代理响应返回给客户端。
 * 支持：
 *   - 基于路径的路由到多个后端
 *   - 头部转发（X-Forwarded-For、X-Forwarded-Host、X-Forwarded-Proto）
 *   - 响应头部透传
 *   - 后端失败的错误处理
 *   - 请求日志
 *
 * 基于标准 HTTP 反向代理模式。
 */

// ---- 代理配置 ----

class ProxyRoute {
    public let path: String
    public let target: String

    public init(path: String, target: String) {
        this.path = path
        this.target = target
    }
}

// 配置代理路由：路径前缀 → 后端 URL
let proxyRoutes = ArrayList<ProxyRoute>()

func addRoute(path: String, target: String): Unit {
    proxyRoutes.add(ProxyRoute(path, target))
    println("[Proxy] Route: ${path} → ${target}")
}

/**
 * 为给定请求路径查找后端目标。
 */
func findBackend(path: String): ?String {
    for (route in proxyRoutes) {
        if (path.startsWith(route.path)) {
            return Some(route.target)
        }
    }
    None
}

/**
 * 通过替换路径前缀构建代理 URL。
 * 例如：/api/users → http://backend:3000/users
 */
func buildProxyUrl(path: String, backend: String, route: ProxyRoute): String {
    // 去除路由前缀并拼接到后端
    let remaining = if (path.size > route.path.size) {
        path[route.path.size..]
    } else {
        "/"
    }
    // 确保前导斜杠
    let normalizedRemaining = if (remaining.startsWith("/")) { remaining } else { "/${remaining}" }
    // 去除后端尾部斜杠
    let backendClean = if (backend.endsWith("/")) { backend[..backend.size - 1] } else { backend }
    "${backendClean}${normalizedRemaining}"
}

/**
 * 从请求头部提取客户端 IP。
 * 标准 X-Forwarded-For 头部客户端 IP 提取。
 */
func clientIp(req: HttpRequest): String {
    match (req.headers.get("x-forwarded-for")) {
        case Some(xff) =>
            match (xff.indexOf(",")) {
                case Some(idx) => String(xff.toRuneArray()[..idx])
                case None => xff
            }
        case None => "127.0.0.1"
    }
}

// ---- 代理处理器 ----

func proxyHandler(req: HttpRequest, client: HttpClient): HttpResponse {
    match (findBackend(req.path)) {
        case Some(backend) =>
            // 查找匹配的路由
            var matchedRoute: ?ProxyRoute = None
            for (route in proxyRoutes) {
                if (req.path.startsWith(route.path)) {
                    matchedRoute = Some(route)
                    break
                }
            }

            match (matchedRoute) {
                case Some(route) =>
                    let targetUrl = buildProxyUrl(req.path, backend, route)

                    println("[Proxy] ${req.method} ${req.path} → ${targetUrl}")

                    // 构建代理请求
                    let builder = HttpRequestBuilder()
                    match (req.method) {
                        case HttpMethod.GET => builder.get()
                        case HttpMethod.POST => builder.post()
                        case HttpMethod.PUT => builder.put()
                        case HttpMethod.DELETE => builder.delete()
                        case HttpMethod.PATCH => builder.patch()
                        case HttpMethod.HEAD => builder.head()
                        case HttpMethod.OPTIONS => builder.options()
                        case _ => builder.get()
                    }
                    builder.withUrl(targetUrl)

                    // 转发相关头部
                    let names = req.headers.names()
                    for (name in names) {
                        // 跳过逐跳头部
                        if (name == "connection" || name == "keep-alive" ||
                            name == "transfer-encoding" || name == "te" ||
                            name == "trailer" || name == "upgrade") {
                            continue
                        }
                        match (req.headers.get(name)) {
                            case Some(v) => builder.withHeader(name, v)
                            case None => ()
                        }
                    }

                    // 添加代理头部
                    let ip = clientIp(req)
                    builder.withHeader("X-Forwarded-For", ip)
                    builder.withHeader("X-Forwarded-Host", match (req.headers.get("host")) {
                        case Some(h) => h
                        case None => "localhost"
                    })
                    builder.withHeader("X-Forwarded-Proto", "http")

                    // 转发主体（如果存在）
                    if (req.body.getLimit() > 0) {
                        builder.withBody(req.bodyAsBytes())
                    }

                    let proxyReq = builder.build()

                    // 发送到后端
                    try {
                        let resp = client.send(proxyReq)
                        // 删除逐跳响应头部
                        resp.headers.remove("connection")
                        resp.headers.remove("keep-alive")
                        resp.headers.remove("transfer-encoding")
                        resp.headers.remove("trailer")
                        resp
                    } catch (e: Exception) {
                        println("[Proxy] Backend error: ${e.message}")
                        HttpResponse.text(HttpStatus.BAD_GATEWAY,
                            "Bad Gateway: ${e.message}")
                    }
                case None =>
                    HttpResponse.text(HttpStatus.BAD_GATEWAY, "No route matched")
            }
        case None =>
            HttpResponse.text(HttpStatus.NOT_FOUND, "No backend configured for this path")
    }
}

// ---- 状态页面 ----

func statusHandler(req: HttpRequest): HttpResponse {
    var json = "{\"proxy\":\"http_lib-reverse-proxy\",\"routes\":["
    var first = true
    for (route in proxyRoutes) {
        if (first) { first = false } else { json += "," }
        json += "{\"path\":\"${route.path}\",\"target\":\"${route.target}\"}"
    }
    json += "]}"
    HttpResponse.json(HttpStatus.OK, json)
}

func healthHandler(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")
}

// ---- 主程序 ----

main(): Int64 {
    // 配置代理路由
    addRoute("/api/", "http://127.0.0.1:8080")
    addRoute("/static/", "http://127.0.0.1:8081")
    addRoute("/files/", "http://127.0.0.1:8081")

    println("========================================")
    println("  Reverse Proxy Server")
    println("  Listening on: http://127.0.0.1:8888")
    println("")
    println("  Routes:")
    println("    /api/*    → http://127.0.0.1:8080")
    println("    /static/* → http://127.0.0.1:8081")
    println("    /files/*  → http://127.0.0.1:8081")
    println("")
    println("  Test with:")
    println("    curl http://127.0.0.1:8888/api/users")
    println("    curl http://127.0.0.1:8888/status")
    println("========================================")

    // 创建用于后端请求的共享 HTTP 客户端
    let clientConfig = HttpClientConfig()
    clientConfig.connectionPoolEnabled = true
    clientConfig.maxConnectionsPerHost = 10
    clientConfig.connectionIdleTimeout = Duration.second * 30
    clientConfig.followRedirects = false  // Don't follow backend redirects
    let httpClient = HttpClient(config: clientConfig)

    let router = Router()
        .get("/status", statusHandler)
        .get("/health", healthHandler)

    // 为代理路径连接代理处理器 — 在闭包中捕获 httpClient
    let proxyWrapper = { req: HttpRequest => proxyHandler(req, httpClient) }
    router.get("/api/*path",  proxyWrapper)
    router.post("/api/*path", proxyWrapper)
    router.put("/api/*path", proxyWrapper)
    router.delete("/api/*path", proxyWrapper)
    router.patch("/api/*path", proxyWrapper)
    router.get("/static/*path", proxyWrapper)
    router.get("/files/*path", proxyWrapper)

    let handler = router.handler()

    let serverConfig = HttpServerConfig()
    serverConfig.keepAlive = true
    serverConfig.readTimeout = Duration.second * 30
    serverConfig.writeTimeout = Duration.second * 60
    serverConfig.serverName = "http_lib-proxy/0.1"

    let server = HttpServer(handler: handler, config: serverConfig)
    server.listenAndServe("127.0.0.1", 8888)

    httpClient.close()
    0
}
