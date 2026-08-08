package http_lib.message

import http_lib.core.{assertTrue, assertFalse}
import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpMethod, HttpStatus, HttpVersion, HttpHeaders}

@Test
public class DumpTest {

    @TestCase
    public func testDumpGetRequest(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "http://example.com/test")
        req.headers.set("Host", "example.com")
        req.headers.set("User-Agent", "test-agent")
        let result = dumpRequest(req)
        let resultStr = String.fromUtf8(result)
        assertTrue(resultStr.startsWith("GET http://example.com/test HTTP/1.1\r\n"))
        assertTrue(resultStr.contains("Host: example.com"))
        assertTrue(resultStr.contains("User-Agent: test-agent"))
    }

    @TestCase
    public func testDumpPostRequestWithBody(): Unit {
        let bodyBytes = unsafe { "hello=world".rawData() }
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        let req = HttpRequest(method: HttpMethod.POST, url: "http://example.com/post", body: body)
        req.headers.set("Content-Type", "application/x-www-form-urlencoded")
        let result = dumpRequest(req)
        let resultStr = String.fromUtf8(result)
        assertTrue(resultStr.startsWith("POST http://example.com/post HTTP/1.1\r\n"))
        assertTrue(resultStr.contains("hello=world"))
    }

    @TestCase
    public func testDumpRequestToString(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "http://example.com/")
        req.headers.set("Host", "example.com")
        let result = dumpRequestToString(req)
        assertTrue(result.startsWith("GET http://example.com/ HTTP/1.1\r\n"))
    }

    @TestCase
    public func testDumpResponseOk(): Unit {
        let bodyBytes = unsafe { "OK".rawData() }
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        let headers = HttpHeaders()
        headers.set("Content-Type", "text/plain")
        let resp = HttpResponse(status: HttpStatus.OK, headers: headers, body: body)
        let result = dumpResponse(resp)
        let resultStr = String.fromUtf8(result)
        assertTrue(resultStr.startsWith("HTTP/1.1 200 OK\r\n"))
        assertTrue(resultStr.contains("Content-Type: text/plain"))
        assertTrue(resultStr.contains("OK"))
    }

    @TestCase
    public func testDumpResponseNoBody(): Unit {
        let resp = HttpResponse(status: HttpStatus.NO_CONTENT)
        let result = dumpResponse(resp, body: false)
        let resultStr = String.fromUtf8(result)
        assertTrue(resultStr.startsWith("HTTP/1.1 204 No Content\r\n"))
    }

    @TestCase
    public func testDumpResponseMaxBody(): Unit {
        let bodyData = Array<UInt8>(500, repeat: 0x41)
        let body = ByteBuffer(capacity: bodyData.size)
        body.write(bodyData)
        let resp = HttpResponse(status: HttpStatus.OK, body: body)
        let result = dumpResponse(resp, body: true, maxBody: 100)
        let resultStr = String.fromUtf8(result)
        assertTrue(resultStr.contains("[截断"))
        assertTrue(resultStr.size < 300)
    }

    @TestCase
    public func testDumpRequestSafeTruncates(): Unit {
        let bodyData = Array<UInt8>(500, repeat: 0x42)
        let body = ByteBuffer(capacity: bodyData.size)
        body.write(bodyData)
        let req = HttpRequest(method: HttpMethod.POST, url: "http://example.com/large", body: body)
        let result = dumpRequestSafe(req, maxBodyLen: 50)
        let resultStr = String.fromUtf8(result)
        assertTrue(resultStr.contains("[主体"))
        assertTrue(resultStr.contains("截断"))
    }

    @TestCase
    public func testDumpResponseToStringHelper(): Unit {
        let resp = HttpResponse(status: HttpStatus.NOT_FOUND)
        let result = dumpResponseToString(resp)
        assertTrue(result.startsWith("HTTP/1.1 404 Not Found\r\n"))
    }
}
