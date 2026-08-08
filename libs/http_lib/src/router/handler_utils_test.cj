package http_lib.router

import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpStatus, HttpVersion}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class HandlerUtilsTest {

    @TestCase
    public func testPrefixStripperExactMatch(): Unit {
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let stripped = PrefixStripper("/api", handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/api/users")
        let resp = stripped(req)
        assertTrue(resp.status == HttpStatus.OK)
    }

    @TestCase
    public func testPrefixStripperNoMatch(): Unit {
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let stripped = PrefixStripper("/api", handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/other/users")
        let resp = stripped(req)
        assertTrue(resp.status == HttpStatus.NOT_FOUND,
            message: "Should return 404 for non-matching prefix")
    }

    @TestCase
    public func testPrefixStripperWithTrailingSlash(): Unit {
        let handler: Handler = {_ => HttpResponse.text(HttpStatus.OK, "ok")}
        let stripped = PrefixStripper("/api/", handler)
        let req = HttpRequest(method: HttpMethod.GET, url: "/api/users")
        let resp = stripped(req)
        assertTrue(resp.status == HttpStatus.OK)
    }
}

@Test
public class HandlerUtilsOtherTest {

    @TestCase
    public func testNotFoundHandler(): Unit {
        let handler = NotFoundHandler
        let req = HttpRequest(method: HttpMethod.GET, url: "/nonexistent")
        let resp = handler(req)
        assertTrue(resp.status == HttpStatus.NOT_FOUND)
        assertTrue(resp.bodyAsString().contains("404"),
            message: "Should contain 404")
    }

    @TestCase
    public func testRedirectHandler(): Unit {
        let handler = RedirectHandler("/new-path")
        let req = HttpRequest(method: HttpMethod.GET, url: "/old-path")
        let resp = handler(req)
        assertTrue(resp.status == HttpStatus.MOVED_PERMANENTLY)
        let location = resp.headers.get("Location")
        match (location) {
            case Some(v) => assertTrue(v == "/new-path")
            case None => assertTrue(false, message: "Should have Location header")
        }
    }

    @TestCase
    public func testRedirectHandlerCustomStatus(): Unit {
        let handler = RedirectHandler("/new-path", status: HttpStatus.FOUND)
        let req = HttpRequest(method: HttpMethod.GET, url: "/old-path")
        let resp = handler(req)
        assertTrue(resp.status == HttpStatus.FOUND)
    }
}
