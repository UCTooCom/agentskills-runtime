package http_lib.message

import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion}

/**
 * 消息解析、序列化、分块编码、内容协商基准测试。
 */
@Test public class MessageBench {
    @Bench
    public func requestParseGet(): Unit {
        let raw = "GET /api/v1/users/123?page=1&limit=10 HTTP/1.1\r\nHost: example.com\r\nUser-Agent: benchmark\r\nAccept: application/json\r\n\r\n"
        let bytes = unsafe { raw.rawData() }
        try { let _ = HttpRequestParser.parse(bytes) } catch (_: Exception) {}
    }

    @Bench
    public func requestParsePost(): Unit {
        let body = "key1=value1&key2=value2&key3=value3"
        let raw = "POST /submit HTTP/1.1\r\nHost: example.com\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: ${body.size}\r\n\r\n${body}"
        let bytes = unsafe { raw.rawData() }
        try { let _ = HttpRequestParser.parse(bytes) } catch (_: Exception) {}
    }

    @Bench
    public func responseParseJson(): Unit {
        let raw = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 17\r\nDate: Mon, 15 Jan 2024 12:30:45 GMT\r\n\r\n{\"status\":\"ok\"}"
        let bytes = unsafe { raw.rawData() }
        try { let _ = HttpResponseParser.parse(bytes) } catch (_: Exception) {}
    }

    @Bench
    public func requestToBytes(): Unit {
        let headers = HttpHeaders()
        headers.set("Host", "example.com")
        headers.set("User-Agent", "test/1.0")
        headers.set("Accept", "text/html")
        let bodyBytes = Array<UInt8>(100, repeat: 0x41)
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        let req = HttpRequest(method: HttpMethod.POST, url: "/path/to/resource",
            version: HttpVersion.HTTP_1_1, headers: headers, body: body)
        let _ = req.toBytes()
    }

    @Bench
    public func responseToBytes(): Unit {
        let headers = HttpHeaders()
        headers.set("Content-Type", "application/json")
        headers.set("Cache-Control", "no-cache")
        let bodyData = unsafe { "{\"key\":\"value\",\"number\":42}".rawData() }
        let body = ByteBuffer(capacity: bodyData.size)
        body.write(bodyData)
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers, body: body)
        let _ = resp.toBytes()
    }

    @Bench
    public func responseStaticFactories(): Unit {
        let _ = HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")
        let _ = HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
        let _ = HttpResponse.html(HttpStatus.OK, "<html><body>Hello</body></html>")
        let _ = HttpResponse.empty(HttpStatus.NO_CONTENT)
        let _ = HttpResponse.redirect("/login")
        let _ = HttpResponse.bytes(HttpStatus.OK, "image/png", Array<UInt8>(100, repeat: 0x00))
    }

    @Bench
    public func bodyParseUrlEncoded(): Unit {
        let _ = BodyParser.parseUrlEncoded("field1=value1&field2=value2&field3=value3&name=John+Doe&email=john@example.com&page=1&limit=20")
    }

    @Bench
    public func selectContentType(): Unit {
        let _ = selectContentType(Some("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"),
            ["application/json", "text/html", "text/plain"])
    }

    @Bench
    public func selectContentEncoding(): Unit {
        let _ = selectContentEncoding(Some("gzip, deflate, br"), ["gzip", "deflate", "br", "identity"])
    }

    @Bench
    public func chunkedEncode(): Unit {
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o', b' ', b'W', b'o', b'r', b'l', b'd']
        let _ = ChunkedWriter.encodeChunked(data)
    }

    @Bench
    public func chunkedDecode(): Unit {
        let input = "4\r\nWiki\r\n5\r\npedia\r\nE\r\n in\r\n\r\nchunks.\r\n0\r\n\r\n"
        let bytes = unsafe { input.rawData() }
        let _ = ChunkedDecoder.decode(bytes)
    }
}
