# Server 使用指南

## 快速开始

### 最小化 HTTP Server

```cangjie
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.router.Router
import http_lib.core.{HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

main() {
    let router = Router()
    router.get("/", { req => HttpResponse.text(HttpStatus.OK, "Hello") })
    router.get("/api/health", { req => HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}") })

    let server = HttpServer(handler: router.handler())
    server.listenAndServe("0.0.0.0", 8080)
}
```

### 带配置的 Server

```cangjie
import http_lib.server.{HttpServer, HttpServerConfig}
import std.time.Duration

main() {
    let config = HttpServerConfig()
    config.readTimeout = Duration.second * 30
    config.writeTimeout = Duration.second * 30
    config.maxHeaderSize = 65536
    config.maxBodySize = 10485760  // 10MB
    config.keepAlive = true
    config.serverName = "http_lib/0.1.0"
    config.enableHttp2 = true
    config.autoDateHeader = true
    config.autoServerHeader = true
    config.autoCompress = true

    let router = Router()
    router.get("/", handler)
    let server = HttpServer(handler: router.handler(), config: config)
    server.listenAndServe("0.0.0.0", 8080)
}
```

## 路由

### 静态路由

```cangjie
router.get("/", homeHandler)
router.post("/users", createUser)
router.put("/users/42", updateUser)
router.delete("/users/42", deleteUser)
router.patch("/users/42", patchUser)
router.head("/files/data", headHandler)
router.options("/api", optionsHandler)
```

### 路径参数

```cangjie
router.get("/users/:id", { req =>
    let result = router.find(HttpMethod.GET, req.url)
    match (result.params.get("id")) {
        case Some(id) => HttpResponse.text(HttpStatus.OK, "User: ${id}")
        case None => HttpResponse.text(HttpStatus.BAD_REQUEST, "Missing id")
    }
})
```

### Catch-All 路由

```cangjie
router.get("/files/{path}", { req =>
    let result = router.find(HttpMethod.GET, req.url)
    match (result.params.get("path")) {
        case Some(p) => serveFile(p)
        case None => HttpResponse.empty(HttpStatus.NOT_FOUND)
    }
})
```

### 查看匹配结果

```cangjie
let result = router.find(HttpMethod.GET, "/users/42")
result.handler.isSome()      // true
result.params.get("id")      // Some("42")
```

## 路由处理器 (Router Handler)

路由器的 `handler()` 方法返回一个经过完全配置的处理函数，自动包裹中间件、处理尾部斜杠重定向、注入路径参数并返回自动错误响应：

```cangjie
let server = HttpServer(handler: router.handler())
```

`router.handler()` 自动完成以下工作：
- 应用所有已注册的中间件（日志、认证、CORS、速率限制等）
- 处理尾部斜杠重定向，保持 URL 整洁
- 将路径参数注入到请求中
- 当路由存在但方法不匹配时，返回 **405 Method Not Allowed** 并附带正确的 `Allow` 响应头
- 对未匹配的路由返回 **404 Not Found**

## 中间件

### 全局中间件

```cangjie
import http_lib.router.{MiddlewareChain, Middleware}

let chain = MiddlewareChain()

// 日志中间件
chain.use({ next =>
    { req =>
        let start = DateTime.now()
        let resp = next(req)
        println("${req.method} ${req.url} -> ${resp.status.code} (${...}μs)")
        resp
    }
})

// 认证中间件
chain.use({ next =>
    { req =>
        match (req.headers.get("authorization")) {
            case Some(_) => next(req)
            case None => HttpResponse.text(HttpStatus.UNAUTHORIZED, "Unauthorized")
        }
    }
})

let finalHandler = chain.apply(routerHandler)
```

### CORS 中间件

```cangjie
import http_lib.router.{corsMiddleware, CorsConfig}

let corsConfig = CorsConfig()
corsConfig.allowOrigins = ["https://example.com"]
corsConfig.allowMethods = ["GET", "POST", "PUT"]
corsConfig.allowHeaders = ["Content-Type", "Authorization"]
corsConfig.allowCredentials = true
corsConfig.maxAge = 86400

let middleware = corsMiddleware(corsConfig)
```

预检请求验证：
- **`Access-Control-Request-Method`** 会与 `allowMethods` 进行校验，不匹配时返回 **403**
- **`Access-Control-Request-Headers`** 会与 `allowHeaders` 进行校验，不匹配时返回 **403**
- **缺少 `Access-Control-Request-Method` 头** 返回 **400 Bad Request**
- **通配符与凭据**：当 `allowOrigins = ["*"]` 且 `allowCredentials = true` 时，会回显具体的请求来源而非返回 `*`
- **`Vary: Origin`** 响应头在回显特定来源时自动添加
- **来源比较不区分大小写**，遵循 URL 规范

### 安全中间件

```cangjie
import http_lib.server.{securityHeadersMiddleware, hstsMiddleware, cspMiddleware, loggingMiddleware}

chain.use(securityHeadersMiddleware())
chain.use(hstsMiddleware(maxAge: 31536000, includeSubDomains: true))
chain.use(cspMiddleware("default-src 'self'"))
chain.use(loggingMiddleware())
```

## 请求处理

### 读取请求数据

```cangjie
router.post("/api/submit", { req =>
    // 读取 body
    let body = req.bodyAsString()

    // 读取查询参数
    let params = req.queryParams()
    let page = match (params["page"]) {
        case Some(p) => p
        case None => "1"
    }

    // 读取特定 header
    let contentType = req.contentType()
    let userAgent = req.userAgent()
    let referer = req.referer()

    // 读取 Cookie
    let sessionId = req.cookie("session_id")

    // 读取客户端 IP
    let ip = req.clientIp()

    // 读取 Basic Auth
    let username = req.basicAuth()

    // 内容协商
    if (req.accepts("application/json")) {
        HttpResponse.json(HttpStatus.OK, generateJson())
    } else {
        HttpResponse.html(HttpStatus.OK, generateHtml())
    }
})
```

### 解析 Body

```cangjie
import http_lib.message.{parseFormBody, parseJsonBody, parseMultipartBody}

// URL-encoded form
let form = parseFormBody(req)

// JSON
let json = parseJsonBody(req)

// Multipart (file upload)
let fields = parseMultipartBody(req)
match (fields["file"]) {
    case Some(fileField) =>
        // fileField.fileName, fileField.data, fileField.asString()
    case None => ()
}
```

## 响应构建

### 常用响应类型

```cangjie
// JSON
HttpResponse.json(HttpStatus.OK, "{\"result\":\"ok\"}")

// 纯文本
HttpResponse.text(HttpStatus.OK, "Hello, World!")

// HTML
HttpResponse.html(HttpStatus.OK, "<h1>Hello</h1>")

// 空响应
HttpResponse.empty(HttpStatus.NO_CONTENT)

// 二进制
HttpResponse.bytes(HttpStatus.OK, "image/png", imageBytes)

// 重定向
HttpResponse.redirect("https://example.com/new-location")
HttpResponse.redirect("https://example.com", status: HttpStatus.MOVED_PERMANENTLY)
```

### 设置 Cookie

```cangjie
let resp = HttpResponse.text(HttpStatus.OK, "Logged in")
    .withCookie("session", token,
        path: "/",
        maxAge: 3600,
        httpOnly: true,
        secure: true,
        sameSite: "Lax")
```

## 流式响应 (message 模块)

使用 `http_lib.message.ResponseBuilder` 实现基于连接的分块流式输出，
适用于大文件或实时数据推送。

```cangjie
import http_lib.message.{ResponseBuilder, StreamingHandler, wrapHandler}

let streamingHandler: StreamingHandler = { req, w =>
    w.setStatus(HttpStatus.OK)
    w.setHeader("Content-Type", "text/plain")
    w.writeHeader(None)
    w.writeString("chunk 1\n")
    w.writeString("chunk 2\n")
    w.finish()
}
```

`ResponseBuilder` 支持分块传输编码（Transfer-Encoding: chunked），
自动添加响应头和结束块。支持以下方法：

| 方法 | 说明 |
|------|------|
| `setStatus(HttpStatus)` | 设置状态码（必须在首次写入前调用） |
| `setHeader(name, value)` | 设置响应头 |
| `addTrailer(name, value)` | 添加 trailer 字段（必须在写入数据前声明） |
| `writeHeader(?HttpStatus)` | 写入状态行和头（首次 `write()` 自动调用） |
| `write(Array<UInt8>)` | 写入数据块 |
| `writeString(String)` | 写入字符串块 |
| `finish()` | 结束响应，写入最终空块和 trailer |
| `takeover()` | 劫持底层 TCP 连接（用于 WebSocket 等协议升级） |

## 优雅关闭

```cangjie
let server = HttpServer(router, config: config)
// 在另一个协程中监听
spawn { server.listenAndServe("0.0.0.0", 8080) }
// 收到信号后
server.shutdown()  // 等待正在处理的请求完成，HTTP/2 连接发送 GOAWAY
server.close()
```

## HTTP/2

启用 HTTP/2 只需在配置中设置:

```cangjie
config.enableHttp2 = true
```

Server 自动检测 HTTP/2 连接（通过连接前言 `PRI * HTTP/2.0`），
并处理多路复用流。每个流在独立协程中处理。

## WebSocket

```cangjie
router.get("/ws", { req =>
    let upgrade = req.headers.get("upgrade")
    match (upgrade) {
        case Some(up) =>
            if (up.toLower() == "websocket") {
                // Server 自动处理 WebSocket 升级握手
                // 连接升级后在 handler 中通过 ConnectionController 接管
            }
        case None => ()
    }
    HttpResponse.text(HttpStatus.BAD_REQUEST, "Not a WebSocket request")
})
```

## 速率限制

基于 IP 的滑动窗口速率限制器，自动定期清理过期条目以防止内存泄漏：

```cangjie
import http_lib.server.RateLimiter

let limiter = RateLimiter(window: Duration.minute * 1, maxRequests: 100)
chain.use(limiter.middleware())
```

> **注意**：速率限制器使用挂钟时间（wall-clock time）。系统时钟调整（如 NTP 同步、手动修改）可能会短暂影响窗口计算。内部有定期后台清理任务，配合每次访问时的按需清理，及时释放非活跃客户端占用的内存。

## 配置参考

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `readTimeout` | Duration | 30s | 读超时 |
| `writeTimeout` | Duration | 30s | 写超时 |
| `maxHeaderSize` | Int64 | 65536 | 最大 header 大小 |
| `maxBodySize` | Int64 | - | 最大 body 大小 (0 = 无限制) |
| `keepAlive` | Bool | true | Keep-Alive |
| `tlsConfig` | TlsConfig? | None | TLS 配置 |
| `enableHttp2` | Bool | false | 启用 HTTP/2 |
| `serverName` | String | - | Server 头值 |
| `autoDateHeader` | Bool | true | 自动添加 Date 头 |
| `autoServerHeader` | Bool | true | 自动添加 Server 头 |
| `autoCompress` | Bool | false | 自动压缩 |
| `compressMinSize` | Int64 | 1024 | 压缩最小字节数 |
| `idleTimeout` | Duration | 60s | Keep-alive 空闲超时 |

## 虚拟主机路由

```cangjie
let router = Router()
router.host("api.example.com").get("/v1/users", apiHandler)
router.host("admin.example.com").get("/dashboard", adminHandler)

let server = HttpServer(handler: router.handler())
server.listenAndServe("0.0.0.0", 8080)
```

## 路由分组

```cangjie
let router = Router()
let api = router.group("/api/v1")
api.get("/users", listHandler)
api.post("/users", createHandler)
// 匹配 /api/v1/users
```

## 目录列表

```cangjie
let config = FileServerConfig()
config.listingEnabled = true
let handler = serveStatic("/var/www", config: config)
router.get("/files/{path}", handler)
```

## HTTP/2 Server Push

```cangjie
let pushRequest = HttpRequest(method: HttpMethod.GET, url: "/style.css")
let pushId = h2conn.pushPromise(streamId, pushRequest)
h2conn.sendPushResponse(pushId, pushResponse)
```

## 超时和限制

真正的超时机制 — 将处理器在独立协程中运行，并配合定时器强制执行超时：

```cangjie
let handler = TimedHandler(slowHandler, Duration.second * 5)    // 5秒超时，返回 503
let handler2 = SizeLimitHandler(uploadHandler, 10 * 1024 * 1024)  // 10MB body 限制
```

---

## ResponseBuilder 构建器 (server 模块)

`http_lib.server.ResponseBuilder` 是另一种响应构建方式，遵循
`http_lib.server.ResponseBuilder` 写入器模式。它与 `message.ResponseBuilder` 的区别在于：

- **`message.ResponseBuilder`**: 流式写入模式，直接向 TCP 连接写入分块数据。
- **`server.ResponseBuilder`**: 构建器模式，累积状态码、头和 body 数据后
  统一生成 `HttpResponse` 对象。适合希望在 handler 中使用写入器风格的 API，
  但仍返回标准 `HttpResponse` 的场景。

### 基本用法

```cangjie
import http_lib.server.ResponseBuilder

// 创建 ResponseBuilder 构建器
let rw = ResponseBuilder()
rw.writeHeader(200)
rw.header("Content-Type", "application/json")
rw.writeString("{\"result\":\"ok\"}")
let resp = rw.build()  // 生成 HttpResponse 对象
```

### 方法说明

| 方法 | 说明 |
|------|------|
| `writeHeader(Int64)` | 设置状态码（只生效一次，后续调用被忽略） |
| `header(name, value)` | 设置响应头 |
| `write(Array<UInt8>)` | 写入 body 字节数据（若未调用 writeHeader，自动设状态为 200） |
| `writeString(String)` | 写入字符串到 body |
| `build()` | 构建并返回 `HttpResponse` 对象 |

### 与 Handler 配合使用

通过 `wrapResponseBuilderHandler` 可以将 `(HttpRequest, ResponseBuilder) -> Unit`
风格的 handler 转换为标准 `Handler`，用于路由注册：

```cangjie
import http_lib.server.{ResponseBuilder, wrapResponseBuilderHandler}

let handler = wrapResponseBuilderHandler({req, rw =>
    rw.writeHeader(201)
    rw.header("Content-Type", "application/json")
    rw.header("X-Request-ID", req.headers.get("x-request-id").getOr(""))
    rw.writeString("{\"status\":\"created\"}")
})

router.post("/api/resource", handler)
```

### 在路由中直接使用

```cangjie
router.get("/stream", wrapResponseBuilderHandler({req, rw =>
    rw.writeHeader(200)
    rw.header("Content-Type", "text/event-stream")
    rw.header("Cache-Control", "no-cache")
    rw.writeString("data: event 1\n\n")
    rw.writeString("data: event 2\n\n")
}))
```

## HTTP 辅助函数

server 模块提供了一组 HTTP 辅助函数，用于快速生成常见的
HTTP 错误和重定向响应。

### HttpError

`HttpError(req, message, statusCode)` 返回一个包含指定错误信息和状态码的
HTTP 响应。自动设置 `Content-Type: text/plain; charset=utf-8` 和
`X-Content-Type-Options: nosniff` 头。

```cangjie
import http_lib.server.HttpError

router.get("/api/data", { req =>
    let data = fetchData()
    match (data) {
        case Some(d) => HttpResponse.json(HttpStatus.OK, d)
        case None => HttpError(req, "数据不存在", 404)
    }
})

// 自定义错误消息
router.get("/admin", { req =>
    if (!authenticated) {
        HttpError(req, "需要管理员权限", 403)
    } else {
        handleRequest(req)
    }
})
```

### HttpNotFound

`HttpNotFound(req)` 返回一个 404 Not Found 响应，等价于
`HttpError(req, "404 page not found", 404)`。

```cangjie
import http_lib.server.HttpNotFound

router.get("/users/:id", { req =>
    let result = router.find(HttpMethod.GET, req.url)
    match (result.params.get("id")) {
        case Some(id) =>
            match (findUser(id)) {
                case Some(user) => HttpResponse.json(HttpStatus.OK, user)
                case None => HttpNotFound(req)
            }
        case None => HttpNotFound(req)
    }
})
```

### HttpRedirect

`HttpRedirect(req, url, statusCode)` 返回一个 HTTP 重定向响应。
自动设置 `Location` 头和包含链接的 HTML body。

```cangjie
import http_lib.server.HttpRedirect

// 301 永久重定向
router.get("/old-page", { req =>
    HttpRedirect(req, "/new-page", 301)
})

// 302 临时重定向
router.get("/legacy-path", { req =>
    HttpRedirect(req, "/new-path", 302)
})

// 307 临时重定向（保持请求方法）
router.post("/v1/endpoint", { req =>
    HttpRedirect(req, "/v2/endpoint", 307)
})

// 308 永久重定向（保持请求方法）
router.put("/v1/resource", { req =>
    HttpRedirect(req, "/v2/resource", 308)
})
```

## NotFoundResponder 和 RedirectResponder

这两个工厂函数可快速生成可直接用于路由注册的 Handler，无需手写闭包。

### NotFoundResponder

`NotFoundResponder()` 返回一个始终返回 404 Not Found 的 Handler。

```cangjie
import http_lib.server.NotFoundResponder

// 兜底路由：所有未匹配的路径返回 404
router.all("/{path}", NotFoundResponder())

// 或者给特定路由组设置 404
let api = router.group("/api/v2")
api.get("/users", listHandler)
// 其他 /api/v2/* 路径返回 404

// 作为全局 fallback handler（推荐直接使用 router.handler()）
let server = HttpServer(handler: router.handler())
```

### RedirectResponder

`RedirectResponder(url, statusCode)` 返回一个始终将请求重定向到指定 URL
的 Handler。

```cangjie
import http_lib.server.RedirectResponder

// 永久重定向旧路径
router.get("/old-docs", RedirectResponder("/docs", 301))
router.get("/legacy-home", RedirectResponder("https://new-site.com", 301))

// 临时重定向
router.get("/temp-maintenance", RedirectResponder("/maintenance.html", 302))

// 方法保持重定向
router.post("/v1/submit", RedirectResponder("/v2/submit", 307))
```

### 组合使用示例

```cangjie
let router = Router()

// 正常路由
router.get("/", homeHandler)
router.get("/api/users", userListHandler)

// 旧路径永久重定向
router.get("/old-home", RedirectResponder("/", 301))
router.get("/old-api", RedirectResponder("/api", 301))

// 兜底 404
router.all("/{path}", NotFoundResponder())

let server = HttpServer(handler: router.handler())
server.listenAndServe("0.0.0.0", 8080)
```

## 103 Early Hints (RFC 8297)

在最终响应之前发送预加载提示，允许客户端提前连接或预加载关键资源：

```cangjie
// 发送 103 Early Hints
responseBuilder.sendEarlyHints([
    ("Link", "</style.css>; rel=preload; as=style"),
    ("Link", "</script.js>; rel=preload; as=script"),
])

// 随后发送最终 200 响应
responseBuilder.writeHeader(HttpStatus.OK)
responseBuilder.write("<html>...")
responseBuilder.finish()
```

## ResponseController

统一控制流式响应，支持 Flush、Hijack、读/写截止时间和全双工模式：

```cangjie
import http_lib.server.ResponseController
import http_lib.connection.Connection

let ctrl = ResponseController(responseBuilder, conn)
ctrl.flush()
let conn = ctrl.hijack()
ctrl.setReadDeadline(DateTime.now() + Duration.second * 30)
ctrl.setWriteDeadline(DateTime.now() + Duration.second * 30)
ctrl.enableFullDuplex()
```
