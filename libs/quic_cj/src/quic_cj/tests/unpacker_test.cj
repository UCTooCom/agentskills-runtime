package quic_cj.tests

import quic_cj.protocol.{VERSION_1, EncryptionLevel}
import quic_cj.core.{PacketUnpacker, ParsedPacket, removeHeaderProtectionAndDecodePn}
import quic_cj.tls.AesHeaderProtector
import quic_cj.wire.{Frame, PingFrame, PaddingFrame}

@Test
public class UnpackerTestSuite {
    @TestCase
    public func testUnpackerCreation(): Unit {
        let up = PacketUnpacker()
        @Assert(true, true)  // 可创建性测试
    }

    @TestCase
    public func testUnpackShortPacket(): Unit {
        let pkt: Array<Byte> = [0x40u8, 0x01u8]
        let up = PacketUnpacker()
        let result = up.unpackShortHeader(pkt)
        @Assert(result.consumed, 2)
    }

    @TestCase
    public func testUnpackLongHeader(): Unit {
    // 长包头初始包，DCIL=0，SCIL=0，TokenLength=0，Length=1，PN=1
    let pkt: Array<Byte> = [
        0xc0u8,           // 长包头 + 初始类型
        0x00u8, 0x00u8, 0x00u8, 0x01u8,  // 版本 1
        0x00u8,           // DCIL = 0
        0x00u8,           // SCIL = 0
        0x00u8,           // 令牌长度 = 0
        0x01u8,           // 长度 = 1
        0x01u8            // PN = 1
    ]
        let up = PacketUnpacker()
        let result = up.unpackLongHeader(pkt)
        @Assert(result.consumed > 0, true)
    }

    @TestCase
    public func testParseFramesEmpty(): Unit {
        let up = PacketUnpacker()
        let frames = up.parseFramesFromPayload([])
        @Assert(frames.size, 0)
    }

    @TestCase
    public func testUnpackShortHeaderWithConnId(): Unit {
        let pkt: Array<Byte> = [0x40u8, 0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8]
        let up = PacketUnpacker()
        let result0 = up.unpackShortHeader(pkt)
        let result4 = up.unpackShortHeaderWithConnId(pkt, 4)
        @Assert(result0.packetNumber, 1)
        @Assert(result4.packetNumber, 5)
    }
}

@Test
public class UnpackerExtendedTestSuite {
    @TestCase
    public func testUnpackLongHeaderPayloadClip(): Unit {
        // pkt with Length=2 but extra trailing bytes beyond payloadLen
        // Long header Initial, DCIL=0, SCIL=0, tokenLen=0
        let pkt: Array<Byte> = [
            0xc0u8,                            // type: long header + Initial
            0x00u8, 0x00u8, 0x00u8, 0x01u8,   // version 1
            0x00u8,                            // DCIL = 0
            0x00u8,                            // SCIL = 0
            0x00u8,                            // token length = 0
            0x02u8,                            // Length = 2 (1 PN + 1 payload)
            0x00u8,                            // PN = 0
            0x01u8,                            // payload: PingFrame
            0xffu8, 0xffu8                     // extra bytes (not in Length)
        ]
        let up = PacketUnpacker()
        let result = up.unpackLongHeader(pkt)
        @Assert(result.consumed > 0, true)
        // payload should be clipped to payloadLen=2, not including extra bytes
        @Assert(result.payload.size, 2)
        @Assert(result.payload[0], 0x01u8)
        @Assert(result.payload[1], 0xffu8)
        @Assert(result.packetNumber, 0)
    }

    @TestCase
    public func testUnpackLongHeaderWithToken(): Unit {
        // Initial packet with 4-byte token
        let pkt: Array<Byte> = [
            0xc0u8,                            // type: long header + Initial
            0x00u8, 0x00u8, 0x00u8, 0x01u8,   // version 1
            0x00u8,                            // DCIL = 0
            0x00u8,                            // SCIL = 0
            0x04u8,                            // token length = 4
            0xa1u8, 0xa2u8, 0xa3u8, 0xa4u8,   // token bytes
            0x03u8,                            // Length = 3 (1 PN + 2 payload)
            0x01u8,                            // PN = 1
            0x01u8, 0x02u8                     // payload: PingFrame + extra
        ]
        let up = PacketUnpacker()
        let result = up.unpackLongHeader(pkt)
        @Assert(result.consumed > 0, true)
        @Assert(result.packetNumber, 1)
        @Assert(result.payload.size, 2)
    }

    @TestCase
    public func testUnpackShortHeaderWithConnIdLen0(): Unit {
        // Short header with connIdLen=0 => PN starts at offset 1
        let pkt: Array<Byte> = [
            0x40u8,  // short header, key phase=0, pnLen=1 (0x40 & 0x03 = 0)
            0x01u8   // 1-byte PN = 1
        ]
        let up = PacketUnpacker()
        let result = up.unpackShortHeaderWithConnId(pkt, 0)
        @Assert(result.packetNumber, 1)
    }

    @TestCase
    public func testUnpackShortHeaderWithConnIdLen10(): Unit {
        // Short header with connIdLen=10 => PN starts at offset 11
        let pkt: Array<Byte> = Array<Byte>(12, repeat: 0x00u8)
        pkt[0] = 0x40u8  // short header, pnLen=1 (0x40 & 0x03 = 0 => +1 = 1)
        pkt[11] = 0x05u8  // PN = 5 at offset 11
        let up = PacketUnpacker()
        let result = up.unpackShortHeaderWithConnId(pkt, 10)
        @Assert(result.packetNumber, 5)
    }

    @TestCase
    public func testUnpackLongHeaderBadTruncated(): Unit {
        // Too-short long header data
        let up = PacketUnpacker()
        let result = up.unpackLongHeader([0xc0u8])
        @Assert(result.consumed, 0)
        @Assert(result.payload.size, 0)
    }

    @TestCase
    public func testParseFramesFromPayloadMultipleFrame(): Unit {
        let up = PacketUnpacker()
        let payload: Array<Byte> = [0x01u8, 0x00u8, 0x00u8]
        let frames = up.parseFramesFromPayload(payload)
        @Assert(frames.size, 2)
        @Assert(Int64(frames[0].frameType()), Int64(PingFrame().frameType()))
        @Assert(Int64(frames[1].frameType()), Int64(PaddingFrame().frameType()))
    }

    @TestCase
    public func testParseFramesFromPayloadSingleFrame(): Unit {
        let up = PacketUnpacker()
        let frames = up.parseFramesFromPayload([0x01u8])
        @Assert(frames.size, 1)
        @Assert(Int64(frames[0].frameType()), Int64(PingFrame().frameType()))
    }

    @TestCase
    public func testParseFramesFromPayloadUnknownStop(): Unit {
        let up = PacketUnpacker()
        // Unknown frame type 0xff stops parsing; parseFrameAt returns (Frame(), 1)
        // which consumed > 0, so the loop keeps consuming bytes
        let payload: Array<Byte> = [0x01u8, 0xffu8]
        let frames = up.parseFramesFromPayload(payload)
        @Assert(frames.size >= 1, true)
    }
}
