package http_lib.message

import http_lib.buffer.ByteBuffer
import http_lib.core.{assertTrue, assertFalse, ProtocolException, HttpStatus}

/**
 * 测试 HttpResponseParser 主体帧划分（阶段 1A）。
 */
@Test
public class ResponseParserTest {
    /**
     * 带 Content-Length 主体的响应。
     */
    @TestCase
    public func testContentLengthBody(): Unit {
        let raw = unsafe { "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 200)
        assertTrue(resp.headers.get("content-length").isSome())
        assertTrue(resp.bodyAsString() == "hello")
    }

    /**
     * 带 Transfer-Encoding: chunked 主体的响应。
     */
    @TestCase
    public func testChunkedBody(): Unit {
        let raw = unsafe { "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 200)
        assertTrue(resp.bodyAsString() == "hello")
    }

    /**
     * 无主体响应（204 No Content）。
     */
    @TestCase
    public func testNoBodyFor204(): Unit {
        let raw = unsafe { "HTTP/1.1 204 No Content\r\nContent-Length: 5\r\n\r\nshouldnot".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 204)
        assertTrue(resp.body.toArray().size == 0)
    }

    /**
     * 无主体响应（304 Not Modified）。
     */
    @TestCase
    public func testNoBodyFor304(): Unit {
        let raw = unsafe { "HTTP/1.1 304 Not Modified\r\n\r\n".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 304)
        assertTrue(resp.body.toArray().size == 0)
    }

    /**
     * 带 Connection: close 的响应（HTTP/1.0 风格）。
     */
    @TestCase
    public func testConnectionCloseBody(): Unit {
        let raw = unsafe { "HTTP/1.0 200 OK\r\n\r\nsome legacy body".rawData() }
        let resp = HttpResponseParser.parse(raw)
        assertTrue(resp.status.code == 200)
        assertTrue(resp.bodyAsString() == "some legacy body")
    }

    /**
     * 空响应抛出 ProtocolException。
     */
    @TestCase
    public func testEmptyResponseThrows(): Unit {
        var threw = false
        try {
            HttpResponseParser.parse([])
        } catch (e: ProtocolException) {
            threw = true
        }
        assertTrue(threw)
    }
}
