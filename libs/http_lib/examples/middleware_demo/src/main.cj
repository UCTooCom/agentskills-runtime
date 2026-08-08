package sample_middleware_demo

import std.collection.HashMap
import std.time.DateTime
import http_lib.core.*
import http_lib.message.*
import http_lib.router.{Router, Handler, Middleware, MiddlewareChain}
import http_lib.server.{HttpServer, HttpServerConfig, loggingMiddleware, securityHeadersMiddleware, hstsMiddleware, RateLimiter, extractClientIp}

/**
 * 中间件链演示服务器，展示如何按正确顺序组合和
 * 应用多个中间件层。
 *
 * 中间件顺序（最外层优先）：
 *   1. 安全头部 —— X-Content-Type-Options、X-Frame-Options 等
 * 2. HSTS               —— Strict-Transport-Security
 * 3. Rate Limiting      — 每 IP 请求限制
 * 4. Request ID         — X-Request-ID 生成
 * 5. Access Logging     — 方法、路径、状态、持续时间
 * 6. Handler            — 业务逻辑
 */

// ---- 自定义中间件示例 ----

/**
 * 请求 ID 中间件：生成唯一的 X-Request-ID 用于追踪。
 */
func requestIdMiddleware(): Middleware {
    {handler: Handler =>
        {req: HttpRequest =>
            match (req.headers.get("x-request-id")) {
                case Some(_) => ()  // Client provided one
                case None =>
                    // 生成简单的请求 ID
                    let idBytes = Array<UInt8>(16, repeat: 0)
                    var i: Int64 = 0
                    while (i < 16) {
                        let nano = DateTime.now().nanosecond
                        idBytes[i] = UInt8((nano >> (i * 2)) & 0xff)
                        i += 1
                    }
                    req.headers.set("X-Request-ID", "req-${DateTime.now().second}")
            }
            let resp = handler(req)
            // 在响应中回显请求 ID
            match (req.headers.get("x-request-id")) {
                case Some(rid) => resp.headers.set("X-Request-ID", rid)
                case None => ()
            }
            resp
        }
    }
}

/**
 * 响应计时中间件：添加 X-Response-Time 头部。
 */
func timingMiddleware(): Middleware {
    {handler: Handler =>
        {req: HttpRequest =>
            let start = DateTime.now()
            let resp = handler(req)
            let endT = DateTime.now()
            let ms = (endT.nanosecond - start.nanosecond) / 1000000 + (endT.second - start.second) * 1000
            resp.headers.set("X-Response-Time", "${ms}ms")
            resp
        }
    }
}

/**
 * 恢复中间件：捕获恐慌并返回 500。
 */
func recoveryMiddleware(): Middleware {
    {handler: Handler =>
        {req: HttpRequest =>
            try {
                handler(req)
            } catch (e: Exception) {
                HttpResponse.json(HttpStatus.INTERNAL_SERVER_ERROR,
                    "{\"error\":\"Internal Server Error\",\"message\":\"${e.message}\"}")
            }
        }
    }
}

// ---- 处理器 ----

func indexHandler(req: HttpRequest): HttpResponse {
    let html = "<!DOCTYPE html><html><head><title>Middleware Demo</title><style>body{font-family:monospace;max-width:800px;margin:50px auto;padding:20px}h1{color:#333}.middleware{background:#f5f5f5;padding:10px;margin:5px 0;border-left:4px solid #007bff}</style></head><body><h1>🧱 Middleware Chain Demo</h1><p>Check response headers to see middleware in action:</p><div class='middleware'>1. Security Headers (X-Content-Type-Options, X-Frame-Options)</div><div class='middleware'>2. HSTS (Strict-Transport-Security)</div><div class='middleware'>3. Rate Limiting (100 req/min per IP)</div><div class='middleware'>4. Request ID (X-Request-ID)</div><div class='middleware'>5. Response Timing (X-Response-Time)</div><div class='middleware'>6. Access Logging (request log)</div><div class='middleware'>7. Recovery (error handling)</div></body></html>"
    HttpResponse.html(HttpStatus.OK, html)
}

func apiHandler(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK,
        "{\"message\":\"Hello from the API!\",\"path\":\"${req.url}\",\"method\":\"${req.method}\"}")
}

func slowHandler(req: HttpRequest): HttpResponse {
    // 模拟慢响应
    let start = DateTime.now()
    while (DateTime.now() - start < Duration.millisecond * 500) { }  // busy-wait 500ms
    HttpResponse.json(HttpStatus.OK, "{\"message\":\"Slow response complete\"}")
}

func errorHandler(req: HttpRequest): HttpResponse {
    throw HttpException("This is a deliberate error for testing recovery middleware!")
}

// ---- 主程序 ----

main(): Int64 {
    let router = Router()
        .get("/", indexHandler)
        .get("/api", apiHandler)
        .get("/slow", slowHandler)
        .get("/error", errorHandler)

    let routeHandler: Handler = router.handler()

    // 手动构建中间件链（从最外层到最内层）
    var handler = routeHandler
    handler = loggingMiddleware()(handler)        // 6. Logging
    handler = timingMiddleware()(handler)          // 5. Response timing
    handler = requestIdMiddleware()(handler)       // 4. Request ID
    handler = RateLimiter(maxRequests: 100).middleware()(handler)  // 3. Rate limit
    handler = hstsMiddleware(maxAge: 31536000)(handler)  // 2. HSTS
    handler = securityHeadersMiddleware()(handler)  // 1. Security headers
    handler = recoveryMiddleware()(handler)        // 0. Recovery (outermost!)

    let serverConfig = HttpServerConfig()
    serverConfig.keepAlive = true
    serverConfig.serverName = "http_lib-middleware-demo/0.1"

    let server = HttpServer(handler: handler, config: serverConfig)

    println("========================================")
    println("  Middleware Chain Demo Server")
    println("  Listening on: http://127.0.0.1:8082")
    println("")
    println("  Endpoints:")
    println("    GET /         HTML info page")
    println("    GET /api      JSON API response")
    println("    GET /slow     Simulated slow (500ms)")
    println("    GET /error    Trigger error for recovery test")
    println("")
    println("  Check response headers:")
    println("    curl -v http://127.0.0.1:8082/")
    println("========================================")

    server.listenAndServe("127.0.0.1", 8082)
    0
}
