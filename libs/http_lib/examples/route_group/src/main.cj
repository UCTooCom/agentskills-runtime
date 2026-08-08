/**
 * 路由组中间件示例
 *
 * 演示使用作用域中间件分组路由。
 * 全局中间件（日志记录器）+ 组中间件（/api/ 路由的认证）。
 *
 * 用法：cjpm build && ./target/release/bin/main
 */
package sample_route_group

import http_lib.core.*
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.{Router, Handler, Middleware, MiddlewareChain}
import http_lib.server.{HttpServer, HttpServerConfig}

main(): Int64 {
    let router = Router()

    // ---- 中间件定义 ----
    let loggingMiddleware: Middleware = {next: Handler =>
        {req: HttpRequest =>
            let start = currentHttpDate()
            let resp = next(req)
            println("[${start}] ${req.method} ${req.path} -> ${resp.status.code}")
            resp
        }
    }

    let authMiddleware: Middleware = {next: Handler =>
        {req: HttpRequest =>
            match (req.headers.get("authorization")) {
                case Some(auth) =>
                    if (auth.startsWith("Bearer ")) {
                        // 令牌验证（简化版）
                        println("  auth: valid token")
                        next(req)
                    } else {
                        HttpResponse.text(HttpStatus.UNAUTHORIZED, "Invalid auth scheme")
                    }
                case None =>
                    HttpResponse.text(HttpStatus.UNAUTHORIZED, "Authorization required")
            }
        }
    }

    // 压缩中间件 — 对大响应自动 gzip
    let compressMiddleware: Middleware = {next: Handler =>
        {req: HttpRequest =>
            let resp = next(req)
            // 服务器自动压缩通过 HttpServerConfig 处理此功能
            resp
        }
    }

    // ---- 全局中间件（应用于所有路由） ----
    router.use(loggingMiddleware)

    // ---- 公开路由（无需认证） ----
    router.get("/", {_ => HttpResponse.text(HttpStatus.OK, "Welcome! Visit /api/ for protected routes.")})
    router.get("/health", {_ => HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")})

    // ---- API 分组（需要认证） ----
    // 仅对 /api/ 路由应用认证中间件
    let apiMiddleware = MiddlewareChain().use(authMiddleware).use(compressMiddleware)
    let apiHandler = apiMiddleware.apply({req: HttpRequest =>
        match (req.path) {
            case "/api/users" => HttpResponse.json(HttpStatus.OK, "[{\"id\":1,\"name\":\"Alice\"}]")
            case "/api/me" => HttpResponse.json(HttpStatus.OK, "{\"user\":\"admin\"}")
            case _ => HttpResponse.text(HttpStatus.NOT_FOUND, "API endpoint not found")
        }
    })

    // 使用包装后的处理器注册 /api/* 路由
    router.get("/api/users", apiHandler)
    router.get("/api/me", apiHandler)
    // 用于处理未知 API 路径的 /api/* 通用兜底
    // 在实际应用中，为 API 分组使用独立的路由器

    let config = HttpServerConfig()
    config.serverName = "RouteGroupDemo/1.0"
    let server = HttpServer(handler: router.handler(), config: config)

    println("=== Route Group Middleware Demo ===")
    println("Listening on http://localhost:8080")
    println("  Public: GET /     -> welcome page")
    println("  Public: GET /health -> health check")
    println("  Auth:   GET /api/users -> needs Bearer token")
    println("  Auth:   GET /api/me -> needs Bearer token")
    println("Try: curl http://localhost:8080/api/me")
    println("     curl -H 'Authorization: Bearer test123' http://localhost:8080/api/me")

    server.listenAndServe("0.0.0.0", 8080)
    0
}
