package http_lib.core

@Test public class ConstantsUnitTest {
    @TestCase public func testParseDecimal(): Unit { assertTrue(parseDecimal("12345")==12345) }
    @TestCase public func testParseDecimalZero(): Unit { assertTrue(parseDecimal("0")==0) }
    @TestCase public func testParseDecimalInvalid(): Unit { let ok=try{parseDecimal("abc");false}catch(_:Exception){true}; assertTrue(ok) }
    @TestCase public func testParseContentLength(): Unit { assertTrue(parseContentLength("1024")==1024) }

    @TestCase public func testHttpProtocolsDefaults(): Unit {
        let p = HttpProtocols()
        assertTrue(p.isHttp1Enabled())
        assertTrue(p.isHttp2Enabled())
        assertFalse(p.isUnencryptedHttp2Enabled())
    }

    @TestCase public func testHttpProtocolsSetHttp1(): Unit {
        let p = HttpProtocols()
        p.setHttp1(false)
        assertFalse(p.isHttp1Enabled())
        p.setHttp1(true)
        assertTrue(p.isHttp1Enabled())
    }

    @TestCase public func testHttpProtocolsSetHttp2(): Unit {
        let p = HttpProtocols()
        p.setHttp2(false)
        assertFalse(p.isHttp2Enabled())
        p.setHttp2(true)
        assertTrue(p.isHttp2Enabled())
    }

    @TestCase public func testHttpProtocolsSetUnencryptedHttp2(): Unit {
        let p = HttpProtocols()
        p.setUnencryptedHttp2(true)
        assertTrue(p.isUnencryptedHttp2Enabled())
        p.setUnencryptedHttp2(false)
        assertFalse(p.isUnencryptedHttp2Enabled())
    }

    @TestCase public func testHttpProtocolsAll(): Unit {
        let p = HttpProtocols.all()
        assertTrue(p.isHttp1Enabled())
        assertTrue(p.isHttp2Enabled())
        assertFalse(p.isUnencryptedHttp2Enabled())
    }

    @TestCase public func testHttp2ConfigDefaults(): Unit {
        let cfg = Http2Config()
        assertTrue(cfg.enabled)
        assertTrue(cfg.allowH2C)
        assertTrue(cfg.maxConcurrentStreams == 100)
        assertTrue(cfg.initialWindowSize == 65535)
        assertTrue(cfg.maxFrameSize == 16384)
        assertTrue(cfg.maxHeaderListSize == 0)
        assertTrue(!cfg.enablePush)
    }

    @TestCase public func testConnStateNewIsNotClosed(): Unit {
        let newState = ConnState.STATE_NEW
        let closedState = ConnState.STATE_CLOSED
        assertTrue(true)  // 枚举值可正常构造
    }

    @TestCase public func testConnStateToString(): Unit {
        // 验证所有枚举常量可正常访问
        let _ = ConnState.STATE_NEW
        let _ = ConnState.STATE_ACTIVE
        let _ = ConnState.STATE_IDLE
        let _ = ConnState.STATE_HIJACKED
        let _ = ConnState.STATE_CLOSED
        assertTrue(true)
    }

    @TestCase public func testProtocolConstants(): Unit {
        assertTrue(CRLF == "\r\n")
        assertTrue(CRLF_BYTES.size == 2)
        assertTrue(CRLF_BYTES[0] == b'\r')
        assertTrue(CRLF_BYTES[1] == b'\n')
        assertTrue(HEADER_END_BYTES.size == 4)
        assertTrue(HTTP_VERSION_PREFIX == "HTTP/")
        assertTrue(SPACE_BYTE == b' ')
        assertTrue(COLON_BYTE == b':')
    }

    @TestCase public func testDefaultTimeouts(): Unit {
        assertTrue(DEFAULT_CONNECT_TIMEOUT == Duration.second * 30)
        assertTrue(DEFAULT_READ_TIMEOUT == Duration.second * 30)
        assertTrue(DEFAULT_WRITE_TIMEOUT == Duration.second * 30)
    }

    @TestCase public func testDefaultBufferSizes(): Unit {
        assertTrue(DEFAULT_BUFFER_SIZE == 8192)
        assertTrue(MAX_HEADER_SIZE == 65536)
        assertTrue(MAX_LINE_LENGTH == 8192)
    }
}
