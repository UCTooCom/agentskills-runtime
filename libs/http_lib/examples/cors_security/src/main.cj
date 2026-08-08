package sample_cors_security

import http_lib.core.{HttpMethod, HttpStatus, HttpHeaders}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.server.{securityHeadersMiddleware, hstsMiddleware, cspMiddleware}
import http_lib.router.{Router, corsMiddleware, CorsConfig}

/**
 * CORS + 安全中间件示例。
 *
 * 演示如何为 HTTP 服务配置安全响应头、HSTS、CORS 和 CSP。
 */
main() {
    let router = Router()

    // === 安全中间件 ===
    router.use(securityHeadersMiddleware())
    router.use(hstsMiddleware(maxAge: 31536000, includeSubDomains: true))

    // 为 /api 路由启用 CSP
    let api = router.group("/api")
    api.use(cspMiddleware("default-src 'self'"))

    // === CORS 中间件 ===
    let corsConfig = CorsConfig()

    api.use(corsMiddleware(corsConfig))
    api.get("/public", {req: HttpRequest =>
        HttpResponse.text(HttpStatus.OK, "{\"message\": \"CORS-enabled public API\"}")
    })

    // === 公开路由 ===
    router.get("/", {req: HttpRequest =>
        HttpResponse.text(HttpStatus.OK, "CORS + Security Demo Server")
    })
    router.get("/health", {req: HttpRequest => HttpResponse.text(HttpStatus.OK, "OK")})

    let config = HttpServerConfig()
    config.serverName = "cors_security_demo"
    let server = HttpServer(handler: router.handler(), config: config)
    println("CORS + Security server listening on :8080")
    server.listenAndServe("0.0.0.0", 8080)
}
