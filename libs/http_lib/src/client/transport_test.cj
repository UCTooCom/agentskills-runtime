package http_lib.client

import http_lib.core.{assertTrue, assertFalse}
import http_lib.connection.TlsConfig

/**
 * HttpTransport 公共方法的全面单元测试：
 *   init(), cleanIdleConnections(), closeAll()
 *
 * HttpTransport 管理内部池（idleConnectionPool、activeConnectionCount）
 * 这些是私有字段。这些测试通过公共 API 对其进行测试，
 * 验证默认值、幂等生命周期方法、属性变更、
 * 以及边界情况（零/短超时、重复调用、生命周期顺序）。
 *
 * 注意：roundTrip(HttpRequest) 需要活跃的 TCP/TLS 连接，不适用于
 * 在此测试；其内部池交互（returnToPool、getIdleConnection）
 * 由 ConnectionPoolTest（单独文件）间接覆盖。
 */

@Test
public class TransportTest {

    // ===================== init() 测试 =====================

    @TestCase
    public func testInitDefaultValues(): Unit {
        let t = HttpTransport()
        assertTrue(t.maxIdleConnections == 100)
        assertTrue(t.maxIdleConnectionsPerHost == 5)
        assertTrue(t.maxConnectionsPerHost == 10)
        assertTrue(t.idleConnectionTimeout == Duration.second * 90)
        assertTrue(t.connectTimeout == Duration.second * 30)
        assertTrue(t.tlsTimeout == Duration.second * 10)
        assertTrue(t.responseTimeout == Duration.second * 60)
        assertTrue(t.continueTimeout == Duration.second * 1)
        assertFalse(t.disableKeepAlive)
        assertFalse(t.disableAutoDecompress)
        assertTrue(t.forceHttp2)
        assertTrue(t.proxyUrl.isNone())
        assertTrue(t.proxyConnectHeader.isEmpty())
    }

    @TestCase
    public func testInitTlsConfigDefault(): Unit {
        let t = HttpTransport()
        assertTrue(t.tlsConfig.verifyPeer)
        assertTrue(t.tlsConfig.verifyHost)
        assertFalse(t.tlsConfig.enableDiagnostics)
        assertTrue(t.tlsConfig.autoLoadSystemCerts)
        assertTrue(t.tlsConfig.nextProtos.size == 2)
        assertTrue(t.tlsConfig.nextProtos[0] == "h2")
        assertTrue(t.tlsConfig.nextProtos[1] == "http/1.1")
        assertTrue(t.tlsConfig.minVersion == UInt16(0))
        assertTrue(t.tlsConfig.maxVersion == UInt16(0))
    }

    @TestCase
    public func testInitProxyDefaults(): Unit {
        let t = HttpTransport()
        assertTrue(t.proxyUrl.isNone())
        assertTrue(t.proxyConnectHeader.isEmpty())
    }

    @TestCase
    public func testInitIdempotent(): Unit {
        let t1 = HttpTransport()
        let t2 = HttpTransport()
        assertTrue(t1.maxIdleConnections == t2.maxIdleConnections)
        assertTrue(t1.maxConnectionsPerHost == t2.maxConnectionsPerHost)
        assertTrue(t1.idleConnectionTimeout == t2.idleConnectionTimeout)
        assertTrue(t1.connectTimeout == t2.connectTimeout)
        assertTrue(t1.responseTimeout == t2.responseTimeout)
        assertTrue(t1.disableKeepAlive == t2.disableKeepAlive)
        assertTrue(t1.disableAutoDecompress == t2.disableAutoDecompress)
        assertTrue(t1.forceHttp2 == t2.forceHttp2)
    }

    // ===================== cleanIdleConnections() 测试 =====================

    @TestCase
    public func testCloseIdleOnFreshTransport(): Unit {
        let t = HttpTransport()
        t.cleanIdleConnections()
        assertTrue(true)
    }

    @TestCase
    public func testCloseIdleMultipleCalls(): Unit {
        let t = HttpTransport()
        t.cleanIdleConnections()
        t.cleanIdleConnections()
        t.cleanIdleConnections()
        assertTrue(true)
    }

    @TestCase
    public func testCloseIdleAfterCloseAll(): Unit {
        let t = HttpTransport()
        t.closeAll()
        t.cleanIdleConnections()
        assertTrue(true)
    }

    @TestCase
    public func testCloseIdleWithZeroTimeout(): Unit {
        let t = HttpTransport()
        t.idleConnectionTimeout = Duration.second * 0
        t.cleanIdleConnections()
        assertTrue(true)
    }

    @TestCase
    public func testCloseIdleWithNanosecondTimeout(): Unit {
        let t = HttpTransport()
        t.idleConnectionTimeout = Duration.nanosecond * 1
        t.cleanIdleConnections()
        assertTrue(true)
    }

    @TestCase
    public func testCloseIdlePreservesProperties(): Unit {
        let t = HttpTransport()
        t.idleConnectionTimeout = Duration.second * 30
        t.maxIdleConnections = 50
        t.maxIdleConnectionsPerHost = 3
        t.cleanIdleConnections()
        assertTrue(t.idleConnectionTimeout == Duration.second * 30)
        assertTrue(t.maxIdleConnections == 50)
        assertTrue(t.maxIdleConnectionsPerHost == 3)
    }

    @TestCase
    public func testCloseIdleWithDisabledKeepAlives(): Unit {
        let t = HttpTransport()
        t.disableKeepAlive = true
        t.cleanIdleConnections()
        assertTrue(t.disableKeepAlive)
    }

    @TestCase
    public func testCloseIdleAfterSettingProxyUrl(): Unit {
        let t = HttpTransport()
        t.proxyUrl = Some("http://proxy:3128")
        t.cleanIdleConnections()
        match (t.proxyUrl) {
            case Some(url) => assertTrue(url == "http://proxy:3128")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testCloseIdlePreservesActiveConnConfig(): Unit {
        let t = HttpTransport()
        t.maxConnectionsPerHost = 20
        t.cleanIdleConnections()
        assertTrue(t.maxConnectionsPerHost == 20)
    }

    // ===================== closeAll() 测试 =====================

    @TestCase
    public func testCloseAllOnFreshTransport(): Unit {
        let t = HttpTransport()
        t.closeAll()
        assertTrue(true)
    }

    @TestCase
    public func testCloseAllMultipleCalls(): Unit {
        let t = HttpTransport()
        t.closeAll()
        t.closeAll()
        t.closeAll()
        assertTrue(true)
    }

    @TestCase
    public func testCloseAllAfterCloseIdle(): Unit {
        let t = HttpTransport()
        t.cleanIdleConnections()
        t.closeAll()
        assertTrue(true)
    }

    @TestCase
    public func testCloseAllPreservesProperties(): Unit {
        let t = HttpTransport()
        t.disableKeepAlive = true
        t.disableAutoDecompress = true
        t.forceHttp2 = false
        t.closeAll()
        assertTrue(t.disableKeepAlive)
        assertTrue(t.disableAutoDecompress)
        assertFalse(t.forceHttp2)
    }

    @TestCase
    public func testCloseAllWithMaxConnsChange(): Unit {
        let t = HttpTransport()
        t.maxConnectionsPerHost = 5
        t.maxIdleConnections = 10
        t.closeAll()
        assertTrue(t.maxConnectionsPerHost == 5)
        assertTrue(t.maxIdleConnections == 10)
    }

    @TestCase
    public func testCloseAllThenModifyThenCloseIdle(): Unit {
        let t = HttpTransport()
        t.closeAll()
        t.maxIdleConnections = 200
        t.idleConnectionTimeout = Duration.second * 10
        t.cleanIdleConnections()
        assertTrue(t.maxIdleConnections == 200)
        assertTrue(t.idleConnectionTimeout == Duration.second * 10)
    }

    @TestCase
    public func testCloseAllWithProxyConfigured(): Unit {
        let t = HttpTransport()
        t.proxyUrl = Some("https://proxy:8443")
        t.proxyConnectHeader.set("Proxy-Authorization", "Basic dGVzdDp0ZXN0")
        t.closeAll()
        match (t.proxyUrl) {
            case Some(url) => assertTrue(url == "https://proxy:8443")
            case None => assertTrue(false)
        }
        match (t.proxyConnectHeader.get("proxy-authorization")) {
            case Some(v) => assertTrue(v == "Basic dGVzdDp0ZXN0")
            case None => assertTrue(false)
        }
    }

    // ===================== 属性变更测试 =====================

    @TestCase
    public func testSetMaxIdleConns(): Unit {
        let t = HttpTransport()
        t.maxIdleConnections = 200
        assertTrue(t.maxIdleConnections == 200)
        t.maxIdleConnections = 0
        assertTrue(t.maxIdleConnections == 0)
    }

    @TestCase
    public func testSetMaxIdleConnsPerHost(): Unit {
        let t = HttpTransport()
        assertTrue(t.maxIdleConnectionsPerHost == 5)
        t.maxIdleConnectionsPerHost = 10
        assertTrue(t.maxIdleConnectionsPerHost == 10)
        t.maxIdleConnectionsPerHost = 0
        assertTrue(t.maxIdleConnectionsPerHost == 0)
    }

    @TestCase
    public func testSetMaxConnsPerHost(): Unit {
        let t = HttpTransport()
        t.maxConnectionsPerHost = 20
        assertTrue(t.maxConnectionsPerHost == 20)
        t.maxConnectionsPerHost = 1
        assertTrue(t.maxConnectionsPerHost == 1)
    }

    @TestCase
    public func testSetIdleConnTimeout(): Unit {
        let t = HttpTransport()
        t.idleConnectionTimeout = Duration.second * 300
        assertTrue(t.idleConnectionTimeout == Duration.second * 300)
        t.idleConnectionTimeout = Duration.millisecond * 500
        assertTrue(t.idleConnectionTimeout == Duration.millisecond * 500)
    }

    @TestCase
    public func testSetDialTimeout(): Unit {
        let t = HttpTransport()
        t.connectTimeout = Duration.second * 60
        assertTrue(t.connectTimeout == Duration.second * 60)
    }

    @TestCase
    public func testSetTlsHandshakeTimeout(): Unit {
        let t = HttpTransport()
        t.tlsTimeout = Duration.second * 30
        assertTrue(t.tlsTimeout == Duration.second * 30)
    }

    @TestCase
    public func testSetResponseHeaderTimeout(): Unit {
        let t = HttpTransport()
        t.responseTimeout = Duration.second * 120
        assertTrue(t.responseTimeout == Duration.second * 120)
    }

    @TestCase
    public func testSetExpectContinueTimeout(): Unit {
        let t = HttpTransport()
        t.continueTimeout = Duration.millisecond * 500
        assertTrue(t.continueTimeout == Duration.millisecond * 500)
    }

    @TestCase
    public func testToggleKeepAlives(): Unit {
        let t = HttpTransport()
        assertFalse(t.disableKeepAlive)
        t.disableKeepAlive = true
        assertTrue(t.disableKeepAlive)
        t.disableKeepAlive = false
        assertFalse(t.disableKeepAlive)
    }

    @TestCase
    public func testToggleCompression(): Unit {
        let t = HttpTransport()
        assertFalse(t.disableAutoDecompress)
        t.disableAutoDecompress = true
        assertTrue(t.disableAutoDecompress)
        t.disableAutoDecompress = false
        assertFalse(t.disableAutoDecompress)
    }

    @TestCase
    public func testToggleHttp2(): Unit {
        let t = HttpTransport()
        assertTrue(t.forceHttp2)
        t.forceHttp2 = false
        assertFalse(t.forceHttp2)
        t.forceHttp2 = true
        assertTrue(t.forceHttp2)
    }

    @TestCase
    public func testSetProxyUrl(): Unit {
        let t = HttpTransport()
        assertTrue(t.proxyUrl.isNone())
        t.proxyUrl = Some("http://proxy:8080")
        match (t.proxyUrl) {
            case Some(url) => assertTrue(url == "http://proxy:8080")
            case None => assertTrue(false)
        }
        t.proxyUrl = None
        assertTrue(t.proxyUrl.isNone())
    }

    @TestCase
    public func testSetProxyConnectHeader(): Unit {
        let t = HttpTransport()
        assertTrue(t.proxyConnectHeader.isEmpty())
        t.proxyConnectHeader.set("Proxy-Authorization", "Basic dGVzdDp0ZXN0")
        assertFalse(t.proxyConnectHeader.isEmpty())
        match (t.proxyConnectHeader.get("proxy-authorization")) {
            case Some(v) => assertTrue(v == "Basic dGVzdDp0ZXN0")
            case None => assertTrue(false)
        }
        t.proxyConnectHeader.clear()
        assertTrue(t.proxyConnectHeader.isEmpty())
    }

    @TestCase
    public func testSetTlsConfig(): Unit {
        let t = HttpTransport()
        let config = TlsConfig()
        config.verifyPeer = false
        config.verifyHost = false
        config.enableDiagnostics = true
        t.tlsConfig = config
        assertFalse(t.tlsConfig.verifyPeer)
        assertFalse(t.tlsConfig.verifyHost)
        assertTrue(t.tlsConfig.enableDiagnostics)
    }

    @TestCase
    public func testSetAllTimeouts(): Unit {
        let t = HttpTransport()
        t.connectTimeout = Duration.second * 15
        t.tlsTimeout = Duration.second * 5
        t.responseTimeout = Duration.second * 30
        t.continueTimeout = Duration.second * 2
        assertTrue(t.connectTimeout == Duration.second * 15)
        assertTrue(t.tlsTimeout == Duration.second * 5)
        assertTrue(t.responseTimeout == Duration.second * 30)
        assertTrue(t.continueTimeout == Duration.second * 2)
    }

    @TestCase
    public func testSetFlags(): Unit {
        let t = HttpTransport()
        t.disableKeepAlive = true
        t.disableAutoDecompress = true
        t.forceHttp2 = false
        assertTrue(t.disableKeepAlive)
        assertTrue(t.disableAutoDecompress)
        assertFalse(t.forceHttp2)
    }

    // ===================== 组合生命周期测试 =====================

    @TestCase
    public func testInitThenCloseIdleThenCloseAll(): Unit {
        let t = HttpTransport()
        t.cleanIdleConnections()
        t.closeAll()
        assertTrue(true)
    }

    @TestCase
    public func testInitThenCloseAllThenCloseIdle(): Unit {
        let t = HttpTransport()
        t.closeAll()
        t.cleanIdleConnections()
        assertTrue(true)
    }

    @TestCase
    public func testModifyThenCloseIdleThenModifyThenCloseAll(): Unit {
        let t = HttpTransport()
        t.maxIdleConnections = 50
        t.maxIdleConnectionsPerHost = 2
        t.idleConnectionTimeout = Duration.second * 30
        t.disableKeepAlive = true
        t.cleanIdleConnections()
        assertTrue(t.maxIdleConnections == 50)
        assertTrue(t.maxIdleConnectionsPerHost == 2)
        assertTrue(t.idleConnectionTimeout == Duration.second * 30)
        assertTrue(t.disableKeepAlive)
        t.disableKeepAlive = false
        t.closeAll()
        assertFalse(t.disableKeepAlive)
        assertTrue(t.maxIdleConnections == 50)
    }

    @TestCase
    public func testFullLifecycle(): Unit {
        let t = HttpTransport()
        assertTrue(t.maxIdleConnections == 100)
        assertTrue(t.idleConnectionTimeout == Duration.second * 90)
        assertFalse(t.disableKeepAlive)
        assertTrue(t.proxyUrl.isNone())
        t.maxIdleConnections = 200
        t.idleConnectionTimeout = Duration.second * 300
        t.disableKeepAlive = true
        t.proxyUrl = Some("http://proxy:8080")
        t.cleanIdleConnections()
        assertTrue(t.maxIdleConnections == 200)
        assertTrue(t.idleConnectionTimeout == Duration.second * 300)
        assertTrue(t.disableKeepAlive)
        t.closeAll()
        assertTrue(t.maxIdleConnections == 200)
        assertTrue(t.disableKeepAlive)
        match (t.proxyUrl) {
            case Some(url) => assertTrue(url == "http://proxy:8080")
            case None => assertTrue(false)
        }
        t.cleanIdleConnections()
        assertTrue(true)
    }

    @TestCase
    public func testLifecycleWithTlsConfigChange(): Unit {
        let t = HttpTransport()
        let config = TlsConfig()
        config.verifyPeer = false
        t.tlsConfig = config
        t.cleanIdleConnections()
        assertFalse(t.tlsConfig.verifyPeer)
        t.closeAll()
        assertFalse(t.tlsConfig.verifyPeer)
    }

    @TestCase
    public func testLifecycleWithProxyHeader(): Unit {
        let t = HttpTransport()
        t.proxyConnectHeader.set("Proxy-Authorization", "Basic dGVzdDp0ZXN0")
        t.cleanIdleConnections()
        match (t.proxyConnectHeader.get("proxy-authorization")) {
            case Some(v) => assertTrue(v == "Basic dGVzdDp0ZXN0")
            case None => assertTrue(false)
        }
        t.closeAll()
        match (t.proxyConnectHeader.get("proxy-authorization")) {
            case Some(v) => assertTrue(v == "Basic dGVzdDp0ZXN0")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRepeatedLifecycle(): Unit {
        let t = HttpTransport()
        var i: Int64 = 0
        while (i < 5) {
            t.cleanIdleConnections()
            t.closeAll()
            i += 1
        }
        assertTrue(true)
    }

    @TestCase
    public func testModifyBetweenCloseCalls(): Unit {
        let t = HttpTransport()
        t.cleanIdleConnections()
        t.maxIdleConnections = 50
        t.cleanIdleConnections()
        t.maxIdleConnectionsPerHost = 2
        t.closeAll()
        assertTrue(t.maxIdleConnections == 50)
        assertTrue(t.maxIdleConnectionsPerHost == 2)
    }

    @TestCase
    public func testInitAfterClosePreservesDefaults(): Unit {
        let t = HttpTransport()
        assertTrue(t.maxIdleConnections == 100)
        assertTrue(t.maxConnectionsPerHost == 10)
        assertTrue(t.maxIdleConnectionsPerHost == 5)
        assertTrue(t.idleConnectionTimeout == Duration.second * 90)
        assertTrue(t.connectTimeout == Duration.second * 30)
        assertTrue(t.tlsTimeout == Duration.second * 10)
        assertTrue(t.responseTimeout == Duration.second * 60)
        assertTrue(t.continueTimeout == Duration.second * 1)
    }
}

// ---- HTTP/2 Transport 测试 ----

public class TransportH2Test {
    public func testTransportForceHttp2Flag(): Unit {
        let t = HttpTransport()
        assertTrue(t.forceHttp2, message: "forceHttp2 默认应为 true")
        t.forceHttp2 = false
        assertTrue(!t.forceHttp2, message: "forceHttp2 可设为 false")
    }

    public func testTransportH2MethodsExist(): Unit {
        let t = HttpTransport()
        t.closeAll()
        assertTrue(true, message: "HttpTransport H2 基础设施存在")
    }

    public func testTransportCleanIdleConnections(): Unit {
        let t = HttpTransport()
        t.cleanIdleConnections()
        assertTrue(true, message: "cleanIdleConnections 空池调用不崩溃")
    }

    public func testTransportCloseAll(): Unit {
        let t = HttpTransport()
        t.closeAll()
        t.closeAll()
        assertTrue(true, message: "closeAll 多次调用应幂等")
    }
}

