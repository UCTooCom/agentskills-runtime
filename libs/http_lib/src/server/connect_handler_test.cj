package http_lib.server

import http_lib.core.{assertTrue, assertFalse, HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * 测试 HTTP CONNECT 处理器。
 */
@Test
public class ConnectHandlerTest {

    @TestCase
    public func testConnectHandlerReturns200(): Unit {
        let handler = connectTunnelHandler()
        let req = HttpRequest(method: HttpMethod.CONNECT, url: "example.com:443")
        req.takenOver = true
        let resp = handler(req)
        assertTrue(resp.status.code == 200u16, message: "CONNECT should return 200")
    }

    @TestCase
    public func testConnectHandlerRejectsWithoutHijack(): Unit {
        let handler = connectTunnelHandler()
        let req = HttpRequest(method: HttpMethod.CONNECT, url: "example.com:443")
        req.takenOver = false
        let resp = handler(req)
        assertTrue(resp.status.code == 400u16, message: "CONNECT without takeover should return 400")
    }

    @TestCase
    public func testConnectHandlerRejectsEmptyTarget(): Unit {
        let handler = connectTunnelHandler()
        let req = HttpRequest(method: HttpMethod.CONNECT, url: "")
        req.takenOver = true
        let resp = handler(req)
        assertTrue(resp.status.code == 400u16, message: "CONNECT with empty target should return 400")
    }
}
