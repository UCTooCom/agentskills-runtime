package http_lib.message

import http_lib.buffer.ByteBuffer
import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion}
import http_lib.connection.Connection
import http_lib.utils.{findHeaderEnd, findCrlf, findByte, skipSpaces, trimEnd, containsIgnoreCase}

/**
 * 测试 ChunkedWriter - 将数据编码为分块传输编码。
 */
@Test
public class ChunkedWriterTest {

    @TestCase
    public func testChunkTerminator(): Unit {
        let term = ChunkedWriter.chunkTerminator()
        assertTrue(term.size == 5)
        assertTrue(term[0] == b'0')
        assertTrue(term[1] == b'\r')
        assertTrue(term[2] == b'\n')
        assertTrue(term[3] == b'\r')
        assertTrue(term[4] == b'\n')
    }

    @TestCase
    public func testEncodeChunkedEmpty(): Unit {
        let data: Array<UInt8> = []
        let encoded = ChunkedWriter.encodeChunked(data)
        // 应仅返回结束标记："0\r\n\r\n"
        assertTrue(encoded.size == 5)
    }

    @TestCase
    public func testEncodeChunkedSmall(): Unit {
        let data = unsafe { "Hello".rawData() }
        let encoded = ChunkedWriter.encodeChunked(data)
        // 应为："5\r\nHello\r\n0\r\n\r\n"
        assertTrue(encoded.size > 5)  // 大于仅终结符
        // 检查是否以十六进制大小开头
        assertTrue(encoded[0] == b'5')
        assertTrue(encoded[1] == b'\r')
        assertTrue(encoded[2] == b'\n')
    }

    @TestCase
    public func testEncodeChunkedRoundTrip(): Unit {
        let data = unsafe { "Wikipedia".rawData() }
        let encoded = ChunkedWriter.encodeChunked(data)
        let decoded = ChunkedDecoder.decode(encoded)
        let text = unsafe { String.withRawData(decoded) }
        assertTrue(text == "Wikipedia")
    }

    @TestCase
    public func testEncodeChunkedLargerDataRoundTrip(): Unit {
        // 构建 1KB 数据
        let data = Array<UInt8>(1024, repeat: 0x41)
        let encoded = ChunkedWriter.encodeChunked(data)
        let decoded = ChunkedDecoder.decode(encoded)
        assertTrue(decoded.size == data.size)
    }
}

/**
 * 测试请求解析器边界情况。
 */
@Test
public class RequestParserEdgeTest {

    @TestCase
    public func testParseSimpleGetRequest(): Unit {
        let raw = unsafe { "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n".rawData() }
        let req = HttpRequestParser.parse(raw)
        assertTrue(req.method == HttpMethod.GET)
        assertTrue(req.url == "/")
        assertTrue(req.version == HttpVersion.HTTP_1_1)
    }

    @TestCase
    public func testParsePostRequest(): Unit {
        let body = "name=test"
        let header = "POST /submit HTTP/1.1\r\nHost: example.com\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: ${body.size}\r\n\r\n"
        let raw = unsafe { (header + body).rawData() }
        let req = HttpRequestParser.parse(raw)
        assertTrue(req.method == HttpMethod.POST)
        assertTrue(req.url == "/submit")
        assertTrue(req.body.getLimit() == body.size)
    }

    @TestCase
    public func testParseRequestWithHeaders(): Unit {
        let raw = unsafe {
            "GET /api HTTP/1.1\r\nHost: api.example.com\r\nAccept: application/json\r\nAuthorization: Bearer secret\r\n\r\n".rawData()
        }
        let req = HttpRequestParser.parse(raw)
        match (req.headers.get("host")) {
            case Some(v) => assertTrue(v == "api.example.com")
            case None => assertTrue(false)
        }
        match (req.headers.get("accept")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
        match (req.headers.get("authorization")) {
            case Some(v) => assertTrue(v == "Bearer secret")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testParseRequestPutPatchDeleteMethods(): Unit {
        let methods = [
            ("PUT", HttpMethod.PUT),
            ("PATCH", HttpMethod.PATCH),
            ("DELETE", HttpMethod.DELETE),
            ("HEAD", HttpMethod.HEAD),
            ("OPTIONS", HttpMethod.OPTIONS),
        ]
        for ((methodStr, expectedMethod) in methods) {
            let raw = unsafe { "${methodStr} / HTTP/1.1\r\nHost: test\r\n\r\n".rawData() }
            let req = HttpRequestParser.parse(raw)
            assertTrue(req.method == expectedMethod, message: "Expected ${expectedMethod} for method ${methodStr}")
        }
    }

    @TestCase
    public func testFindHeaderEnd(): Unit {
        let raw = unsafe { "GET / HTTP/1.1\r\nHost: test\r\n\r\nBody".rawData() }
        let end = findHeaderEnd(raw, raw.size)
        assertTrue(end > 0)
    }

    @TestCase
    public func testFindHeaderEndNotFound(): Unit {
        let raw = unsafe { "GET / HTTP/1.1\r\nHost: test\r\n".rawData() }  // 无终结符 \r\n
        let end = findHeaderEnd(raw, raw.size)
        assertTrue(end < 0)
    }

    @TestCase
    public func testFindCrlf(): Unit {
        let raw = unsafe { "Line\r\n".rawData() }
        let pos = findCrlf(raw, raw.size)
        assertTrue(pos == 4)  // "Line" 占 4 字节
    }

    @TestCase
    public func testFindByteFound(): Unit {
        let raw = unsafe { "key: value".rawData() }
        let pos = findByte(raw, 0, raw.size, b':')
        assertTrue(pos == 3)
    }

    @TestCase
    public func testFindByteNotFound(): Unit {
        let raw = unsafe { "no colon here".rawData() }
        let pos = findByte(raw, 0, raw.size, b':')
        assertTrue(pos < 0)
    }

    @TestCase
    public func testSkipSpaces(): Unit {
        let raw = unsafe { "   value".rawData() }
        let pos = skipSpaces(raw, 0, raw.size)
        assertTrue(pos == 3)  // 跳过 3 个空格
    }

    @TestCase
    public func testTrimEnd(): Unit {
        let raw = unsafe { "value  ".rawData() }
        let end = trimEnd(raw, 0, raw.size)
        assertTrue(end == 5)  // "value" 占 5 字节
    }

    @TestCase
    public func testParseHeaders(): Unit {
        let raw = unsafe { "Content-Type: text/html\r\nX-Custom: value\r\n\r\n".rawData() }
        // 使用 findHeaderEnd 定位头部边界
        let headerEnd = findHeaderEnd(raw, raw.size)
        let headers = parseHeaders(raw, 0, headerEnd)
        match (headers.get("content-type")) {
            case Some(v) => assertTrue(v == "text/html")
            case None => assertTrue(false)
        }
        match (headers.get("x-custom")) {
            case Some(v) => assertTrue(v == "value")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testContainsIgnoreCase(): Unit {
        let data = unsafe { "Transfer-Encoding: chunked".rawData() }
        let needle = "chunked".toRuneArray()
        assertTrue(containsIgnoreCase(data, needle))
    }

    @TestCase
    public func testContainsIgnoreCaseNotFound(): Unit {
        let data = unsafe { "Transfer-Encoding: gzip".rawData() }
        let needle = "chunked".toRuneArray()
        assertFalse(containsIgnoreCase(data, needle))
    }
}

/**
 * 测试响应解析器边界情况。
 */
@Test
public class ResponseParserEdgeTest {

    @TestCase
    public func testParseResponse500(): Unit {
        let raw = unsafe { "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 500)
        assertTrue(resp.status.isServerError())
    }

    @TestCase
    public func testParseChunkedResponse(): Unit {
        // 带 Transfer-Encoding: chunked 的响应
        let raw = unsafe {
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n0\r\n\r\n".rawData()
        }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 200)
        let body = resp.bodyAsString()
        assertTrue(body.contains("Hello"))
    }

    @TestCase
    public func testParseHttp10Response(): Unit {
        let raw = unsafe { "HTTP/1.0 200 OK\r\nContent-Length: 0\r\n\r\n".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.version == HttpVersion.HTTP_1_0)
    }
}
