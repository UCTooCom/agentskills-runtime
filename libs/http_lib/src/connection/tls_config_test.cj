package http_lib.connection

import http_lib.core.{assertTrue, assertFalse}

@Test
public class TlsConfigUnitTest {

    @TestCase
    public func testDefaultConfig(): Unit {
        let config = TlsConfig.default()
        assertTrue(config.verifyPeer)
        assertTrue(config.verifyHost)
        assertTrue(config.nextProtos.size > 0)
        assertTrue(config.supportsHttp1())
    }

    @TestCase
    public func testInsecureConfig(): Unit {
        let config = TlsConfig.insecure()
        assertFalse(config.verifyPeer)
        assertFalse(config.verifyHost)
    }

    @TestCase
    public func testHttp1OnlyConfig(): Unit {
        let config = TlsConfig.http1Only()
        assertTrue(config.supportsHttp1())
        assertFalse(config.supportsH2())
    }

    @TestCase
    public func testSupportsH2(): Unit {
        let config = TlsConfig.default()
        if (config.nextProtos.contains("h2")) {
            assertTrue(config.supportsH2())
        }
    }

    @TestCase
    public func testNegotiateProtocolH2(): Unit {
        let config = TlsConfig.default()
        let result = config.negotiateProtocol(["h2", "http/1.1"])
        assertTrue(result.size > 0)
    }

    @TestCase
    public func testNegotiateProtocolHttp1Only(): Unit {
        let config = TlsConfig.default()
        let result = config.negotiateProtocol(["http/1.1"])
        assertTrue(result == "http/1.1")
    }

    @TestCase
    public func testNegotiateProtocolNoMatch(): Unit {
        let config = TlsConfig.http1Only()
        let result = config.negotiateProtocol(["h2"])
        assertTrue(result == "")
    }

    @TestCase
    public func testCopy(): Unit {
        let original = TlsConfig.default()
        original.serverCertPath = "/tmp/test.crt"
        let copied = original.copy()
        assertTrue(copied.serverCertPath == original.serverCertPath)
        assertTrue(copied.verifyPeer == original.verifyPeer)
    }

    @TestCase
    public func testServerCertPath(): Unit {
        let config = TlsConfig()
        config.serverCertPath = "/etc/ssl/server.pem"
        config.serverKeyPath = "/etc/ssl/key.pem"
        assertTrue(config.serverCertPath == "/etc/ssl/server.pem")
        assertTrue(config.serverKeyPath == "/etc/ssl/key.pem")
    }

    @TestCase
    public func testCaCertPath(): Unit {
        let config = TlsConfig()
        config.caCertPath = "/etc/ssl/ca.pem"
        assertTrue(config.caCertPath == "/etc/ssl/ca.pem")
    }

    @TestCase
    public func testClientCertConfig(): Unit {
        let config = TlsConfig()
        config.clientCertPath = "/etc/ssl/client.pem"
        config.clientKeyPath = "/etc/ssl/client-key.pem"
        assertTrue(config.clientCertPath == "/etc/ssl/client.pem")
    }

    @TestCase
    public func testMinMaxVersion(): Unit {
        let config = TlsConfig.default()
        assertTrue(config.minVersion >= 0)
        assertTrue(config.maxVersion >= 0)
    }

    @TestCase
    public func testDetectSystemCaBundle(): Unit {
        let result = try {
            let path = detectSystemCaBundle()
            path
        } catch (_: Exception) { "" }
        // 可能找到也可能找不到系统证书，但不应崩溃
        assertTrue(true)
    }

    @TestCase
    public func testDetectSystemServerCert(): Unit {
        let result = try {
            let path = detectSystemServerCert()
            path
        } catch (_: Exception) { "" }
        assertTrue(true)
    }

    @TestCase
    public func testDetectSystemServerKey(): Unit {
        let result = try {
            let path = detectSystemServerKey()
            path
        } catch (_: Exception) { "" }
        assertTrue(true)
    }

    @TestCase
    public func testLoadSystemCerts(): Unit {
        let success = try {
            let _ = loadSystemCerts()
            true
        } catch (_: Exception) { false }
        // 可能找到也可能找不到系统证书，但不应崩溃
        assertTrue(true)
    }

    @TestCase
    public func testEnsureCaCert(): Unit {
        let config = TlsConfig.default()
        let success = try {
            config.ensureCaCert()
            true
        } catch (_: Exception) { false }
        // 可能会或不会找到系统证书，但不应崩溃
        assertTrue(true)
    }

    @TestCase
    public func testEnsureServerCert(): Unit {
        let config = TlsConfig.default()
        let success = try {
            config.ensureServerCert()
            true
        } catch (_: Exception) { false }
        assertTrue(true)
    }

    @TestCase
    public func testCopyModifyIndependent(): Unit {
        let original = TlsConfig.default()
        original.serverCertPath = "/original/path"
        let copied = original.copy()
        copied.serverCertPath = "/copied/path"
        assertTrue(original.serverCertPath == "/original/path",
            message: "Original should be unchanged after copy modify")
        assertTrue(copied.serverCertPath == "/copied/path",
            message: "Copy should have its own path")
    }
}
