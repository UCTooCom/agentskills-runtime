package http_lib.message
import std.collection.ArrayList
import http_lib.core.{assertTrue, assertFalse, HttpStatus, HttpVersion}

@Test
public class ResponseTest {
    @TestCase
    public func testDefaultResponse(): Unit {
        let resp = HttpResponse()
        assertTrue(resp.status == HttpStatus.OK)
        assertTrue(resp.version == HttpVersion.HTTP_1_1)
        assertTrue(resp.bodyAsString() == "")
        assertTrue(resp.isSuccess())
    }

    @TestCase
    public func testStatusLine(): Unit {
        let resp = HttpResponse(status: HttpStatus.NOT_FOUND)
        assertTrue(resp.buildStatusLine() == "HTTP/1.1 404 Not Found\r\n")
    }

    @TestCase
    public func testIsSuccess(): Unit {
        assertTrue(HttpResponse(status: HttpStatus.OK).isSuccess())
        assertFalse(HttpResponse(status: HttpStatus.NOT_FOUND).isSuccess())
        assertFalse(HttpResponse(status: HttpStatus.INTERNAL_SERVER_ERROR).isSuccess())
    }

    @TestCase
    public func testIsRedirect(): Unit {
        assertTrue(HttpResponse(status: HttpStatus.FOUND).isRedirect())
        assertFalse(HttpResponse(status: HttpStatus.OK).isRedirect())
    }

    @TestCase
    public func testJsonResponse(): Unit {
        let resp = HttpResponse.json(HttpStatus.CREATED, "{\"id\":1}")
        assertTrue(resp.status == HttpStatus.CREATED)
        match (resp.headers.get("Content-Type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
        match (resp.headers.get("Content-Length")) {
            case Some(v) => assertTrue(v == "8")
            case None => assertTrue(false)
        }
        assertTrue(resp.bodyAsString() == "{\"id\":1}")
    }

    @TestCase
    public func testTextResponse(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "Hello, World!")
        assertTrue(resp.status == HttpStatus.OK)
        match (resp.headers.get("Content-Type")) {
            case Some(v) => assertTrue(v == "text/plain; charset=utf-8")
            case None => assertTrue(false)
        }
        assertTrue(resp.bodyAsString() == "Hello, World!")
    }

    @TestCase
    public func testEmptyResponse(): Unit {
        let resp = HttpResponse.empty(HttpStatus.NO_CONTENT)
        assertTrue(resp.status == HttpStatus.NO_CONTENT)
        assertTrue(resp.bodyAsString() == "")
    }

    @TestCase
    public func testToBytes(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "OK")
        let bytes = resp.toBytes()
        let str = String.fromUtf8(bytes)
        assertTrue(str.startsWith("HTTP/1.1 200 OK\r\n"))
        assertTrue(str.endsWith("OK"))
    }

    @TestCase
    public func testBodyAsBytes(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "data")
        let bytes = resp.bodyAsBytes()
        let str = String.fromUtf8(bytes)
        assertTrue(str == "data")
    }

    @TestCase
    public func testHtmlResponse(): Unit {
        let resp = HttpResponse.html(HttpStatus.OK, "<h1>Hello</h1>")
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "text/html; charset=utf-8")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRedirectResponse(): Unit {
        let resp = HttpResponse.redirect("https://example.com/new")
        assertTrue(resp.status == HttpStatus.FOUND)
        match (resp.headers.get("location")) {
            case Some(v) => assertTrue(v == "https://example.com/new")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testBytesResponse(): Unit {
        let data = [b'B', b'y', b't', b'e', b's']
        let resp = HttpResponse.bytes(HttpStatus.OK, "application/octet-stream", data)
        assertTrue(resp.body.getLimit() == 5)
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "application/octet-stream")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testWithCookie(): Unit {
        let resp = HttpResponse.empty(HttpStatus.OK)
            .withCookie("session", "abc123", maxAge: 3600, httpOnly: true, secure: true)
        let cookies = resp.headers.getAll("set-cookie")
        assertTrue(cookies.size > 0)
        match (cookies.get(0)) {
            case Some(c) =>
                assertTrue(c.contains("session=abc123"))
                assertTrue(c.contains("Max-Age=3600"))
                assertTrue(c.contains("HttpOnly"))
                assertTrue(c.contains("Secure"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testChunkedResponse(): Unit {
        let resp = HttpResponse.chunked(HttpStatus.OK)
        match (resp.headers.get("transfer-encoding")) {
            case Some(v) => assertTrue(v == "chunked")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testChunkedResponseWithTrailers(): Unit {
        let trailerNames = Some(["X-Checksum", "X-Processing-Time"])
        let resp = HttpResponse.chunked(HttpStatus.OK, trailerNames: trailerNames)
        match (resp.headers.get("trailer")) {
            case Some(v) =>
                assertTrue(v.contains("X-Checksum"))
                assertTrue(v.contains("X-Processing-Time"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testIsKeepAliveHttp11(): Unit {
        let resp = HttpResponse()
        resp.version = HttpVersion.HTTP_1_1
        assertTrue(resp.isKeepAlive())
    }

    @TestCase
    public func testIsKeepAliveConnectionClose(): Unit {
        let resp = HttpResponse()
        resp.version = HttpVersion.HTTP_1_1
        resp.headers.set("Connection", "close")
        assertFalse(resp.isKeepAlive())
    }

    @TestCase
    public func testReadLineCrLf(): Unit {
        let bodyStr = "line1\r\nline2\r\nline3"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "line1")
            case None => assertTrue(false)
        }
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "line2")
            case None => assertTrue(false)
        }
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "line3")
            case None => assertTrue(false)
        }
        match (resp.readLine()) {
            case Some(_) => assertTrue(false)
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testReadLineLfOnly(): Unit {
        let bodyStr = "a\nb\nc"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "a")
            case None => assertTrue(false)
        }
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "b")
            case None => assertTrue(false)
        }
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "c")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testReadLineEmptyBody(): Unit {
        let resp = HttpResponse.empty(HttpStatus.OK)
        match (resp.readLine()) {
            case Some(_) => assertTrue(false, message: "Should return None for empty body")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testReadLineSseFormat(): Unit {
        let bodyStr = "data: {\"chunk\":1}\n\ndata: {\"chunk\":2}\n\ndata: [DONE]\n"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        var dataLines = ArrayList<String>()
        while (true) {
            match (resp.readLine()) {
                case Some(line) =>
                    if (line.startsWith("data: ")) {
                        dataLines.add(line)
                    }
                case None => break
            }
        }
        assertTrue(dataLines.size == 3, message: "Expected 3 SSE data lines, got ${dataLines.size}")
    }

    @TestCase
    public func testReadBodyThenReadLine(): Unit {
        // readBody 和 readLine 共享相同的内部位置
        let bodyStr = "header\nbody content here\nfooter"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        // 通过 readLine 读取第一行
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "header")
            case None => assertTrue(false)
        }
        // 重置并通过 readBody 读取
        resp.resetRead()
        let buf = Array<UInt8>(100, repeat: 0)
        let n = resp.readBody(buf)
        let readStr = String.fromUtf8(buf[0..n])
        assertTrue(readStr == bodyStr, message: "readBody after reset should return full body")
    }

    @TestCase
    public func testResetRead(): Unit {
        let bodyStr = "first\nsecond"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        // 读取所有行
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "first")
            case None => assertTrue(false)
        }
        // 重置并重新读取
        resp.resetRead()
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "first")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testReadLineCrOnly(): Unit {
        // 仅 CR 换行符（经典 Mac 风格）
        let bodyStr = "a\rb\rc"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "a")
            case None => assertTrue(false)
        }
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "b")
            case None => assertTrue(false)
        }
        match (resp.readLine()) {
            case Some(line) => assertTrue(line == "c")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testReadLineMixedEndings(): Unit {
        let bodyStr = "unix\nwindows\r\nclassic\rlast"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        var lines = ArrayList<String>()
        while (true) {
            match (resp.readLine()) {
                case Some(line) => lines.add(line)
                case None => break
            }
        }
        assertTrue(lines.size == 4, message: "Should have 4 lines, got ${lines.size}")
    }

    @TestCase
    public func testReadLineSingleCharacter(): Unit {
        let bodyStr = "A\nB\nC"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        match (resp.readLine()) { case Some(l) => assertTrue(l == "A"); case None => assertTrue(false) }
        match (resp.readLine()) { case Some(l) => assertTrue(l == "B"); case None => assertTrue(false) }
        match (resp.readLine()) { case Some(l) => assertTrue(l == "C"); case None => assertTrue(false) }
    }

    @TestCase
    public func testReadLineEmptyLines(): Unit {
        let bodyStr = "first\n\nthird"
        let resp = HttpResponse.text(HttpStatus.OK, bodyStr)
        match (resp.readLine()) { case Some(l) => assertTrue(l == "first"); case None => assertTrue(false) }
        match (resp.readLine()) { case Some(l) => assertTrue(l == ""); case None => assertTrue(false) }
        match (resp.readLine()) { case Some(l) => assertTrue(l == "third"); case None => assertTrue(false) }
    }

    @TestCase
    public func testResponseTrailersDefaultEmpty(): Unit {
        let resp = HttpResponse()
        assertTrue(resp.trailers.isEmpty(),
            message: "New response should have empty trailers")
    }

    @TestCase
    public func testResponseTrailersSetAndRead(): Unit {
        let resp = HttpResponse()
        resp.trailers.set("X-Trailer", "trailer-value")
        match (resp.trailers.get("x-trailer")) {
            case Some(v) => assertTrue(v == "trailer-value")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testResponseTrailersMultiple(): Unit {
        let resp = HttpResponse()
        resp.trailers.set("X-Request-Id", "req-001")
        resp.trailers.set("X-Processing-Time", "42ms")
        assertTrue(resp.trailers.contains("x-request-id"),
            message: "Trailers should contain request id")
        assertTrue(resp.trailers.contains("x-processing-time"),
            message: "Trailers should contain processing time")
    }
}
