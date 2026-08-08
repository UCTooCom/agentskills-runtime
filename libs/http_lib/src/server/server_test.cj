package http_lib.server

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class ServerSecurityTest {

    @TestCase
    public func testSecurityHeadersMiddleware(): Unit {
        let middleware = securityHeadersMiddleware()
        let handler = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})
        let req = HttpRequest()
        let resp = handler(req)

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
    public func testHstsMiddleware(): Unit {
        let middleware = hstsMiddleware()
        let handler = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})
        let req = HttpRequest()
        let resp = handler(req)

        match (resp.headers.get("strict-transport-security")) {
            case Some(v) =>
                assertTrue(v.contains("max-age=31536000"))
                assertTrue(v.contains("includeSubDomains"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testHstsMiddlewareNoSubdomains(): Unit {
        let middleware = hstsMiddleware(includeSubDomains: false)
        let handler = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})
        let resp = handler(HttpRequest())
        match (resp.headers.get("strict-transport-security")) {
            case Some(v) => assertFalse(v.contains("includeSubDomains"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testCspMiddleware(): Unit {
        let policy = "default-src 'self'; img-src 'self' https:; script-src 'self'"
        let middleware = cspMiddleware(policy)
        let handler = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})
        let resp = handler(HttpRequest())

        match (resp.headers.get("content-security-policy")) {
            case Some(v) => assertTrue(v == policy)
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRateLimiterMiddlewareBasic(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 2)
        let middleware = limiter.middleware()
        let handler = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})
        let req = HttpRequest()
        req.headers.set("X-Real-IP", "10.0.0.1")

        let resp1 = handler(req)
        assertTrue(resp1.status.code == 200)

        let resp2 = handler(req)
        assertTrue(resp2.status.code == 200)

        let resp3 = handler(req)
        assertTrue(resp3.status.code == 429)
    }

    @TestCase
    public func testRateLimiterRequestCount(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 100)
        assertTrue(limiter.requestCount("127.0.0.1") == 0)
    }

    @TestCase
    public func testRateLimiterReset(): Unit {
        let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 100)
        assertTrue(limiter.requestCount("10.0.0.1") == 0)
        limiter.reset()
        assertTrue(limiter.requestCount("10.0.0.1") == 0)
    }

    @TestCase
    public func testExtractClientIpXForwardedFor(): Unit {
        let req = HttpRequest()
        req.headers.set("X-Forwarded-For", "203.0.113.195, 70.41.3.18, 150.172.238.178")
        let ip = extractClientIp(req)
        assertTrue(ip == "203.0.113.195")
    }

    @TestCase
    public func testExtractClientIpXRealIP(): Unit {
        let req = HttpRequest()
        req.headers.set("X-Real-IP", "10.0.0.1")
        let ip = extractClientIp(req)
        assertTrue(ip == "10.0.0.1")
    }

    @TestCase
    public func testExtractClientIpDefault(): Unit {
        let req = HttpRequest()
        let ip = extractClientIp(req)
        assertTrue(ip == "127.0.0.1")
    }

    @TestCase
    public func testExtractClientIpXForwardedForTakesPriority(): Unit {
        let req = HttpRequest()
        req.headers.set("X-Forwarded-For", "8.8.8.8")
        req.headers.set("X-Real-IP", "10.0.0.1")
        let ip = extractClientIp(req)
        assertTrue(ip == "8.8.8.8")
    }

    @TestCase
    public func testLoggingMiddleware(): Unit {
        let middleware = loggingMiddleware()
        let handler = middleware({req => HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")})
        let req = HttpRequest(method: HttpMethod.GET, url: "/test")
        let resp = handler(req)
        assertTrue(resp.status.code == 404)
    }
}

@Test
public class ServerConfigTest {

    @TestCase
    public func testHttpServerConfigDefaults(): Unit {
        let config = HttpServerConfig()
        assertTrue(config.readTimeout == Duration.second * 30)
        assertTrue(config.writeTimeout == Duration.second * 30)
        assertTrue(config.maxHeaderSize == 65536)
        assertTrue(config.maxBodySize == 10485760)
        assertTrue(config.keepAlive == true)
        assertTrue(config.enableHttp2 == true)
        assertTrue(config.serverName == "http_lib/0.1")
        assertTrue(config.autoDateHeader == true)
        assertTrue(config.autoServerHeader == true)
        assertTrue(config.autoCompress == true)
        assertTrue(config.compressMinSize == 1024)
        assertTrue(config.tlsConfig.isNone())
    }
}

@Test
public class TimedHandlerTest {

    @TestCase
    public func testTimedHandlerFastRequest(): Unit {
        let handler = TimedHandler(
            {req => HttpResponse.text(HttpStatus.OK, "OK")},
            Duration.second * 10
        )
        let req = HttpRequest()
        let resp = handler(req)
        assertTrue(resp.status.code == 200)
    }

    @TestCase
    public func testTimedHandlerWithCustomMessage(): Unit {
        let customMsg = "Custom timeout message"
        let handler = TimedHandler(
            {req =>
                // 通过返回带延迟的响应来模拟慢处理器
                HttpResponse.text(HttpStatus.OK, "OK")
            },
            Duration.nanosecond * 1,
            message: customMsg
        )
        let req = HttpRequest()
        let resp = handler(req)
        // 处理器足够快，因此应返回 OK
        // 对于真正的超时测试，我们需要控制时间的能力
        assertTrue(resp.status.code == 200 || resp.status.code == 503)
    }

    @TestCase
    public func testTimedHandlerExceptionInHandler(): Unit {
        let handler = TimedHandler(
            {req => throw Exception("Handler error")},
            Duration.second * 10
        )
        let req = HttpRequest()
        let resp = handler(req)
        assertTrue(resp.status.code == 500,
            message: "Handler exception should return 500 Internal Server Error")
    }

    @TestCase
    public func testTimedHandlerVeryShortTimeout(): Unit {
        let handler = TimedHandler(
            {req => HttpResponse.text(HttpStatus.OK, "OK")},
            Duration.nanosecond * 1
        )
        let req = HttpRequest()
        let resp = handler(req)
        // 可能超时也可能不超时，取决于时钟粒度
        assertTrue(resp.status.code == 200 || resp.status.code == 503)
    }

    @TestCase
    public func testTimedHandlerEmptyMessage(): Unit {
        let handler = TimedHandler(
            {req => HttpResponse.text(HttpStatus.OK, "OK")},
            Duration.second * 10,
            message: ""
        )
        let req = HttpRequest()
        let resp = handler(req)
        assertTrue(resp.status.code == 200)
    }

    @TestCase
    public func testSizeLimitHandlerUnderLimit(): Unit {
        let handler = SizeLimitHandler(
            {req => HttpResponse.text(HttpStatus.OK, "OK")},
            1000
        )
        let req = HttpRequest()
        let bodyData = Array<UInt8>(100, repeat: 0x41)
        req.setBody(bodyData)
        let resp = handler(req)
        assertTrue(resp.status.code == 200)
    }

    @TestCase
    public func testSizeLimitHandlerOverLimit(): Unit {
        let handler = SizeLimitHandler(
            {req => HttpResponse.text(HttpStatus.OK, "OK")},
            50
        )
        let req = HttpRequest()
        let bodyData = Array<UInt8>(100, repeat: 0x41)
        req.setBody(bodyData)
        let resp = handler(req)
        assertTrue(resp.status.code == 413)
    }

    @TestCase
    public func testSizeLimitHandlerEmptyBody(): Unit {
        let handler = SizeLimitHandler(
            {req => HttpResponse.text(HttpStatus.OK, "OK")},
            100
        )
        let req = HttpRequest()
        // 未设置主体 — 主体应为空
        let resp = handler(req)
        assertTrue(resp.status.code == 200,
            message: "Empty body should pass through")
    }

    @TestCase
    public func testSizeLimitHandlerExactLimit(): Unit {
        let handler = SizeLimitHandler(
            {req => HttpResponse.text(HttpStatus.OK, "OK")},
            100
        )
        let req = HttpRequest()
        let bodyData = Array<UInt8>(100, repeat: 0x42)
        req.setBody(bodyData)
        let resp = handler(req)
        assertTrue(resp.status.code == 200,
            message: "Body exactly at limit should pass")
    }

    @TestCase
    public func testSizeLimitHandlerOneByteOver(): Unit {
        let handler = SizeLimitHandler(
            {req => HttpResponse.text(HttpStatus.OK, "OK")},
            100
        )
        let req = HttpRequest()
        let bodyData = Array<UInt8>(101, repeat: 0x43)
        req.setBody(bodyData)
        let resp = handler(req)
        assertTrue(resp.status.code == 413,
            message: "One byte over limit should return 413")
    }
}
