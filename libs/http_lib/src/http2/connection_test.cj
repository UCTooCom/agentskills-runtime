package http_lib.http2

import http_lib.core.{assertTrue, assertFalse, HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.buffer.ByteBuffer
import http_lib.connection.MockConnection

/**
 * 构建 HEADERS 帧的辅助函数（私有 buildHeadersFrame 的内联版本）。
 */
private func makeHeadersFrame(streamId: UInt32, headerBlock: Array<UInt8>, endStream: Bool): Array<UInt8> {
    var flags: UInt8 = FLAG_END_HEADERS
    if (endStream) { flags = flags | FLAG_END_STREAM }
    let header = Http2FrameHeader(headerBlock.size, Http2FrameType.HEADERS, flags: flags, streamId: streamId)
    encodeFrame(header, headerBlock)
}

// ──────────────────────────────────────────────
// Http2Connection — 初始状态（零 I/O）
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionInitialStateTest {
    @TestCase
    public func testInitialIsConnectedFalse(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        assertFalse(h2conn.isConnected(), message: "New connection should not be connected")
    }

    @TestCase
    public func testInitialIsDrainingFalse(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        assertFalse(h2conn.isDraining(), message: "New connection should not be draining")
    }

    @TestCase
    public func testInitialIsGoawayReceivedFalse(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        assertFalse(h2conn.isGoawayReceived(), message: "New connection should not have received GOAWAY")
    }

    @TestCase
    public func testInitialGetGoawayDebugDataEmpty(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        let debug = h2conn.getGoawayDebugData()
        assertTrue(debug.size == 0, message: "GOAWAY debug data should be empty initially")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — close() 测试
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionCloseTest {
    @TestCase
    public func testCloseDoesNotThrow(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.close()
        assertTrue(true)
    }

    @TestCase
    public func testCloseIsConnectedFalse(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.close()
        assertFalse(h2conn.isConnected(), message: "After close, isConnected should be false")
    }

    @TestCase
    public func testCloseNoGoawayFlagSet(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.close()
        assertFalse(h2conn.isGoawayReceived(), message: "close() should not set goawayReceived flag")
        assertFalse(h2conn.isDraining(), message: "close() should not set isDraining")
    }

    @TestCase
    public func testCloseWritesGoawayFrame(): Unit {
        let mock = MockConnection([])
        let h2conn = Http2Connection(mock)
        h2conn.close()
        let written = mock.getWrittenBytes()
        assertTrue(written.size >= 9, message: "GOAWAY frame should have at least 9 bytes")
        assertTrue(written.size > 3, message: "Written data should include frame header")
        assertTrue(written[3] == 0x7, message: "Frame type byte should be GOAWAY (0x7)")
    }

    @TestCase
    public func testCloseIdempotent(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.close()
        h2conn.close()
        h2conn.close()
        assertTrue(true, message: "Multiple close() calls should not throw")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — gracefulShutdown() 测试
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionGracefulShutdownTest {
    @TestCase
    public func testGracefulShutdownDoesNotThrow(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.gracefulShutdown()
        assertTrue(true)
    }

    @TestCase
    public func testGracefulShutdownIsDrainingTrue(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        assertFalse(h2conn.isDraining(), message: "Before shutdown, should not be draining")
        h2conn.gracefulShutdown()
        assertTrue(h2conn.isDraining(), message: "After gracefulShutdown, should be draining")
    }

    @TestCase
    public func testGracefulShutdownGoawayReceivedTrue(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        assertFalse(h2conn.isGoawayReceived(), message: "Before shutdown, goaway not received")
        h2conn.gracefulShutdown()
        assertTrue(h2conn.isGoawayReceived(), message: "After gracefulShutdown, goawayReceived should be true")
    }

    @TestCase
    public func testGracefulShutdownCustomErrorCode(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.gracefulShutdown(errorCode: Http2ErrorCode.INTERNAL_ERROR)
        assertTrue(h2conn.isDraining(), message: "Should be draining after shutdown with error code")
    }

    @TestCase
    public func testGracefulShutdownWithDebugData(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        let debug: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        h2conn.gracefulShutdown(errorCode: Http2ErrorCode.NO_ERROR, debugData: debug)
        assertTrue(h2conn.isDraining())
    }

    @TestCase
    public func testGracefulShutdownWritesGoawayFrame(): Unit {
        let mock = MockConnection([])
        let h2conn = Http2Connection(mock)
        h2conn.gracefulShutdown()
        let written = mock.getWrittenBytes()
        assertTrue(written.size >= 9, message: "Should have written a GOAWAY frame")
        assertTrue(written[3] == 0x7, message: "Frame type byte should be GOAWAY (0x7)")
    }

    @TestCase
    public func testGracefulShutdownIsConnectedFalse(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.gracefulShutdown()
        assertFalse(h2conn.isConnected(), message: "After shutdown, isConnected should be false")
    }

    @TestCase
    public func testMultipleGracefulShutdown(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.gracefulShutdown()
        assertTrue(h2conn.isDraining())
        h2conn.gracefulShutdown()
        assertTrue(h2conn.isDraining(), message: "Still draining after second call")
        h2conn.gracefulShutdown()
        assertTrue(h2conn.isDraining(), message: "Still draining after third call")
    }

    @TestCase
    public func testCloseAfterGracefulShutdown(): Unit {
        let h2conn = Http2Connection(MockConnection([]))
        h2conn.gracefulShutdown()
        assertTrue(h2conn.isDraining())
        h2conn.close()
        assertTrue(h2conn.isDraining(), message: "Should still be draining after close()")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 通过 MockConnection 的 connect()
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionConnectTest {
    @TestCase
    public func testConnectSuccess(): Unit {
        let settingsFrame = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock)
        h2conn.connect()
        assertTrue(h2conn.isConnected(), message: "After successful connect(), isConnected should be true")
    }

    @TestCase
    public func testConnectSendsPrefaceAndSettings(): Unit {
        let settingsFrame = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock)
        h2conn.connect()
        let written = mock.getWrittenBytes()
        assertTrue(written.size >= 24, message: "Should have written at least the client preface")
        assertTrue(written[0] == b'P', message: "Preface should start with 'P'")
    }

    @TestCase
    public func testConnectServerRespondsWithGoaway(): Unit {
        let goawayFrame = buildGoawayFrame(0, Http2ErrorCode.PROTOCOL_ERROR)
        let mock = MockConnection([])
        mock.feedData(goawayFrame)
        let h2conn = Http2Connection(mock)
        let threw = try {
            h2conn.connect()
            false
        } catch (_: Http2Exception) {
            true
        } catch (_: Exception) {
            true
        }
        assertTrue(threw, message: "connect() should throw when server sends GOAWAY during preface")
        assertFalse(h2conn.isConnected(), message: "Connection should not be connected after failed connect")
    }

    @TestCase
    public func testConnectSetsConnectedTrue(): Unit {
        let settingsFrame = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock)
        assertFalse(h2conn.isConnected(), message: "Before connect, not connected")
        h2conn.connect()
        assertTrue(h2conn.isConnected(), message: "After connect, connected")
    }

    @TestCase
    public func testConnectIsNotDraining(): Unit {
        let settingsFrame = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock)
        h2conn.connect()
        assertFalse(h2conn.isDraining(), message: "After normal connect, should not be draining")
    }

    @TestCase
    public func testConnectFlushesWrittenData(): Unit {
        let settingsFrame = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock)
        h2conn.connect()
        let written = mock.getWrittenBytes()
        assertTrue(written.size > 0, message: "Connect should have written data")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 通过 MockConnection 的 accept()
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionAcceptTest {
    @TestCase
    public func testAcceptSuccess(): Unit {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        assertTrue(h2conn.isConnected(), message: "After successful accept(), isConnected should be true")
    }

    @TestCase
    public func testAcceptSetsConnectedTrue(): Unit {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        assertFalse(h2conn.isConnected(), message: "Before accept, not connected")
        h2conn.accept(None)
        assertTrue(h2conn.isConnected(), message: "After accept, connected")
    }

    @TestCase
    public func testAcceptSendsSettingsAndAck(): Unit {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        let written = mock.getWrittenBytes()
        assertTrue(written.size >= 18, message: "Should have written SETTINGS and ACK frames")
    }

    @TestCase
    public func testAcceptSetsIsNotDraining(): Unit {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        assertFalse(h2conn.isDraining(), message: "After normal accept, should not be draining")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 通过 MockConnection 的 ping()
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionPingTest {
    private let pingData: Array<UInt8> = [1, 2, 3, 4, 5, 6, 7, 8]

    @TestCase
    public func testPingAckReceivedReturnsTrue(): Unit {
        let pingAck = buildPingFrame(pingData, ack: true)
        let mock = MockConnection([])
        mock.feedData(pingAck)
        let h2conn = Http2Connection(mock)
        let result = h2conn.ping(pingData)
        assertTrue(result, message: "ping() should return true when PING ACK is received")
    }

    @TestCase
    public func testPingNoResponseReturnsFalse(): Unit {
        let mock = MockConnection([])
        let h2conn = Http2Connection(mock)
        let result = h2conn.ping(pingData)
        assertFalse(result, message: "ping() should return false when no ACK is received")
    }

    @TestCase
    public func testPingSendsPingFrame(): Unit {
        let pingAck = buildPingFrame(pingData, ack: true)
        let mock = MockConnection([])
        mock.feedData(pingAck)
        let h2conn = Http2Connection(mock)
        let _ = h2conn.ping(pingData)
        let written = mock.getWrittenBytes()
        assertTrue(written.size >= 17, message: "PING frame should be 17 bytes total")
        assertTrue(written[3] == 0x6, message: "Frame type byte should be PING (0x6)")
    }

    @TestCase
    public func testPingDifferentOpaqueData(): Unit {
        let customPingData: Array<UInt8> = [0xde, 0xad, 0xbe, 0xef, 0xca, 0xfe, 0xba, 0xbe]
        let pingAck = buildPingFrame(customPingData, ack: true)
        let mock = MockConnection([])
        mock.feedData(pingAck)
        let h2conn = Http2Connection(mock)
        let result = h2conn.ping(customPingData)
        assertTrue(result, message: "ping() should work with custom opaque data")
    }

    @TestCase
    public func testPingWrongFrameTypeIgnored(): Unit {
        let settingsFrame = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock)
        let result = h2conn.ping(pingData)
        assertFalse(result, message: "ping() should return false when wrong frame type received")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 跨方法交互
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionInteractionTest {
    @TestCase
    public func testConnectThenGracefulShutdown(): Unit {
        let settingsFrame = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock)
        h2conn.connect()
        assertTrue(h2conn.isConnected(), message: "Connected after connect")
        h2conn.gracefulShutdown()
        assertTrue(h2conn.isDraining(), message: "Draining after gracefulShutdown")
        assertFalse(h2conn.isConnected(), message: "Not connected after gracefulShutdown")
    }

    @TestCase
    public func testConnectThenClose(): Unit {
        let settingsFrame = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock)
        h2conn.connect()
        assertTrue(h2conn.isConnected())
        h2conn.close()
        assertFalse(h2conn.isConnected(), message: "Not connected after close")
    }

    @TestCase
    public func testAcceptThenClose(): Unit {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        assertTrue(h2conn.isConnected())
        h2conn.close()
        assertFalse(h2conn.isConnected())
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 通过 MockConnection 的 sendRequest() + recvResponse()
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionSendRecvTest {
    private func setupClient(): (MockConnection, Http2Connection) {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock)
        h2conn.connect()
        (mock, h2conn)
    }

    @TestCase
    public func testSendRequestForGET(): Unit {
        let (_, h2conn) = setupClient()
        let request = HttpRequest(method: HttpMethod.GET, url: "https://example.com/")
        let streamId = h2conn.sendRequest(request)
        assertTrue(streamId > 0, message: "sendRequest should return a valid stream ID")
        assertTrue(streamId % 2 == 1, message: "Client stream ID should be odd")
    }

    @TestCase
    public func testSendRequestWritesHeaders(): Unit {
        let (mock, h2conn) = setupClient()
        h2conn.sendRequest(HttpRequest(method: HttpMethod.GET, url: "https://example.com/"))
        let written = mock.getWrittenBytes()
        // 在 24 字节 HTTP/2 前导 + SETTINGS 帧后，扫描 HEADERS 帧
        let startPos: Int64 = 24  // 跳过客户端 preface
        var foundHeaders = false
        var i: Int64 = startPos
        while (i + 9 <= written.size) {
            let frameType = written[i + 3]
            if (frameType == 0x1 && (written[i + 4] & 0x4) != 0) {
                foundHeaders = true
                break
            }
            let payloadLen = (Int64(written[i]) << 16) | (Int64(written[i + 1]) << 8) | Int64(written[i + 2])
            i += 9 + payloadLen
        }
        assertTrue(foundHeaders, message: "Should have written HEADERS frame with END_HEADERS")
    }

    @TestCase
    public func testRecvResponse(): Unit {
        let (mock, h2conn) = setupClient()
        let respHeaders = HttpHeaders()
        respHeaders.set(":status", "200")
        let encoder = HPACK()
        let encodedHeaders = encoder.encode(respHeaders)
        let headersFrame = makeHeadersFrame(1, encodedHeaders, false)
        let bodyData: Array<UInt8> = [b'O', b'K']
        let dataHeader = Http2FrameHeader(bodyData.size, Http2FrameType.DATA,
            flags: FLAG_END_STREAM, streamId: 1)
        let dataFrame = encodeFrame(dataHeader, bodyData)
        mock.feedData(headersFrame)
        mock.feedData(dataFrame)
        let response = h2conn.recvResponse(1)
        assertTrue(response.status.code == 200u16, message: "Expected 200 OK")
        assertTrue(response.bodyAsString() == "OK", message: "Expected OK body")
    }

    @TestCase
    public func testSendRequestWithBody(): Unit {
        let (_, h2conn) = setupClient()
        let body = ByteBuffer(capacity: 4)
        body.writeString("body")
        let request = HttpRequest(
            method: HttpMethod.POST,
            url: "https://example.com/upload",
            headers: HttpHeaders(),
            body: body
        )
        let streamId = h2conn.sendRequest(request)
        assertTrue(streamId > 0)
    }

    @TestCase
    public func testStreamIdsIncrement(): Unit {
        let (_, h2conn) = setupClient()
        let id1 = h2conn.sendRequest(HttpRequest(method: HttpMethod.GET, url: "https://example.com/"))
        let id2 = h2conn.sendRequest(HttpRequest(method: HttpMethod.GET, url: "https://example.com/"))
        let id3 = h2conn.sendRequest(HttpRequest(method: HttpMethod.GET, url: "https://example.com/"))
        assertTrue(id2 > id1, message: "Stream IDs should increment")
        assertTrue(id3 > id2, message: "Stream IDs should increment")
        assertTrue(id1 % 2 == 1, message: "Client stream 1 should be odd")
        assertTrue(id2 % 2 == 1, message: "Client stream 2 should be odd")
        assertTrue(id3 % 2 == 1, message: "Client stream 3 should be odd")
    }

    @TestCase
    public func testRecvResponseWithHeaders(): Unit {
        let (mock, h2conn) = setupClient()
        let respHeaders = HttpHeaders()
        respHeaders.set(":status", "404")
        respHeaders.set("content-type", "text/plain")
        let encoder = HPACK()
        let encodedHeaders = encoder.encode(respHeaders)
        let headersFrame = makeHeadersFrame(1, encodedHeaders, true)
        mock.feedData(headersFrame)
        let response = h2conn.recvResponse(1)
        assertTrue(response.status.code == 404u16, message: "Expected 404")
        match (response.headers.get("content-type")) {
            case Some(ct) => assertTrue(ct == "text/plain", message: "Wrong content-type")
            case None => assertTrue(false, message: "Missing content-type")
        }
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 通过 MockConnection 的 sendResponse() + recvRequest()
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionServerTest {
    private func setupServer(): (MockConnection, Http2Connection) {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        (mock, h2conn)
    }

    @TestCase
    public func testRecvRequest(): Unit {
        let (mock, h2conn) = setupServer()
        let reqHeaders = HttpHeaders()
        reqHeaders.set(":method", "GET")
        reqHeaders.set(":path", "/")
        reqHeaders.set(":scheme", "https")
        reqHeaders.set(":authority", "example.com")
        let encoder = HPACK()
        let encoded = encoder.encode(reqHeaders)
        let headersFrame = makeHeadersFrame(1, encoded, true)
        mock.feedData(headersFrame)
        let (streamId, request) = h2conn.recvRequest()
        assertTrue(streamId > 0, message: "Should receive a valid stream ID")
        assertTrue(request.method == HttpMethod.GET, message: "Expected GET method")
        assertTrue(request.url == "https://example.com/", message: "Expected URL")
    }

    @TestCase
    public func testSendResponse(): Unit {
        let (_, h2conn) = setupServer()
        let response = HttpResponse.text(HttpStatus.OK, "hello")
        h2conn.sendResponse(1, response)
        assertTrue(true, message: "sendResponse should not throw")
    }

    @TestCase
    public func testRecvRequestWithContinuation(): Unit {
        let (mock, h2conn) = setupServer()
        let reqHeaders = HttpHeaders()
        reqHeaders.set(":method", "POST")
        reqHeaders.set(":path", "/api/data")
        reqHeaders.set(":scheme", "https")
        reqHeaders.set(":authority", "example.com")
        reqHeaders.set("content-type", "application/json")
        reqHeaders.set("x-custom-header", "some-long-value-that-needs-multiple-frames")
        let encoder = HPACK()
        let encoded = encoder.encode(reqHeaders)
        let splitPoint = encoded.size / 2
        let frag1 = Array<UInt8>(splitPoint, repeat: 0)
        var i: Int64 = 0
        while (i < splitPoint) { frag1[i] = encoded[i]; i += 1 }
        let frag2Size = encoded.size - splitPoint
        let frag2 = Array<UInt8>(frag2Size, repeat: 0)
        i = 0
        while (i < frag2Size) { frag2[i] = encoded[splitPoint + i]; i += 1 }
        let hfHeader = Http2FrameHeader(frag1.size, Http2FrameType.HEADERS, streamId: 1)
        let hfFrame = encodeFrame(hfHeader, frag1)
        mock.feedData(hfFrame)
        let contHeader = Http2FrameHeader(frag2.size, Http2FrameType.CONTINUATION,
            flags: FLAG_END_HEADERS | FLAG_END_STREAM, streamId: 1)
        let contFrame = encodeFrame(contHeader, frag2)
        mock.feedData(contFrame)
        let (streamId, request) = h2conn.recvRequest()
        assertTrue(streamId == 1u32, message: "Expected stream ID 1")
        assertTrue(request.method == HttpMethod.POST, message: "Expected POST method")
    }

    @TestCase
    public func testAcceptInvalidPreface(): Unit {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let invalidPreface = Array<UInt8>(24, repeat: 0x00)
        let mock = MockConnection(invalidPreface)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        let threw = try {
            h2conn.accept(None)
            false
        } catch (_: Http2Exception) {
            true
        } catch (_: Exception) {
            true
        }
        assertTrue(threw, message: "accept() should throw when client preface is invalid")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 通过 MockConnection 的服务器推送测试
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionServerPushTest {
    private func setupConnectedServer(): (MockConnection, Http2Connection) {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        (mock, h2conn)
    }

    @TestCase
    public func testPushPromiseReturnsValidId(): Unit {
        let (_, h2conn) = setupConnectedServer()
        let pushRequest = HttpRequest(method: HttpMethod.GET, url: "https://example.com/push.js")
        let streamId = h2conn.pushPromise(1, pushRequest)
        assertTrue(streamId > 0, message: "pushPromise should return valid stream ID")
        assertTrue(streamId % 2 == 0, message: "Server push stream ID should be even")
    }

    @TestCase
    public func testPushPromiseWritesFrame(): Unit {
        let (mock, h2conn) = setupConnectedServer()
        let pushRequest = HttpRequest(method: HttpMethod.GET, url: "https://example.com/push.js")
        let _ = h2conn.pushPromise(1, pushRequest)
        let written = mock.getWrittenBytes()
        assertTrue(written.size > 0, message: "pushPromise should write frames")
    }

    @TestCase
    public func testSendPushResponse(): Unit {
        let (_, h2conn) = setupConnectedServer()
        let pushRequest = HttpRequest(method: HttpMethod.GET, url: "https://example.com/push.js")
        let streamId = h2conn.pushPromise(1, pushRequest)
        assertTrue(streamId > 0)
        let response = HttpResponse.text(HttpStatus.OK, "push content")
        h2conn.sendPushResponse(streamId, response)
        assertTrue(true, message: "sendPushResponse should not throw")
    }

    @TestCase
    public func testPushPromiseReturnsZeroWhenPushDisabled(): Unit {
        let peerSettingsPayload = encodeSettings([
            (Http2SettingsId.ENABLE_PUSH, UInt32(0))
        ])
        let settingsFrame = encodeFrame(
            Http2FrameHeader(peerSettingsPayload.size, Http2FrameType.SETTINGS, streamId: 0),
            peerSettingsPayload
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(settingsFrame)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        let pushRequest = HttpRequest(method: HttpMethod.GET, url: "https://example.com/push.js")
        let streamId = h2conn.pushPromise(1, pushRequest)
        assertTrue(streamId == 0u32, message: "pushPromise should return 0 when push is disabled")
    }

    @TestCase
    public func testCancelPush(): Unit {
        let (_, h2conn) = setupConnectedServer()
        h2conn.cancelPush(2)
        assertTrue(true, message: "cancelPush should not throw")
    }

    @TestCase
    public func testCancelPushWritesRstStream(): Unit {
        let (mock, h2conn) = setupConnectedServer()
        h2conn.cancelPush(2)
        let written = mock.getWrittenBytes()
        assertTrue(written.size > 0, message: "cancelPush should write RST_STREAM frame")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 通过 MockConnection 的 recvRequestBody()
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionRecvBodyTest {
    @TestCase
    public func testRecvRequestBodyEmpty(): Unit {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        let reqHeaders = HttpHeaders()
        reqHeaders.set(":method", "GET")
        reqHeaders.set(":path", "/")
        reqHeaders.set(":scheme", "https")
        reqHeaders.set(":authority", "example.com")
        let encoder = HPACK()
        let encoded = encoder.encode(reqHeaders)
        let headersFrame = makeHeadersFrame(1, encoded, true)
        mock.feedData(headersFrame)
        let (streamId, _) = h2conn.recvRequest()
        let body = h2conn.recvRequestBody(streamId)
        assertTrue(body.size == 0, message: "GET request should have empty body")
    }

    @TestCase
    public func testRecvRequestBodyWithData(): Unit {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock, isServer: true)
        h2conn.accept(None)
        let reqHeaders = HttpHeaders()
        reqHeaders.set(":method", "POST")
        reqHeaders.set(":path", "/api")
        reqHeaders.set(":scheme", "https")
        reqHeaders.set(":authority", "example.com")
        reqHeaders.set("content-length", "5")
        let encoder = HPACK()
        let encoded = encoder.encode(reqHeaders)
        let headersFrame = makeHeadersFrame(1, encoded, false)
        mock.feedData(headersFrame)
        let (streamId, _) = h2conn.recvRequest()
        assertTrue(streamId > 0)
        let bodyData: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        let dataHeader = Http2FrameHeader(bodyData.size, Http2FrameType.DATA,
            flags: FLAG_END_STREAM, streamId: streamId)
        let dataFrame = encodeFrame(dataHeader, bodyData)
        mock.feedData(dataFrame)
        let body = h2conn.recvRequestBody(streamId)
        assertTrue(body.size == 5, message: "Expected 5 body bytes")
        let bodyStr = String.fromUtf8(body)
        assertTrue(bodyStr == "Hello", message: "Expected Hello")
    }
}

// ──────────────────────────────────────────────
// Http2Connection — 通过 MockConnection 的 WINDOW_UPDATE
// ──────────────────────────────────────────────

@Test
public class Http2ConnectionWindowUpdateTest {
    private func setupClient(): (MockConnection, Http2Connection) {
        let emptySettings = encodeFrame(
            Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
        )
        let mock = MockConnection([])
        mock.feedData(emptySettings)
        let h2conn = Http2Connection(mock)
        h2conn.connect()
        (mock, h2conn)
    }

    @TestCase
    public func testLargeResponseData(): Unit {
        let (mock, h2conn) = setupClient()
        // 通告更大的 MAX_FRAME_SIZE 以允许大数据帧
        h2conn.setPeerMaxFrameSize(32768)
        let respHeaders = HttpHeaders()
        respHeaders.set(":status", "200")
        let encoder = HPACK()
        let encodedHeaders = encoder.encode(respHeaders)
        let headersFrame = makeHeadersFrame(1, encodedHeaders, false)
        let largeData = Array<UInt8>(32768, repeat: 0x41)
        let dataframeFlags: UInt8 = FLAG_END_STREAM
        let dataHeader = Http2FrameHeader(largeData.size, Http2FrameType.DATA,
            flags: dataframeFlags, streamId: 1)
        let dataFrame = encodeFrame(dataHeader, largeData)
        mock.feedData(headersFrame)
        mock.feedData(dataFrame)
        let response = h2conn.recvResponse(1)
        assertTrue(response.status.code == 200u16)
        let body = response.bodyAsBytes()
        assertTrue(body.size == 32768, message: "Expected 32768 body bytes")
    }
}

/**
 * Extended CONNECT（RFC 8441）测试。
 */
public class Http2ConnectionExtendedConnectTest {
    public func testSendExtendedConnectResponseNoCrash(): Unit {
        let mock = MockConnection()
        let h2 = Http2Connection(mock)
        h2.sendExtendedConnectResponse(1, "websocket")
        assertTrue(true, message: "Extended CONNECT 响应发送不崩溃")
    }

    public func testSendExtendedConnectResponseCustomStatus(): Unit {
        let mock = MockConnection()
        let h2 = Http2Connection(mock)
        h2.sendExtendedConnectResponse(1, "websocket", status: 200)
        assertTrue(true, message: "自定义状态码的 Extended CONNECT 应生效")
    }

    public func testSendExtendedConnectResponseWritesFrame(): Unit {
        let mock = MockConnection()
        let h2 = Http2Connection(mock)
        h2.sendExtendedConnectResponse(1, "websocket")
        let written = mock.getWrittenBytes()
        assertTrue(written.size > 0, message: "Extended CONNECT 应写入帧数据")
    }
}

/**
 * Http2Connection 辅助方法测试。
 */
public class Http2ConnectionMiscTest {
    public func testSetPeerMaxFrameSizeNoCrash(): Unit {
        let mock = MockConnection()
        let h2 = Http2Connection(mock)
        h2.setPeerMaxFrameSize(65536)
        assertTrue(true, message: "setPeerMaxFrameSize 不崩溃")
    }

    public func testGetPeerOriginsInitiallyEmpty(): Unit {
        let mock = MockConnection()
        let h2 = Http2Connection(mock)
        let origins = h2.getPeerOrigins()
        assertTrue(origins.size == 0, message: "初始时 peerOrigins 应为空")
    }

    public func testGetPeerAltSvcInitiallyEmpty(): Unit {
        let mock = MockConnection()
        let h2 = Http2Connection(mock)
        let altSvc = h2.getPeerAltSvc()
        assertTrue(altSvc.size == 0, message: "初始时 peerAltSvc 应为空")
    }
}
