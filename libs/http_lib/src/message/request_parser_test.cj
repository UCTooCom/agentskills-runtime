package http_lib.message
import http_lib.core.{assertTrue, assertFalse, ProtocolException, HttpMethod, HttpHeaders}
import http_lib.utils.{findHeaderEnd, findCrlf, findByte, skipSpaces, trimEnd, containsIgnoreCase}

@Test
public class RequestParserTest {
    @TestCase
    public func testParseSimpleGet(): Unit {
        let raw = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"
        let req = HttpRequestParser.parse(unsafe { raw.rawData() })
        assertTrue(req.method == HttpMethod.GET)
        assertTrue(req.url == "/")
        assertTrue(req.version.toString() == "HTTP/1.1")
        match (req.headers.get("host")) {
            case Some(v) => assertTrue(v == "example.com")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParsePostWithBody(): Unit {
        let body = "hello=world"
        let raw = "POST /api HTTP/1.1\r\nHost: example.com\r\nContent-Length: ${body.size}\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\n${body}"
        let req = HttpRequestParser.parse(unsafe { raw.rawData() })
        assertTrue(req.method == HttpMethod.POST)
        assertTrue(req.url == "/api")
        assertTrue(req.bodyAsString() == body)
    }

    @TestCase
    public func testParseHeaders(): Unit {
        let raw = "GET /path HTTP/1.0\r\nHost: a.com\r\nUser-Agent: test\r\nAccept: */*\r\n\r\n"
        let req = HttpRequestParser.parse(unsafe { raw.rawData() })
        match (req.headers.get("host")) {
            case Some(v) => assertTrue(v == "a.com")
            case None => assertTrue(false)
        }
        match (req.headers.get("user-agent")) {
            case Some(v) => assertTrue(v == "test")
            case None => assertTrue(false)
        }
        match (req.headers.get("accept")) {
            case Some(v) => assertTrue(v == "*/*")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseMultipleHeaderValues(): Unit {
        let raw = "GET / HTTP/1.1\r\nX-Custom: val1\r\nX-Custom: val2\r\n\r\n"
        let req = HttpRequestParser.parse(unsafe { raw.rawData() })
        let all = req.headers.getAll("x-custom")
        assertTrue(all.size == 2)
        assertTrue(all[0] == "val1")
        assertTrue(all[1] == "val2")
    }

    @TestCase
    public func testParseEmptyRequestThrows(): Unit {
        try {
            HttpRequestParser.parse([])
            assertTrue(false)
        } catch (e: ProtocolException) {
            assertTrue(e.message.size > 0)
        }
    }

    @TestCase
    public func testParseIncompleteHeadersThrows(): Unit {
        try {
            HttpRequestParser.parse(unsafe { "GET / HTTP/1.1\r\nHost: a".rawData() })
            assertTrue(false)
        } catch (e: ProtocolException) {
            assertTrue(e.message.size > 0)
        }
    }

    @TestCase
    public func testFindHeaderEnd(): Unit {
        let data = "Header1: value\r\n\r\nbody"
        let bytes = unsafe { data.rawData() }
        let end = findHeaderEnd(bytes, bytes.size)
        assertTrue(end > 0)
    }

    @TestCase
    public func testFindCrlf(): Unit {
        let data = "abc\r\ndef"
        let bytes = unsafe { data.rawData() }
        let pos = findCrlf(bytes, bytes.size)
        assertTrue(pos == 3)
    }

    @TestCase
    public func testParseHttp10Request(): Unit {
        let raw = "GET /old HTTP/1.0\r\nHost: legacy.com\r\n\r\n"
        let req = HttpRequestParser.parse(unsafe { raw.rawData() })
        assertTrue(req.version.toString() == "HTTP/1.0")
        assertTrue(req.url == "/old")
    }

    @TestCase
    public func testParseChunkedTransferEncoding(): Unit {
        let chunkedBody = "5\r\nHello\r\n0\r\n\r\n"
        let raw = "POST /data HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\nContent-Type: text/plain\r\n\r\n${chunkedBody}"
        let req = HttpRequestParser.parse(unsafe { raw.rawData() })
        assertTrue(req.method == HttpMethod.POST)
        // Transfer-Encoding chunked 应被检测到
        assertTrue(req.bodyAsString() == "Hello")
    }

    @TestCase
    public func testParseLargeHeadersThrows(): Unit {
        var raw = "GET / HTTP/1.1\r\n"
        var i: Int64 = 0
        while (i < 6000) {
            raw += "X-H${i}: v${i}\r\n"
            i += 1
        }
        raw += "\r\n"
        try {
            HttpRequestParser.parse(unsafe { raw.rawData() })
            assertTrue(false)
        } catch (e: ProtocolException) {
            assertTrue(e.message.size > 0)
        }
    }

    @TestCase
    public func testFindHeaderEndNoMatch(): Unit {
        let data = "Header1: value\r\nHeader2: value2"
        let bytes = unsafe { data.rawData() }
        let end = findHeaderEnd(bytes, bytes.size)
        assertTrue(end == -1)
    }

    @TestCase
    public func testFindByte(): Unit {
        let data = "abc:def"
        let bytes = unsafe { data.rawData() }
        let pos = findByte(bytes, 0, bytes.size, b':')
        assertTrue(pos == 3)
    }

    @TestCase
    public func testSkipSpaces(): Unit {
        let data = "   hello"
        let bytes = unsafe { data.rawData() }
        let pos = skipSpaces(bytes, 0, bytes.size)
        assertTrue(pos == 3)
    }

    @TestCase
    public func testTrimEndNoChangeWhenNoWhitespace(): Unit {
        let data = "hello"
        let bytes = unsafe { data.rawData() }
        let trimmed = trimEnd(bytes, 0, bytes.size)
        assertTrue(trimmed == bytes.size)
    }

    @TestCase
    public func testTrimEndNoTrailing(): Unit {
        let data = "header: value"
        let bytes = unsafe { data.rawData() }
        let trimmed = trimEnd(bytes, 0, bytes.size)
        assertTrue(trimmed == bytes.size,
            message: "No trailing whitespace should not change length")
    }

    @TestCase
    public func testTrimEndTrailingSpaces(): Unit {
        let data = "header: value   "
        let bytes = unsafe { data.rawData() }
        let trimmed = trimEnd(bytes, 0, bytes.size)
        let result = String.fromUtf8(bytes[0..trimmed])
        assertTrue(result == "header: value",
            message: "Trailing spaces should be trimmed, got '${result}'")
    }

    @TestCase
    public func testTrimEndTrailingTab(): Unit {
        let data = "header: value\t"
        let bytes = unsafe { data.rawData() }
        let trimmed = trimEnd(bytes, 0, bytes.size)
        let result = String.fromUtf8(bytes[0..trimmed])
        assertTrue(result == "header: value",
            message: "Trailing tab should be trimmed")
    }

    @TestCase
    public func testContainsIgnoreCaseMatch(): Unit {
        let data = "Content-Type: text/html"
        let bytes = unsafe { data.rawData() }
        let needle = "content-type".toRuneArray()
        assertTrue(containsIgnoreCase(bytes, needle),
            message: "Should find case-insensitive match")
    }

    @TestCase
    public func testContainsIgnoreCaseNoMatch(): Unit {
        let data = "Content-Type: text/html"
        let bytes = unsafe { data.rawData() }
        let needle = "accept".toRuneArray()
        assertFalse(containsIgnoreCase(bytes, needle),
            message: "Should not find non-matching needle")
    }

    @TestCase
    public func testContainsIgnoreCasePartialMatch(): Unit {
        let data = "Content-Type: text/html"
        let bytes = unsafe { data.rawData() }
        let needle = "text/html".toRuneArray()
        assertTrue(containsIgnoreCase(bytes, needle),
            message: "Should find partial match within value")
    }

    @TestCase
    public func testParseBodyWithContentLength(): Unit {
        let bodyStr = "Hello, HTTP Body!"
        let bodyBytes = unsafe { bodyStr.rawData() }
        let headers = HttpHeaders()
        headers.set("Content-Length", "${bodyStr.size}")
        let result = parseBody(bodyBytes, 0, bodyStr.size, headers, HttpMethod.POST)
        let resultStr = String.fromUtf8(result.toArray())
        assertTrue(resultStr == bodyStr,
            message: "Body should match input, got '${resultStr}'")
    }

    @TestCase
    public func testParseBodyEmpty(): Unit {
        let headers = HttpHeaders()
        let result = parseBody([], 0, 0, headers, HttpMethod.GET)
        assertTrue(result.getLimit() == 0,
            message: "Empty body should produce empty result")
    }

    @TestCase
    public func testMultipleTransferEncodingHeaders(): Unit {
        let raw = "POST / HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\nTransfer-Encoding: identity\r\n\r\n5\r\nHello\r\n0\r\n\r\n"
        try {
            let data = unsafe { raw.rawData() }
            let req = HttpRequestParser.parse(data)
            assertTrue(false, message: "Multiple TE headers should throw")
        } catch (e: ProtocolException) {
            assertTrue(e.message.size > 0)
        }
    }

    @TestCase
    public func testCommaSeparatedTransferEncoding(): Unit {
        let raw = "POST / HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked, gzip\r\n\r\n5\r\nHello\r\n0\r\n\r\n"
        try {
            let data = unsafe { raw.rawData() }
            let req = HttpRequestParser.parse(data)
            assertTrue(false, message: "Comma-separated TE should throw")
        } catch (e: ProtocolException) {
            assertTrue(e.message.size > 0)
        }
    }

    @TestCase
    public func testConflictingContentLengthHeaders(): Unit {
        let raw = "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 5\r\nContent-Length: 10\r\n\r\nHello"
        try {
            let data = unsafe { raw.rawData() }
            let req = HttpRequestParser.parse(data)
            assertTrue(false, message: "Different CL values should throw")
        } catch (e: ProtocolException) {
            assertTrue(e.message.size > 0)
        }
    }

    @TestCase
    public func testDuplicateContentLengthHeadersSameValue(): Unit {
        let raw = "POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 5\r\nContent-Length: 5\r\n\r\nHello"
        try {
            let data = unsafe { raw.rawData() }
            let req = HttpRequestParser.parse(data)
            assertTrue(req.bodyAsString() == "Hello")
        } catch (e: Exception) {
            assertTrue(false, message: "Dup CL same value should be accepted")
        }
    }

    @TestCase
    public func testTransferEncodingAndContentLength(): Unit {
        let raw = "POST / HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\nContent-Length: 5\r\n\r\n5\r\nHello\r\n0\r\n\r\n"
        try {
            let data = unsafe { raw.rawData() }
            let req = HttpRequestParser.parse(data)
            assertTrue(false, message: "TE + CL should throw")
        } catch (e: ProtocolException) {
            assertTrue(e.message.size > 0)
        }
    }

    @TestCase
    public func testChunkedTransferEncodingValid(): Unit {
        let chunkedBody = "5\r\nHello\r\n0\r\n\r\n"
        let raw = "POST /data HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\nContent-Type: text/plain\r\n\r\n" + chunkedBody
        let data = unsafe { raw.rawData() }
        let req = HttpRequestParser.parse(data)
        assertTrue(req.bodyAsString() == "Hello")
    }
}
