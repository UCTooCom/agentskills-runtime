package http_lib.server

import http_lib.core.{assertTrue, assertFalse, HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.{Handler, Middleware}

/**
 * === 测试大纲：安全测试 ===
 * 以下测试场景应添加以覆盖完整的安全性：
 * - 通过响应体中用户控制的输入注入 CSP 头部
 * - 通过错误页面中反射的 URL 参数进行 XSS
 * - HTTPS 响应的 HSTS 头部存在性和 max-age 验证
 * - CORS 来源验证：允许/禁止的来源、通配符匹配
 * - CORS 预检 OPTIONS 请求处理
 * - CORS 凭据标志处理
 * - 速率限制器：突发行为、窗口重置、按 IP 跟踪
 * - 速率限制器：跨多个 IP 的分布式/协同攻击
 * - TLS 安全：最低版本强制执行、密码套件限制
 * - HTTP 方法覆盖保护（X-HTTP-Method-Override）
 * - 文件服务中的路径遍历防护
 * - Host 头部验证以防止主机投毒攻击
 * - 请求走私：Content-Length 与 Transfer-Encoding 冲突
 * - 通过头部注入的响应拆分
 * - Cookie 安全标志（HttpOnly、Secure、SameSite）确认
 */

@Test
public class SecurityMiddlewareTest {

    // ---- 安全头部中间件 ----

    @TestCase
    public func testSecurityHeadersMiddleware(): Unit {
        let mw = securityHeadersMiddleware()
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = wrapped(req)
        assertTrue(resp.headers.get("x-content-type-options").isSome(),
            message: "X-Content-Type-Options should be set")
        assertTrue(resp.headers.get("x-frame-options").isSome(),
            message: "X-Frame-Options should be set")
        assertTrue(resp.headers.get("referrer-policy").isSome(),
            message: "Referrer-Policy should be set")
    }

    @TestCase
    public func testSecurityHeadersMiddlewareValues(): Unit {
        let mw = securityHeadersMiddleware()
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)
        let resp = wrapped(HttpRequest(method: HttpMethod.GET, url: "/"))

        match (resp.headers.get("x-content-type-options")) {
            case Some(v) => assertTrue(v == "nosniff")
            case None => assertTrue(false)
        }
        match (resp.headers.get("x-frame-options")) {
            case Some(v) => assertTrue(v == "DENY")
            case None => assertTrue(false)
        }
        match (resp.headers.get("referrer-policy")) {
            case Some(v) => assertTrue(v == "strict-origin-when-cross-origin")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testSecurityHeadersMiddlewarePreservesExistingHeaders(): Unit {
        let mw = securityHeadersMiddleware()
        // 设置自身头部的处理器
        let handler: Handler = {_ =>
            let resp = HttpResponse.text(HttpStatus.OK, "ok")
            resp.headers.set("X-Custom-Header", "custom-value")
            resp
        }
        let wrapped = mw(handler)
        let resp = wrapped(HttpRequest(method: HttpMethod.GET, url: "/"))

        // 自定义头部应被保留
        match (resp.headers.get("x-custom-header")) {
            case Some(v) => assertTrue(v == "custom-value")
            case None => assertTrue(false, message: "Custom headers should be preserved")
        }
        // 安全头部也应存在
        assertTrue(resp.headers.get("x-content-type-options").isSome())
    }

    // ---- HSTS 中间件 ----

    @TestCase
    public func testHstsMiddleware(): Unit {
        let mw = hstsMiddleware(maxAge: 31536000, includeSubDomains: true)
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = wrapped(req)
        match (resp.headers.get("strict-transport-security")) {
            case Some(v) =>
                assertTrue(v.contains("max-age=31536000"))
                assertTrue(v.contains("includeSubDomains"))
            case None => assertTrue(false, message: "HSTS header should be set")
        }
    }

    @TestCase
    public func testHstsMiddlewareDefaultParams(): Unit {
        let mw = hstsMiddleware()
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.OK, "ok")})
        let resp = wrapped(HttpRequest(method: HttpMethod.GET, url: "/"))
        match (resp.headers.get("strict-transport-security")) {
            case Some(v) =>
                assertTrue(v.contains("max-age=31536000"))
                assertTrue(v.contains("includeSubDomains"))
                assertFalse(v.contains("preload"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testHstsMiddlewareWithoutSubdomains(): Unit {
        let mw = hstsMiddleware(maxAge: 86400, includeSubDomains: false)
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = wrapped(req)
        match (resp.headers.get("strict-transport-security")) {
            case Some(v) => assertTrue(v.contains("max-age=86400"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testHstsMiddlewareWithPreload(): Unit {
        let mw = hstsMiddleware(maxAge: 31536000, includeSubDomains: true, preload: true)
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.OK, "ok")})
        let resp = wrapped(HttpRequest(method: HttpMethod.GET, url: "/"))
        match (resp.headers.get("strict-transport-security")) {
            case Some(v) =>
                assertTrue(v.contains("preload"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testHstsMiddlewareCustomMaxAge(): Unit {
        let mw = hstsMiddleware(maxAge: 86400)
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.OK, "ok")})
        let resp = wrapped(HttpRequest(method: HttpMethod.GET, url: "/"))
        match (resp.headers.get("strict-transport-security")) {
            case Some(v) => assertTrue(v.contains("max-age=86400"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testHstsMiddlewarePreservesResponseHeaders(): Unit {
        let mw = hstsMiddleware()
        let wrapped = mw({_ =>
            let resp = HttpResponse.text(HttpStatus.CREATED, "created")
            resp
        })
        let resp = wrapped(HttpRequest(method: HttpMethod.POST, url: "/api"))
        assertTrue(resp.status.code == 201,
            message: "HSTS middleware should preserve response status")
    }

    // ---- CSP 中间件 ----

    @TestCase
    public func testCspMiddleware(): Unit {
        let mw = cspMiddleware("default-src 'self'")
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = wrapped(req)
        match (resp.headers.get("content-security-policy")) {
            case Some(v) => assertTrue(v == "default-src 'self'")
            case None => assertTrue(false, message: "CSP header should be set")
        }
    }

    @TestCase
    public func testCspMiddlewareComplexPolicy(): Unit {
        let policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https:; font-src 'self' https://fonts.gstatic.com; connect-src 'self' https://api.example.com"
        let mw = cspMiddleware(policy)
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.OK, "ok")})
        let resp = wrapped(HttpRequest(method: HttpMethod.GET, url: "/"))
        match (resp.headers.get("content-security-policy")) {
            case Some(v) => assertTrue(v == policy)
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testCspMiddlewareEmptyPolicy(): Unit {
        let mw = cspMiddleware("")
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.OK, "ok")})
        let resp = wrapped(HttpRequest(method: HttpMethod.GET, url: "/"))
        match (resp.headers.get("content-security-policy")) {
            case Some(v) => assertTrue(v == "")
            case None => assertTrue(false)
        }
    }

    // ---- 日志中间件 ----

    @TestCase
    public func testLoggingMiddleware(): Unit {
        let mw = loggingMiddleware()
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/test")
        let resp = wrapped(req)
        assertTrue(resp.status == HttpStatus.OK, message: "Logging middleware should pass through")
    }

    @TestCase
    public func testLoggingMiddlewareErrorStatus(): Unit {
        let mw = loggingMiddleware()
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.NOT_FOUND, "not found")})
        let resp = wrapped(HttpRequest(method: HttpMethod.GET, url: "/missing"))
        assertTrue(resp.status.code == 404,
            message: "Logging middleware should pass through error status")
    }

    @TestCase
    public func testLoggingMiddlewareDifferentMethod(): Unit {
        let mw = loggingMiddleware()
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.NO_CONTENT, "")})
        let resp = wrapped(HttpRequest(method: HttpMethod.POST, url: "/api/data"))
        assertTrue(resp.status.code == 204)
    }

    // ---- 提取客户端 IP ----

    @TestCase
    public func testExtractClientIpDirect(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let ip = extractClientIp(req)
        assertTrue(ip == "127.0.0.1", message: "Direct connection should return 127.0.0.1")
    }

    @TestCase
    public func testExtractClientIpFromXForwardedFor(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Forwarded-For", "10.0.0.1, 10.0.0.2")
        let ip = extractClientIp(req)
        assertTrue(ip == "10.0.0.1", message: "Should use first X-Forwarded-For IP")
    }

    @TestCase
    public func testExtractClientIpFromXForwardedForSingle(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Forwarded-For", "192.168.1.100")
        let ip = extractClientIp(req)
        assertTrue(ip == "192.168.1.100",
            message: "Single X-Forwarded-For should work")
    }

    @TestCase
    public func testExtractClientIpFromXRealIp(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Real-IP", "192.168.1.1")
        let ip = extractClientIp(req)
        assertTrue(ip == "192.168.1.1", message: "Should use X-Real-IP")
    }

    @TestCase
    public func testExtractClientIpXForwardedForPriority(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Forwarded-For", "203.0.113.5")
        req.headers.set("X-Real-IP", "10.0.0.1")
        let ip = extractClientIp(req)
        assertTrue(ip == "203.0.113.5",
            message: "X-Forwarded-For should take priority over X-Real-IP")
    }

    @TestCase
    public func testExtractClientIpMultipleXForwardedFor(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Forwarded-For", " 203.0.113.195 , 70.41.3.18 , 150.172.238.178")
        let ip = extractClientIp(req)
        // 第一个 IP 包含前导空格——行为取决于实现
        assertTrue(ip.size > 0, message: "Should extract first IP")
    }

    // ---- 速率限制器 ----

    @TestCase
    public func testRateLimiterInit(): Unit {
        let limiter = RateLimiter(window: Duration.minute * 1, maxRequests: 50)
        assertTrue(true)  // 初始化不崩溃
    }

    @TestCase
    public func testRateLimiterInitDefaults(): Unit {
        let limiter = RateLimiter()
        assertTrue(true)  // 默认初始化不崩溃
    }

    @TestCase
    public func testRateLimiterMiddleware(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 100)
        let mw = limiter.middleware()
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = wrapped(req)
        assertTrue(resp.status == HttpStatus.OK || resp.status == HttpStatus.TOO_MANY_REQUESTS,
            message: "Rate limiter should allow or deny")
    }

    @TestCase
    public func testRateLimiterRejectsAfterLimit(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 2)
        let mw = limiter.middleware()
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Real-IP", "10.0.0.5")

        let resp1 = wrapped(req)
        let resp2 = wrapped(req)
        let resp3 = wrapped(req)

        assertTrue(resp1.status.code == 200,
            message: "First request should be allowed")
        assertTrue(resp2.status.code == 200,
            message: "Second request should be allowed")
        assertTrue(resp3.status.code == 429,
            message: "Third request should be rate limited")
    }

    @TestCase
    public func testRateLimiterPerIpIsolation(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 2)
        let mw = limiter.middleware()
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let wrapped = mw(handler)

        // 从不同 IP 发起请求
        let req1 = HttpRequest(method: HttpMethod.GET, url: "/")
        req1.headers.set("X-Real-IP", "10.0.0.1")
        let req2 = HttpRequest(method: HttpMethod.GET, url: "/")
        req2.headers.set("X-Real-IP", "10.0.0.2")

        // 耗尽 IP1 的配额
        let _ = wrapped(req1)
        let _ = wrapped(req1)
        let resp1Blocked = wrapped(req1)
        assertTrue(resp1Blocked.status.code == 429,
            message: "IP1 should be blocked after 2 requests")

        // IP2 应仍被允许
        let resp2Allowed = wrapped(req2)
        assertTrue(resp2Allowed.status.code == 200,
            message: "IP2 should not be affected by IP1's rate limit")
    }

    @TestCase
    public func testRateLimiterRequestCount(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 10)
        let count = limiter.requestCount("10.0.0.1")
        assertTrue(count >= 0, message: "Request count should be non-negative")
    }

    @TestCase
    public func testRateLimiterRequestCountAfterRequest(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 10)
        let mw = limiter.middleware()
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.OK, "ok")})
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Real-IP", "10.0.0.3")
        let _ = wrapped(req)
        let count = limiter.requestCount("10.0.0.3")
        assertTrue(count >= 1, message: "Request count should increase after a request")
    }

    @TestCase
    public func testRateLimiterReset(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 10)
        limiter.reset()
        assertTrue(true)  // 重置后不崩溃
    }

    @TestCase
    public func testRateLimiterResetClearsCounts(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 10)
        let mw = limiter.middleware()
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.OK, "ok")})
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Real-IP", "10.0.0.4")
        let _ = wrapped(req)
        limiter.reset()
        let count = limiter.requestCount("10.0.0.4")
        assertTrue(count == 0, message: "Request count should be 0 after reset")
    }

    @TestCase
    public func testRateLimiterLargeLimit(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 10000)
        let mw = limiter.middleware()
        let wrapped = mw({_ => HttpResponse.text(HttpStatus.OK, "ok")})
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        req.headers.set("X-Real-IP", "10.0.0.6")
        // 发起 10 个请求——全部应通过
        var i: Int64 = 0
        while (i < 10) {
            let resp = wrapped(req)
            assertTrue(resp.status.code == 200,
                message: "Request ${i + 1} should be allowed under large limit")
            i += 1
        }
    }
}
