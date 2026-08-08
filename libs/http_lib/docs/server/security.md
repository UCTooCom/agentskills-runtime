# Server 安全配置

## 安全头中间件

自动添加基础安全头:

```cangjie
import http_lib.server.securityHeadersMiddleware

chain.use(securityHeadersMiddleware())
```

添加的头部:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: strict-origin-when-cross-origin`

## HSTS (HTTP Strict Transport Security)

强制浏览器使用 HTTPS:

```cangjie
import http_lib.server.hstsMiddleware

chain.use(hstsMiddleware(
    maxAge: 31536000,          // 1 年
    includeSubDomains: true,   // 包含子域名
    preload: true              // 加入 HSTS preload 列表
))
```

## CSP (Content Security Policy)

```cangjie
import http_lib.server.cspMiddleware

// 严格 CSP
chain.use(cspMiddleware("default-src 'self'"))

// 允许特定域名
chain.use(cspMiddleware(
    "default-src 'self'; script-src 'self' https://cdn.example.com; " +
    "style-src 'self' 'unsafe-inline'; img-src 'self' data:"
))
```

## CORS 预检请求验证

CORS 中间件执行严格的预检请求验证:

```cangjie
import http_lib.router.{corsMiddleware, CorsConfig}

let corsConfig = CorsConfig()
corsConfig.allowOrigins = ["https://example.com"]
corsConfig.allowMethods = ["GET", "POST", "PUT", "DELETE"]
corsConfig.allowHeaders = ["Content-Type", "Authorization"]
corsConfig.allowCredentials = true
corsConfig.maxAge = 86400

chain.use(corsMiddleware(corsConfig))
```

验证行为:
- **`Access-Control-Request-Method`**: 与 `allowMethods` 进行校验，不匹配时返回 **400**
- **`Access-Control-Request-Headers`**: 与 `allowHeaders` 进行校验，不匹配时返回 **403**
- **通配符与凭据**: 当 `allowOrigins = ["*"]` 且 `allowCredentials = true` 时，回显具体请求来源而非返回 `*`
- **`Vary: Origin`** 响应头: 在回显特定来源时自动添加
- **来源比较不区分大小写**: 遵循 URL 规范

## 速率限制

基于 IP 的滑动窗口速率限制:

```cangjie
import http_lib.server.RateLimiter
import std.time.Duration

// 每分钟最多 100 个请求
let limiter = RateLimiter(
    window: Duration.minute * 1,
    maxRequests: 100
)
chain.use(limiter.middleware())

// 查看某 IP 的请求数
let count = limiter.requestCount("192.168.1.1")

// 重置所有计数
limiter.reset()
```

内部实现: 速率限制器现在会定期后台清理过期 IP 条目，防止非活跃客户端导致内存泄漏。定时器使用挂钟时间（wall-clock time），系统时钟调整（如 NTP 同步、手动修改）可能会短暂影响窗口计算。每次访问仍然会触发按需清理。

## 访问日志

```cangjie
import http_lib.server.loggingMiddleware

chain.use(loggingMiddleware())
// 输出格式: METHOD URL -> STATUS
```

## 请求超时与大小限制

基于超时和大小限制的 DoS 防护:

```cangjie
import http_lib.server.{TimedHandler, SizeLimitHandler}
import std.time.Duration

// 超时处理 — 在独立协程中运行处理器并配合定时器强制执行超时，超过 5 秒返回 503
let handler = TimedHandler(myHandler, Duration.second * 5, "Request timed out")

// 请求体大小限制 — 超过 1MB 返回 413
let handler = SizeLimitHandler(myHandler, 1024 * 1024)

// 组合使用
let handler = SizeLimitHandler(
    TimedHandler(myHandler, Duration.second * 5),
    1024 * 1024
)
```

## 客户端 IP 提取

```cangjie
import http_lib.server.extractClientIp

let ip = extractClientIp(req)  // 从 X-Forwarded-For / X-Real-IP 提取
```

## 组合使用

使用路由时，通过 `router.use()` 注册中间件，通过 `router.handler()` 自动应用:

```cangjie
let router = Router()
router.use(loggingMiddleware())
router.use(securityHeadersMiddleware())
router.use(hstsMiddleware(maxAge: 31536000))
router.use(cspMiddleware("default-src 'self'"))
router.use(limiter.middleware())
router.use(corsMiddleware(corsConfig))

let server = HttpServer(handler: router.handler())
server.listenAndServe("0.0.0.0", 443)
```

## ResponseBuilder (新增 v0.3)

流式响应构建器，遵循 `ResponseBuilder` 模式:

```cangjie
import http_lib.server.ResponseBuilder

let rw = ResponseBuilder()
rw.writeHeader(200)
rw.header("Content-Type", "application/json")
rw.writeString("{\"status\":\"ok\"}")
let resp = rw.build()
```

配合 `wrapResponseBuilderHandler` 可将流式 handler 转为标准 Handler:

```cangjie
import http_lib.server.wrapResponseBuilderHandler

let handler = wrapResponseBuilderHandler({req, rw =>
    rw.writeHeader(404)
    rw.writeString("Not Found")
})
```

## HTTP 辅助函数 (新增 v0.3)

```cangjie
import http_lib.server.{HttpError, HttpNotFound, HttpRedirect}

// 标准错误响应
HttpError(req, "Forbidden", 403)

// 404 快捷
HttpNotFound(req)

// 重定向
HttpRedirect(req, "/login", 302)

// Handler 工厂
NotFoundResponder()       // 404 handler
RedirectResponder("/", 301)  // 重定向 handler
```
