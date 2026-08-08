package quic_cj.tests

import quic_cj.protocol.{VERSION_1, EncryptionLevel, Perspective}
import quic_cj.core.{PacketPacker, PacketUnpacker, newClientConnection, newServerConnection, ConnectionState}
import quic_cj.wire.{Frame, PingFrame, appendFrame}

@Test
public class IntegrationTestSuite {
    @TestCase
    public func testClientConnectionLifecycle(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let isInitial = match (conn.getState()) { case ConnectionState.Initial => true; case _ => false }
        @Assert(isInitial, true)
        conn.closeWithError(0u64, "normal close")
        let isClosing = match (conn.getState()) { case ConnectionState.Closing => true; case _ => false }
        @Assert(isClosing, true)
        conn.tick(3001)
        let isClosed = match (conn.getState()) { case ConnectionState.Closed => true; case _ => false }
        @Assert(isClosed, true)
    }

    @TestCase
    public func testServerConnectionLifecycle(): Unit {
        let conn = newServerConnection([0x05u8, 0x06u8])
        let isInitial = match (conn.getState()) { case ConnectionState.Initial => true; case _ => false }
        @Assert(isInitial, true)
        conn.closeWithError(1u64, "server close")
        let isClosing = match (conn.getState()) { case ConnectionState.Closing => true; case _ => false }
        @Assert(isClosing, true)
        conn.tick(5000)
        let isClosed = match (conn.getState()) { case ConnectionState.Closed => true; case _ => false }
        @Assert(isClosed, true)
    }

    @TestCase
    public func testPacketPackerRoundTrip(): Unit {
        let pp = PacketPacker(VERSION_1, [0x0au8, 0x0bu8], [0x0cu8, 0x0du8])
        let frames: Array<Frame> = [PingFrame()]
        let packet = pp.packShortHeaderPacket(frames, 1u8)
        @Assert(packet.size > 0, true)
        @Assert(Int64(packet[0]) & 0x40, 0x40)
    }

    @TestCase
    public func testPackerUnpackerRoundTrip(): Unit {
        let destId: Array<Byte> = [0x01u8, 0x02u8]
        let srcId: Array<Byte> = [0x03u8, 0x04u8]
        let pp = PacketPacker(VERSION_1, srcId, destId)
        let up = PacketUnpacker()
        let frames: Array<Frame> = [PingFrame()]
        let packet = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, 1u8)
        let result = up.unpackLongHeader(packet)
        @Assert(result.consumed > 0, true)
    }


    @TestCase
    public func testHandleEmptyPacket(): Unit {
        let conn = newClientConnection([0x01u8, 0x02u8], [0x03u8, 0x04u8])
        let response = conn.handlePacket([])
        @Assert(response.size, 0)
    }
}
