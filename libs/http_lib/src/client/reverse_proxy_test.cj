package http_lib.client

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class ReverseProxyTest {

    @TestCase
    public func testCreateReverseProxy(): Unit {
        let proxy = ReverseProxy("http://localhost:8080")
        assertTrue(proxy.errorHandler.isNone())
        assertTrue(proxy.modifyResponse.isNone())
        assertTrue(proxy.rewrite.isNone())
    }

    @TestCase
    public func testReverseProxySetHooks(): Unit {
        let proxy = ReverseProxy("http://localhost:8080")
        proxy.errorHandler = {req, msg => HttpResponse(status: HttpStatus.BAD_GATEWAY) }
        assertTrue(proxy.errorHandler.isSome())
        proxy.rewrite = {req => req}
        assertTrue(proxy.rewrite.isSome())
        proxy.modifyResponse = {req, resp => resp}
        assertTrue(proxy.modifyResponse.isSome())
    }

    @TestCase
    public func testReverseProxyHandlerWrapper(): Unit {
        let proxy = ReverseProxy("http://localhost:8080")
        let handler = reverseProxyHandler(proxy)
        assertTrue(true)
    }
}
