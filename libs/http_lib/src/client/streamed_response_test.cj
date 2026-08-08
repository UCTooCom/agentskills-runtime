package http_lib.client

import http_lib.core.{assertTrue, assertFalse}
import http_lib.connection.MockConnection
import http_lib.core.{HttpMethod, HttpStatus, HttpVersion, HttpHeaders}
import http_lib.buffer.ByteBuffer

@Test
public class StreamedResponseTest {

    @TestCase
    public func testInitWithContentLength(): Unit {
        let bodyData = unsafe { "Hello, World!".rawData() }
        let conn = MockConnection(bodyData)
        let headers = HttpHeaders()
        headers.set("Content-Length", "13")
        let resp = StreamedHttpResponse(
            conn: conn, version: HttpVersion.HTTP_1_1,
            status: HttpStatus.OK, headers: headers,
            prefetchedData: []
        )
        assertFalse(resp.isClosed())
    }

    @TestCase
    public func testContentLengthRead(): Unit {
        let bodyData = unsafe { "Hello, World!".rawData() }
        let conn = MockConnection(bodyData)
        let headers = HttpHeaders()
        headers.set("Content-Length", "13")
        let resp = StreamedHttpResponse(
            conn: conn, version: HttpVersion.HTTP_1_1,
            status: HttpStatus.OK, headers: headers,
            prefetchedData: []
        )
        let buf = Array<UInt8>(64, repeat: 0)
        let n = resp.read(buf)
        assertTrue(n == 13)
        assertTrue(String.fromUtf8(buf[..13]) == "Hello, World!")
    }

    @TestCase
    public func testReadLineSimple(): Unit {
        let bodyData = unsafe { "line1\r\nline2\r\nline3\r\n".rawData() }
        let conn = MockConnection(bodyData)
        let headers = HttpHeaders()
        headers.set("Content-Length", "21")
        let resp = StreamedHttpResponse(
            conn: conn, version: HttpVersion.HTTP_1_1,
            status: HttpStatus.OK, headers: headers,
            prefetchedData: []
        )
        let line1 = resp.readLine()
        assertTrue(line1 == "line1")
        let line2 = resp.readLine()
        assertTrue(line2 == "line2")
        let line3 = resp.readLine()
        assertTrue(line3 == "line3")
        resp.close()
    }

    @TestCase
    public func testIsClosedAfterRead(): Unit {
        let bodyData = unsafe { "OK".rawData() }
        let conn = MockConnection(bodyData)
        let headers = HttpHeaders()
        headers.set("Content-Length", "2")
        let resp = StreamedHttpResponse(
            conn: conn, version: HttpVersion.HTTP_1_1,
            status: HttpStatus.OK, headers: headers,
            prefetchedData: []
        )
        let buf = Array<UInt8>(16, repeat: 0)
        let n1 = resp.read(buf)
        assertTrue(n1 == 2)
        let n2 = resp.read(buf)
        assertTrue(n2 == 0)
        resp.close()
        assertTrue(resp.isClosed())
    }

    @TestCase
    public func testReadWithPrefetchedData(): Unit {
        let prefetched = unsafe { "Hello ".rawData() }
        let moreData = unsafe { "World!".rawData() }
        let conn = MockConnection(moreData)
        let headers = HttpHeaders()
        headers.set("Content-Length", "12")
        let resp = StreamedHttpResponse(
            conn: conn, version: HttpVersion.HTTP_1_1,
            status: HttpStatus.OK, headers: headers,
            prefetchedData: prefetched
        )
        let buf = Array<UInt8>(64, repeat: 0)
        let n = resp.read(buf)
        assertTrue(n == 12)
        assertTrue(String.fromUtf8(buf[..12]) == "Hello World!")
    }

    @TestCase
    public func testDoubleCloseIsSafe(): Unit {
        let conn = MockConnection([])
        let resp = StreamedHttpResponse(
            conn: conn, version: HttpVersion.HTTP_1_1,
            status: HttpStatus.OK, headers: HttpHeaders(),
            prefetchedData: []
        )
        resp.close()
        resp.close()  // 不应崩溃
        assertTrue(resp.isClosed())
    }

    @TestCase
    public func testChunkedRead(): Unit {
        // 分块编码数据：\r\n5\r\nHello\r\n7\r\n World!\r\n0\r\n\r\n
        let chunkedData = unsafe { "5\r\nHello\r\n7\r\n World!\r\n0\r\n\r\n".rawData() }
        let conn = MockConnection(chunkedData)
        let headers = HttpHeaders()
        headers.set("Transfer-Encoding", "chunked")
        let resp = StreamedHttpResponse(
            conn: conn, version: HttpVersion.HTTP_1_1,
            status: HttpStatus.OK, headers: headers,
            prefetchedData: []
        )
        let buf = Array<UInt8>(64, repeat: 0)
        let n = resp.read(buf)
        assertTrue(n == 12)
        assertTrue(String.fromUtf8(buf[..n]) == "Hello World!")
    }
}
