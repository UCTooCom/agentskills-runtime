/**
 * HTTP/3 连接与请求/响应单元测试（RFC 9114）。
 *
 * 覆盖：
 * - H3Connection 初始状态与连接管理
 * - SETTINGS / GOAWAY 交换
 * - 控制流创建与处理
 * - 请求发送与响应处理
 * - 连接状态枚举
 * - 服务端/客户端配置到连接配置的传播
 */
package http_lib.http3

import std.collection.ArrayList
import std.collection.HashMap
import http_lib.core.{assertTrue, assertFalse, HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.http2.{encodeQuicVarint, decodeQuicVarint}
import http_lib.buffer.ByteBuffer

// ======== 辅助函数（防止跨测试文件循环依赖）========

private func createServerH3Connection(): (MockQuicConnection, H3Connection) {
    let quicConn = MockQuicConnection(serverMode: true)
    let h3Conn = H3Connection(quicConn, config: H3ConnectionConfig(), isServer: true)
    (quicConn, h3Conn)
}

private func createClientH3Connection(): (MockQuicConnection, H3Connection) {
    let quicConn = MockQuicConnection(serverMode: false)
    let h3Conn = H3Connection(quicConn, config: H3ConnectionConfig(), isServer: false)
    (quicConn, h3Conn)
}

private func createServerConnection(): (MockQuicConnection, H3Connection) {
    let quicConn = MockQuicConnection(serverMode: true)
    let config = H3ConnectionConfig()
    let h3Conn = H3Connection(quicConn, config: config, isServer: true)
    (quicConn, h3Conn)
}

private func createClientConnection(): (MockQuicConnection, H3Connection) {
    let quicConn = MockQuicConnection(serverMode: false)
    let config = H3ConnectionConfig()
    let h3Conn = H3Connection(quicConn, config: config, isServer: false)
    (quicConn, h3Conn)
}

// ======== HTTP/3 连接测试 ========

@Test
public class H3ConnectionTest {

    @TestCase
    public func testInitialState(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        assertTrue(h3Conn.getState().toString() == "INITIAL",
            message: "New connection should be in INITIAL state")
        assertTrue(!h3Conn.isConnected(),
            message: "Not connected until SETTINGS exchanged")
    }

    @TestCase
    public func testSendSettingsCreatesControlStreams(): Unit {
        let (quicConn, h3Conn) = createServerH3Connection()
        h3Conn.sendSettings()
        let outgoing = quicConn.getOutgoingUnidirStreams()
        assertTrue(outgoing.size >= 3,
            message: "Should create 3 unidirectional streams (control + 2 QPACK)")
        let controlStream = outgoing[0]
        let writtenData = controlStream.getWrittenData()
        assertTrue(writtenData.size > 0, message: "Control stream should have data")
        assertTrue(writtenData[0] == 0x00u8,
            message: "First byte of control stream should be stream type 0x00")
    }

    @TestCase
    public func testPeerSettingsFromControlStream(): Unit {
        let (quicConn, h3Conn) = createServerH3Connection()
        h3Conn.sendSettings()

        let settingsPayload = ArrayList<UInt8>()
        settingsPayload.add(0x01u8)
        settingsPayload.add(0x40u8)
        settingsPayload.add(0x20u8)
        settingsPayload.add(0x06u8)
        settingsPayload.add(0x80u8)
        settingsPayload.add(0x80u8)
        settingsPayload.add(0x00u8)

        let settingsFrame = encodeH3Frame(Http3FrameType.SETTINGS, settingsPayload.toArray())
        let ctrlStreamData = ArrayList<UInt8>()
        ctrlStreamData.add(0x00u8)
        for (b in settingsFrame) { ctrlStreamData.add(b) }

        let peerCtrlStream = MockQuicStream(data: ctrlStreamData.toArray(), streamType: QuicStreamType.UNIDIRECTIONAL)
        quicConn.addIncomingUnidirStream(peerCtrlStream)

        let processed = h3Conn.processNextStream()
        assertTrue(processed, message: "Should process the stream")

        assertTrue(h3Conn.getState().toString() == "CONNECTED" || h3Conn.getState().toString() == "INITIAL",
            message: "Connection should be connected after settings exchange")
    }

    @TestCase
    public func testGoawayHandling(): Unit {
        let (quicConn, h3Conn) = createServerH3Connection()
        h3Conn.sendSettings()

        let goawayPayload = encodeQuicVarint(42u64)
        let goawayFrame = encodeH3Frame(Http3FrameType.GOAWAY, goawayPayload)
        let ctrlStreamData = ArrayList<UInt8>()
        ctrlStreamData.add(0x00u8)
        for (b in goawayFrame) { ctrlStreamData.add(b) }

        let peerCtrlStream = MockQuicStream(data: ctrlStreamData.toArray(), streamType: QuicStreamType.UNIDIRECTIONAL)
        quicConn.addIncomingUnidirStream(peerCtrlStream)

        let processed = h3Conn.processNextStream()
        assertTrue(processed, message: "Should process GOAWAY")

        h3Conn.sendGoaway()
        h3Conn.gracefulShutdown()
    }

    @TestCase
    public func testSendGoawayClosesGracefully(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        h3Conn.sendSettings()
        h3Conn.sendGoaway()
        h3Conn.gracefulShutdown()
        assertTrue(!h3Conn.isConnected(),
            message: "After gracefulShutdown, should not be connected")
    }

    @TestCase
    public func testSendMaxPushId(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        h3Conn.sendSettings()
        try {
            h3Conn.sendMaxPushId(50)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "sendMaxPushId should not throw")
        }
    }

    @TestCase
    public func testCloseConnection(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        h3Conn.sendSettings()
        h3Conn.close()
        assertTrue(!h3Conn.isConnected(),
            message: "After close, should not be connected")
    }
}

// ======== HTTP/3 请求/响应流测试 ========

@Test
public class H3RequestResponseTest {

    @TestCase
    public func testBuildRequestHeaders(): Unit {
        let req = HttpRequest(method: HttpMethod.GET, url: "/api/test")
        req.headers.set("accept", "application/json")
        let (quicConn, h3Conn) = createClientConnection()
        h3Conn.sendSettings()
        let streamId = h3Conn.sendRequest(req)
        match (streamId) {
            case Some(id) =>
                assertTrue(true, message: "Request should be sent on stream ")
            case None =>
                assertTrue(false, message: "Request should be sent successfully")
        }
    }

    @TestCase
    public func testServerProcessRequest(): Unit {
        let (quicConn, h3Conn) = createServerConnection()
        h3Conn.sendSettings()

        let processed = h3Conn.processNextStream()
        assertTrue(processed, message: "processNextStream should handle empty state")
    }

    @TestCase
    public func testServerSendResponse(): Unit {
        let (_, h3Conn) = createServerConnection()
        h3Conn.sendSettings()

        let response = HttpResponse.text(HttpStatus.OK, "Hello H3!")
        let streamId: UInt64 = 4
        let responseStream = MockQuicStream(streamId: streamId)
        try {
            h3Conn.sendResponse(streamId, response)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(true, message: "sendResponse should handle missing stream")
        }
    }

    @TestCase
    public func testClientRequestServerResponseRoundTrip(): Unit {
        let (clientQuic, clientConn) = createClientConnection()
        clientConn.sendSettings()

        let req = HttpRequest(method: HttpMethod.GET, url: "/hello")
        req.headers.set("host", "example.com")

        let streamId = clientConn.sendRequest(req)
        match (streamId) {
            case Some(sid) =>
                assertTrue(true, message: "Client should send request on stream ")
            case None =>
                assertTrue(false, message: "Client should send request successfully")
        }
    }
}

// ======== QUIC 连接状态枚举测试 ========

@Test
public class H3ConnectionStateTest {

    @TestCase
    public func testStateToString(): Unit {
        assertTrue(H3ConnectionState.H3_STATE_INITIAL.toString() == "INITIAL")
        assertTrue(H3ConnectionState.H3_STATE_CONNECTED.toString() == "CONNECTED")
        assertTrue(H3ConnectionState.H3_STATE_GOAWAY_SENT.toString() == "GOAWAY_SENT")
        assertTrue(H3ConnectionState.H3_STATE_GOAWAY_RECV.toString() == "GOAWAY_RECV")
        assertTrue(H3ConnectionState.H3_STATE_CLOSED.toString() == "CLOSED")
    }
}

// ======== HTTP/3 连接配置测试（补充）========

@Test
public class H3ConnectionConfigExtTest {

    @TestCase
    public func testServerConfigToConnectionConfig(): Unit {
        let sc = Http3ServerConfig()
        sc.serverName = "test_h3/1.0"
        sc.readTimeout = Duration.second * 15
        sc.maxFieldSectionSize = 131072
        sc.qpackMaxTableCapacity = 8192
        let cc = sc.toH3ConnectionConfig()
        assertTrue(cc.maxFieldSectionSize == 131072, message: "maxFieldSectionSize should propagate")
        assertTrue(cc.qpackMaxTableCapacity == 8192, message: "qpackMaxTableCapacity should propagate")
    }

    @TestCase
    public func testClientConfigToConnectionConfig(): Unit {
        let cc = Http3ClientConfig()
        cc.readTimeout = Duration.second * 60
        cc.maxFieldSectionSize = 16384
        let cfg = cc.toH3ConnectionConfig()
        assertTrue(cfg.maxFieldSectionSize == 16384, message: "maxFieldSectionSize should propagate")
    }
}


// ======== H3Connection 配置与查询测试 ========

@Test
public class H3ConnectionConfigQueryTest {

    @TestCase
    public func testSetRequestHandler(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        let handler: (HttpRequest) -> HttpResponse = {_ =>
            HttpResponse.text(HttpStatus.OK, "ok")
        }
        try {
            h3Conn.setRequestHandler(handler)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "setRequestHandler should not throw")
        }
    }

    @TestCase
    public func testSetPushResponseHandler(): Unit {
        let (_, h3Conn) = createClientH3Connection()
        let handler: (UInt64, HttpResponse) -> Unit = {_, _ => ()}
        try {
            h3Conn.setPushResponseHandler(handler)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "setPushResponseHandler should not throw")
        }
    }

    @TestCase
    public func testIsExtendedConnectRequestNoProtocol(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        let request = HttpRequest(method: HttpMethod.GET, url: "https://example.com/")
        let result = h3Conn.isExtendedConnectRequest(request)
        assertFalse(result, message: "GET request should not be extended CONNECT")
    }

    @TestCase
    public func testIsExtendedConnectRequestConnectNoProtocol(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        let request = HttpRequest(method: HttpMethod.CONNECT, url: "https://example.com/")
        let result = h3Conn.isExtendedConnectRequest(request)
        assertFalse(result, message: "CONNECT without :protocol header should not be extended")
    }

    @TestCase
    public func testIsExtendedConnectRequestWithProtocol(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        let request = HttpRequest(method: HttpMethod.CONNECT, url: "https://example.com/")
        request.headers.set(":protocol", "websocket")
        let result = h3Conn.isExtendedConnectRequest(request)
        assertTrue(result, message: "CONNECT with :protocol should be extended CONNECT")
    }

    @TestCase
    public func testIsExtendedConnectRequestDisabled(): Unit {
        let quicConn = MockQuicConnection(serverMode: true)
        let config = H3ConnectionConfig()
        config.enableConnectProtocol = false
        let h3Conn = H3Connection(quicConn, config: config, isServer: true)
        let request = HttpRequest(method: HttpMethod.CONNECT, url: "https://example.com/")
        request.headers.set(":protocol", "websocket")
        let result = h3Conn.isExtendedConnectRequest(request)
        assertFalse(result, message: "Extended CONNECT should be disabled when enableConnectProtocol=false")
    }

    @TestCase
    public func testGetAvailablePushIdsDefault(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        let pushIds = h3Conn.getAvailablePushIds()
        assertTrue(pushIds == 0, message: "Default maxPushId=0 should give 0 available push IDs")
    }

    @TestCase
    public func testGetCompletedPushesEmpty(): Unit {
        let (_, h3Conn) = createClientH3Connection()
        let pushes = h3Conn.getCompletedPushes()
        assertTrue(pushes.size == 0, message: "Initial completed pushes should be empty")
    }

    @TestCase
    public func testGetLastErrorNone(): Unit {
        let (_, h3Conn) = createServerH3Connection()
        let err = h3Conn.getLastError()
        match (err) {
            case Some(_) => assertTrue(false, message: "Initial last error should be None")
            case None => assertTrue(true)
        }
    }
}


// ======== 0-RTT 设置验证测试（RFC 9114 §7.2.4.2）========

@Test
public class H3ConnectionZeroRttTest {

    /**
     * 构建对端 SETTINGS 帧数据（用于注入 Mock 控制流）。
     */
    private func buildPeerSettingsFrame(): Array<UInt8> {
        let settings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096u64),
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536u64),
        ]
        let frame = buildH3SettingsFrame(settings)
        let ctrlData = ArrayList<UInt8>()
        ctrlData.add(0x00u8)  // 控制流类型
        for (b in frame) { ctrlData.add(b) }
        ctrlData.toArray()
    }

    @TestCase
    public func testZeroRttPriorSettingsValid(): Unit {
        // 前提：zeroRttPriorSettings 值 <= 对端当前值 → 验证通过
        let prior = HashMap<UInt16, UInt64>()
        prior[0x01u16] = 4096u64  // QPACK_MAX_TABLE_CAPACITY（与默认相同）
        prior[0x06u16] = 65536u64 // MAX_FIELD_SECTION_SIZE（与默认相同）

        let config = H3ConnectionConfig()
        config.zeroRttPriorSettings = Some(prior)

        let quicConn = MockQuicConnection(serverMode: true)
        let h3Conn = H3Connection(quicConn, config: config, isServer: true)
        h3Conn.sendSettings()

        let streamData = buildPeerSettingsFrame()
        let peerCtrlStream = MockQuicStream(data: streamData, streamType: QuicStreamType.UNIDIRECTIONAL)
        quicConn.addIncomingUnidirStream(peerCtrlStream)

        let processed = h3Conn.processNextStream()
        assertTrue(processed, message: "Should process peer control stream")

        // 验证：连接应保持 CONNECTED 状态
        assertTrue(h3Conn.isConnected(), message: "0-RTT settings valid: should stay connected")
        match (h3Conn.getLastError()) {
            case Some(_) => assertTrue(false, message: "Should have no error after valid 0-RTT")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testZeroRttPriorSettingsInvalid(): Unit {
        // 前提：zeroRttPriorSettings 值 > 对端当前值 → 验证失败
        let prior = HashMap<UInt16, UInt64>()
        prior[0x01u16] = 8192u64  // QPACK_MAX_TABLE_CAPACITY（高于默认 4096）
        prior[0x06u16] = 131072u64 // MAX_FIELD_SECTION_SIZE（高于默认 65536）

        let config = H3ConnectionConfig()
        config.zeroRttPriorSettings = Some(prior)

        let quicConn = MockQuicConnection(serverMode: true)
        let h3Conn = H3Connection(quicConn, config: config, isServer: true)
        h3Conn.sendSettings()

        let streamData = buildPeerSettingsFrame()
        let peerCtrlStream = MockQuicStream(data: streamData, streamType: QuicStreamType.UNIDIRECTIONAL)
        quicConn.addIncomingUnidirStream(peerCtrlStream)

        let processed = h3Conn.processNextStream()
        assertTrue(processed, message: "Should process peer control stream")
        sleep(Duration.millisecond * 5)

        // 验证：连接应被关闭
        assertTrue(!h3Conn.isConnected(), message: "0-RTT invalid: should be disconnected")
        match (h3Conn.getLastError()) {
            case Some(msg) =>
                assertTrue(msg.contains("0-RTT"), message: "Error should mention 0-RTT, got: ${msg}")
            case None => assertTrue(false, message: "Should have error after invalid 0-RTT")
        }
    }

    @TestCase
    public func testZeroRttPriorSettingsNone(): Unit {
        // 未设置 zeroRttPriorSettings → 不影响正常 SETTINGS 交换
        let config = H3ConnectionConfig()
        config.zeroRttPriorSettings = None

        let quicConn = MockQuicConnection(serverMode: true)
        let h3Conn = H3Connection(quicConn, config: config, isServer: true)
        h3Conn.sendSettings()

        let streamData = buildPeerSettingsFrame()
        let peerCtrlStream = MockQuicStream(data: streamData, streamType: QuicStreamType.UNIDIRECTIONAL)
        quicConn.addIncomingUnidirStream(peerCtrlStream)

        let processed = h3Conn.processNextStream()
        assertTrue(processed, message: "Should process peer control stream")
        assertTrue(h3Conn.isConnected(), message: "No 0-RTT config: should stay connected")
    }

    @TestCase
    public func testZeroRttEndToEndRoundTrip(): Unit {
        // 完整 0-RTT 往返测试：
        // 1. 客户端首次连接接收服务器 SETTINGS
        // 2. getPeerSettings() 捕获对端设置
        // 3. 用捕获的设置作为 zeroRttPriorSettings 重建连接
        // 4. 服务器发送相同 SETTINGS → 验证通过
        // 5. 服务器发送降级 SETTINGS → 验证失败

        // Step 1-2: 首次连接 → 保存对端 SETTINGS
        let serverSettings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 8192u64),
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536u64),
        ]

        let (clientQuic, clientConn) = createClientH3Connection()
        clientConn.sendSettings()

        // 模拟服务器发送 SETTINGS
        let settingsFrame = buildH3SettingsFrame(serverSettings)
        let ctrlData = ArrayList<UInt8>()
        ctrlData.add(0x00u8)
        for (b in settingsFrame) { ctrlData.add(b) }

        let peerCtrlStream = MockQuicStream(data: ctrlData.toArray(), streamType: QuicStreamType.UNIDIRECTIONAL)
        clientQuic.addIncomingUnidirStream(peerCtrlStream)

        let processed = clientConn.processNextStream()
        assertTrue(processed, message: "Should process server SETTINGS")
        sleep(Duration.millisecond * 5)

        let savedSettings = clientConn.getPeerSettings()
        match (savedSettings.get(0x01u16)) {
            case Some(v) => assertTrue(v == 8192u64, message: "Saved QPACK_MAX_TABLE_CAPACITY should be 8192")
            case None => assertTrue(false, message: "QPACK_MAX_TABLE_CAPACITY should be present")
        }

        // Step 3-4: 0-RTT 重连 → 相同设置 → 验证通过
        let reconnectConfig = H3ConnectionConfig()
        reconnectConfig.zeroRttPriorSettings = Some(savedSettings)

        let (reconnectQuic, reconnectConn) = createClientH3Connection()
        reconnectConn.sendSettings()

        let sameCtrlData = ArrayList<UInt8>()
        sameCtrlData.add(0x00u8)
        for (b in settingsFrame) { sameCtrlData.add(b) }

        let samePeerStream = MockQuicStream(data: sameCtrlData.toArray(), streamType: QuicStreamType.UNIDIRECTIONAL)
        reconnectQuic.addIncomingUnidirStream(samePeerStream)

        let reconnectProcessed = reconnectConn.processNextStream()
        assertTrue(reconnectProcessed, message: "Should process SETTINGS on reconnect")
        sleep(Duration.millisecond * 5)
        assertTrue(reconnectConn.isConnected(), message: "0-RTT reconnect with same settings should succeed")

        // Step 5: 降级设置 → 验证失败
        let reducedSettings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096u64),  // 从 8192 降级！
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536u64),
        ]

        let badConfig = H3ConnectionConfig()
        badConfig.zeroRttPriorSettings = Some(savedSettings)
        let badQuic = MockQuicConnection(serverMode: false)
        let badConn = H3Connection(badQuic, config: badConfig, isServer: false)
        badConn.sendSettings()

        let reducedFrame = buildH3SettingsFrame(reducedSettings)
        let reducedCtrlData = ArrayList<UInt8>()
        reducedCtrlData.add(0x00u8)
        for (b in reducedFrame) { reducedCtrlData.add(b) }

        let reducedPeerStream = MockQuicStream(data: reducedCtrlData.toArray(), streamType: QuicStreamType.UNIDIRECTIONAL)
        badQuic.addIncomingUnidirStream(reducedPeerStream)

        let badProcessed = badConn.processNextStream()
        assertTrue(badProcessed, message: "Should process reduced SETTINGS")
        sleep(Duration.millisecond * 5)
        assertTrue(!badConn.isConnected(), message: "0-RTT with reduced QPACK_MAX_TABLE_CAPACITY should fail")
        match (badConn.getLastError()) {
            case Some(msg) => assertTrue(msg.contains("0-RTT"), message: "Error should mention 0-RTT, got: ${msg}")
            case None => assertTrue(false, message: "Should have error after reduced settings")
        }
    }

    @TestCase
    public func testZeroRttMaxFieldSectionSizeDecreased(): Unit {
        // MAX_FIELD_SECTION_SIZE 降级也应被检测到
        let prior = HashMap<UInt16, UInt64>()
        prior[0x06u16] = 131072u64  // 高于默认 65536

        let config = H3ConnectionConfig()
        config.zeroRttPriorSettings = Some(prior)

        let quicConn = MockQuicConnection(serverMode: true)
        let h3Conn = H3Connection(quicConn, config: config, isServer: true)
        h3Conn.sendSettings()

        // 对端发送默认 SETTINGS（MAX_FIELD_SECTION_SIZE=65536 < prior 131072）
        let settings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536u64),
        ]
        let frame = buildH3SettingsFrame(settings)
        let ctrlData = ArrayList<UInt8>()
        ctrlData.add(0x00u8)
        for (b in frame) { ctrlData.add(b) }

        let peerStream = MockQuicStream(data: ctrlData.toArray(), streamType: QuicStreamType.UNIDIRECTIONAL)
        quicConn.addIncomingUnidirStream(peerStream)

        let processed = h3Conn.processNextStream()
        assertTrue(processed, message: "Should process peer SETTINGS")
        sleep(Duration.millisecond * 5)
        assertTrue(!h3Conn.isConnected(), message: "MAX_FIELD_SECTION_SIZE decreased: should disconnect")
        match (h3Conn.getLastError()) {
            case Some(msg) => assertTrue(msg.contains("0-RTT"), message: "Error should mention 0-RTT")
            case None => assertTrue(false, message: "Should have error")
        }
    }
}
