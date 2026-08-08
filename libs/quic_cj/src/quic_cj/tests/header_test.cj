package quic_cj.tests

import quic_cj.wire.{isLongHeaderPacket, parseVersion, parseLongPacketType, isPotentialQUICPacket, parseHeader, Header}
import quic_cj.protocol.{VERSION_1, VERSION_2, VERSION_UNKNOWN, MAX_CONN_ID_LEN, MIN_CONN_ID_LEN_INITIAL}

@Test
public class HeaderTestSuite {
    @TestCase
    public func testIsLongHeaderPacket(): Unit {
        @Assert(isLongHeaderPacket(0xc0u8), true)
        @Assert(isLongHeaderPacket(0x40u8), false)
        @Assert(isLongHeaderPacket(0x80u8), true)
        @Assert(isLongHeaderPacket(0x3fu8), false)
    }

    @TestCase
    public func testIsPotentialQUICPacket(): Unit {
        @Assert(isPotentialQUICPacket(0x40u8), true)
        @Assert(isPotentialQUICPacket(0x7fu8), true)
        @Assert(isPotentialQUICPacket(0x00u8), false)
        @Assert(isPotentialQUICPacket(0x3fu8), false)
        @Assert(isPotentialQUICPacket(0x80u8), false)
    }

    @TestCase
    public func testParseVersionV1(): Unit {
        let data: Array<Byte> = [0xc0u8, 0x00u8, 0x00u8, 0x00u8, 0x01u8]
        let v = parseVersion(data)
        @Assert(v, VERSION_1)
    }

    @TestCase
    public func testParseVersionV2(): Unit {
        let data: Array<Byte> = [0xc0u8, 0x6bu8, 0x33u8, 0x43u8, 0xcfu8]
        let v = parseVersion(data)
        @Assert(v, VERSION_2)
    }

    @TestCase
    public func testParseVersionTooShort(): Unit {
        let data: Array<Byte> = [0xc0u8, 0x00u8]
        let v = parseVersion(data)
        @Assert(v, VERSION_UNKNOWN)
    }

    @TestCase
    public func testParseLongPacketType(): Unit {
        // 初始 = 0，重试 = 1，握手 = 2，零 RTT = 3
        @Assert(parseLongPacketType(0xc0u8), 0u8)  // Initial
        @Assert(parseLongPacketType(0xd0u8), 1u8)  // Retry
        @Assert(parseLongPacketType(0xe0u8), 2u8)  // Handshake
        @Assert(parseLongPacketType(0xf0u8), 3u8)  // ZeroRTT
    }

    @TestCase
    public func testParseHeaderShort(): Unit {
        let data: Array<Byte> = [0x40u8, 0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let (hdr, n) = parseHeader(data)
        @Assert(hdr.isLongHeader, false)
        @Assert(n, 1)
    }

    @TestCase
    public func testParseHeaderEmpty(): Unit {
        let (hdr, n) = parseHeader([])
        @Assert(n, 0)
    }

    @TestCase
    public func testParseHeaderLong(): Unit {
        // 长包头初始包，4 字节 DCID 和 4 字节 SCID
        let data: Array<Byte> = [
            0xc0u8,           // 长包头 + 初始类型（0xc0 = 11000000，type = 0）
            0x00u8, 0x00u8, 0x00u8, 0x01u8,  // VERSION_1
            0x04u8,           // DCIL = 4
            0x01u8, 0x02u8, 0x03u8, 0x04u8,  // DCID = 4 字节
            0x04u8,           // SCIL = 4
            0x05u8, 0x06u8, 0x07u8, 0x08u8,  // SCID = 4 字节
            0x00u8            // 剩余部分（负载）
        ]
        let (hdr, n) = parseHeader(data)
        @Assert(hdr.isLongHeader, true)
        @Assert(n, 15)
        @Assert(hdr.version, VERSION_1)
        @Assert(hdr.destConnId.size, 4)
        @Assert(hdr.srcConnId.size, 4)
    }

    @TestCase
    public func testParseHeaderLongInvalidDestLen(): Unit {
        let data: Array<Byte> = [
            0xc0u8,
            0x00u8, 0x00u8, 0x00u8, 0x01u8,
            0xFFu8  // DCIL 过大
        ]
        let (hdr, n) = parseHeader(data)
        @Assert(n, 0)
    }

    @TestCase
    public func testParseHeaderLongMinimal(): Unit {
        // 零长度 DCID 和 SCID 的长包头
        let data: Array<Byte> = [
            0xc0u8,
            0x00u8, 0x00u8, 0x00u8, 0x01u8,
            0x00u8,  // DCIL = 0
            0x00u8,  // SCIL = 0
            0x00u8   // 负载起始位
        ]
        let (hdr, n) = parseHeader(data)
        @Assert(hdr.isLongHeader, true)
        @Assert(n, 7)
        @Assert(hdr.destConnId.size, 0)
        @Assert(hdr.srcConnId.size, 0)
    }
}
