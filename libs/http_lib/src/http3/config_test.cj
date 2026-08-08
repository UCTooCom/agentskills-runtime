/**
 * HTTP/3 配置单元测试。
 *
 * 覆盖：
 * - H3ConnectionConfig 默认值
 * - Http3ServerConfig 到 H3ConnectionConfig 的转换
 * - H3TlsConfig 默认服务端/客户端配置
 */
package http_lib.http3

import std.collection.HashMap
import http_lib.core.{assertTrue, assertFalse}

// ======== HTTP/3 Config 测试 ========

@Test
public class Http3ConfigTest {

    @TestCase
    public func testDefaultConfig(): Unit {
        let config = Http3Config()
        assertTrue(config.maxFieldSectionSize == 65536)
        assertTrue(config.qpackMaxTableCapacity == 4096)
        assertTrue(config.qpackBlockedStreams == 100)
        assertTrue(config.enableConnectProtocol == true)
    }

    @TestCase
    public func testHttp3ServerConfigConversion(): Unit {
        let serverConfig = Http3ServerConfig()
        serverConfig.serverName = "test-server"
        let connConfig = serverConfig.toH3ConnectionConfig()
        assertTrue(connConfig.serverName == "test-server",
            message: "serverName should propagate")
    }

    @TestCase
    public func testH3TlsConfigDefaultServer(): Unit {
        let tls = H3TlsConfig.defaultServer("/cert.pem", "/key.pem")
        assertTrue(tls.serverCertPath == "/cert.pem")
        assertTrue(tls.serverKeyPath == "/key.pem")
    }

    @TestCase
    public func testH3TlsConfigDefaultClient(): Unit {
        let tls = H3TlsConfig.defaultClient("example.com")
        assertTrue(tls.serverName == "example.com")
    }
}

// ======== 0-RTT 配置传播测试 ========

@Test
public class Http3ConfigZeroRttPropagationTest {

    @TestCase
    public func testHttp3ConfigZeroRttDefault(): Unit {
        let config = Http3Config()
        match (config.zeroRttPriorSettings) {
            case Some(_) => assertTrue(false, message: "Default zeroRttPriorSettings should be None")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testHttp3ServerConfigZeroRttPropagation(): Unit {
        let prior = HashMap<UInt16, UInt64>()
        prior[0x01u16] = 8192u64

        let sc = Http3ServerConfig()
        sc.zeroRttPriorSettings = Some(prior)

        // Test: toH3ConnectionConfig()
        let connConfig = sc.toH3ConnectionConfig()
        match (connConfig.zeroRttPriorSettings) {
            case Some(p) =>
                match (p.get(0x01u16)) {
                    case Some(v) => assertTrue(v == 8192u64, message: "QPACK_MAX_TABLE_CAPACITY should propagate")
                    case None => assertTrue(false, message: "QPACK_MAX_TABLE_CAPACITY should be present")
                }
            case None => assertTrue(false, message: "zeroRttPriorSettings should propagate via toH3ConnectionConfig()")
        }

        // Test: toHttp3Config()
        let http3Config = sc.toHttp3Config()
        match (http3Config.zeroRttPriorSettings) {
            case Some(p) =>
                match (p.get(0x01u16)) {
                    case Some(v) => assertTrue(v == 8192u64, message: "QPACK_MAX_TABLE_CAPACITY should propagate via toHttp3Config()")
                    case None => assertTrue(false, message: "QPACK_MAX_TABLE_CAPACITY should be present")
                }
            case None => assertTrue(false, message: "zeroRttPriorSettings should propagate via toHttp3Config()")
        }

        // Test: full chain: Http3ServerConfig → Http3Config → H3ConnectionConfig → H3Connection
        let fullChainConfig = H3ConnectionConfig.from(http3Config)
        let quicConn = MockQuicConnection(serverMode: true)
        let h3Conn = H3Connection(quicConn, config: fullChainConfig, isServer: true)
        match (h3Conn.getLastError()) {
            case Some(_) => assertTrue(false, message: "No error expected from config-only setup")
            case None => assertTrue(true)
        }
        // Verify connection starts in INITIAL state (not invalid from 0-RTT)
        assertTrue(h3Conn.getState() == H3ConnectionState.H3_STATE_INITIAL,
            message: "Connection should be in INITIAL state after construction")
    }

    @TestCase
    public func testHttp3ClientConfigZeroRttPropagation(): Unit {
        let prior = HashMap<UInt16, UInt64>()
        prior[0x06u16] = 131072u64  // MAX_FIELD_SECTION_SIZE

        let cc = Http3ClientConfig()
        cc.zeroRttPriorSettings = Some(prior)

        let connConfig = cc.toH3ConnectionConfig()
        match (connConfig.zeroRttPriorSettings) {
            case Some(p) =>
                match (p.get(0x06u16)) {
                    case Some(v) => assertTrue(v == 131072u64, message: "MAX_FIELD_SECTION_SIZE should propagate")
                    case None => assertTrue(false, message: "MAX_FIELD_SECTION_SIZE should be present")
                }
            case None => assertTrue(false, message: "zeroRttPriorSettings should propagate from client config")
        }
    }

    @TestCase
    public func testH3ConnectionConfigFromPropagation(): Unit {
        let prior = HashMap<UInt16, UInt64>()
        prior[0x01u16] = 4096u64
        prior[0x06u16] = 65536u64

        let http3 = Http3Config()
        http3.zeroRttPriorSettings = Some(prior)

        let connConfig = H3ConnectionConfig.from(http3)
        match (connConfig.zeroRttPriorSettings) {
            case Some(p) =>
                match (p.get(0x01u16)) {
                    case Some(v) => assertTrue(v == 4096u64, message: "QPACK_MAX_TABLE_CAPACITY should propagate from Http3Config")
                    case None => assertTrue(false, message: "QPACK_MAX_TABLE_CAPACITY should be present")
                }
            case None => assertTrue(false, message: "zeroRttPriorSettings should propagate from H3ConnectionConfig.from()")
        }
    }
}
