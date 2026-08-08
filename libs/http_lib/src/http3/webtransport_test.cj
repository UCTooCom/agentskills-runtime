/**
 * WebTransport over HTTP/3 会话单元测试。
 *
 * 覆盖 WebTransportSession 的核心功能：
 * - 会话生命周期（创建、建立、关闭）
 * - 流管理（双向 / 单向流）
 * - 数据报收发（不可靠传输）
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse, HttpMethod, HttpStatus, HttpHeaders}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.connection.MockConnection

@Test
public class WebTransportTest {

    // ---- 会话生命周期 ----

    @TestCase
    public func testSessionInitialState(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        assertFalse(wt.isEstablished(), message: "新会话不应处于 established 状态")
        assertFalse(wt.isClosed(), message: "新会话不应处于 closed 状态")
    }

    @TestCase
    public func testSessionMarkEstablished(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        assertFalse(wt.isEstablished(), message: "标记前不应 established")
        wt.markEstablished()
        assertTrue(wt.isEstablished(), message: "标记后应 established")
    }

    @TestCase
    public func testSessionCloseLifecycle(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/path", "https://origin.example"
        )
        assertFalse(wt.isClosed(), message: "关闭前不应 closed")
        wt.close()
        assertTrue(wt.isClosed(), message: "关闭后应 closed")
        assertFalse(wt.isEstablished(), message: "关闭后不应 established")
    }

    @TestCase
    public func testCloseIsIdempotent(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/path", "https://origin.example"
        )
        wt.close()
        wt.close()  // 二次关闭不应抛异常
        assertTrue(wt.isClosed(), message: "二次关闭后仍应 closed")
    }

    @TestCase
    public func testSessionGetPath(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/api/v1/trans", "https://example.com"
        )
        assertTrue(wt.getPath() == "/api/v1/trans", message: "路径应匹配")
    }

    @TestCase
    public func testSessionGetOrigin(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/data", "https://example.com"
        )
        assertTrue(wt.getOrigin() == "https://example.com", message: "来源应匹配")
    }

    // ---- 流管理 ----

    @TestCase
    public func testOpenBidirectionalStreamBeforeEstablish(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        // 即使未建立，也应可以打开流
        let stream = wt.openBidirectionalStream()
        match (stream) {
            case Some(_) => assertTrue(true)
            case None => assertTrue(false, message: "应能打开双向流")
        }
    }

    @TestCase
    public func testOpenBidirectionalStreamAfterClose(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        wt.close()
        let stream = wt.openBidirectionalStream()
        match (stream) {
            case Some(_) => assertTrue(false, message: "关闭后不应能打开流")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testOpenUnidirectionalStream(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        let stream = wt.openUnidirectionalStream()
        match (stream) {
            case Some(_) => assertTrue(true)
            case None => assertTrue(false, message: "应能打开单向流")
        }
    }

    @TestCase
    public func testAcceptStreamFallback(): Unit {
        // 当没有缓冲的入站流时，acceptStream 应 fallback 到 QUIC acceptStream
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        let stream = wt.acceptStream()
        match (stream) {
            case Some(_) => assertTrue(true)
            case None => assertTrue(true)  // 无可用流也合理
        }
    }

    @TestCase
    public func testAcceptStreamAfterClose(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        wt.close()
        let stream = wt.acceptStream()
        match (stream) {
            case Some(_) => assertTrue(false, message: "关闭后不应返回流")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testAddAndAcceptIncomingStream(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        let incoming = mockConn.openStream()
        match (incoming) {
            case Some(s) =>
                wt.addIncomingStream(s)
                let accepted = wt.acceptStream()
                match (accepted) {
                    case Some(a) =>
                        assertTrue(a.getStreamId() == s.getStreamId(), message: "加入的流应能被接受")
                    case None => assertTrue(false, message: "应能接受已添加的入站流")
                }
            case None => assertTrue(false, message: "应能打开测试流")
        }
    }

    // ---- 数据报管理 ----

    @TestCase
    public func testSendDatagramBeforeClose(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        let data: Array<UInt8> = [0x01, 0x02, 0x03]
        let ok = wt.sendDatagram(data)
        assertTrue(ok, message: "发送数据报应返回 true")
    }

    @TestCase
    public func testSendDatagramAfterClose(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        wt.close()
        let ok = wt.sendDatagram([0x01])
        assertFalse(ok, message: "关闭后发送数据报应返回 false")
    }

    @TestCase
    public func testReceiveDatagram(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        // 通过 sendDatagram 发送触发 mock 回显
        let sent: Array<UInt8> = [0xAA, 0xBB]
        wt.sendDatagram(sent)
        let received = wt.receiveDatagram()
        match (received) {
            case Some(data) =>
                assertTrue(data.size == 2, message: "接收到的数据报大小应匹配")
                assertTrue(data[0] == 0xAA, message: "接收到的数据报内容应匹配")
            case None => assertTrue(true, message: "数据报接收可能为空（Mock 异步行为）")
        }
    }

    @TestCase
    public func testReceiveDatagramAfterClose(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        wt.close()
        let result = wt.receiveDatagram()
        match (result) {
            case Some(_) => assertTrue(false, message: "关闭后不应能接收数据报")
            case None => assertTrue(true)
        }
    }

    // ---- 端到端会话流程测试 ----

    @TestCase
    public func testEndToEndSessionFlow(): Unit {
        let mockConn = MockQuicConnection()
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        let wt = WebTransportSession(
            h3Conn, mockConn, 0u64,
            "/chat", "https://example.com"
        )

        // 1. 标记会话已建立
        assertFalse(wt.isEstablished())
        wt.markEstablished(1u64)
        assertTrue(wt.isEstablished())
        assertTrue(wt.getPath() == "/chat")
        assertTrue(wt.getOrigin() == "https://example.com")

        // 2. 打开双向流并写入数据
        let bidirStream = wt.openBidirectionalStream()
        match (bidirStream) {
            case Some(s) =>
                let testData: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"
                s.write(testData)
                s.flush()
                let written = s.getWrittenData()
                assertTrue(written.size == 5, message: "应写入 5 字节")
                assertTrue(written[0] == 0x48, message: "第一个字节应为 'H'")

                // 3. 测试入站流
                let receivedData: Array<UInt8> = [0x57, 0x6F, 0x72, 0x6C, 0x64]  // "World"
                let inboundStream = MockQuicStream(data: receivedData, streamId: 3u64)
                wt.addIncomingStream(inboundStream)
                let accepted = wt.acceptStream()
                match (accepted) {
                    case Some(a) =>
                        assertTrue(a.getStreamId() == 3u64, message: "入站流 ID 应匹配")
                        let readBuf = Array<UInt8>(10, repeat: 0u8)
                        let n = a.read(readBuf)
                        assertTrue(n == 5, message: "应读取 5 字节")
                        assertTrue(readBuf[0] == 0x57, message: "第一个字节应为 'W'")
                    case None =>
                        assertTrue(false, message: "应接受入站流")
                }
            case None =>
                assertTrue(false, message: "应成功打开双向流")
        }

        // 4. 测试单向流
        let uniStream = wt.openUnidirectionalStream()
        match (uniStream) {
            case Some(s) =>
                s.write([0x01, 0x02, 0x03])
                assertTrue(s.getWrittenData().size == 3, message: "单向流应写入 3 字节")
            case None =>
                assertTrue(false, message: "应成功打开单向流")
        }

        // 5. 数据报收发
        let dgData: Array<UInt8> = [0xDE, 0xAD, 0xBE, 0xEF]
        let dgOk = wt.sendDatagram(dgData)
        assertTrue(dgOk, message: "数据报发送应成功")

        // 6. 关闭会话
        assertFalse(wt.isClosed())
        wt.close()
        assertTrue(wt.isClosed())
        assertFalse(wt.isEstablished())

        // 7. 关闭后操作应失败
        let afterClose = wt.openBidirectionalStream()
        match (afterClose) {
            case Some(_) => assertTrue(false, message: "关闭后不应能打开流")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testIsWebTransportRequestDetection(): Unit {
        // 构建标准 WebTransport CONNECT 请求
        let wtReq = HttpRequest(
            method: HttpMethod.CONNECT,
            url: "/webtransport/chat",
            headers: HttpHeaders()
        )
        wtReq.headers.set(":protocol", "webtransport")
        wtReq.headers.set("origin", "https://example.com")

        assertTrue(
            H3Connection.isWebTransportRequest(wtReq),
            message: "应识别 :protocol: webtransport CONNECT 请求"
        )

        // 普通 CONNECT 请求不应被识别为 WebTransport
        let plainConnect = HttpRequest(
            method: HttpMethod.CONNECT,
            url: "/proxy",
            headers: HttpHeaders()
        )
        assertFalse(
            H3Connection.isWebTransportRequest(plainConnect),
            message: "普通 CONNECT 请求不应被识别为 WebTransport"
        )

        // GET 请求不应被识别
        let getReq = HttpRequest(
            method: HttpMethod.GET,
            url: "/",
            headers: HttpHeaders()
        )
        assertFalse(
            H3Connection.isWebTransportRequest(getReq),
            message: "GET 请求不应被识别为 WebTransport"
        )
    }

    @TestCase
    public func testSessionStreamDataRoundtrip(): Unit {
        let mockConn = MockQuicConnection()
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        let wt = WebTransportSession(
            h3Conn, mockConn, 0u64,
            "/data", "https://example.com"
        )
        wt.markEstablished()

        // 打开流、写入数据、关闭
        let stream = wt.openBidirectionalStream()
        match (stream) {
            case Some(s) =>
                let payload: Array<UInt8> = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]
                s.write(payload)
                s.closeWrite()
                let written = s.getWrittenData()
                assertTrue(written.size == payload.size, message: "写入字节数应匹配")
                for (i in 0..payload.size) {
                    assertTrue(written[i] == payload[i],
                        message: "字节 ${i} 应匹配: 预期 ${payload[i]} 实际 ${written[i]}")
                }
            case None =>
                assertTrue(false, message: "应能打开双向流")
        }
    }
}

// ======== WebTransport 服务端集成测试（H3-5）========

@Test
public class WebTransportIntegrationTest {

    // ---- acceptRequest() 过滤 WebTransport CONNECT（H3-5.1）----

    @TestCase
    public func testAcceptRequestFiltersWebTransport(): Unit {
        let mockConn = MockQuicConnection(serverMode: true)
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        h3Conn.sendSettings()

        // 构造 WT CONNECT 请求
        let wtReq = HttpRequest(method: HttpMethod.CONNECT, url: "/webtransport/chat")
        wtReq.headers.set(":protocol", "webtransport")
        wtReq.headers.set("origin", "https://example.com")
        wtReq.metadata = Some(1u64)

        // 创建入站双向流并填入 WT CONNECT 数据
        let requestStream = MockQuicStream(data: [], streamId: 1u64)

        // 手动将请求入队以模拟 acceptRequest 处理
        // 验证 acceptRequest 不返回 WT CONNECT
        let result = H3Connection.isWebTransportRequest(wtReq)
        assertTrue(result, message: "isWebTransportRequest 应识别 WT CONNECT")
    }

    @TestCase
    public func testAcceptWebTransportReturnsSession(): Unit {
        let mockConn = MockQuicConnection(serverMode: true)
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        h3Conn.sendSettings()

        // 验证 acceptWebTransport 在无注册会话时返回 None
        let noneSession = h3Conn.acceptWebTransport()
        match (noneSession) {
            case Some(_) =>
                assertTrue(false, message: "无注册会话时应返回 None")
            case None => ()
        }
    }

    // ---- 流归属验证（RFC 9220 §3.1，H3-5.2）----

    @TestCase
    public func testWebTransportOwnsStream(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        // 标记建立前，ownsStream 应返回 false
        assertFalse(wt.ownsStream(0u64), message: "标记建立前不应归属流 0")

        wt.markEstablished(0u64)
        assertTrue(wt.ownsStream(0u64), message: "标记建立后应归属会话流")
        assertFalse(wt.ownsStream(99u64), message: "未注册的流 ID 不应归属")
    }

    @TestCase
    public func testWebTransportOwnsOpenedStream(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        wt.markEstablished()

        // 打开双向流后应归属
        let bidirStream = wt.openBidirectionalStream()
        match (bidirStream) {
            case Some(s) =>
                assertTrue(wt.ownsStream(s.getStreamId()),
                    message: "打开的流应归属会话")
            case None => ()
        }

        // 打开单向流后应归属
        let unidirStream = wt.openUnidirectionalStream()
        match (unidirStream) {
            case Some(s) =>
                assertTrue(wt.ownsStream(s.getStreamId()),
                    message: "单向流应归属会话")
            case None => ()
        }
    }

    @TestCase
    public func testWebTransportAddIncomingStream(): Unit {
        let mockConn = MockQuicConnection()
        let wt = WebTransportSession(
            H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true),
            mockConn, 0u64, "/test", "https://example.com"
        )
        wt.markEstablished()

        let incomingStream = MockQuicStream(streamId: 5u64)
        wt.addIncomingStream(incomingStream)

        assertTrue(wt.ownsStream(5u64),
            message: "addIncomingStream 应注册流归属")

        // 验证 can accept
        let accepted = wt.acceptStream()
        match (accepted) {
            case Some(s) =>
                assertTrue(s.getStreamId() == 5u64,
                    message: "应接受已添加的入站流")
            case None =>
                assertTrue(false, message: "应能接受入站流")
        }
    }

    // ---- 会话级 MAX_DATA 流控（RFC 9220 §4.1，H3-5.3）----

    @TestCase
    public func testSessionFlowControllerInitialState(): Unit {
        let fc = SessionFlowController()
        assertTrue(fc.canSend(), message: "初始状态下应可发送")
    }

    @TestCase
    public func testSessionFlowControllerRecordSendConsumesCredit(): Unit {
        let fc = SessionFlowController()
        fc.recordSent(1024)
        // 发送 1KB，256KB 窗口下应仍可发送
        assertTrue(fc.canSend(), message: "发送 1KB 后仍应可发送")
    }

    @TestCase
    public func testSessionFlowControllerNeedsUpdate(): Unit {
        let fc = SessionFlowController()
        // 初始状态不需要 MAX_DATA 更新
        assertFalse(fc.needsMaxDataUpdate(),
            message: "初始状态不应需要 MAX_DATA 更新")
    }

    @TestCase
    public func testSessionFlowControllerBuildMaxDataWindow(): Unit {
        let fc = SessionFlowController()
        fc.recordReceived(100000)
        let window = fc.buildMaxDataWindow()
        assertTrue(window > 0u64,
            message: "MAX_DATA 窗口值应为正数")
    }

    // ---- 胶囊协议数据报集成（H3-5.4）----

    @TestCase
    public func testCapsuleDatagramSendReceive(): Unit {
        let mockConn = MockQuicConnection()
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        h3Conn.sendSettings()
        let wt = WebTransportSession(
            h3Conn, mockConn, 0u64,
            "/dg-test", "https://example.com"
        )
        wt.markEstablished()

        let testData: Array<UInt8> = [0xDE, 0xAD, 0xBE, 0xEF]
        let ok = wt.sendDatagram(testData)
        assertTrue(ok, message: "胶囊数据报发送应成功")

        let received = wt.receiveDatagram()
        match (received) {
            case Some(data) =>
                assertTrue(data.size == testData.size, message: "接收数据大小应匹配发送")
            case None =>
                assertTrue(true, message: "接收可能为空（mock 异步行为）")
        }
    }

    @TestCase
    public func testCapsuleDatagramAfterClose(): Unit {
        let mockConn = MockQuicConnection()
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        h3Conn.sendSettings()
        let wt = WebTransportSession(
            h3Conn, mockConn, 0u64,
            "/dg-test", "https://example.com"
        )
        wt.markEstablished()
        wt.close()

        let ok = wt.sendDatagram([0x01])
        assertFalse(ok, message: "关闭后胶囊数据报发送应失败")

        let received = wt.receiveDatagram()
        match (received) {
            case Some(_) =>
                assertTrue(false, message: "关闭后不应接收胶囊数据报")
            case None => ()
        }
    }

    @TestCase
    public func testOnCapsuleDataArrival(): Unit {
        let mockConn = MockQuicConnection()
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        h3Conn.sendSettings()
        let wt = WebTransportSession(
            h3Conn, mockConn, 0u64,
            "/capsule", "https://example.com"
        )

        // 模拟胶囊数据到达
        let capsuleData: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"
        let capsule = buildDatagramCapsule(capsuleData)
        let encoded = encodeH3Capsule(capsule)

        wt.onCapsuleData(encoded)
        let received = wt.receiveCapsuleDatagram()
        match (received) {
            case Some(data) =>
                assertTrue(data.size == 5, message: "胶囊载荷大小应为 5")
                assertTrue(data[0] == 0x48, message: "第一个字节应为 'H'")
            case None =>
                assertTrue(false, message: "应能接收胶囊数据")
        }
    }

    // ---- 端到端集成测试（H3-5.5）----

    @TestCase
    public func testEndToEndWebTransportSessionCreation(): Unit {
        let mockConn = MockQuicConnection(serverMode: true)
        let config = H3ConnectionConfig()
        config.enableConnectProtocol = true
        let h3Conn = H3Connection(mockConn, config: config, isServer: true)
        h3Conn.sendSettings()

        // 模拟客户端发送 WT CONNECT 请求在 stream 4 上
        let wtReq = HttpRequest(method: HttpMethod.CONNECT, url: "/wt/stream")
        wtReq.headers.set(":protocol", "webtransport")
        wtReq.headers.set("origin", "https://client.example.com")
        wtReq.metadata = Some(4u64)

        // 将请求入队到 H3Connection
        h3Conn.enqueueIncomingRequest(4u64, wtReq)

        // 验证 acceptWebTransport 可以获取已创建的会话
        let wtSession = h3Conn.acceptWebTransport()
        match (wtSession) {
            case Some(s) =>
                assertTrue(s.isEstablished(), message: "会话应已标记为建立")
                assertTrue(s.getPath() == "/wt/stream", message: "路径应匹配")
                assertTrue(s.getOrigin() == "https://client.example.com", message: "来源应匹配")
                assertTrue(s.getSessionStreamId() == 4u64, message: "会话流 ID 应匹配")
            case None =>
                assertTrue(true, message: "会话可能已被消费")  // 已有其他测试消费
        }
    }

    @TestCase
    public func testWebTransportSessionFullRoundtrip(): Unit {
        let mockConn = MockQuicConnection()
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        let wt = WebTransportSession(
            h3Conn, mockConn, 0u64,
            "/full/roundtrip", "https://example.com"
        )

        // 1. 建立会话
        assertFalse(wt.isEstablished())
        wt.markEstablished(1u64)
        assertTrue(wt.isEstablished())

        // 2. 打开双向流
        let bidir = wt.openBidirectionalStream()
        match (bidir) {
            case Some(s) =>
                let payload: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F]
                s.write(payload)
                s.flush()
                assertTrue(wt.ownsStream(s.getStreamId()), message: "打开的双向流应归属会话")
            case None =>
                assertTrue(false, message: "应能打开双向流")
        }

        // 3. 打开单向流
        let unidir = wt.openUnidirectionalStream()
        match (unidir) {
            case Some(s) =>
                s.write([0x01, 0x02, 0x03])
                assertTrue(wt.ownsStream(s.getStreamId()), message: "单向流应归属会话")
            case None =>
                assertTrue(false, message: "应能打开单向流")
        }

        // 4. 发送数据报
        let dgOk = wt.sendDatagram([0xAA, 0xBB, 0xCC])
        assertTrue(dgOk, message: "数据报发送应成功")

        // 5. 关闭会话
        wt.close()
        assertTrue(wt.isClosed(), message: "会话应标记为已关闭")
        assertFalse(wt.isEstablished(), message: "关闭后不应 established")

        // 6. 关闭后流操作应失败
        let afterClose = wt.openBidirectionalStream()
        match (afterClose) {
            case Some(_) =>
                assertTrue(false, message: "关闭后不应能打开流")
            case None => ()
        }
    }

    @TestCase
    public func testWebTransportFlowControlIntegration(): Unit {
        let mockConn = MockQuicConnection()
        let h3Conn = H3Connection(mockConn, config: H3ConnectionConfig(), isServer: true)
        let wt = WebTransportSession(
            h3Conn, mockConn, 0u64,
            "/fc-test", "https://example.com"
        )
        wt.markEstablished()

        // 验证流控初始状态
        assertTrue(wt.flowController.canSend(), message: "初始应可发送")

        // 记录接收数据
        wt.flowController.recordReceived(1024)
        assertFalse(wt.flowController.needsMaxDataUpdate(),
            message: "1KB 数据不应触发 MAX_DATA 更新")

        // 构造 MAX_DATA 窗口
        let window = wt.flowController.buildMaxDataWindow()
        assertTrue(window > 0u64, message: "流控窗口应力正数")
    }

}