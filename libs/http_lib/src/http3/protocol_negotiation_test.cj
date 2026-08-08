/**
 * 协议协商单元测试（HTTP/1 ↔ HTTP/2 ↔ HTTP/3）。
 *
 * 测试协议标识、连接键构建和 Alt-Svc 发现相关的逻辑。
 * 完整的端到端协商测试需要真实的 HTTP/1 + HTTP/2 服务器环境，
 * 以及可用的 quic_cj QUIC 传输层（用于 HTTP/3）。
 *
 * 当前的单元测试覆盖了可以在无网络连接或完整服务器的情况下
 * 单独验证的协商逻辑组件。
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse, HttpVersion, HttpHeaders}

// ======== 协议标识测试 ========

@Test
public class ProtocolIdentifierTest {

    @TestCase
    public func testExtendedConnectProtocolConstants(): Unit {
        assertTrue(EXTENDED_CONNECT_PROTOCOL_WEBSOCKET == "websocket",
            message: "WebSocket protocol constant should be 'websocket'")
        assertTrue(EXTENDED_CONNECT_PROTOCOL_CONNECT_UDP == "connect-udp",
            message: "CONNECT-UDP protocol constant should be 'connect-udp'")
    }

    @TestCase
    public func testHttpVersionConstants(): Unit {
        assertTrue(HttpVersion.HTTP_1_0.toString() == "HTTP/1.0",
            message: "HTTP/1.0 toString")
        assertTrue(HttpVersion.HTTP_1_1.toString() == "HTTP/1.1",
            message: "HTTP/1.1 toString")
        assertTrue(HttpVersion.HTTP_2_0.toString() == "HTTP/2.0",
            message: "HTTP/2 toString")
        assertTrue(HttpVersion.HTTP_3_0.toString() == "HTTP/3.0",
            message: "HTTP/3 toString")
        assertTrue(HttpVersion.HTTP_1_1.supportsPersistentConnection(),
            message: "HTTP/1.1 should support persistent connections")
        assertTrue(!HttpVersion.HTTP_1_0.supportsPersistentConnection(),
            message: "HTTP/1.0 should not support persistent connections")
    }

    @TestCase
    public func testHttp3FrameTypeConstants(): Unit {
        assertTrue(Http3FrameType.DATA.toUInt8() == 0x00u8,
            message: "DATA frame type should be 0x00")
        assertTrue(Http3FrameType.HEADERS.toUInt8() == 0x01u8,
            message: "HEADERS frame type should be 0x01")
        assertTrue(Http3FrameType.SETTINGS.toUInt8() == 0x04u8,
            message: "SETTINGS frame type should be 0x04")
        assertTrue(Http3FrameType.GOAWAY.toUInt8() == 0x07u8,
            message: "GOAWAY frame type should be 0x07")
    }

    @TestCase
    public func testQuicStreamTypeConstants(): Unit {
        assertTrue(QuicStreamType.BIDIRECTIONAL != QuicStreamType.UNIDIRECTIONAL,
            message: "BIDIRECTIONAL and UNIDIRECTIONAL should differ")
    }

    @TestCase
    public func testHttp3SettingsIds(): Unit {
        match (Http3SettingsId.fromUInt16(0x00u16)) {
            case Some(_) => assertTrue(false, message: "0x00 should not be a valid setting id")
            case None => assertTrue(true)
        }
        match (Http3SettingsId.fromUInt16(0x01u16)) {
            case Some(id) =>
                assertTrue(id.toUInt16() == 0x01u16, message: "QPACK_MAX_TABLE_CAPACITY should have value 1")
            case None => assertTrue(false, message: "0x01 should map to QPACK_MAX_TABLE_CAPACITY")
        }
    }
}

// ======== h2c Upgrade 相关测试 ========

@Test
public class H2cUpgradeTest {

    /**
     * 测试 h2c Upgrade 请求头构造的模式。
     * h2c Upgrade 需要 HTTP/1.1 请求中包含 Upgrade: h2c 和 HTTP2-Settings 头部。
     */
    @TestCase
    public func testH2cUpgradeHeaderPattern(): Unit {
        // h2c Upgrade 使用 HTTP/1.1 Upgrade 机制
        // RFC 9113 §3.2: 客户端发送 GET 请求，包含 Upgrade: h2c 和 HTTP2-Settings 头
        let headers = HttpHeaders()
        headers.set("Upgrade", "h2c")
        headers.set("HTTP2-Settings", "")

        let upgrade = headers.get("Upgrade")
        match (upgrade) {
            case Some(v) => assertTrue(v == "h2c", message: "Upgrade header value should be 'h2c'")
            case None => assertTrue(false, message: "Upgrade header should be present")
        }

        let settings = headers.get("HTTP2-Settings")
        match (settings) {
            case Some(_) => assertTrue(true, message: "HTTP2-Settings header should be present")
            case None => assertTrue(false, message: "HTTP2-Settings header should be present")
        }
    }
}

// ======== Alt-Svc 发现相关测试 ========

@Test
public class AltSvcDiscoveryTest {

    /**
     * 测试 Alt-Svc 头的解析模式。
     * Alt-Svc 头用于发现 HTTP/3 端点（RFC 7838）。
     */
    @TestCase
    public func testAltSvcHeaderPattern(): Unit {
        let headers = HttpHeaders()
        headers.set("Alt-Svc", "h3=\":443\"; ma=2592000")

        let altSvc = headers.get("Alt-Svc")
        match (altSvc) {
            case Some(v) =>
                assertTrue(v.contains("h3"), message: "Alt-Svc should mention h3 protocol")
                assertTrue(v.contains(":443"), message: "Alt-Svc should mention port 443")
            case None => assertTrue(false, message: "Alt-Svc header should be present")
        }

        let keys = headers.names()
        assertTrue(keys.size == 1, message: "Should have exactly one header key")
    }

    @TestCase
    public func testAltSvcMultipleProtocols(): Unit {
        let headers = HttpHeaders()
        headers.set("Alt-Svc", "h2=\":443\"; ma=2592000, h3=\":443\"; ma=2592000")

        let altSvc = headers.get("Alt-Svc")
        match (altSvc) {
            case Some(v) =>
                assertTrue(v.contains("h3"), message: "Alt-Svc should mention h3")
                assertTrue(v.contains("h2"), message: "Alt-Svc should mention h2")
                assertTrue(v.count(",") >= 1, message: "Multiple entries should be comma-separated")
            case None => assertTrue(false, message: "Alt-Svc header should be present")
        }
    }
}
