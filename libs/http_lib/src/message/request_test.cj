package http_lib.message
import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpVersion}

@Test
public class RequestTest {
    @TestCase
    public func testDefaultRequest(): Unit {
        let req = HttpRequest()
        assertTrue(req.method == HttpMethod.GET)
        assertTrue(req.url == "/")
        assertTrue(req.version == HttpVersion.HTTP_1_1)
        assertTrue(req.headers.isEmpty())
        assertTrue(req.bodyAsString() == "")
    }

    @TestCase
    public func testRequestLine(): Unit {
        let req = HttpRequest(method: HttpMethod.POST, url: "/api/users", version: HttpVersion.HTTP_1_0)
        assertTrue(req.buildRequestLine() == "POST /api/users HTTP/1.0\r\n")
    }

    @TestCase
    public func testAddHeader(): Unit {
        let req = HttpRequest()
        req.addHeader("Content-Type", "application/json")
        match (req.headers.get("Content-Type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testBody(): Unit {
        let req = HttpRequest()
        let bodyBytes = "Hello".toArray()
        req.setBody(bodyBytes)
        assertTrue(req.bodyAsString() == "Hello")
        match (req.headers.get("Content-Length")) {
            case Some(v) => assertTrue(v == "5")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testJsonBody(): Unit {
        let req = HttpRequest()
        req.setJsonBody("{\"key\":\"value\"}")
        match (req.headers.get("Content-Type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
        match (req.headers.get("Content-Length")) {
            case Some(v) => assertTrue(v == "15")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testToBytes(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/test")
        req.addHeader("Host", "example.com")
        let bytes = req.toBytes()
        let str = String.fromUtf8(bytes)
        assertTrue(str.startsWith("GET /test HTTP/1.1\r\n"))
    }

    @TestCase
    public func testQueryParam(): Unit {
        let req = HttpRequest(url: "/search?q=hello&page=1&filter=active")
        match (req.queryParam("q")) {
            case Some(v) => assertTrue(v == "hello")
            case None => assertTrue(false)
        }
        match (req.queryParam("page")) {
            case Some(v) => assertTrue(v == "1")
            case None => assertTrue(false)
        }
        assertTrue(req.queryParam("missing").isNone())
    }

    @TestCase
    public func testCookieParsing(): Unit {
        let req = HttpRequest()
        req.headers.set("Cookie", "session=abc123; theme=dark; lang=en")
        match (req.cookie("session")) {
            case Some(v) => assertTrue(v == "abc123")
            case None => assertTrue(false)
        }
        match (req.cookie("theme")) {
            case Some(v) => assertTrue(v == "dark")
            case None => assertTrue(false)
        }
        assertTrue(req.cookie("nonexistent").isNone())
    }

    @TestCase
    public func testUserAgentReferer(): Unit {
        let req = HttpRequest()
        req.headers.set("User-Agent", "test-agent/1.0")
        req.headers.set("Referer", "https://google.com")
        assertTrue(req.userAgent() == "test-agent/1.0")
        assertTrue(req.referer() == "https://google.com")
        // 未设置时为空
        let req2 = HttpRequest()
        assertTrue(req2.userAgent() == "")
        assertTrue(req2.referer() == "")
    }

    @TestCase
    public func testContentType(): Unit {
        let req = HttpRequest()
        req.headers.set("Content-Type", "application/json; charset=utf-8")
        assertTrue(req.contentType() == "application/json; charset=utf-8")
        let req2 = HttpRequest()
        assertTrue(req2.contentType() == "")
    }

    @TestCase
    public func testBasicAuth(): Unit {
        // "testuser:testpass" 的 Base64 编码 = "dGVzdHVzZXI6dGVzdHBhc3M="
        let req = HttpRequest()
        req.headers.set("Authorization", "Basic dGVzdHVzZXI6dGVzdHBhc3M=")
        match (req.basicAuth()) {
            case Some(u) => assertTrue(u == "testuser")
            case None => assertTrue(false)
        }
        match (req.basicAuthPassword()) {
            case Some(p) => assertTrue(p == "testpass")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testAccepts(): Unit {
        let req = HttpRequest()
        req.headers.set("Accept", "text/html, application/json;q=0.9, */*;q=0.8")
        assertTrue(req.accepts("text/html"))
        assertTrue(req.accepts("application/json"))
        assertTrue(req.accepts("text/plain"))  // 匹配 */*
        let req2 = HttpRequest()
        assertTrue(req2.accepts("anything"))  // 无 Accept 头部 = 接受所有
    }

    @TestCase
    public func testClientIp(): Unit {
        let req = HttpRequest()
        req.headers.set("X-Forwarded-For", "10.0.0.1, 10.0.0.2")
        assertTrue(req.clientIp() == "10.0.0.1")
        let req2 = HttpRequest()
        req2.headers.set("X-Real-IP", "192.168.1.1")
        assertTrue(req2.clientIp() == "192.168.1.1")
        let req3 = HttpRequest()
        assertTrue(req3.clientIp() == "127.0.0.1")
    }

    @TestCase
    public func testSetHeader(): Unit {
        let req = HttpRequest()
        req.setHeader("X-Custom", "value")
        match (req.headers.get("X-Custom")) {
            case Some(v) => assertTrue(v == "value")
            case None => assertTrue(false)
        }
        // 替换现有值
        req.setHeader("X-Custom", "newvalue")
        match (req.headers.get("X-Custom")) {
            case Some(v) => assertTrue(v == "newvalue")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testQueryParams(): Unit {
        let req = HttpRequest(url: "/search?q=hello&page=1&filter=active")
        let params = req.queryParams()
        match (params.get("q")) {
            case Some(v) => assertTrue(v == "hello")
            case None => assertTrue(false)
        }
        match (params.get("page")) {
            case Some(v) => assertTrue(v == "1")
            case None => assertTrue(false)
        }
        match (params.get("filter")) {
            case Some(v) => assertTrue(v == "active")
            case None => assertTrue(false)
        }
        assertTrue(params.size == 3)
    }

    @TestCase
    public func testQueryParamsNoQuery(): Unit {
        let req = HttpRequest(url: "/path")
        let params = req.queryParams()
        assertTrue(params.size == 0)
    }

    @TestCase
    public func testQueryParamsEmptyQuery(): Unit {
        let req = HttpRequest(url: "/path?")
        let params = req.queryParams()
        assertTrue(params.size == 0)
    }

    @TestCase
    public func testPath(): Unit {
        let req = HttpRequest(url: "/api/users?page=1")
        assertTrue(req.path == "/api/users")
    }

    @TestCase
    public func testPathNoQuery(): Unit {
        let req = HttpRequest(url: "/api/users")
        assertTrue(req.path == "/api/users")
    }

    @TestCase
    public func testPathRoot(): Unit {
        let req = HttpRequest(url: "/")
        assertTrue(req.path == "/")
    }

    @TestCase
    public func testPathEmpty(): Unit {
        let req = HttpRequest(url: "")
        assertTrue(req.path == "")
    }

    @TestCase
    public func testRequestTrailersDefaultEmpty(): Unit {
        let req = HttpRequest()
        assertTrue(req.trailers.isEmpty(),
            message: "New request should have empty trailers")
    }

    @TestCase
    public func testRequestTrailersSetAndRead(): Unit {
        let req = HttpRequest()
        req.trailers.set("X-Trailer", "value")
        match (req.trailers.get("x-trailer")) {
            case Some(v) => assertTrue(v == "value")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRequestTrailersMultiple(): Unit {
        let req = HttpRequest()
        req.trailers.set("X-Content-MD5", "abc123")
        req.trailers.set("X-Checksum", "sha256:xyz")
        assertTrue(!req.trailers.isEmpty(),
            message: "Request should have trailer entries")
        match (req.trailers.get("x-content-md5")) {
            case Some(v) => assertTrue(v == "abc123")
            case None => assertTrue(false)
        }
    }
}
