package sample_rest_api

import std.collection.{HashMap, ArrayList}
import http_lib.core.*
import http_lib.message.*
import http_lib.router.{Router, Handler, corsMiddleware, CorsConfig}
import http_lib.server.{HttpServer, HttpServerConfig, loggingMiddleware, securityHeadersMiddleware, hstsMiddleware, RateLimiter}

/**
 * 全功能 REST API 服务器，演示：
 *   - 带路径参数的基数树路由
 *   - CORS 中间件
 *   - 安全头部（HSTS、CSP、X-Frame-Options）
 *   - 速率限制
 *   - 访问日志
 *   - JSON 请求/响应处理
 *   - URL 编码表单处理
 * - 带有适当状态码的错误处理
 */

// ---- 内存数据存储 ----
class User {
    public var id: Int64
    public var name: String
    public var email: String

    public init(id: Int64, name: String, email: String) {
        this.id = id
        this.name = name
        this.email = email
    }
}

var users = ArrayList<User>()
var nextId: Int64 = 1

// ---- JSON 辅助函数 ----
func jsonError(status: HttpStatus, message: String): HttpResponse {
    HttpResponse.json(status, "{\"error\":\"${message}\"}")
}

func jsonUser(user: User): String {
    "{\"id\":${user.id},\"name\":\"${user.name}\",\"email\":\"${user.email}\"}"
}

func jsonUsersList(userList: ArrayList<User>): String {
    var json = "["
    var first = true
    for (user in userList) {
        if (first) { first = false } else { json += "," }
        json += jsonUser(user)
    }
    json += "]"
    json
}

// ---- 处理器 ----

func listUsers(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK, jsonUsersList(users))
}

func getUser(req: HttpRequest): HttpResponse {
    match (req.headers.get("X-Path-Params")) {
        case Some(params) =>
            // 从路径中提取 :id（简化版 — 生产环境请使用路由参数）
            let idStr = match (req.url.split("/").get(2)) {
                case Some(s) => s
                case None =>
                    return jsonError(HttpStatus.BAD_REQUEST, "Missing user ID")
            }
            let bytes = idStr.toArray()
            var id: Int64 = 0
            for (b in bytes) {
                if (b >= b'0' && b <= b'9') {
                    id = id * 10 + Int64(b - b'0')
                }
            }
            for (user in users) {
                if (user.id == id) {
                    return HttpResponse.json(HttpStatus.OK, jsonUser(user))
                }
            }
            jsonError(HttpStatus.NOT_FOUND, "User not found")
        case None =>
            jsonError(HttpStatus.BAD_REQUEST, "Missing path params")
    }
}

func createUser(req: HttpRequest): HttpResponse {
    let body = req.bodyAsString()
    // 简单 JSON 解析：提取名称和邮箱
    var name = ""
    var email = ""

    match (body.indexOf("\"name\"")) {
        case Some(idx) =>
            let startIdx = body.indexOf(":", idx + 6)
            match (startIdx) {
                case Some(si) =>
                    let quoteStart = body.indexOf("\"", si + 1)
                    match (quoteStart) {
                        case Some(qs) =>
                            let quoteEnd = body.indexOf("\"", qs + 1)
                            match (quoteEnd) {
                                case Some(qe) =>
                                    if (qe > qs + 1) {
                                        name = body[qs + 1..qe]
                                    }
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }

    match (body.indexOf("\"email\"")) {
        case Some(idx) =>
            let startIdx = body.indexOf(":", idx + 7)
            match (startIdx) {
                case Some(si) =>
                    let quoteStart = body.indexOf("\"", si + 1)
                    match (quoteStart) {
                        case Some(qs) =>
                            let quoteEnd = body.indexOf("\"", qs + 1)
                            match (quoteEnd) {
                                case Some(qe) =>
                                    if (qe > qs + 1) {
                                        email = body[qs + 1..qe]
                                    }
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }

    if (name.size == 0) {
        return jsonError(HttpStatus.BAD_REQUEST, "Name is required")
    }

    let user = User(nextId, name, email)
    users.add(user)
    nextId += 1

    HttpResponse.json(HttpStatus.CREATED, jsonUser(user))
}

func updateUser(req: HttpRequest): HttpResponse {
    // 从 URL 解析 ID
    let parts = req.url.split("/")
    if (parts.size < 3) {
        return jsonError(HttpStatus.BAD_REQUEST, "Missing user ID")
    }
    let idStr = parts[2]
    let bytes = idStr.toArray()
    var id: Int64 = 0
    for (b in bytes) {
        if (b >= b'0' && b <= b'9') {
            id = id * 10 + Int64(b - b'0')
        }
    }

    let body = req.bodyAsString()
    var found = false
    var index: Int64 = 0
    while (index < users.size) {
        if (users[index].id == id) {
            found = true
            // 更新字段（如果存在）
            match (body.indexOf("\"name\"")) {
                case Some(_) =>
                    match (extractJsonString(body, "name")) {
                        case Some(n) => users[index].name = n
                        case None => ()
                    }
                case None => ()
            }
            match (body.indexOf("\"email\"")) {
                case Some(_) =>
                    match (extractJsonString(body, "email")) {
                        case Some(e) => users[index].email = e
                        case None => ()
                    }
                case None => ()
            }
            return HttpResponse.json(HttpStatus.OK, jsonUser(users[index]))
        }
        index += 1
    }

    if (!found) {
        jsonError(HttpStatus.NOT_FOUND, "User not found")
    } else {
        HttpResponse.json(HttpStatus.OK, "{}")
    }
}

func deleteUser(req: HttpRequest): HttpResponse {
    let parts = req.url.split("/")
    if (parts.size < 3) {
        return jsonError(HttpStatus.BAD_REQUEST, "Missing user ID")
    }
    let idStr = parts[2]
    let bytes = idStr.toArray()
    var id: Int64 = 0
    for (b in bytes) {
        if (b >= b'0' && b <= b'9') {
            id = id * 10 + Int64(b - b'0')
        }
    }

    var index: Int64 = 0
    while (index < users.size) {
        if (users[index].id == id) {
            users.remove(index..index + 1)
            return HttpResponse.empty(HttpStatus.NO_CONTENT)
        }
        index += 1
    }
    jsonError(HttpStatus.NOT_FOUND, "User not found")
}

func healthCheck(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\",\"uptime\":\"running\"}")
}

func handleForm(req: HttpRequest): HttpResponse {
    let form = parseFormBody(req)
    HttpResponse.json(HttpStatus.OK, "{\"received\":true,\"fields\":${form.size}}")
}

// ---- 辅助函数 ----

func extractJsonString(json: String, key: String): ?String {
    let searchKey = "\"${key}\""
    match (json.indexOf(searchKey)) {
        case Some(idx) =>
            let startIdx = json.indexOf(":", idx + searchKey.size)
            match (startIdx) {
                case Some(si) =>
                    let quoteStart = json.indexOf("\"", si + 1)
                    match (quoteStart) {
                        case Some(qs) =>
                            let quoteEnd = json.indexOf("\"", qs + 1)
                            match (quoteEnd) {
                                case Some(qe) =>
                                    if (qe > qs + 1) {
                                        return Some(json[qs + 1..qe])
                                    }
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }
    None
}

// ---- 主程序 ----

main(): Int64 {
    // 用一些数据初始化
    users.add(User(1, "Alice", "alice@example.com"))
    users.add(User(2, "Bob", "bob@example.com"))
    users.add(User(3, "Charlie", "charlie@example.com"))
    nextId = 4

    // 构建包含完整 REST 端点的路由器
    let router = Router()
        .get("/", healthCheck)
        .get("/api/users", listUsers)
        .get("/api/users/:id", getUser)
        .post("/api/users", createUser)
        .put("/api/users/:id", updateUser)
        .delete("/api/users/:id", deleteUser)
        .post("/api/form", handleForm)

    // CORS 配置
    let cors = CorsConfig()
    cors.allowOrigins = ["*"]
    cors.allowMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    cors.allowHeaders = ["Content-Type", "Authorization"]

    // 速率限制器：每个 IP 每分钟 100 个请求
    let limiter = RateLimiter(window: Duration.minute, maxRequests: 100)

    // 构建中间件链
    let routeHandler: Handler = router.handler()

    // 应用中间件：security → HSTS → CORS → logging → rate limit → handler
    var handler = routeHandler
    handler = limiter.middleware()(handler)
    handler = loggingMiddleware()(handler)
    handler = corsMiddleware(cors)(handler)
    handler = hstsMiddleware(maxAge: 31536000, includeSubDomains: true)(handler)
    handler = securityHeadersMiddleware()(handler)

    // 服务器配置
    let serverConfig = HttpServerConfig()
    serverConfig.keepAlive = true
    serverConfig.readTimeout = Duration.second * 30
    serverConfig.writeTimeout = Duration.second * 30
    serverConfig.autoCompress = true
    serverConfig.serverName = "http_lib-rest-api/0.1"

    let server = HttpServer(handler: handler, config: serverConfig)

    println("========================================")
    println("  REST API Server")
    println("  Listening on: http://127.0.0.1:8080")
    println("")
    println("  Endpoints:")
    println("    GET    /api/users          List all users")
    println("    GET    /api/users/:id      Get a user")
    println("    POST   /api/users          Create a user")
    println("    PUT    /api/users/:id      Update a user")
    println("    DELETE /api/users/:id      Delete a user")
    println("    POST   /api/form           Submit a form")
    println("")
    println("  Middleware: HSTS + CSP + CORS + Logging + Rate Limiting")
    println("========================================")

    server.listenAndServe("127.0.0.1", 8080)
    0
}
