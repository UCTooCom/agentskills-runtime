package http_lib.connection

import http_lib.core.{assertTrue, assertFalse}

@Test
public class AlpnParserUnitTest {
    @TestCase
    public func testExtractFromEmptyLikeBuffer(): Unit {
        let data = Array<Byte>(30, repeat: 0)
        let protos = extractAlpnFromClientHello(data)
        assertTrue(protos.size == 0)
    }
    @TestCase
    public func testExtractFromMinimalBuffer(): Unit {
        let data = Array<Byte>(50, repeat: 0)
        let protos = extractAlpnFromClientHello(data)
        assertTrue(protos.size == 0)
    }
    @TestCase
    public func testParseClientHelloAlpnHelper(): Unit {
        let data = Array<Byte>(50, repeat: 0)
        let protos = parseClientHelloAlpn(data)
        assertTrue(protos.size == 0)
    }
}
