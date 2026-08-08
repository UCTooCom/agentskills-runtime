package http_lib.router

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class CorsTest {

    @TestCase
    public func testCorsConfigDefaults(): Unit {
        let config = CorsConfig()
        assertTrue(config.allowOrigins.size == 1)
        assertTrue(config.allowOrigins[0] == "*")
        assertTrue(config.allowMethods.size >= 5)
        assertTrue(config.allowHeaders.size >= 3)
        assertTrue(config.allowCredentials == false)
        assertTrue(config.maxAge == 86400)
    }

    @TestCase
    public func testCorsMiddlewarePreflight(): Unit {
        let config = CorsConfig()
        let middleware = corsMiddleware(config)
        let wrapped = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})

        let req = HttpRequest(method: HttpMethod.OPTIONS, url: "/api/data")
        req.headers.set("Origin", "https://example.com")
        req.headers.set("Access-Control-Request-Method", "GET")

        let resp = wrapped(req)
        assertTrue(resp.status.code == 204)

        match (resp.headers.get("access-control-allow-origin")) {
            case Some(v) => assertTrue(v == "*")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testCorsMiddlewareActualRequest(): Unit {
        let config = CorsConfig()
        let middleware = corsMiddleware(config)
        let wrapped = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})

        let req = HttpRequest(method: HttpMethod.GET, url: "/api/data")
        req.headers.set("Origin", "https://example.com")

        let resp = wrapped(req)
        assertTrue(resp.status.code == 200)
        match (resp.headers.get("access-control-allow-origin")) {
            case Some(v) => assertTrue(v == "*")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testCorsMiddlewareSpecificOrigin(): Unit {
        let config = CorsConfig()
        config.allowOrigins = ["https://trusted.com"]
        config.allowCredentials = true
        let middleware = corsMiddleware(config)

        // 允许的来源
        let req1 = HttpRequest(method: HttpMethod.GET, url: "/api")
        req1.headers.set("Origin", "https://trusted.com")
        let resp1 = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})(req1)
        match (resp1.headers.get("access-control-allow-origin")) {
            case Some(v) => assertTrue(v == "https://trusted.com")
            case None => assertTrue(false)
        }
        match (resp1.headers.get("access-control-allow-credentials")) {
            case Some(v) => assertTrue(v == "true")
            case None => assertTrue(false)
        }

        // 被禁止的来源
        let req2 = HttpRequest(method: HttpMethod.GET, url: "/api")
        req2.headers.set("Origin", "https://evil.com")
        let resp2 = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})(req2)
        match (resp2.headers.get("access-control-allow-origin")) {
            case Some(_) => assertTrue(false)  // 不应有 CORS 头部
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testCorsMiddlewareNoOrigin(): Unit {
        let config = CorsConfig()
        let middleware = corsMiddleware(config)
        let req = HttpRequest(method: HttpMethod.GET, url: "/api")
        // 无 Origin 头部
        let resp = middleware({req => HttpResponse.text(HttpStatus.OK, "OK")})(req)
        match (resp.headers.get("access-control-allow-origin")) {
            case Some(_) => assertTrue(false)  // 不应设置头部
            case None => assertTrue(true)
        }
    }
}
