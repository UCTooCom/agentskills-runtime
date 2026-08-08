package quic_cj.tests

import quic_cj.{Config, defaultConfig, QError, Transport, Conn, Listener, HandlerFunc, newTransportError}
import quic_cj.protocol.{EncryptionLevel, VERSION_1}
import quic_cj.core.PacketPacker
import quic_cj.wire.{Frame, PingFrame}
import quic_cj.util.{NO_ERROR, PROTOCOL_VIOLATION}
import std.net.IPv4Address

@Test
public class ApiTestSuite {
    @TestCase
    public func testDefaultConfig(): Unit {
        let cfg = defaultConfig()
        let ok = cfg.validate()
        @Assert(ok, true)
        @Assert(cfg.maxIncomingStreams > 0, true)
    }

    @TestCase
    public func testQErrorTransport(): Unit {
        let err = newTransportError(PROTOCOL_VIOLATION, "test error")
        @Assert(err.isTransport, true)
    }

    @TestCase
    public func testTransportCreation(): Unit {
        let cfg = defaultConfig()
        let t = Transport("127.0.0.1:0", cfg)
        if (let Some(_) <- t.listen()) {
            @Assert(true, true)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testTransportPacketDemux(): Unit {
        let cfg = defaultConfig()
        let t = Transport("127.0.0.1:0", cfg)
        let connId: Array<Byte> = [0x01u8, 0x02u8]
        let handler: HandlerFunc = { d, a, ts => () }
        let ok = t.setHandler(connId, handler)
        @Assert(ok, true)

        let pp = PacketPacker(VERSION_1, [0x03u8, 0x04u8], connId)
        let frames: Array<Frame> = [PingFrame()]
        let packet = pp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, 1u8)
        t.handleReceivedPacket(packet, "127.0.0.1:12345", 0)

        let unknownId: Array<Byte> = [0xffu8, 0xfeu8]
        let unknownPp = PacketPacker(VERSION_1, [0xfdu8, 0xfcu8], unknownId)
        let unknownPacket = unknownPp.packLongHeaderPacket(2u8, EncryptionLevel.Handshake, frames, 1u8)
        t.handleReceivedPacket(unknownPacket, "127.0.0.1:12345", 0)
    }

    @TestCase
    public func testTransportLocalAddr(): Unit {
        let cfg = defaultConfig()
        let t = Transport("127.0.0.1:0", cfg)
        if (let Some(_) <- t.listen()) {
            let addr = t.localAddr()
            @Assert(addr != IPv4Address.unspecified, true)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testTransportIsInitialized(): Unit {
        let cfg = defaultConfig()
        let t = Transport("127.0.0.1:0", cfg)
        @Assert(t.isInitialized(), false)
        if (let Some(_) <- t.listen()) {
            @Assert(t.isInitialized(), true)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testTransportHandleEmptyPacket(): Unit {
        let cfg = defaultConfig()
        let t = Transport("127.0.0.1:0", cfg)
        if (let Some(_) <- t.listen()) {
            t.handleReceivedPacket([], "127.0.0.1:12345", 0)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testTransportHandleShortPacketNoHandler(): Unit {
        let cfg = defaultConfig()
        let t = Transport("127.0.0.1:0", cfg)
        if (let Some(_) <- t.listen()) {
            let unknownId: Array<Byte> = [0xffu8]
            let connId: Array<Byte> = [0x01u8, 0x02u8]
            let handler: HandlerFunc = { d, a, ts => () }
            let ok2 = t.setHandler(connId, handler)
            @Assert(ok2, true)
            t.handleReceivedPacket(unknownId, "127.0.0.1:12345", 0)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testConfigValidation(): Unit {
        let cfg = defaultConfig()
        @Assert(cfg.validate(), true)
        cfg.versions = []
        @Assert(cfg.validate(), false)
    }
}
