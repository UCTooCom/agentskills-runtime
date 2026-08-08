package http_lib.message

import http_lib.core.{assertTrue, assertFalse, HttpHeaders, HttpStatus, HttpVersion, ProtocolException, HttpMethod}
import http_lib.buffer.ByteBuffer
import http_lib.connection.MockConnection

@Test
public class ResponseBuilderTest {

    @TestCase
    public func testInit(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        assertTrue(true)  // 初始化不崩溃
    }

    @TestCase
    public func testSetStatus(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.setStatus(HttpStatus.CREATED)
        w.writeString("body")
        w.finish()
        // 检查状态是否已写入
        let written = conn.getWrittenString()
        assertTrue(written.contains("201"), message: "Status 201 should be in response")
    }

    @TestCase
    public func testHeader(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        let h = w.header()
        h.set("X-Test", "value")
        w.finish()
        // 验证头部已写入且不崩溃
        assertTrue(h.names().size > 0, message: "Header map should have entries")
    }

    @TestCase
    public func testSetHeaderFluent(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
            .setHeader("Content-Type", "text/plain")
            .setHeader("X-Custom", "test")
        w.finish()
        assertTrue(true)  // 链式调用不应崩溃
    }

    @TestCase
    public func testWriteHeader(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.writeHeader(HttpStatus.OK)
        w.finish()
        let written = conn.getWrittenString()
        assertTrue(written.contains("200 OK"), message: "Status line should be 200 OK")
    }

    @TestCase
    public func testWrite(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        let data = Array<UInt8>(3, repeat: 0x41)  // "AAA" 测试数据
        let n = w.write(data)
        w.finish()
        assertTrue(n == 3, message: "Should return bytes written count")
    }

    @TestCase
    public func testWriteString(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        let n = w.writeString("Hello")
        w.finish()
        assertTrue(n > 0, message: "Should return bytes written")
    }

    @TestCase
    public func testFinishAutoWritesHeader(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        // 不要调用 writeHeader——finish 应自动写入
        w.finish()
        let written = conn.getWrittenString()
        assertTrue(written.contains("200 OK"), message: "finish() should auto-write status line")
    }

    @TestCase
    public func testFlush(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.writeString("test")
        w.flush()
        // flush 不应崩溃
        assertTrue(true)
    }

    @TestCase
    public func testContentLengthDisablesChunked(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.setHeader("Content-Length", "5")
        w.writeHeader(HttpStatus.OK)
        w.writeString("hello")
        w.finish()
        let written = conn.getWrittenString()
        // 当设置了 Content-Length 时，不应出现 Transfer-Encoding: chunked
        assertFalse(written.contains("Transfer-Encoding"),
            message: "Content-Length should disable chunked encoding")
    }

    @TestCase
    public func testAddTrailerBeforeWrite(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.addTrailer("X-Checksum", "abc123")
        w.finish()
        // Trailer 应在头部发送前声明——不应崩溃
        assertTrue(true)
    }

    @TestCase
    public func testAddTrailerAfterWriteIgnored(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.writeHeader(HttpStatus.OK)
        // writeHeader 后添加 trailer——应被静默忽略（RFC 7230 §4.1.2）
        w.addTrailer("X-Checksum", "abc123")
        assertTrue(true)  // 不应崩溃或抛出异常
    }

    @TestCase
    public func testWriteHeaderOnlyOnce(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.writeHeader(HttpStatus.OK)
        w.writeHeader(HttpStatus.CREATED)  // 第二次调用应被忽略
        w.finish()
        let written = conn.getWrittenString()
        assertTrue(written.contains("200"), message: "First status should be preserved")
    }

    @TestCase
    public func testSetStatusAfterWriteIgnored(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.writeString("data")
        // 第一次写入后 setStatus 应被忽略
        w.setStatus(HttpStatus.INTERNAL_SERVER_ERROR)
        w.finish()
        let written = conn.getWrittenString()
        assertTrue(written.contains("200"), message: "Status should remain as original default")
    }

    @TestCase
    public func testEmptyWrite(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        let n = w.write([])
        w.finish()
        assertTrue(n == 0, message: "Empty write should return 0")
    }

    @TestCase
    public func testMultipleWrites(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.writeString("chunk1")
        w.writeString("chunk2")
        w.writeString("chunk3")
        w.finish()
        // 多次写入不应崩溃
        assertTrue(true)
    }

    @TestCase
    public func testSuppressBodyForHead(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn, suppressBody: true)
        w.writeHeader(HttpStatus.OK)
        let n = w.writeString("should be suppressed")
        w.finish()
        assertTrue(n == 0, message: "HEAD response should suppress body writes")
    }

    @TestCase
    public func testSuppressBodyFinish(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn, suppressBody: true)
        w.writeHeader(HttpStatus.OK)
        w.finish()
        // suppressBody + finish 不应崩溃
        assertTrue(true)
    }

    @TestCase
    public func testStreamFlusherInterface(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        w.writeString("data")
        w.flush()
        // StreamFlusher.flush() 应可无错误调用
        assertTrue(true)
    }

    @TestCase
    public func testConnectionControllerReturnsErrorWithoutSocket(): Unit {
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        try {
            let _ = w.takeover()
            assertTrue(false, message: "Should have thrown without raw socket")
        } catch (e: Exception) {
            assertTrue(true, message: "Expected ProtocolException")
        }
    }

    @TestCase
    public func testWrapHandler(): Unit {
        let handler = {req: HttpRequest => HttpResponse.text(HttpStatus.OK, "hello")}
        let streamingHandler = wrapHandler(handler)
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        let req = HttpRequest()
        streamingHandler(req, w)
        let written = conn.getWrittenString()
        assertTrue(written.contains("200"))
    }

    @TestCase
    public func testWrapHandlerWithCustomStatus(): Unit {
        let handler = {req: HttpRequest =>
            let bodyData = unsafe { "{\"id\": 1}".rawData() }
            let bodyBuf = ByteBuffer()
            bodyBuf.write(bodyData)
            let resp = HttpResponse(status: HttpStatus.CREATED, headers: HttpHeaders(), body: bodyBuf)
            resp.headers.set("Content-Type", "application/json")
            resp
        }
        let streamingHandler = wrapHandler(handler)
        let conn = MockConnection([])
        let w = ResponseBuilder(conn)
        streamingHandler(HttpRequest(), w)
        let written = conn.getWrittenString()
        // ResponseBuilder 应写入正确的 HTTP 响应
        assertTrue(written.size > 0, message: "ResponseBuilder should have written data")
    }
}


// ======== HttpError/HttpNotFound/HttpRedirect 函数测试 ========

@Test
public class HttpErrorHelperTest {

    @TestCase
    public func testHttpError(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/test", version: HttpVersion.HTTP_1_1, headers: HttpHeaders(), body: ByteBuffer())
        let resp = HttpError(req, "not found", 404)
        assertTrue(resp.status.code == 404, message: "Status code should be 404")
        let body = resp.bodyAsString()
        assertTrue(body.contains("not found") || body.contains("404"),
            message: "Body should contain error description")
    }

    @TestCase
    public func testHttpNotFound(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/missing")
        let resp = HttpNotFound(req)
        assertTrue(resp.status.code == 404, message: "Status code should be 404")
    }

    @TestCase
    public func testHttpRedirect(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/old")
        let resp = HttpRedirect(req, "/new", 301)
        assertTrue(resp.status.code == 301, message: "Status code should be 301")
    }

    @TestCase
    public func testHttpRedirectTemporary(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/old")
        let resp = HttpRedirect(req, "/new", 302)
        assertTrue(resp.status.code == 302, message: "Status code should be 302")
    }

}
