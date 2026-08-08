package quic_cj.tests

import quic_cj.wire.{composeVersionNegotiation, parseVersionNegotiationPacket, isVersionNegotiationPacket}
import quic_cj.protocol.{VERSION_1, VERSION_2}

@Test
public class VersionNegotiationTestSuite {
    @TestCase
    public func testComposeAndParseRoundTrip(): Unit {
        let destId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let srcId: Array<Byte> = [0x05u8, 0x06u8, 0x07u8, 0x08u8]
        let versions: Array<UInt32> = [VERSION_1, VERSION_2]
        let packet = composeVersionNegotiation(destId, srcId, versions)
        @Assert(packet.size > 0, true)
        // 验证首字节有 QUIC 位
        @Assert((UInt8(packet[0]) & 0xc0u8), 0xc0u8)
        // 验证版本字段为 0
        @Assert(UInt8(packet[1]), 0u8)
        @Assert(UInt8(packet[2]), 0u8)
        @Assert(UInt8(packet[3]), 0u8)
        @Assert(UInt8(packet[4]), 0u8)
        // 反向解析
        if (let Some((parsedDest, parsedSrc, parsedVersions)) <- parseVersionNegotiationPacket(packet)) {
            @Assert(parsedDest, destId)
            @Assert(parsedSrc, srcId)
            @Assert(parsedVersions.size, 2)
            @Assert(parsedVersions[0], VERSION_1)
            @Assert(parsedVersions[1], VERSION_2)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testIsVersionNegotiationPacket(): Unit {
        let packet = composeVersionNegotiation([0x01u8], [0x02u8], [VERSION_1])
        @Assert(isVersionNegotiationPacket(packet), true)
        // 普通初始包不是 VN
        let notVn: Array<Byte> = [0xc0u8, 0x00u8, 0x00u8, 0x00u8, 0x01u8]
        @Assert(isVersionNegotiationPacket(notVn), false)
    }

    @TestCase
    public func testParseInvalidShortPacket(): Unit {
        let none = match (parseVersionNegotiationPacket([0xffu8])) { case None => true; case _ => false }
        @Assert(none, true)
    }
}
