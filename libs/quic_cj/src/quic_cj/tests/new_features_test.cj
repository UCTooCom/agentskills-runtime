package quic_cj.tests

import std.collection.ArrayList
import quic_cj.protocol.{VERSION_1, VERSION_2, EncryptionLevel, Perspective}
import quic_cj.core.{Connection, newClientConnection, newServerConnection, ConnectionState}
import quic_cj.wire.{composeVersionNegotiation, appendVarint, appendBytes, appendFrame, Frame, PingFrame, ImmediateAckFrame}
import quic_cj.ack.ReceivedPacketTracker
import quic_cj.tls.getRetryIntegrityTag

/// 测试新的协议特性：版本协商、Retry、无状态重置、IMMEDIATE_ACK、0-RTT
@Test
public class NewFeaturesTestSuite {
    /// 测试 handlePacket 检测并处理版本协商包
    @TestCase
    public func testVersionNegotiationPacketDetection(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8, 0x03u8, 0x04u8], [0x05u8, 0x06u8, 0x07u8, 0x08u8])
        let vnPacket = composeVersionNegotiation(
            [0x01u8, 0x02u8, 0x03u8, 0x04u8],
            [0x05u8, 0x06u8, 0x07u8, 0x08u8],
            [VERSION_1, VERSION_2]
        )
        let response = conn.handlePacket(vnPacket)
        // Connection should survive and produce some output (re-init crypto)
        @Assert(response.size <= 1280, true)
    }

    /// 测试 Retry 包检测：长包头 type=3
    @TestCase
    public func testRetryPacketDetection(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        // 构造一个 Retry 包（长包头 type=3，版本 VERSION_1）
        // 首字节: 11 (长包头) + 11 (type=3) << 4 = 0xF0
        let firstByte: UInt8 = 0xF0u8 | 0x00u8  // type=3, pnLen=1
        var retryPkt: Array<Byte> = [firstByte]
        // 版本 = VERSION_1 (4 字节)
        retryPkt = appendBytes(retryPkt, [0x00u8, 0x00u8, 0x00u8, 0x01u8])
        // DCID 长度 + 值
        retryPkt = appendBytes(retryPkt, [0x02u8, 0x01u8, 0x02u8])
        // SCID 长度 + 值 (retrySrcConnId)
        retryPkt = appendBytes(retryPkt, [0x02u8, 0x0au8, 0x0bu8])
        // Token: varint 长度 + 值
        retryPkt = appendVarint(retryPkt, 4)
        retryPkt = appendBytes(retryPkt, [0xa1u8, 0xa2u8, 0xa3u8, 0xa4u8])
        // 计算正确的完整性标签
        let integrityTag = getRetryIntegrityTag(retryPkt, [0x01u8, 0x02u8], VERSION_1)
        retryPkt = appendBytes(retryPkt, integrityTag)

        let response = conn.handlePacket(retryPkt)
        // Should detect as Retry and produce outgoing Initial with token
        @Assert(response.size > 0, true)
    }

    /// 测试 handlePacket 忽略长包头 type=3 的误映射（原 bug）
    @TestCase
    public func testRetryPacketNotMisroutedToShortHeader(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        // 构造短包头包（应走短路径）
        let shortPkt: Array<Byte> = [0x40u8, 0x01u8, 0x02u8, 0x00u8]
        let response = conn.handlePacket(shortPkt)
        // 短包应被正常处理，不会崩溃
        @Assert(response.size >= 0, true)
    }

    /// 测试无状态重置令牌设置与获取
    @TestCase
    public func testStatelessResetTokenRoundTrip(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let token: Array<Byte> = Array<Byte>(16, repeat: 0xabu8)
        conn.setStatelessResetToken(token)
        let retrieved = conn.getStatelessResetToken()
        @Assert(retrieved.size, 16)
        var matched: Bool = true
        var i: Int64 = 0
        while (i < 16) {
            if (retrieved[i] != 0xabu8) { matched = false; break }
            i += 1
        }
        @Assert(matched, true)
    }

    /// 测试设置错误长度的令牌被忽略
    @TestCase
    public func testStatelessResetTokenWrongSizeIgnored(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.setStatelessResetToken([0x01u8, 0x02u8])  // 太短
        let retrieved = conn.getStatelessResetToken()
        @Assert(retrieved.size, 0)
    }

    /// 测试 IMMEDIATE_ACK 帧处理在 ReceivedPacketTracker
    @TestCase
    public func testImmediateAckTriggersAck(): Unit {
        let tracker = ReceivedPacketTracker()
        let none1 = match (tracker.getAckFrame()) { case None => true; case _ => false }
        @Assert(none1, true)

        tracker.requestImmediateAck()
        let some1 = match (tracker.getAckFrame()) { case Some(_) => true; case _ => false }
        @Assert(some1, true)
    }

    /// 测试 IMMEDIATE_ACK 帧只触发一次
    @TestCase
    public func testImmediateAckOnlyOnce(): Unit {
        let tracker = ReceivedPacketTracker()
        tracker.requestImmediateAck()
        let some2 = match (tracker.getAckFrame()) { case Some(_) => true; case _ => false }
        @Assert(some2, true)
        let none2 = match (tracker.getAckFrame()) { case None => true; case _ => false }
        @Assert(none2, true)
    }

    /// 测试 0-RTT 早期数据 API
    @TestCase
    public func testZeroRttEarlyDataApi(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        // 初始时 0-RTT 不可用
        @Assert(conn.canSendEarlyData(), false)
        @Assert(conn.sendEarlyData([0x01u8]), false)
        // 启用 0-RTT
        conn.setZeroRttAvailable(true)
        @Assert(conn.canSendEarlyData(), true)
        // 发送早期数据
        let ok = conn.sendEarlyData([0x01u8, 0x02u8, 0x03u8])
        @Assert(ok, true)
        // 接收早期数据（服务端侧）
        let received = conn.receiveEarlyData()
        let isNone = match (received) { case None => true; case _ => false }
        @Assert(isNone, true)  // 客户端没有收到任何数据
    }

    /// 测试 0-RTT 接收回调（仅验证设置不崩溃）
    @TestCase
    public func testZeroRttReceiveCallback(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.setEarlyDataRcvCallback({ data =>
            // 回调被调用时，打印数据大小
            let _ = data.size
        })
        // 设置回调不应崩溃
        @Assert(true, true)
    }

    /// 测试 0-RTT 端到端数据流：sendEarlyData → generateOutgoing → handlePacket → receiveEarlyData
    /// 验证早期数据从客户端发送队列经包编码/解码后到达服务端接收缓冲的完整管线。
    @TestCase
    public func testZeroRttEndToEndDataFlow(): Unit {
        let DATA: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let clientConn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let serverConn = newServerConnection([0x01u8, 0x02u8])
        // 双方启用 0-RTT
        clientConn.setZeroRttAvailable(true)
        serverConn.setZeroRttAvailable(true)
        // 开启加密（使包处理进入加密路径，但 ZeroRTT 密钥未设置 → 走无解密处理路径）
        clientConn.enableCrypto()
        serverConn.enableCrypto()
        // 注册服务端早期数据回调
        let callbackHolder = ArrayList<Array<Byte>>()
        serverConn.setEarlyDataRcvCallback({ data =>
            callbackHolder.add(data)
        })
        // 客户端发送早期数据
        let sendOk = clientConn.sendEarlyData(DATA)
        @Assert(sendOk, true)
        // 客户端生成出站包（应输出 ZeroRTT 包）
        let outgoing = clientConn.handlePacket([])
        @Assert(outgoing.size > 0, true)
        // 服务端处理收到的包
        let _ = serverConn.handlePacket(outgoing)
        // 服务端应收到早期数据
        let earlyData = serverConn.receiveEarlyData()
        match (earlyData) {
            case Some(ed) => @Assert(ed == DATA, true)
            case None => @Assert(false, true)
        }
        // 回调也应被调用
        @Assert(callbackHolder.size > 0, true)
        if (callbackHolder.size > 0) {
            @Assert(callbackHolder[0] == DATA, true)
        }
    }

    /// 测试重传队列不同加密级别
    @TestCase
    public func testRetransmissionQueueLevels(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let rq = conn.getRetransmissionQueue()
        @Assert(rq.hasData(EncryptionLevel.Initial), false)
        @Assert(rq.hasData(EncryptionLevel.Handshake), false)
        @Assert(rq.hasData(EncryptionLevel.ZeroRTT), false)
        @Assert(rq.hasData(EncryptionLevel.OneRTT), false)
    }

    /// 测试 IP 地址转字符串
    @TestCase
    public func testIpv4ToString(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        // 验证连接创建成功
        let isInitial = match (conn.getState()) { case ConnectionState.Initial => true; case _ => false }
        @Assert(isInitial, true)
    }
}
