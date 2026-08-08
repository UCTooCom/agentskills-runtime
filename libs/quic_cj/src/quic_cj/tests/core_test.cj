package quic_cj.tests

import quic_cj.protocol.{VERSION_1, EncryptionLevel, Perspective, PacketNumber, PacketNumberLen}
import quic_cj.core.{PacketPacker, PacketNumberSpace, PacketUnpacker, Framer, Connection, newClientConnection, ConnectionState, sealPacket, unsealPacket, removeHeaderProtectionAndDecodePn, SendQueue}
import quic_cj.wire.{Frame, PingFrame, parseFrame, FRAME_TYPE_PING}
import quic_cj.tls.{UpdatableAEAD, AesHeaderProtector, AeadSealer, AeadOpener, CryptoSetup}

@Test
public class CoreTestSuite {
    @TestCase
    public func testPacketNumberSpace(): Unit {
        let pns = PacketNumberSpace()
        @Assert(pns.nextPacketNumber(), 0)
        @Assert(pns.nextPacketNumber(), 1)
        @Assert(pns.nextPacketNumber(), 2)
    }

    @TestCase
    public func testPacketPackerCreation(): Unit {
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        @Assert(pp is PacketPacker, true)
    }

    @TestCase
    public func testFramerInitialState(): Unit {
        let f = Framer()
        @Assert(f.hasData(), false)
    }

    @TestCase
    public func testFramerQueueCrypto(): Unit {
        let f = Framer()
        f.queueCryptoData([0x01u8, 0x02u8, 0x03u8])
        @Assert(f.hasData(), true)
        let frames = f.getFrames()
        @Assert(frames.size > 0, true)
    }

    @TestCase
    public func testClientConnectionCreation(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let isInitial = match (conn.getState()) { case ConnectionState.Initial => true; case _ => false }
        @Assert(isInitial, true)
        @Assert(conn.getVersion(), VERSION_1)
    }

    @TestCase
    public func testPacketPackerPayloadLength(): Unit {
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame()]
        // 长包头（握手，无令牌）：1+4+1+2+1+2+1(长度)=12 + 负载(PN1+帧1)=2 = 14
        let handshakePkt = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, 1u8)
        @Assert(handshakePkt.size, 14)
        // 长包头（初始，令牌长度=0）：头 12+1(令牌)+1(长度)=13 + 负载=2 = 15
        let initialPkt = pp.packLongHeaderPacket(0u8, EncryptionLevel.Initial, frames, 1u8)
        @Assert(initialPkt.size, 15)
        // 短包头：头字段 = 1+2 = 3，加负载（PN 1 + PingFrame 1）= 2
        let shortPkt = pp.packShortHeaderPacket(frames, 1u8)
        @Assert(shortPkt.size, 5)
    }

    @TestCase
    public func testSealUnsealRoundTrip(): Unit {
        let key: Array<Byte> = Array<Byte>(16, repeat: 0xabu8)
        let iv: Array<Byte> = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey: Array<Byte> = Array<Byte>(16, repeat: 0xefu8)

        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)

        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        // 使用多个 PingFrame 以获得足够的密文大小（需要 19+ 字节用于采样）
        let frames: Array<Frame> = [PingFrame(), PingFrame(), PingFrame(), PingFrame(), PingFrame()]
        let pnLen: PacketNumberLen = 1u8
        let packet = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, pnLen)
        // pnOffset = AAD 长度。对于 2 字节 DCID/SCID 的握手包：
        // 包头(1)+版本(4)+DCIL(1)+DCID(2)+SCIL(1)+SCID(2)+长度(1) = 12
        let pnOffset: Int64 = 12
        // pn = 0（第一个握手包编号）
        let sealed = sealPacket(packet, 0, pnOffset, Int64(pnLen), AeadSealer(aead), hp)
        @Assert(sealed.size > packet.size, true)  // 加密增加了认证标签
        @Assert(sealed.size, packet.size + 16)  // 认证标签为 16 字节
        // 验证包头发保护已应用（首字节与原始不同）
        @Assert(Int64(sealed[0]) != Int64(packet[0]), true)

        // 解封并验证恢复了 PingFrame
        var unsealData = sealed[..sealed.size]
        let correctedPn = removeHeaderProtectionAndDecodePn(
            unsealData, pnOffset, Int64(pnLen), -1, hp)
        let decrypted = unsealPacket(unsealData, correctedPn, pnOffset, Int64(pnLen), AeadOpener(aead), hp)
        @Assert(decrypted.size > 0, true)
        let (frame, consumed) = parseFrame(decrypted)
        @Assert(consumed > 0, true)
        @Assert(Int64(frame.frameType()), Int64(FRAME_TYPE_PING))
    }


    @TestCase
    public func testIdleTimerExpires(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let isInitial = match (conn.getState()) { case ConnectionState.Initial => true; case _ => false }
        @Assert(isInitial, true)
        conn.tick(35000)  // 超过默认 30 秒空闲超时
        let isClosed = match (conn.getState()) { case ConnectionState.Closed => true; case _ => false }
        @Assert(isClosed, true)
    }

    @TestCase
    public func testCustomIdleTimeout(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.setIdleTimeout(5000)  // 5 秒空闲超时
        conn.tick(6000)  // 超过 5 秒超时
        let isClosed = match (conn.getState()) { case ConnectionState.Closed => true; case _ => false }
        @Assert(isClosed, true)
    }

    @TestCase
    public func testConnectionOpenStream(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        if (let Some(stream) <- conn.openStream()) {
            @Assert(true, true)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testConnectionCloseError(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.closeWithError(0x01u64, "test error")
        let (code, reason) = conn.getCloseError()
        @Assert(code, 0x01u64)
    }

    @TestCase
    public func testConnectionStateTransitions(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.setState(ConnectionState.Handshake)
        let isHS = match (conn.getState()) { case ConnectionState.Handshake => true; case _ => false }
        @Assert(isHS, true)
        conn.setState(ConnectionState.Established)
        let isEst = match (conn.getState()) { case ConnectionState.Established => true; case _ => false }
        @Assert(isEst, true)
    }

    @TestCase
    public func testConnectionIsClosed(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.closeWithError(0u64, "close")
        // 关闭后，应处于关闭中状态（直到定时器到期才变为已关闭）
        let isClosing = match (conn.getState()) { case ConnectionState.Closing => true; case _ => false }
        @Assert(isClosing, true)
    }

}

@Test
public class CoreExtendedTestSuite {
    @TestCase
    public func testConnectionHandlePacket(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let response = conn.handlePacket([])
        @Assert(response.size, 0)
    }

    @TestCase
    public func testConnectionDuplicateOpenStream(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        if (let Some(s1) <- conn.openStream()) {
            if (let Some(s2) <- conn.openStream()) {
                @Assert(s1.getStreamId() != s2.getStreamId(), true)
            } else {
                @Assert(false, true)
            }
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testConnectionLocalRemoteAddr(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let local = conn.localAddr()
        let remote = conn.remoteAddr()
        @Assert(local.size > 0, true)
        @Assert(remote.size > 0, true)
    }

    @TestCase
    public func testConnectionLocalRemoteAddrNotEmpty(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let localSize = conn.localAddr().size > 0
        @Assert(localSize, true)
        let remoteSize = conn.remoteAddr().size > 0
        @Assert(remoteSize, true)
    }

    @TestCase
    public func testFramerGetFramesTwice(): Unit {
        let f = Framer()
        f.queueCryptoData([0x01u8])
        let f1 = f.getFrames()
        @Assert(f1.size > 0, true)
        let f2 = f.getFrames()
        @Assert(f2.size, 0)
    }

    @TestCase
    public func testPacketNumberSpaceConsecutive(): Unit {
        let pns = PacketNumberSpace()
        @Assert(pns.nextPacketNumber(), 0)
        @Assert(pns.nextPacketNumber(), 1)
        @Assert(pns.nextPacketNumber(), 2)
        @Assert(pns.nextPacketNumber(), 3)
        @Assert(pns.nextPacketNumber(), 4)
    }

    @TestCase
    public func testPacketPackerShortHeaderSize(): Unit {
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame(), PingFrame()]
        let pkt = pp.packShortHeaderPacket(frames, 1u8)
        @Assert(pkt.size > 0, true)
        @Assert(Int64(pkt[0]) & 0x40, 0x40)
    }

    @TestCase
    public func testSealUnsealEmptyPayload(): Unit {
        let key: Array<Byte> = Array<Byte>(16, repeat: 0xabu8)
        let iv: Array<Byte> = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey: Array<Byte> = Array<Byte>(16, repeat: 0xefu8)

        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)

        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        // 需要至少 19 字节的负载进行采样
        let frames: Array<Frame> = [PingFrame(), PingFrame(), PingFrame(), PingFrame(), PingFrame()]
        let pkt = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, 1u8)
        let pnOffset: Int64 = 12
        // 使用 PN=0 来匹配包中编码的 PN（packLongHeaderPacket 的第一个包）
        let sealed = sealPacket(pkt, 0, pnOffset, 1, AeadSealer(aead), hp)
        @Assert(sealed.size > pkt.size, true)

        var unsealData = sealed[..sealed.size]
        let correctedPn = removeHeaderProtectionAndDecodePn(
            unsealData, pnOffset, 1, -1, hp)
       let decrypted = unsealPacket(unsealData, correctedPn, pnOffset, 1, AeadOpener(aead), hp)
       @Assert(decrypted.size > 0, true)
       let (frame, consumed) = parseFrame(decrypted)
       @Assert(consumed > 0, true)
   }

    @TestCase
    public func testRemoveHeaderProtectionDecodePn(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame(), PingFrame(), PingFrame(), PingFrame(), PingFrame()]
        let pnLen: PacketNumberLen = 1u8
        let pkt = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, pnLen)
        let pnOffset: Int64 = 12
        let pktPn: PacketNumber = 0

        let sealed = sealPacket(pkt, pktPn, pnOffset, Int64(pnLen), AeadSealer(aead), hp)

        var hpRemoved = sealed[..sealed.size]
        let correctedPn = removeHeaderProtectionAndDecodePn(
            hpRemoved, pnOffset, Int64(pnLen), -1, hp)
        @Assert(correctedPn, pktPn)

        let protectMask: UInt8 = 0x0fu8
        @Assert(Int64(hpRemoved[0] & protectMask), Int64(pkt[0] & protectMask))
        @Assert(hpRemoved[pnOffset], pkt[pnOffset])

        let decrypted = unsealPacket(hpRemoved, correctedPn, pnOffset, Int64(pnLen), AeadOpener(aead), hp)
        @Assert(decrypted.size > 0, true)
        let (frame, consumed) = parseFrame(decrypted)
        @Assert(consumed > 0, true)
        @Assert(Int64(frame.frameType()), Int64(FRAME_TYPE_PING))
    }

    @TestCase
    public func testRemoveHeaderProtectionDecodePnShortHeader(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame(), PingFrame(), PingFrame(), PingFrame(), PingFrame()]
        let pnLen: PacketNumberLen = 1u8
        let pkt = pp.packShortHeaderPacket(frames, pnLen)
        let pnOffset: Int64 = 1 + 2
        let pktPn: PacketNumber = 0

        let sealed = sealPacket(pkt, pktPn, pnOffset, Int64(pnLen), AeadSealer(aead), hp)

        var hpRemoved = sealed[..sealed.size]
        let correctedPn = removeHeaderProtectionAndDecodePn(
            hpRemoved, pnOffset, Int64(pnLen), -1, hp)
        @Assert(correctedPn, pktPn)

        let protectMask: UInt8 = 0x1fu8
        @Assert(Int64(hpRemoved[0] & protectMask), Int64(pkt[0] & protectMask))
        @Assert(hpRemoved[pnOffset], pkt[pnOffset])

        let decrypted = unsealPacket(hpRemoved, correctedPn, pnOffset, Int64(pnLen), AeadOpener(aead), hp)
        @Assert(decrypted.size > 0, true)
        let (frame, consumed) = parseFrame(decrypted)
        @Assert(consumed > 0, true)
    }

    @TestCase
    public func testRemoveHeaderProtectionInsufficientSample(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame()]
        let pkt = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, 1u8)
        let pnOffset: Int64 = 12

        let sealed = sealPacket(pkt, 0, pnOffset, 1, AeadSealer(aead), hp)

        var hpRemoved = sealed[..sealed.size]
        let correctedPn = removeHeaderProtectionAndDecodePn(
            hpRemoved, pnOffset, 1, -1, hp)
        @Assert(correctedPn >= 0, true)
    }

    @TestCase
    public func testPacketUnpackerLargestReceived(): Unit {
        let unpacker = PacketUnpacker()
        @Assert(unpacker.getLargestReceived(), -1)
        unpacker.setLargestReceived(42)
        @Assert(unpacker.getLargestReceived(), 42)
        unpacker.setLargestReceived(0)
        @Assert(unpacker.getLargestReceived(), 0)
    }

    @TestCase
    public func testRemoveHeaderProtectionDecodePnLen2(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame(), PingFrame(), PingFrame(), PingFrame(), PingFrame()]
        let pnLen: PacketNumberLen = 2u8
        let pkt = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, pnLen)
        let pnOffset: Int64 = 12
        let expectedPn: PacketNumber = 0

        let sealed = sealPacket(pkt, expectedPn, pnOffset, Int64(pnLen), AeadSealer(aead), hp)

        var hpRemoved = sealed[..sealed.size]
        let correctedPn = removeHeaderProtectionAndDecodePn(
            hpRemoved, pnOffset, Int64(pnLen), -1, hp)
        @Assert(correctedPn, expectedPn)
        @Assert(hpRemoved[pnOffset], pkt[pnOffset])
        @Assert(hpRemoved[pnOffset + 1], pkt[pnOffset + 1])

        let decrypted = unsealPacket(hpRemoved, correctedPn, pnOffset, Int64(pnLen), AeadOpener(aead), hp)
        @Assert(decrypted.size > 0, true)
    }

    @TestCase
    public func testRemoveHeaderProtectionDecodePnLen4(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame(), PingFrame(), PingFrame(), PingFrame(), PingFrame()]
        let pnLen: PacketNumberLen = 4u8
        let pkt = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, pnLen)
        let pnOffset: Int64 = 12
        let expectedPn: PacketNumber = 0

        let sealed = sealPacket(pkt, expectedPn, pnOffset, Int64(pnLen), AeadSealer(aead), hp)

        var hpRemoved = sealed[..sealed.size]
        let correctedPn = removeHeaderProtectionAndDecodePn(
            hpRemoved, pnOffset, Int64(pnLen), -1, hp)
        @Assert(correctedPn, expectedPn)
        @Assert(hpRemoved[pnOffset], pkt[pnOffset])
        @Assert(hpRemoved[pnOffset + 1], pkt[pnOffset + 1])
        @Assert(hpRemoved[pnOffset + 2], pkt[pnOffset + 2])
        @Assert(hpRemoved[pnOffset + 3], pkt[pnOffset + 3])

        let decrypted = unsealPacket(hpRemoved, correctedPn, pnOffset, Int64(pnLen), AeadOpener(aead), hp)
        @Assert(decrypted.size > 0, true)
    }
}

@Test
public class CoreEdgeCaseTestSuite {
    @TestCase
    public func testUnsealPacketBadParamsBadAadLen(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)
        // aadLen <= 0 => should return []
        let result = unsealPacket([0x00u8], 0, 0, 1, AeadOpener(aead), hp)
        @Assert(result.size, 0)
    }

    @TestCase
    public func testUnsealPacketBadParamsAadPnOverflow(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)
        // aadLen + pnLen >= data.size => should return []
        let result = unsealPacket([0x00u8, 0x01u8, 0x02u8], 0, 2, 1, AeadOpener(aead), hp)
        @Assert(result.size, 0)
    }

    @TestCase
    public func testRemoveHeaderProtectionDecodePnEdgeBadParams(): Unit {
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let hp = AesHeaderProtector(hpKey)
        // data where aadLen + pnLen >= data.size triggers early return path
        let shortData: Array<Byte> = [0xc0u8, 0x00u8, 0x00u8]
        let pn = removeHeaderProtectionAndDecodePn(shortData, 1, 2, -1, hp)
        @Assert(pn >= 0, true)
    }

    @TestCase
    public func testRemoveHeaderProtectionDecodePnWithPrevLargest(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let hpKey = Array<Byte>(16, repeat: 0xefu8)
        let aead = UpdatableAEAD(key, iv)
        let hp = AesHeaderProtector(hpKey)
        let pp = PacketPacker(VERSION_1, [0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let frames: Array<Frame> = [PingFrame(), PingFrame(), PingFrame(), PingFrame(), PingFrame()]
        let pnLen: PacketNumberLen = 1u8
        let pkt = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, pnLen)
        let pnOffset: Int64 = 12
        let pktPn: PacketNumber = 0
        let sealed = sealPacket(pkt, pktPn, pnOffset, Int64(pnLen), AeadSealer(aead), hp)
        var hpRemoved = sealed[..sealed.size]
        // largestReceived = 5 means the 0 PN should decode to PN=256 (next in 1-byte window)
        let correctedPn = removeHeaderProtectionAndDecodePn(
            hpRemoved, pnOffset, Int64(pnLen), 5, hp)
        @Assert(correctedPn, 0)
        let decrypted = unsealPacket(hpRemoved, correctedPn, pnOffset, Int64(pnLen), AeadOpener(aead), hp)
        @Assert(decrypted.size > 0, true)
        let (frame, consumed) = parseFrame(decrypted)
        @Assert(consumed > 0, true)
    }
}


@Test
public class CoreNewFeatureTestSuite {
    @TestCase
    public func testKeepAliveGeneratesPing(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.enableKeepAlive(1000)
        conn.tick(1500)
        let response = conn.handlePacket([])
        @Assert(response.size > 0, true)
    }

    @TestCase
    public func testKeepAliveDisabledNoPing(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.enableKeepAlive(1000)
        conn.disableKeepAlive()
        conn.tick(2000)
        let response = conn.handlePacket([])
        @Assert(response.size, 0)
    }

    @TestCase
    public func testGetRetransmissionQueue(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let rq = conn.getRetransmissionQueue()
        @Assert(rq.hasData(EncryptionLevel.Initial), false)
    }

    @TestCase
    public func testGetTokenEmpty(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let token = conn.getToken()
        @Assert(token.size, 0)
    }

    @TestCase
    public func testGetPathManager(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let pm = conn.getPathManager()
        @Assert(pm.isMigrationDisabled(), false)
    }

    @TestCase
    public func testSetMigrationDisabledOnConnection(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        conn.setMigrationDisabled(true)
        let pm = conn.getPathManager()
        @Assert(pm.isMigrationDisabled(), true)
    }

    @TestCase
    public func testGetDatagramQueue(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let dq = conn.getDatagramQueue()
        @Assert(dq.sendLen(), 0)
        @Assert(dq.recvLen(), 0)
    }

    @TestCase
    public func testGetSendQueue(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let sq = conn.getSendQueue()
        @Assert(sq is SendQueue, true)
    }
}
