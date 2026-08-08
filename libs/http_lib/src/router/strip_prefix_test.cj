package http_lib.router

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * 测试 PrefixStripper 处理器。
 */
@Test
public class PrefixStripperTest {

    @TestCase
    public func testPrefixStripperRemovesPrefix(): Unit {
        let inner = {req: HttpRequest =>
            HttpResponse.text(HttpStatus.OK, "path: ${req.path}")
        }
        let handler = PrefixStripper("/static/", inner)

        let req = HttpRequest(method: HttpMethod.GET, url: "/static/css/style.css")
        let resp = handler(req)
        assertTrue(resp.status.code == 200)
        assertTrue(resp.bodyAsString().contains("/css/style.css"),
            message: "Expected path to have /static/ stripped")
    }

    @TestCase
    public func testPrefixStripperExactMatch(): Unit {
        let inner = {req: HttpRequest =>
            HttpResponse.text(HttpStatus.OK, "path: ${req.path}")
        }
        let handler = PrefixStripper("/api/", inner)

        let req = HttpRequest(method: HttpMethod.GET, url: "/api/")
        let resp = handler(req)
        assertTrue(resp.status.code == 200)
    }

    @TestCase
    public func testPrefixStripperNoMatchReturns404(): Unit {
        let handler = PrefixStripper("/api/", {req =>
            HttpResponse.text(HttpStatus.OK, "should not reach here")
        })

        let req = HttpRequest(method: HttpMethod.GET, url: "/other/path")
        let resp = handler(req)
        assertTrue(resp.status.code == 404,
            message: "Expected 404 for non-matching prefix, got ${resp.status.code}")
    }

    @TestCase
    public func testPrefixStripperEmptyPrefix(): Unit {
        let inner = {req: HttpRequest =>
            HttpResponse.text(HttpStatus.OK, "ok")
        }
        let handler = PrefixStripper("", inner)
        let req = HttpRequest(method: HttpMethod.GET, url: "/anything")
        let resp = handler(req)
        assertTrue(resp.status.code == 200)
    }

    @TestCase
    public func testPrefixStripperPreservesQueryString(): Unit {
        let inner = {req: HttpRequest =>
            HttpResponse.text(HttpStatus.OK, "${req.url}")
        }
        let handler = PrefixStripper("/api/", inner)

        let req = HttpRequest(method: HttpMethod.GET, url: "/api/data?key=value&page=1")
        let resp = handler(req)
        assertTrue(resp.status.code == 200)
        // 查询字符串应被保留
        assertTrue(resp.bodyAsString().contains("key=value"))
    }
}
