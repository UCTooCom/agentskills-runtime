/**
 * HTTP/3 Capsule Protocol 单元测试（RFC 9297）。
 *
 * 覆盖：
 * - 胶囊类型枚举值
 * - DATAGRAM 胶囊编码/解码
 * - CLOSE 胶囊编码/解码
 * - DATAGRAM_WITH_CONTEXT 胶囊
 * - 截断数据解码异常
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse, ProtocolException}

// ======== 胶囊类型测试 ========

@Test
public class H3CapsuleTypeTest {

    @TestCase
    public func testCapsuleTypeValues(): Unit {
        assertTrue(H3CapsuleType.DATA.toUInt64() == 0x00u64)
        assertTrue(H3CapsuleType.DATAGRAM.toUInt64() == 0x01u64)
        assertTrue(H3CapsuleType.DATAGRAM_WITH_CONTEXT.toUInt64() == 0x02u64)
        assertTrue(H3CapsuleType.CLOSE.toUInt64() == 0x03u64)
    }

    @TestCase
    public func testCapsuleTypeRoundtrip(): Unit {
        let types = [H3CapsuleType.DATA, H3CapsuleType.DATAGRAM,
            H3CapsuleType.DATAGRAM_WITH_CONTEXT, H3CapsuleType.CLOSE]
        for (t in types) {
            let v = t.toUInt64()
            let back = H3CapsuleType.fromUInt64(v)
            match (back) {
                case Some(bt) => assertTrue(t == bt, message: "${t} round-trip failed")
                case None => assertTrue(false, message: "${t} should round-trip")
            }
        }
    }
}

// ======== 胶囊编解码测试 ========

@Test
public class H3CapsuleEncodeDecodeTest {

    @TestCase
    public func testEncodeDecodeDatagramCapsule(): Unit {
        let payload: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F] // "Hello"
        let capsule = buildDatagramCapsule(payload)
        let encoded = encodeH3Capsule(capsule)
        let decoded = decodeH3Capsule(encoded)
        assertTrue(decoded.capsuleType == H3CapsuleType.DATAGRAM,
            message: "Decoded type should be DATAGRAM")
        assertTrue(decoded.payload.size == 5, message: "Payload should be 5 bytes")
        assertTrue(decoded.payload[0] == 0x48, message: "First byte should be 'H'")
    }

    @TestCase
    public func testEncodeDecodeCloseCapsule(): Unit {
        let capsule = buildCloseCapsule()
        let encoded = encodeH3Capsule(capsule)
        let decoded = decodeH3Capsule(encoded)
        assertTrue(decoded.capsuleType == H3CapsuleType.CLOSE,
            message: "Decoded type should be CLOSE")
        assertTrue(decoded.payload.size == 0, message: "Close payload should be empty")
    }

    @TestCase
    public func testDatagramWithContextCapsule(): Unit {
        let payload: Array<UInt8> = [0x01, 0x02, 0x03]
        let capsule = buildDatagramWithContextCapsule(0x0102u64, payload)
        let encoded = encodeH3Capsule(capsule)
        let decoded = decodeH3Capsule(encoded)
        assertTrue(decoded.capsuleType == H3CapsuleType.DATAGRAM_WITH_CONTEXT,
            message: "Decoded type should be DATAGRAM_WITH_CONTEXT")
        assertTrue(decoded.payload.size == 5, message: "Payload should be 5 bytes")
    }

    @TestCase
    public func testDecodeTruncatedThrows(): Unit {
        var threw = false
        try {
            let _ = decodeH3Capsule([0x01])
        } catch (e: ProtocolException) {
            threw = true
        }
        assertTrue(threw, message: "Truncated capsule should throw")
    }
}

// ======== H3Capsule ToString 测试 ========

@Test
public class H3CapsuleToStringTest {

    @TestCase
    public func testCapsuleToString(): Unit {
        let dataCapsule = buildDatagramCapsule([0x48, 0x65])
        let s1 = dataCapsule.toString()
        assertTrue(s1.size > 0, message: "toString should not be empty")
        assertTrue(s1.contains("DATAGRAM") || s1.contains("datagram"),
            message: "toString should mention capsule type")
    }

    @TestCase
    public func testCloseCapsuleToString(): Unit {
        let closeCapsule = buildCloseCapsule()
        let s2 = closeCapsule.toString()
        assertTrue(s2.size > 0, message: "toString should not be empty")
        assertTrue(s2.contains("CLOSE") || s2.contains("close"),
            message: "toString should mention close type")
    }
}


// ======== H3WebSocketConnection 测试 ========

@Test
public class H3WebSocketConnectionTest {

    private func createWSConn(): H3WebSocketConnection  {
        let quicConn = MockQuicConnection(serverMode: false)
        let h3Conn = H3Connection(quicConn, config: H3ConnectionConfig(), isServer: false)
        let tunnel = H3WebSocketTunnel(h3Conn, 0u64)
        let wsConn = H3WebSocketConnection(tunnel)
        wsConn
    }

    @TestCase
    public func testWSConnectionGetLocalAddress(): Unit {
        let wsConn = createWSConn()
        assertTrue(wsConn.getLocalAddress() == "", message: "Default local address should be empty")
    }

    @TestCase
    public func testWSConnectionSetLocalAddress(): Unit {
        let wsConn = createWSConn()
        wsConn.setLocalAddress("192.168.1.1:8080")
        assertTrue(wsConn.getLocalAddress() == "192.168.1.1:8080",
            message: "Local address should be updated")
    }

    @TestCase
    public func testWSConnectionGetRemoteAddress(): Unit {
        let wsConn = createWSConn()
        assertTrue(wsConn.getRemoteAddress() == "", message: "Default remote address should be empty")
    }

    @TestCase
    public func testWSConnectionSetRemoteAddress(): Unit {
        let wsConn = createWSConn()
        wsConn.setRemoteAddress("192.168.1.2:9090")
        assertTrue(wsConn.getRemoteAddress() == "192.168.1.2:9090",
            message: "Remote address should be updated")
    }

    @TestCase
    public func testWSConnectionClose(): Unit {
        let wsConn = createWSConn()
        assertFalse(wsConn.isClosed(), message: "Should not be closed initially")
        wsConn.close()
        assertTrue(wsConn.isClosed(), message: "Should be closed after close()")
    }

    @TestCase
    public func testWSConnectionCloseIdempotent(): Unit {
        let wsConn = createWSConn()
        wsConn.close()
        try {
            wsConn.close()
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "close() should be idempotent")
        }
    }
}


// ======== H3WebSocketTunnel 胶囊收发测试 ========

@Test
public class H3WebSocketTunnelRecvTest {

    private func createTunnel(): H3WebSocketTunnel {
        let quicConn = MockQuicConnection(serverMode: false)
        let h3Conn = H3Connection(quicConn, config: H3ConnectionConfig(), isServer: false)
        H3WebSocketTunnel(h3Conn, 0u64)
    }

    @TestCase
    public func testTunnelOnDataReceivedAndRecv(): Unit {
        let tunnel = createTunnel()
        let payload: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F] // "Hello"
        let capsule = buildDatagramCapsule(payload)
        let encoded = encodeH3Capsule(capsule)
        tunnel.onDataReceived(encoded)
        let (data, isClosed) = tunnel.recv()
        assertTrue(data.size == 5, message: "Should receive 5 bytes")
        assertTrue(data[0] == 0x48, message: "First byte should be 'H' (0x48)")
        assertFalse(isClosed, message: "Should not be closed after receiving")
    }

    @TestCase
    public func testTunnelRecvEmptyWhenNoData(): Unit {
        let tunnel = createTunnel()
        let (data, isClosed) = tunnel.recv()
        assertTrue(data.size == 0, message: "Should return empty when no data")
        assertFalse(isClosed, message: "Should not be closed")
    }
}





// ======== ConnectUdpTunnel 测试 ========

@Test
public class ConnectUdpTunnelTest {

    private func createTunnel(): ConnectUdpTunnel {
        let quicConn = MockQuicConnection(serverMode: false)
        let h3Conn = H3Connection(quicConn, config: H3ConnectionConfig(), isServer: false)
        ConnectUdpTunnel(h3Conn, 0u64)
    }

    @TestCase
    public func testInitialState(): Unit {
        let tunnel = createTunnel()
        assertFalse(tunnel.isClosed(), message: "Tunnel should not be closed initially")
    }

    @TestCase
    public func testSendAndReceiveDatagram(): Unit {
        let tunnel = createTunnel()
        let payload: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F]
        let capsule = buildDatagramCapsule(payload)
        let encoded = encodeH3Capsule(capsule)
        tunnel.onDataReceived(encoded)
        let (data, isClosed) = tunnel.recv()
        assertTrue(data.size == 5, message: "Should receive 5 bytes")
        assertTrue(data[0] == 0x48, message: "First byte should be 'H' (0x48)")
        assertFalse(isClosed, message: "Should not be closed after receiving")
    }

    @TestCase
    public func testRecvEmptyWhenNoData(): Unit {
        let tunnel = createTunnel()
        let (data, isClosed) = tunnel.recv()
        assertTrue(data.size == 0, message: "Should return empty when no data")
        assertFalse(isClosed, message: "Should not be closed")
    }

    @TestCase
    public func testCloseCapsuleMarksClosed(): Unit {
        let tunnel = createTunnel()
        let closeCap = buildCloseCapsule()
        tunnel.onDataReceived(encodeH3Capsule(closeCap))
        assertTrue(tunnel.isClosed(), message: "Tunnel should be closed after CLOSE capsule")
    }

    @TestCase
    public func testCloseMethod(): Unit {
        let tunnel = createTunnel()
        tunnel.close()
        assertTrue(tunnel.isClosed(), message: "Tunnel should be closed after close()")
    }

    @TestCase
    public func testCloseIdempotent(): Unit {
        let tunnel = createTunnel()
        tunnel.close()
        try {
            tunnel.close()
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "close() should be idempotent")
        }
    }

    @TestCase
    public func testSendThrowsAfterClose(): Unit {
        let tunnel = createTunnel()
        tunnel.close()
        try {
            tunnel.send([0x00u8])
            assertTrue(false, message: "send() should throw after close")
        } catch (_: Exception) {
            assertTrue(true)
        }
    }

    @TestCase
    public func testRecvReturnsClosedFlagAfterClose(): Unit {
        let tunnel = createTunnel()
        tunnel.close()
        let (_, isClosed) = tunnel.recv()
        assertTrue(isClosed, message: "recv() should return closed=true after close")
    }

    @TestCase
    public func testDatagramWithContextCapsule(): Unit {
        let tunnel = createTunnel()
        let payload: Array<UInt8> = [0x00u8, 0x48, 0x69]
        let capsule = buildDatagramWithContextCapsule(0u64, payload)
        let encoded = encodeH3Capsule(capsule)
        tunnel.onDataReceived(encoded)
        let (data, _) = tunnel.recv()
        assertTrue(data.size > 0, message: "Should extract data from DATAGRAM_WITH_CONTEXT")
    }
}
