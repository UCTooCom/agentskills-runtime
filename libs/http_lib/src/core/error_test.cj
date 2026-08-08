package http_lib.core


@Test
public class HttpExceptionTest {

    @TestCase
    public func testHttpException(): Unit {
        let e = HttpException("test error")
        assertTrue(e.message == "test error")
    }

    @TestCase
    public func testInvalidUrlException(): Unit {
        let e = InvalidUrlException("http://[bad url")
        assertTrue(e.message.size > 0)
    }

    @TestCase
    public func testConnectionException(): Unit {
        let e = ConnectionException("example.com:80")
        assertTrue(e.message.size > 0)
        assertTrue(e.message.contains("example.com"))
    }

    @TestCase
    public func testHttpTimeoutException(): Unit {
        let e = HttpTimeoutException("read")
        assertTrue(e.message.size > 0)
        assertTrue(e.message.contains("read"))
    }

    @TestCase
    public func testProtocolException(): Unit {
        let e = ProtocolException("invalid header")
        assertTrue(e.message == "invalid header")
    }

    @TestCase
    public func testHttpIllegalStateException(): Unit {
        let e = HttpIllegalStateException("closed")
        assertTrue(e.message.contains("closed"))
    }

    @TestCase
    public func testRedirectLimitExceededException(): Unit {
        let e = RedirectLimitExceededException(5)
        assertTrue(e.message.contains("5"))
    }

    @TestCase
    public func testUnsupportedOperationException(): Unit {
        let e = UnsupportedOperationException("not supported")
        assertTrue(e.message.contains("not supported"))
    }
}
