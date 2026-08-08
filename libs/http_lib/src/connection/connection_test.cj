package http_lib.connection

import http_lib.core.{assertTrue, assertFalse}

@Test
public class TlsConfigTest {

    @TestCase
    public func testDefaultConfig(): Unit {
        let cfg = TlsConfig.default()
        assertTrue(cfg.supportsH2())
        assertTrue(cfg.supportsHttp1())
        assertTrue(cfg.verifyPeer)
    }

    @TestCase
    public func testInsecureConfig(): Unit {
        let cfg = TlsConfig.insecure()
        assertFalse(cfg.verifyPeer)
        assertFalse(cfg.verifyHost)
    }

    @TestCase
    public func testHttp1OnlyConfig(): Unit {
        let cfg = TlsConfig.http1Only()
        assertFalse(cfg.supportsH2())
        assertTrue(cfg.supportsHttp1())
    }

    @TestCase
    public func testSupportsH2(): Unit {
        let cfg = TlsConfig()
        cfg.nextProtos = ["h2", "http/1.1"]
        assertTrue(cfg.supportsH2())
        cfg.nextProtos = ["http/1.1"]
        assertFalse(cfg.supportsH2())
    }

    @TestCase
    public func testSupportsHttp1(): Unit {
        let cfg = TlsConfig()
        cfg.nextProtos = ["http/1.1"]
        assertTrue(cfg.supportsHttp1())
        cfg.nextProtos = ["h2"]
        assertFalse(cfg.supportsHttp1())
    }

    @TestCase
    public func testNegotiateProtocolH2First(): Unit {
        let cfg = TlsConfig()
        cfg.nextProtos = ["h2", "http/1.1"]
        let result = cfg.negotiateProtocol(["http/1.1", "h2"])
        assertTrue(result == "h2")  // 服务器偏好：h2 优先于 http/1.1
    }

    @TestCase
    public func testNegotiateProtocolNoMatch(): Unit {
        let cfg = TlsConfig()
        cfg.nextProtos = ["h2", "http/1.1"]
        let result = cfg.negotiateProtocol(["ftp"])
        assertTrue(result == "")
    }

    @TestCase
    public func testNegotiateProtocolEmpty(): Unit {
        let cfg = TlsConfig()
        cfg.nextProtos = ["h2", "http/1.1"]
        let result = cfg.negotiateProtocol([])
        assertTrue(result == "")
    }

    @TestCase
    public func testCopy(): Unit {
        let cfg = TlsConfig.default()
        cfg.nextProtos = ["custom"]
        let copied = cfg.copy()
        assertTrue(copied.nextProtos.size == 1)
        assertTrue(copied.nextProtos[0] == "custom")
        // 修改副本不应影响原始对象
        copied.nextProtos = ["other"]
        assertTrue(cfg.nextProtos[0] == "custom")
    }

    @TestCase
    public func testDefaultNextProtos(): Unit {
        let cfg = TlsConfig()
        assertTrue(cfg.nextProtos.size >= 2)
    }

    @TestCase
    public func testMinMaxVersionDefaults(): Unit {
        let cfg = TlsConfig()
        assertTrue(cfg.minVersion == 0)
        assertTrue(cfg.maxVersion == 0)
    }
}

@Test
public class SecureRandomTest {

    @TestCase
    public func test32Bytes(): Unit {
        let bytes = secureRandom32()
        assertTrue(bytes.size == 32)
        // 检查不全是零（CSPRNG 极不可能）
        var allZero = true
        var i: Int64 = 0
        while (i < 32) {
            if (bytes[i] != 0) { allZero = false }
            i += 1
        }
        assertFalse(allZero, message: "secureRandom32 should not return all zeros")
    }

    @TestCase
    public func testMultipleCallsDifferent(): Unit {
        let a = secureRandom32()
        let b = secureRandom32()
        assertFalse(arraysEqualForTest(a, b), message: "Two secure random calls should produce different results")
    }

    private func arraysEqualForTest(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) { return false }
        var i: Int64 = 0
        while (i < a.size) {
            if (a[i] != b[i]) { return false }
            i += 1
        }
        true
    }
}

@Test
public class AlpnParserTest {

    @TestCase
    public func testExtractAlpnTooShort(): Unit {
        let data: Array<Byte> = []
        let protocols = extractAlpnFromClientHello(data)
        assertTrue(protocols.size == 0)
    }

    @TestCase
    public func testParseClientHelloAlpn(): Unit {
        let data = Array<Byte>(50, repeat: 0)
        let protocols = parseClientHelloAlpn(data)
        assertTrue(protocols.size == 0)  // 太短，返回空
    }

    @TestCase
    public func testExtractAlpnMinimalLength(): Unit {
        // 43 字节是有效 ClientHello（不含扩展）的最小长度
        let data = Array<Byte>(42, repeat: 0)
        let protocols = extractAlpnFromClientHello(data)
        assertTrue(protocols.size == 0)  // 太短
    }
}
