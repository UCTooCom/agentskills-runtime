package http_lib.server

import http_lib.connection.{Connection, MockConnection}
import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, ProtocolException}
import http_lib.message.HttpRequest

/**
 * ConnectionController 的测试 — HTTP 处理器的连接劫持支持。
 *
 * 测试使用 MockConnection 模拟双向字节流，
 * 验证 ConnectionController 正确代理读/写/关闭调用，
 * 到底层连接，转换到劫持状态，
 * 并根据 RFC 6455 执行 WebSocket 升级握手。
 */
@Test
public class ConnectionControllerTest {

    /**
     * 辅助函数：创建一个由新的 MockConnection 支持的 ConnectionController，无
     * 初始读取数据。简化了常见设置模式。
     */
    private func makeConnectionController(): (ConnectionController, MockConnection) {
        let conn = MockConnection([])
        let h = ConnectionController(conn)
        (h, conn)
    }

    // ---- 初始化 ----

    @TestCase
    public func testInitNotHijacked(): Unit {
        let (h, _) = makeConnectionController()
        assertFalse(h.isTakenOver(), message: "New ConnectionController should not be taken over")
    }

    // ---- 劫持 ----

    @TestCase
    public func testHijackReturnsConnection(): Unit {
        let (h, conn) = makeConnectionController()
        let result = h.takeover()
        assertTrue(result.isConnected(), message: "Hijack should return the underlying connection")
    }

    @TestCase
    public func testHijackSetsHijackedFlag(): Unit {
        let (h, _) = makeConnectionController()
        assertFalse(h.isTakenOver(), message: "Before takeover, isTakenOver should be false")
        h.takeover()
        assertTrue(h.isTakenOver(), message: "After takeover, isTakenOver should be true")
    }

    @TestCase
    public func testHijackReturnsSameConnectionInstance(): Unit {
        let (h, conn) = makeConnectionController()
        let result = h.takeover()
        // 写入返回的连接并验证其出现在 mock 中
        result.write([b'a', b'b', b'c'])
        let written = conn.getWrittenString()
        assertTrue(written == "abc", message: "The returned connection should be the same instance as the mock")
    }

    @TestCase
    public func testHijackIdempotent(): Unit {
        let (h, _) = makeConnectionController()
        h.takeover()
        assertTrue(h.isTakenOver(), message: "First takeover sets flag")
        h.takeover()
        assertTrue(h.isTakenOver(), message: "Second takeover should keep flag true")
    }

    // ---- 是否已劫持 ----

    @TestCase
    public func testIsHijackedInitialFalse(): Unit {
        let (h, _) = makeConnectionController()
        assertFalse(h.isTakenOver())
    }

    @TestCase
    public func testIsHijackedAfterConstructWithDifferentConnections(): Unit {
        let conn1 = MockConnection([])
        let h1 = ConnectionController(conn1)
        assertFalse(h1.isTakenOver())

        let conn2 = MockConnection([b'x'])
        let h2 = ConnectionController(conn2)
        assertFalse(h2.isTakenOver())
    }

    // ---- 写入 ----

    @TestCase
    public func testWriteDelegatesToConnection(): Unit {
        let (h, conn) = makeConnectionController()
        h.write([b'h', b'e', b'l', b'l', b'o'])
        let written = conn.getWrittenString()
        assertTrue(written == "hello", message: "Written data should match")
    }

    @TestCase
    public func testWriteEmptyArray(): Unit {
        let (h, conn) = makeConnectionController()
        h.write([])
        assertTrue(conn.getWriteCount() == 1, message: "Write should be called even for empty array")
        let written = conn.getWrittenBytes()
        assertTrue(written.size == 0, message: "Empty write produces zero bytes")
    }

    @TestCase
    public func testWriteMultipleTimes(): Unit {
        let (h, conn) = makeConnectionController()
        h.write([b'a'])
        h.write([b'b'])
        h.write([b'c'])
        let written = conn.getWrittenString()
        assertTrue(written == "abc", message: "Multiple writes should concatenate in order")
        assertTrue(conn.getWriteCount() == 3, message: "Should be three separate write calls")
    }

    @TestCase
    public func testWriteAfterHijackStillWorks(): Unit {
        let (h, conn) = makeConnectionController()
        h.takeover()
        h.write([b'd', b'a', b't', b'a'])
        let written = conn.getWrittenString()
        assertTrue(written == "data", message: "Write should work after takeover")
    }

    @TestCase
    public func testWriteBinaryData(): Unit {
        let (h, conn) = makeConnectionController()
        let binary: Array<UInt8> = [0x00, 0xFF, 0xAB, 0xCD]
        h.write(binary)
        let written = conn.getWrittenBytes()
        assertTrue(written.size == 4, message: "Binary data size should be preserved")
        assertTrue(written[0] == 0x00)
        assertTrue(written[1] == 0xFF)
        assertTrue(written[2] == 0xAB)
        assertTrue(written[3] == 0xCD)
    }

    // ---- 读取 ----

    @TestCase
    public func testReadReturnsData(): Unit {
        let conn = MockConnection([b'h', b'e', b'l', b'l', b'o'])
        let h = ConnectionController(conn)
        let buf = Array<UInt8>(10, repeat: 0)
        let n = h.read(buf)
        assertTrue(n == 5, message: "Should read 5 bytes, got: ${n}")
        let result = unsafe { String.withRawData(buf[0..5]) }
        assertTrue(result == "hello", message: "Read data should match")
    }

    @TestCase
    public func testReadPartialBuffer(): Unit {
        let conn = MockConnection([b'a', b'b', b'c', b'd', b'e'])
        let h = ConnectionController(conn)
        let buf = Array<UInt8>(3, repeat: 0)
        let n = h.read(buf)
        assertTrue(n == 3, message: "Should read only as many bytes as buffer size, got: ${n}")
        let result = unsafe { String.withRawData(buf[0..3]) }
        assertTrue(result == "abc", message: "First partial read should get 'abc'")
    }

    @TestCase
    public func testReadMultipleCalls(): Unit {
        let conn = MockConnection([b'a', b'b', b'c', b'd', b'e'])
        let h = ConnectionController(conn)
        var buf = Array<UInt8>(2, repeat: 0)
        var result = ""

        var n = h.read(buf)
        if (n > 0) { result += unsafe { String.withRawData(buf[0..n]) } }

        n = h.read(buf)
        if (n > 0) { result += unsafe { String.withRawData(buf[0..n]) } }

        n = h.read(buf)
        if (n > 0) { result += unsafe { String.withRawData(buf[0..n]) } }

        assertTrue(result == "abcde", message: "Cumulative reads should return all data, got: '${result}'")
    }

    @TestCase
    public func testReadReturnsZeroWhenNoData(): Unit {
        let (h, _) = makeConnectionController()
        let buf = Array<UInt8>(10, repeat: 0)
        let n = h.read(buf)
        assertTrue(n == 0, message: "Read on empty connection should return 0, got: ${n}")
    }

    @TestCase
    public func testReadAfterHijackStillWorks(): Unit {
        let conn = MockConnection([b't', b'e', b's', b't'])
        let h = ConnectionController(conn)
        h.takeover()
        let buf = Array<UInt8>(10, repeat: 0)
        let n = h.read(buf)
        assertTrue(n == 4, message: "Read should work after takeover, got: ${n}")
    }

    // ---- 关闭 ----

    @TestCase
    public func testCloseClosesConnection(): Unit {
        let (h, conn) = makeConnectionController()
        assertTrue(conn.isConnected(), message: "Connection should be open before close")
        h.close()
        assertFalse(conn.isConnected(), message: "Connection should be closed after close")
    }

    @TestCase
    public func testCloseIsIdempotent(): Unit {
        let (h, conn) = makeConnectionController()
        h.close()
        h.close()  // 第二次关闭不应抛出异常
        assertFalse(conn.isConnected(), message: "Connection stays closed after second close")
    }

    @TestCase
    public func testCloseReturnsAfterHijack(): Unit {
        let (h, conn) = makeConnectionController()
        h.takeover()
        h.close()
        assertFalse(conn.isConnected(), message: "Connection should close even after takeover")
    }

    @TestCase
    public func testWriteAfterCloseDoesNotThrow(): Unit {
        let (h, conn) = makeConnectionController()
        h.close()
        // 关闭后写入不应抛出异常；mock 在关闭时静默丢弃写入
        h.write([b't', b'e', b's', b't'])
        let written = conn.getWrittenString()
        assertTrue(written == "", message: "Write after close should be discarded")
    }

    @TestCase
    public func testReadAfterCloseReturnsZeroOrMinusOne(): Unit {
        let conn = MockConnection([b'd', b'a', b't', b'a'])
        let h = ConnectionController(conn)
        h.close()
        let buf = Array<UInt8>(10, repeat: 0)
        let n = h.read(buf)
        // 关闭后，mock 返回 -1（isOpen 为 false）
        assertTrue(n <= 0, message: "Read after close should return <= 0, got: ${n}")
    }

    // ---- upgradeToWebSocket（使用密钥字符串）----

    @TestCase
    public func testUpgradeToWebSocketStringWrites101Response(): Unit {
        let (h, conn) = makeConnectionController()
        h.upgradeToWebSocket("dGhlIHNhbXBsZSBub25jZQ==")
        let written = conn.getWrittenString()
        assertTrue(written.contains("101 Switching Protocols"),
            message: "Response should contain 101 status, got: ${written}")
        assertTrue(written.contains("Upgrade: websocket"),
            message: "Response should contain Upgrade header")
        assertTrue(written.contains("Connection: Upgrade"),
            message: "Response should contain Connection header")
        assertTrue(written.contains("Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo="),
            message: "Response should have correct Sec-WebSocket-Accept per RFC 6455")
    }

    @TestCase
    public func testUpgradeToWebSocketStringSetsHijackedFlag(): Unit {
        let (h, _) = makeConnectionController()
        assertFalse(h.isTakenOver(), message: "Not taken over before upgrade")
        h.upgradeToWebSocket("dGhlIHNhbXBsZSBub25jZQ==")
        assertTrue(h.isTakenOver(), message: "Hijacked after upgradeToWebSocket")
    }

    @TestCase
    public func testUpgradeToWebSocketStringResponseFormat(): Unit {
        let (h, conn) = makeConnectionController()
        h.upgradeToWebSocket("dGhlIHNhbXBsZSBub25jZQ==")
        let written = conn.getWrittenString()
        // 验证完整响应格式以 CRLF CRLF 结尾
        assertTrue(written.endsWith("\r\n\r\n"),
            message: "Response should end with double CRLF")
        // 验证头部以 CRLF 结尾
        assertTrue(written.contains("\r\n"),
            message: "Response should use CRLF line endings")
    }

    @TestCase
    public func testUpgradeToWebSocketStringEmptyKey(): Unit {
        let (h, conn) = makeConnectionController()
        h.upgradeToWebSocket("")
        let written = conn.getWrittenString()
        // 空密钥仍会产生 accept 值（仅有 magic GUID 的 SHA-1）
        assertTrue(written.contains("101 Switching Protocols"),
            message: "Empty key should still produce 101")
        assertTrue(h.isTakenOver(), message: "Should still take over with empty key")
    }

    @TestCase
    public func testUpgradeToWebSocketStringKeyVariesByInput(): Unit {
        let (h1, conn1) = makeConnectionController()
        let (h2, conn2) = makeConnectionController()
        h1.upgradeToWebSocket("key1")
        h2.upgradeToWebSocket("key2")
        let resp1 = conn1.getWrittenString()
        let resp2 = conn2.getWrittenString()
        // 不同密钥产生不同的 accept 值
        assertFalse(resp1 == resp2,
            message: "Different keys should produce different Sec-WebSocket-Accept values")
    }

    // ---- upgradeToWebSocket（使用 HttpRequest）----

    @TestCase
    public func testUpgradeToWebSocketRequestWrites101Response(): Unit {
        let (h, conn) = makeConnectionController()
        let req = HttpRequest()
        req.headers.set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
        h.upgradeToWebSocket(req)
        let written = conn.getWrittenString()
        assertTrue(written.contains("101 Switching Protocols"),
            message: "Response should contain 101 status")
        assertTrue(written.contains("Upgrade: websocket"),
            message: "Response should contain Upgrade header")
        assertTrue(written.contains("Connection: Upgrade"),
            message: "Response should contain Connection header")
        assertTrue(written.contains("Sec-WebSocket-Accept"),
            message: "Response should contain Sec-WebSocket-Accept")
    }

    @TestCase
    public func testUpgradeToWebSocketRequestSetsHijacked(): Unit {
        let (h, _) = makeConnectionController()
        let req = HttpRequest()
        req.headers.set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
        h.upgradeToWebSocket(req)
        assertTrue(h.isTakenOver(), message: "ConnectionController should be taken over after upgrade")
    }

    @TestCase
    public func testUpgradeToWebSocketRequestSetsReqHijacked(): Unit {
        let (h, _) = makeConnectionController()
        let req = HttpRequest()
        req.headers.set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
        assertFalse(req.takenOver, message: "Request takeover flag should be false before upgrade")
        h.upgradeToWebSocket(req)
        assertTrue(req.takenOver, message: "Request takeover flag should be true after upgrade")
    }

    @TestCase
    public func testUpgradeToWebSocketRequestMissingKeyThrows(): Unit {
        let (h, _) = makeConnectionController()
        let req = HttpRequest()
        // 未设置 Sec-WebSocket-Key 头部
        let threw = try {
            h.upgradeToWebSocket(req)
            false
        } catch (e: ProtocolException) {
            true
        } catch (_: Exception) {
            true
        }
        assertTrue(threw, message: "Should throw ProtocolException when Sec-WebSocket-Key is missing")
    }

    @TestCase
    public func testUpgradeToWebSocketRequestRemainsNotHijackedOnError(): Unit {
        let (h, _) = makeConnectionController()
        let req = HttpRequest()
        let _ = try {
            h.upgradeToWebSocket(req)
        } catch (_: Exception) {
            // 期望值
        }
        assertFalse(h.isTakenOver(),
            message: "ConnectionController should not be taken over when upgrade throws")
        assertFalse(req.takenOver,
            message: "Request should not be marked taken over when upgrade throws")
    }

    @TestCase
    public func testUpgradeToWebSocketRequestCaseInsensitiveKey(): Unit {
        let (h, conn) = makeConnectionController()
        let req = HttpRequest()
        // HttpHeaders 会标准化键名，但测试小写以确保其正常工作
        req.headers.set("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
        h.upgradeToWebSocket(req)
        let written = conn.getWrittenString()
        assertTrue(written.contains("101 Switching Protocols"),
            message: "Case-insensitive header lookup should work")
        assertTrue(req.takenOver,
            message: "Request should be taken over")
    }

    @TestCase
    public func testUpgradeToWebSocketRequestKnownAcceptValue(): Unit {
        let (h, conn) = makeConnectionController()
        let req = HttpRequest()
        // RFC 6455 示例密钥 -> "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
        req.headers.set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
        h.upgradeToWebSocket(req)
        let written = conn.getWrittenString()
        assertTrue(written.contains("s3pPLMBiTxaQ9kYGzzhZRbK+xOo="),
            message: "Sec-WebSocket-Accept should match RFC 6455 example")
    }

    @TestCase
    public func testUpgradeToWebSocketWritesToConnectionBeforeHijackFlag(): Unit {
        // 验证 101 响应已写入连接——响应
        // 必须在设置 takeover 标志之前发送，以便服务器发送它。
        let (h, conn) = makeConnectionController()
        h.upgradeToWebSocket("dGhlIHNhbXBsZSBub25jZQ==")
        assertTrue(conn.getWriteCount() >= 1,
            message: "At least one write should have occurred during upgrade")
    }

    @TestCase
    public func testUpgradeToWebSocketRequestWithRandomKeyProducesAccept(): Unit {
        let (h, conn) = makeConnectionController()
        let req = HttpRequest()
        req.headers.set("Sec-WebSocket-Key", "x3JJHMbLiH1f9ODt6Q==")
        h.upgradeToWebSocket(req)
        let written = conn.getWrittenString()
        assertTrue(written.contains("Sec-WebSocket-Accept: "),
            message: "Random key should produce an accept value")
        assertTrue(written.endsWith("\r\n\r\n"),
            message: "Response should end with CRLF CRLF")
    }
}
