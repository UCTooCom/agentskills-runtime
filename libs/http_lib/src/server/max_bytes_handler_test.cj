package http_lib.server

import http_lib.core.{assertTrue, assertFalse}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.core.{HttpMethod, HttpStatus, HttpVersion, HttpHeaders}
import http_lib.buffer.ByteBuffer
import http_lib.router.Handler

@Test
public class MaxBytesHandlerTest {

    @TestCase
    public func testBodyUnderLimit(): Unit {
        let innerHandler: Handler = {req: HttpRequest =>
            HttpResponse(status: HttpStatus.OK)
        }
        let handler = maxBytesHandler(innerHandler, 100)
        let req = HttpRequest(method: HttpMethod.POST, url: "/test")
        let bodyBytes = unsafe { "small".rawData() }
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        req.body = body
        let resp = handler(req)
        assertTrue(resp.status.code == 200u16)
    }

    @TestCase
    public func testContentLengthOverLimit(): Unit {
        let innerHandler: Handler = {req: HttpRequest =>
            HttpResponse(status: HttpStatus.OK)
        }
        let handler = maxBytesHandler(innerHandler, 10)
        let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
        req.headers.set("Content-Length", "100")
        let resp = handler(req)
        assertTrue(resp.status.code == 413u16)
        let respStr = String.fromUtf8(resp.bodyAsBytes())
        assertTrue(respStr.contains("413"))
    }

    @TestCase
    public func testBodySizeOverLimit(): Unit {
        let innerHandler: Handler = {req: HttpRequest =>
            HttpResponse(status: HttpStatus.OK)
        }
        let handler = maxBytesHandler(innerHandler, 5)
        let req = HttpRequest(method: HttpMethod.POST, url: "/upload")
        let bodyBytes = Array<UInt8>(50, repeat: 0x41)
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        req.body = body
        let resp = handler(req)
        assertTrue(resp.status.code == 413u16)
    }

    @TestCase
    public func testZeroMaxBytesBlocksAll(): Unit {
        let innerHandler: Handler = {req: HttpRequest =>
            HttpResponse(status: HttpStatus.OK)
        }
        let handler = maxBytesHandler(innerHandler, 0)
        let req = HttpRequest(method: HttpMethod.GET, url: "/test")
        let bodyBytes = unsafe { "x".rawData() }
        let body = ByteBuffer(capacity: bodyBytes.size)
        body.write(bodyBytes)
        req.body = body
        let resp = handler(req)
        assertTrue(resp.status.code == 413u16)
    }

    @TestCase
    public func testZeroBodyPassesThrough(): Unit {
        let innerHandler: Handler = {req: HttpRequest =>
            HttpResponse(status: HttpStatus.OK)
        }
        let handler = maxBytesHandler(innerHandler, 1024)
        let req = HttpRequest(method: HttpMethod.GET, url: "/health")
        let resp = handler(req)
        assertTrue(resp.status.code == 200u16)
    }
}
