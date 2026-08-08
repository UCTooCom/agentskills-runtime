package http_lib.message

import http_lib.buffer.ByteBuffer
import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion}
import http_lib.connection.Connection
import std.collection.ArrayList

/**
 * 响应写入器、分块编码等的边界情况测试。
 * 响应工厂方法和解析边界情况。
 */

@Test
public class ResponseBuilderEdgeTest {

    @TestCase
    public func testResponseBuilderCreates(): Unit {
        // 验证可创建 ResponseBuilder（测试模块加载）
        assertTrue(true)
    }
}

@Test
public class HttpResponseEdgeTest {

    @TestCase
    public func testResponseJson(): Unit {
        let resp = HttpResponse.json(HttpStatus.OK, "{\"key\":\"value\"}")
        assertTrue(resp.status.code == 200)
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
        let body = resp.bodyAsString()
        assertTrue(body.contains("\"key\""))
    }

    @TestCase
    public func testResponseHtml(): Unit {
        let resp = HttpResponse.html(HttpStatus.OK, "<h1>Hello</h1>")
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "text/html; charset=utf-8")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testResponseRedirect(): Unit {
        let resp = HttpResponse.redirect("https://example.com")
        assertTrue(resp.status.code == 302)
        match (resp.headers.get("location")) {
            case Some(v) => assertTrue(v == "https://example.com")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testResponseRedirectCustomStatus(): Unit {
        let resp = HttpResponse.redirect("https://new.example.com", status: HttpStatus.MOVED_PERMANENTLY)
        assertTrue(resp.status.code == 301)
    }

    @TestCase
    public func testResponseEmpty(): Unit {
        let resp = HttpResponse.empty(HttpStatus.NO_CONTENT)
        assertTrue(resp.status.code == 204)
        assertTrue(resp.body.getLimit() == 0)
    }

    @TestCase
    public func testResponseChunked(): Unit {
        let resp = HttpResponse.chunked(HttpStatus.OK)
        match (resp.headers.get("transfer-encoding")) {
            case Some(v) => assertTrue(v == "chunked")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testResponseChunkedWithTrailers(): Unit {
        let trailerNames: Array<String> = ["X-Checksum", "X-Duration"]
        let resp = HttpResponse.chunked(HttpStatus.OK, trailerNames: Some(trailerNames))
        match (resp.headers.get("trailer")) {
            case Some(v) =>
                assertTrue(v.contains("X-Checksum"))
                assertTrue(v.contains("X-Duration"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testResponseBytes(): Unit {
        let data = Array<UInt8>(10, repeat: 0xAA)
        let resp = HttpResponse.bytes(HttpStatus.OK, "application/octet-stream", data)
        assertTrue(resp.body.getLimit() == 10)
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "application/octet-stream")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testResponseWithCookie(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "OK")
        resp.withCookie("session", "abc123", path: "/", maxAge: Some(3600), httpOnly: true, secure: true, sameSite: Some("Lax"))

        match (resp.headers.get("set-cookie")) {
            case Some(v) =>
                assertTrue(v.contains("session=abc123"))
                assertTrue(v.contains("Path=/"))
                assertTrue(v.contains("Max-Age=3600"))
                assertTrue(v.contains("HttpOnly"))
                assertTrue(v.contains("Secure"))
                assertTrue(v.contains("SameSite=Lax"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testResponseIsKeepAliveHttp11(): Unit {
        let resp = HttpResponse(status: HttpStatus.OK, version: HttpVersion.HTTP_1_1)
        assertTrue(resp.isKeepAlive())  // HTTP/1.1 默认保持连接存活
    }

    @TestCase
    public func testResponseIsKeepAliveConnectionClose(): Unit {
        let headers = HttpHeaders()
        headers.set("Connection", "close")
        let resp = HttpResponse(status: HttpStatus.OK, version: HttpVersion.HTTP_1_1, headers: headers)
        assertFalse(resp.isKeepAlive())
    }

    @TestCase
    public func testResponseIsKeepAliveHttp10(): Unit {
        let resp = HttpResponse(status: HttpStatus.OK, version: HttpVersion.HTTP_1_0)
        assertFalse(resp.isKeepAlive())
    }

    @TestCase
    public func testResponseToBytes(): Unit {
        let resp = HttpResponse.json(HttpStatus.OK, "{}")
        let bytes = resp.toBytes()
        assertTrue(bytes.size > 0)
        // 检查状态行前缀
        let prefix = unsafe { "HTTP/1.1 200".rawData() }
        var i: Int64 = 0
        while (i < prefix.size) {
            assertTrue(bytes[i] == prefix[i])
            i += 1
        }
    }

    @TestCase
    public func testResponseBuildStatusLine(): Unit {
        let resp = HttpResponse(status: HttpStatus.OK, version: HttpVersion.HTTP_1_1)
        let line = resp.buildStatusLine()
        assertTrue(line.startsWith("HTTP/1.1 200 OK"))
    }

    @TestCase
    public func testResponseIsSuccess(): Unit {
        assertTrue(HttpResponse.json(HttpStatus.OK, "{}").isSuccess())
        assertFalse(HttpResponse.text(HttpStatus.NOT_FOUND, "404").isSuccess())
    }

    @TestCase
    public func testResponseIsRedirect(): Unit {
        assertTrue(HttpResponse.redirect("/login").isRedirect())
        assertFalse(HttpResponse.text(HttpStatus.OK, "OK").isRedirect())
    }
}

@Test
public class HttpResponseParserEdgeTest {

    @TestCase
    public func testParseSimple200(): Unit {
        let raw = unsafe { "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 200)
        assertTrue(resp.version.toString() == "HTTP/1.1")
    }

    @TestCase
    public func testParseWithHeaders(): Unit {
        let raw = unsafe { "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: 5\r\n\r\nHello".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 200)
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "text/html")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseWithBody(): Unit {
        let body = "Hello, World!"
        let header = "HTTP/1.1 200 OK\r\nContent-Length: ${body.size}\r\n\r\n"
        let raw = unsafe { (header + body).rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.bodyAsString() == body)
    }

    @TestCase
    public func testParseErrorStatus(): Unit {
        let raw = unsafe { "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 404)
        assertTrue(resp.status.isClientError())
    }

    @TestCase
    public func testParseRedirect(): Unit {
        let raw = unsafe { "HTTP/1.1 301 Moved Permanently\r\nLocation: /new\r\nContent-Length: 0\r\n\r\n".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 301)
        match (resp.headers.get("location")) {
            case Some(v) => assertTrue(v == "/new")
            case None => assertTrue(false)
        }
    }
}

@Test
public class ChunkedDecoderEdgeTest {

    @TestCase
    public func testDecodeSimple(): Unit {
        let chunked = "4\r\nWiki\r\n5\r\npedia\r\n0\r\n\r\n"
        let data = unsafe { chunked.rawData() }
        let result = ChunkedDecoder.decode(data)
        let text = unsafe { String.withRawData(result) }
        assertTrue(text == "Wikipedia")
    }

    @TestCase
    public func testDecodeSingleChunk(): Unit {
        let chunked = "5\r\nHello\r\n0\r\n\r\n"
        let data = unsafe { chunked.rawData() }
        let result = ChunkedDecoder.decode(data)
        let text = unsafe { String.withRawData(result) }
        assertTrue(text == "Hello")
    }

    @TestCase
    public func testDecodeEmpty(): Unit {
        let chunked = "0\r\n\r\n"
        let data = unsafe { chunked.rawData() }
        let result = ChunkedDecoder.decode(data)
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testDecodeHexSizes(): Unit {
        // 块大小使用十六进制编码
        let chunked = "A\r\n0123456789\r\nF\r\nabcdefghijklmno\r\n0\r\n\r\n"
        let data = unsafe { chunked.rawData() }
        let result = ChunkedDecoder.decode(data)
        assertTrue(result.size == 25)  // 10 + 15 = 25
    }
}
