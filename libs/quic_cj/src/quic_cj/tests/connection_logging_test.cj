package quic_cj.tests

import quic_cj.core.{toQlogFrame, toQlogEcn, toQlogPacketTypeStr, QlogFrame, QlogPacketType}
import quic_cj.protocol.{ECN}
import quic_cj.wire.{Frame, CryptoFrame, StreamFrame, AckFrame, DatagramFrame, ConnectionCloseFrame, PingFrame}

@Test
public class ConnectionLoggingTestSuite {
    @TestCase
    public func testToQlogFrameCrypto(): Unit {
        let cf = CryptoFrame()
        cf.offset = 0
        cf.data = [0x01u8, 0x02u8, 0x03u8]
        let qf = toQlogFrame(cf)
        @Assert(qf.frameType, "crypto")
        @Assert(qf.offset, 0)
        @Assert(qf.length, 3)
        @Assert(qf.streamId, -1)
        @Assert(qf.fin, false)
    }

    @TestCase
    public func testToQlogFrameStream(): Unit {
        let sf = StreamFrame()
        sf.streamId = 4
        sf.offset = 100
        sf.data = [0x10u8, 0x20u8]
        sf.fin = true
        let qf = toQlogFrame(sf)
        @Assert(qf.frameType, "stream")
        @Assert(qf.streamId, 4)
        @Assert(qf.offset, 100)
        @Assert(qf.length, 2)
        @Assert(qf.fin, true)
    }

    @TestCase
    public func testToQlogFrameAck(): Unit {
        let af = AckFrame()
        let qf = toQlogFrame(af)
        @Assert(qf.frameType, "ack")
    }

    @TestCase
    public func testToQlogFrameDatagram(): Unit {
        let df = DatagramFrame()
        df.data = [0xAAu8]
        let qf = toQlogFrame(df)
        @Assert(qf.frameType, "datagram")
        @Assert(qf.length, 1)
    }

    @TestCase
    public func testToQlogFrameOther(): Unit {
        let pf = PingFrame()
        let qf = toQlogFrame(pf)
        @Assert(qf.frameType, "other")
    }

    @TestCase
    public func testToQlogEcnUnsupported(): Unit {
        let s = toQlogEcn(ECN.Unsupported)
        @Assert(s, "Unsupported")
    }

    @TestCase
    public func testToQlogEcnNon(): Unit {
        let s = toQlogEcn(ECN.Non)
        @Assert(s, "Unsupported")
    }

    @TestCase
    public func testToQlogEcnEct0(): Unit {
        let s = toQlogEcn(ECN.ECT0)
        @Assert(s, "ECT0")
    }

    @TestCase
    public func testToQlogEcnEct1(): Unit {
        let s = toQlogEcn(ECN.ECT1)
        @Assert(s, "ECT1")
    }

    @TestCase
    public func testToQlogEcnCe(): Unit {
        let s = toQlogEcn(ECN.CE)
        @Assert(s, "ECN-CE")
    }

    @TestCase
    public func testToQlogPacketTypeInitial(): Unit {
        // 0xC0 = Long Header (11) + Type Initial (00) => 0xC0
        let s = toQlogPacketTypeStr(0xC0u8)
        @Assert(s, QlogPacketType.INITIAL)
    }

    @TestCase
    public func testToQlogPacketTypeRetry(): Unit {
        // 0xE0 = Long Header (11) + Type Retry (10) => 0xE0
        let s = toQlogPacketTypeStr(0xE0u8)
        @Assert(s, QlogPacketType.RETRY)
    }

    @TestCase
    public func testToQlogPacketTypeHandshake(): Unit {
        // 0xD0 = Long Header (11) + Type Handshake (01) => 0xD0
        let s = toQlogPacketTypeStr(0xD0u8)
        @Assert(s, QlogPacketType.HANDSHAKE)
    }

    @TestCase
    public func testToQlogPacketTypeZeroRtt(): Unit {
        // 0xF0 = Long Header (11) + Type 0-RTT (00) => 0xF0
        let s = toQlogPacketTypeStr(0xF0u8)
        @Assert(s, QlogPacketType.ZERO_RTT)
    }

    @TestCase
    public func testToQlogPacketTypeShortHeader(): Unit {
        // Short header: 0x40 has high nibble 0x4 which doesn't match long header patterns
        let s = toQlogPacketTypeStr(0x40u8)
        @Assert(s, "unknown")
    }

    @TestCase
    public func testToQlogPacketTypeUnknown(): Unit {
        let s = toQlogPacketTypeStr(0x00u8)
        @Assert(s, "unknown")
    }

    @TestCase
    public func testQlogFrameInitDefaults(): Unit {
        let qf = QlogFrame()
        @Assert(qf.frameType, "other")
        @Assert(qf.streamId, -1)
        @Assert(qf.offset, -1)
        @Assert(qf.length, -1)
        @Assert(qf.fin, false)
    }
}
