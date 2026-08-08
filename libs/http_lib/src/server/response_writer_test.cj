package http_lib.server

import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class ServerResponseBuilderTest {

    @TestCase
    public func testResponseBuilderInit(): Unit {
        let rw = ResponseBuilder()
        let resp = rw.build()
        assertTrue(resp.status.code == 200)
        assertTrue(resp.bodyAsString() == "")
    }

    @TestCase
    public func testWriteHeader(): Unit {
        let rw = ResponseBuilder()
        rw.writeHeader(201)
        let resp = rw.build()
        assertTrue(resp.status.code == 201)
    }

    @TestCase
    public func testWriteHeaderOnce(): Unit {
        let rw = ResponseBuilder()
        rw.writeHeader(201)
        rw.writeHeader(404)  // 第二次调用应被忽略
        let resp = rw.build()
        assertTrue(resp.status.code == 201)
    }

    @TestCase
    public func testWriteBody(): Unit {
        let rw = ResponseBuilder()
        rw.write([72, 101, 108, 108, 111])  // "Hello" 测试数据
        let resp = rw.build()
        assertTrue(resp.bodyAsString() == "Hello")
    }

    @TestCase
    public func testWriteString(): Unit {
        let rw = ResponseBuilder()
        rw.writeString("Hello, World!")
        let resp = rw.build()
        assertTrue(resp.bodyAsString() == "Hello, World!")
    }

    @TestCase
    public func testHeaderSetting(): Unit {
        let rw = ResponseBuilder()
        rw.header("Content-Type", "application/json")
        let resp = rw.build()
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testWriteImplies200(): Unit {
        let rw = ResponseBuilder()
        rw.write([65])
        let resp = rw.build()
        assertTrue(resp.status.code == 200)
    }

    @TestCase
    public func testMultipleWrites(): Unit {
        let rw = ResponseBuilder()
        rw.writeString("Hello, ")
        rw.writeString("World!")
        let resp = rw.build()
        assertTrue(resp.bodyAsString() == "Hello, World!")
    }

    @TestCase
    public func testWriteAfterHeader(): Unit {
        let rw = ResponseBuilder()
        rw.writeHeader(400)
        rw.writeString("Bad Request")
        let resp = rw.build()
        assertTrue(resp.status.code == 400)
        assertTrue(resp.bodyAsString() == "Bad Request")
    }

    @TestCase
    public func testBuildFromDefault(): Unit {
        let rw = ResponseBuilder()
        let resp = rw.build()
        assertTrue(resp.status.code == 200)
        assertTrue(resp.bodyAsString() == "")
    }

    @TestCase
    public func testWrapHandler(): Unit {
        let handler = wrapResponseBuilderHandler({req, rw =>
            rw.writeHeader(200)
            rw.header("X-Custom", "value")
            rw.writeString("OK")
        })
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = handler(req)
        assertTrue(resp.status.code == 200)
        assertTrue(resp.bodyAsString() == "OK")
        match (resp.headers.get("x-custom")) {
            case Some(v) => assertTrue(v == "value")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testWrapHandlerWithStatus(): Unit {
        let handler = wrapResponseBuilderHandler({req, rw =>
            rw.writeHeader(201)
            rw.writeString("Created")
        })
        let resp = handler(HttpRequest(method: HttpMethod.POST, url: "/api"))
        assertTrue(resp.status.code == 201)
        assertTrue(resp.bodyAsString() == "Created")
    }
}

@Test
public class HttpHelpersTest {

    @TestCase
    public func testHttpError(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = HttpError(req, "Not Found", 404)
        assertTrue(resp.status.code == 404)
        let body = resp.bodyAsString()
        assertTrue(body.contains("Not Found"))
    }

    @TestCase
    public func testHttpErrorWithMessage(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = HttpError(req, "Custom error message", 500)
        assertTrue(resp.status.code == 500)
        assertTrue(resp.bodyAsString().contains("Custom error message"))
    }

    @TestCase
    public func testHttpErrorContentType(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/")
        let resp = HttpError(req, "Forbidden", 403)
        match (resp.headers.get("content-type")) {
            case Some(ct) => assertTrue(ct == "text/plain; charset=utf-8")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testHttpNotFound(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/missing")
        let resp = HttpNotFound(req)
        assertTrue(resp.status.code == 404)
    }

    @TestCase
    public func testHttpNotFoundBody(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/missing")
        let resp = HttpNotFound(req)
        let body = resp.bodyAsString()
        assertTrue(body.contains("404"))
    }

    @TestCase
    public func testHttpRedirect(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/old")
        let resp = HttpRedirect(req, "/new", 301)
        assertTrue(resp.status.code == 301)
        match (resp.headers.get("location")) {
            case Some(loc) => assertTrue(loc == "/new")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testHttpRedirect302(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/temporary")
        let resp = HttpRedirect(req, "/new-location", 302)
        assertTrue(resp.status.code == 302)
        match (resp.headers.get("location")) {
            case Some(loc) => assertTrue(loc == "/new-location")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testHttpRedirectBody(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/old-path")
        let resp = HttpRedirect(req, "/new-path", 301)
        let body = resp.bodyAsString()
        assertTrue(body.contains("/new-path"))
    }

    @TestCase
    public func testNotFoundResponder(): Unit {
        let handler = NotFoundResponder()
        let req = HttpRequest(method: HttpMethod.GET, url: "/anything")
        let resp = handler(req)
        assertTrue(resp.status.code == 404)
    }

    @TestCase
    public func testRedirectResponder(): Unit {
        let handler = RedirectResponder("/target", 302)
        let req = HttpRequest(method: HttpMethod.GET, url: "/source")
        let resp = handler(req)
        assertTrue(resp.status.code == 302)
        match (resp.headers.get("location")) {
            case Some(loc) => assertTrue(loc == "/target")
            case None => assertTrue(false)
        }
    }
}
