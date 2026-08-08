package quic_cj.tests

import quic_cj.protocol.{VERSION_1, VERSION_2, VERSION_DRAFT_29, VERSION_UNKNOWN, isValidVersion, chooseSupportedVersion}
import quic_cj.protocol.{generateConnectionId, isValidConnectionIdLen, MAX_CONN_ID_LEN}
import quic_cj.protocol.{StreamType, Perspective, streamNumToStreamId, streamInitiatedBy, streamType, streamNum,
    INVALID_STREAM_ID, FIRST_OUTGOING_BIDI_STREAM_CLIENT, FIRST_OUTGOING_BIDI_STREAM_SERVER,
    FIRST_OUTGOING_UNI_STREAM_CLIENT, FIRST_OUTGOING_UNI_STREAM_SERVER}
import quic_cj.protocol.{decodePacketNumber, packetNumberLengthForHeader, INVALID_PACKET_NUMBER,
    PACKET_NUMBER_LEN_1, PACKET_NUMBER_LEN_2, PACKET_NUMBER_LEN_3, PACKET_NUMBER_LEN_4}
import quic_cj.protocol.{PacketType, packetTypeToWire, packetTypeFromWire}
import quic_cj.protocol.{EncryptionLevel}
import quic_cj.protocol.{ECN}
import quic_cj.protocol.{keyPhaseBit, KeyPhaseBit}
import quic_cj.protocol.{oppositePerspective}

@Test
public class ProtocolVersionTestSuite {
    @TestCase
    public func testValidVersions(): Unit {
        @Assert(isValidVersion(VERSION_1), true)
        @Assert(isValidVersion(VERSION_2), true)
        @Assert(isValidVersion(VERSION_DRAFT_29), false)
        @Assert(isValidVersion(VERSION_UNKNOWN), false)
    }

    @TestCase
    public func testChooseSupportedVersionSame(): Unit {
        let ours: Array<UInt32> = [VERSION_1, VERSION_2]
        let theirs: Array<UInt32> = [VERSION_1]
        if (let Some(v) <- chooseSupportedVersion(ours, theirs)) {
            @Assert(v, VERSION_1)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testChooseSupportedVersionFallback(): Unit {
        let ours: Array<UInt32> = [VERSION_1]
        let theirs: Array<UInt32> = [VERSION_2, VERSION_1]
        if (let Some(v) <- chooseSupportedVersion(ours, theirs)) {
            @Assert(v, VERSION_1)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testChooseSupportedVersionNone(): Unit {
        let ours: Array<UInt32> = [VERSION_1]
        let theirs: Array<UInt32> = [VERSION_DRAFT_29]
        let none1 = match (chooseSupportedVersion(ours, theirs)) { case None => true; case _ => false }
        @Assert(none1, true)
    }

    @TestCase
    public func testChooseSupportedVersionEmptyOurs(): Unit {
        let none2 = match (chooseSupportedVersion([], [VERSION_1])) { case None => true; case _ => false }
        @Assert(none2, true)
    }

    @TestCase
    public func testChooseSupportedVersionEmptyTheirs(): Unit {
        let none3 = match (chooseSupportedVersion([VERSION_1], [])) { case None => true; case _ => false }
        @Assert(none3, true)
    }
}

@Test
public class ProtocolStreamIdTestSuite {
    @TestCase
    public func testStreamNumToIdClientBidi(): Unit {
        let id = streamNumToStreamId(1, StreamType.Bidi, Perspective.Client)
        @Assert(id, FIRST_OUTGOING_BIDI_STREAM_CLIENT)
        let id2 = streamNumToStreamId(2, StreamType.Bidi, Perspective.Client)
        @Assert(id2, 4)
    }

    @TestCase
    public func testStreamNumToIdServerUni(): Unit {
        let id = streamNumToStreamId(1, StreamType.Uni, Perspective.Server)
        @Assert(id, FIRST_OUTGOING_UNI_STREAM_SERVER)
    }

    @TestCase
    public func testStreamNumZeroReturnsInvalid(): Unit {
        let id = streamNumToStreamId(0, StreamType.Bidi, Perspective.Client)
        @Assert(id, INVALID_STREAM_ID)
    }

    @TestCase
    public func testStreamInitiatedByClient(): Unit {
        let isClient = match (streamInitiatedBy(0)) { case Perspective.Client => true; case _ => false }
        @Assert(isClient, true)
        let isServer = match (streamInitiatedBy(1)) { case Perspective.Server => true; case _ => false }
        @Assert(isServer, true)
    }

    @TestCase
    public func testStreamTypeBidi(): Unit {
        let isBidi = match (streamType(0)) { case StreamType.Bidi => true; case _ => false }
        @Assert(isBidi, true)
        let isBidi2 = match (streamType(1)) { case StreamType.Bidi => true; case _ => false }
        @Assert(isBidi2, true)
    }

    @TestCase
    public func testStreamTypeUni(): Unit {
        let isUni = match (streamType(2)) { case StreamType.Uni => true; case _ => false }
        @Assert(isUni, true)
        let isUni2 = match (streamType(3)) { case StreamType.Uni => true; case _ => false }
        @Assert(isUni2, true)
    }

    @TestCase
    public func testStreamNum(): Unit {
        @Assert(streamNum(0), 1)
        @Assert(streamNum(3), 1)
        @Assert(streamNum(4), 2)
        @Assert(streamNum(7), 2)
    }
}

@Test
public class ProtocolConnectionIdTestSuite {
    @TestCase
    public func testGenerateConnIdSize(): Unit {
        let cid = generateConnectionId(8)
        @Assert(cid.size, 8)
    }

    @TestCase
    public func testGenerateConnIdZero(): Unit {
        let cid = generateConnectionId(0)
        @Assert(cid.size, 0)
    }

    @TestCase
    public func testGenerateConnIdMax(): Unit {
        let cid = generateConnectionId(MAX_CONN_ID_LEN)
        @Assert(cid.size, MAX_CONN_ID_LEN)
    }

    @TestCase
    public func testIsValidConnIdLen(): Unit {
        @Assert(isValidConnectionIdLen(0), true)
        @Assert(isValidConnectionIdLen(8), true)
        @Assert(isValidConnectionIdLen(MAX_CONN_ID_LEN), true)
        @Assert(isValidConnectionIdLen(MAX_CONN_ID_LEN + 1), false)
        @Assert(isValidConnectionIdLen(-1), false)
    }

    @TestCase
    public func testGenerateConnectionIdLengths(): Unit {
        let len0 = generateConnectionId(0)
        @Assert(len0.size, 0)
        let len4 = generateConnectionId(4)
        @Assert(len4.size, 4)
        let len8 = generateConnectionId(8)
        @Assert(len8.size, 8)
        let len20 = generateConnectionId(MAX_CONN_ID_LEN)
        @Assert(len20.size, MAX_CONN_ID_LEN)
    }
}

@Test
public class ProtocolPacketNumberTestSuite {
    @TestCase
    public func testDecodePacketNumberTrivial(): Unit {
        let pn = decodePacketNumber(PACKET_NUMBER_LEN_1, 0, 0)
        @Assert(pn, 0)
    }

    @TestCase
    public func testDecodePacketNumberSimple(): Unit {
        let pn = decodePacketNumber(PACKET_NUMBER_LEN_1, 0, 1)
        @Assert(pn, 1)
    }

    @TestCase
    public func testPacketNumberLengthForHeaderBase(): Unit {
        let len0 = packetNumberLengthForHeader(0, INVALID_PACKET_NUMBER)
        // RFC 9000 §17.1: num_unacked = 1 (< 128) → 1 byte
        @Assert(len0, PACKET_NUMBER_LEN_1)
        let lenLarge = packetNumberLengthForHeader(100000, INVALID_PACKET_NUMBER)
        // RFC 9000 §17.1: num_unacked = 100001 (≥ 32768, < 8388608) → 3 bytes
        @Assert(lenLarge, PACKET_NUMBER_LEN_3)
    }

    @TestCase
    public func testPacketNumberLengthForHeaderWithAcked(): Unit {
        let lenSmall = packetNumberLengthForHeader(100, 50)
        // RFC 9000 §17.1: num_unacked = 50 (< 128) → 1 byte
        @Assert(lenSmall, PACKET_NUMBER_LEN_1)
    }

    @TestCase
    public func testDecodePacketNumberLen1(): Unit {
        let pn = decodePacketNumber(PACKET_NUMBER_LEN_1, 255, 0)
        @Assert(pn >= 0, true)
    }

    @TestCase
    public func testDecodePacketNumberLen4(): Unit {
        let pn = decodePacketNumber(PACKET_NUMBER_LEN_4, 1000000, 12345)
        @Assert(pn >= 0, true)
    }

    @TestCase
    public func testDecodePacketNumberWrapping(): Unit {
        let pnWrap = decodePacketNumber(PACKET_NUMBER_LEN_1, 255, 0)
        @Assert(pnWrap, 256)
        let pnSame = decodePacketNumber(PACKET_NUMBER_LEN_1, 0, 0)
        @Assert(pnSame, 0)
        let pnLarge = decodePacketNumber(PACKET_NUMBER_LEN_4, 1000000, 12345)
        @Assert(pnLarge >= 0, true)
    }

    @TestCase
    public func testPacketNumberLengthHeaderLargeAcked(): Unit {
        let len1 = packetNumberLengthForHeader(0, INVALID_PACKET_NUMBER)
        @Assert(len1, PACKET_NUMBER_LEN_1)
        let lenLarge = packetNumberLengthForHeader(100000, INVALID_PACKET_NUMBER)
        @Assert(lenLarge, PACKET_NUMBER_LEN_3)
    }
}

@Test
public class ProtocolPacketTypeTestSuite {
    @TestCase
    public func testPacketTypeRoundTrip(): Unit {
        let types: Array<PacketType> = [PacketType.Initial, PacketType.Retry, PacketType.Handshake, PacketType.ZeroRTT]
        var i: Int64 = 0
        while (i < types.size) {
            let wire = packetTypeToWire(types[i])
            let back = packetTypeFromWire(wire)
            let origOrd = match (types[i]) {
                case PacketType.Initial => 0; case PacketType.Retry => 1
                case PacketType.Handshake => 2; case PacketType.ZeroRTT => 3
            }
            let decodedOrd = match (back) {
                case PacketType.Initial => 0; case PacketType.Retry => 1
                case PacketType.Handshake => 2; case PacketType.ZeroRTT => 3
            }
            @Assert(origOrd, decodedOrd)
            i += 1
        }
    }

    @TestCase
    public func testPacketTypeFromWireUnknown(): Unit {
        let pt = packetTypeFromWire(0xffu8)
        let isInitial = match (pt) { case PacketType.Initial => true; case _ => false }
        @Assert(isInitial, true)
    }
}

@Test
public class ProtocolPerspectiveTestSuite {
    @TestCase
    public func testOppositePerspective(): Unit {
        let isServer = match (oppositePerspective(Perspective.Client)) { case Perspective.Server => true; case _ => false }
        @Assert(isServer, true)
        let isClient = match (oppositePerspective(Perspective.Server)) { case Perspective.Client => true; case _ => false }
        @Assert(isClient, true)
    }
}

@Test
public class ProtocolEncryptionLevelTestSuite {
    @TestCase
    public func testEncryptionLevelValues(): Unit {
        let levels: Array<EncryptionLevel> = [EncryptionLevel.Initial, EncryptionLevel.Handshake, EncryptionLevel.ZeroRTT, EncryptionLevel.OneRTT]
        @Assert(levels.size, 4)
    }
}

@Test
public class ProtocolEcnTestSuite {
    @TestCase
    public func testEcnValues(): Unit {
        let ecns: Array<ECN> = [ECN.Unsupported, ECN.Non, ECN.ECT1, ECN.ECT0, ECN.CE]
        @Assert(ecns.size, 5)
    }
}

@Test
public class ProtocolKeyPhaseTestSuite {
    @TestCase
    public func testKeyPhaseBitEvenZero(): Unit {
        let zero = match (keyPhaseBit(0)) { case KeyPhaseBit.Zero => true; case _ => false }
        @Assert(zero, true)
        let zero2 = match (keyPhaseBit(2)) { case KeyPhaseBit.Zero => true; case _ => false }
        @Assert(zero2, true)
    }

    @TestCase
    public func testKeyPhaseBitOddOne(): Unit {
        let one = match (keyPhaseBit(1)) { case KeyPhaseBit.One => true; case _ => false }
        @Assert(one, true)
        let one2 = match (keyPhaseBit(3)) { case KeyPhaseBit.One => true; case _ => false }
        @Assert(one2, true)
    }
}
