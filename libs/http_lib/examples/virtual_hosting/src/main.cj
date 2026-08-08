/**
 * 虚拟主机服务器示例
 *
 * 演示基于主机的路由：不同主机提供不同内容。
 * 例如：api.example.com 与 admin.example.com 与 default。
 *
 * 用法：cjpm build && ./target/release/bin/main
 * 然后测试：
 *   curl -H "Host: api.localhost" http://localhost:8080/
 *   curl -H "Host: admin.localhost" http://localhost:8080/
 *   curl http://localhost:8080/
 */
package sample_virtual_hosting

import http_lib.core.*
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.{Router, Handler, Middleware}
import http_lib.server.{HttpServer, HttpServerConfig}

main(): Int64 {
    // 不匹配主机的默认处理器
    let defaultRouter = Router()
    defaultRouter.get("/", {_ => HttpResponse.html(HttpStatus.OK,
        "<h1>Default Site</h1><p>No virtual host matched.</p>")})

    // API 主机
    let apiRouter = Router()
    apiRouter.get("/", {_ => HttpResponse.json(HttpStatus.OK,
        "{\"service\":\"API\",\"version\":\"1.0\"}")})
    apiRouter.get("/users", {_ => HttpResponse.json(HttpStatus.OK,
        "{\"users\":[{\"id\":1,\"name\":\"Alice\"}]}")})

    // 管理主机
    let adminRouter = Router()
    adminRouter.get("/", {_ => HttpResponse.html(HttpStatus.OK,
        "<h1>Admin Panel</h1><p>Welcome, administrator.</p>")})
    adminRouter.get("/status", {_ => HttpResponse.json(HttpStatus.OK,
        "{\"status\":\"healthy\",\"uptime\":3600}")})

    // 基于主机的路由处理器
    let hostHandler: Handler = {req =>
        let host = match (req.headers.get("host")) {
            case Some(h) => h
            case None => ""
        }
        if (host.startsWith("api.")) {
            match (apiRouter.find(req.method, req.path).handler) {
                case Some(h) => h(req)
                case None => HttpResponse.text(HttpStatus.NOT_FOUND, "API endpoint not found")
            }
        } else if (host.startsWith("admin.")) {
            match (adminRouter.find(req.method, req.path).handler) {
                case Some(h) => h(req)
                case None => HttpResponse.text(HttpStatus.NOT_FOUND, "Admin page not found")
            }
        } else {
            match (defaultRouter.find(req.method, req.path).handler) {
                case Some(h) => h(req)
                case None => HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
            }
        }
    }

    let config = HttpServerConfig()
    config.serverName = "VirtualHostingDemo/1.0"
    let server = HttpServer(handler: hostHandler, config: config)

    println("=== Virtual Hosting Server ===")
    println("Listening on http://localhost:8080")
    println("Try:")
    println("  curl http://localhost:8080/")
    println("  curl -H 'Host: api.localhost' http://localhost:8080/users")
    println("  curl -H 'Host: admin.localhost' http://localhost:8080/status")

    server.listenAndServe("0.0.0.0", 8080)
    0
}
