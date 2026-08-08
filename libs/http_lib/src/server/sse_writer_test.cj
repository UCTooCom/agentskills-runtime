package http_lib.server

import http_lib.core.{assertTrue, assertFalse, HttpStatus}
import http_lib.message.HttpResponse
import http_lib.connection.MockConnection

@Test
public class SSEWriterTest {

    @TestCase
    public func testCreateSSEWriter(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        assertTrue(!sse.isClosed())
    }

    @TestCase
    public func testSendData(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        sse.sendData("hello world")
        // Content-Type 应设置为 text/event-stream
        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "text/event-stream")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testSendEvent(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        sse.sendEvent("message", "hello", id: "1")
        assertTrue(!sse.isClosed())
    }

    @TestCase
    public func testSendEventWithoutId(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        sse.sendEvent("update", "some data")
        assertTrue(!sse.isClosed())
    }

    @TestCase
    public func testClose(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        assertFalse(sse.isClosed())
        sse.close()
        assertTrue(sse.isClosed())
    }

    @TestCase
    public func testClosePreventsFurtherSends(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        sse.close()
        // 关闭时不应崩溃
        sse.sendData("should not send")
        assertTrue(sse.isClosed())
    }

    @TestCase
    public func testMultipleEvents(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        sse.sendData("first")
        sse.sendEvent("update", "second", id: "2")
        sse.sendData("third")
        assertTrue(!sse.isClosed())
    }

    @TestCase
    public func testDataWithNewlines(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        // 带换行符的数据应分割为多个 data: 行
        sse.sendData("line1\nline2\nline3")
        assertTrue(!sse.isClosed())
    }

    @TestCase
    public func testHeadersSetCorrectly(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)

        match (resp.headers.get("content-type")) {
            case Some(v) => assertTrue(v == "text/event-stream")
            case None => assertTrue(false)
        }
        match (resp.headers.get("cache-control")) {
            case Some(v) => assertTrue(v == "no-cache")
            case None => assertTrue(false)
        }
        match (resp.headers.get("connection")) {
            case Some(v) => assertTrue(v == "keep-alive")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testEmptyData(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        sse.sendData("")
        assertTrue(!sse.isClosed())
    }

    @TestCase
    public func testSendComment(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        sse.sendComment("this is a comment")
        assertTrue(!sse.isClosed())
    }

    @TestCase
    public func testSendRetry(): Unit {
        let resp = HttpResponse.text(HttpStatus.OK, "")
        let mockConn = MockConnection([])
        let sse = SSEWriter(resp, mockConn)
        sse.sendRetry(3000)
        assertTrue(!sse.isClosed())
    }
}
