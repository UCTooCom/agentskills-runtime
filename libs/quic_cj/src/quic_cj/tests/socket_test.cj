package quic_cj.tests

import quic_cj.sys.{linuxCreateUdpSocket, linuxWriteToFd, RawConn, StubRawConn, newRawConn, ConnCapabilities, ReceivedPacket}
import quic_cj.protocol.ECN
import std.net.IPAddress

@Test
public class SocketTestSuite {
    @TestCase
    public func testStubRawConn(): Unit {
        let conn = StubRawConn("127.0.0.1", 12345)
        @Assert(conn.localAddr().toString(), "127.0.0.1")
        let caps = conn.capabilities()
        @Assert(caps.df, false)
        @Assert(caps.ecn, false)
        @Assert(caps.gso, false)
    }

    @TestCase
    public func testNewRawConn(): Unit {
        let conn = newRawConn("0.0.0.0", 0)
        @Assert(conn.localAddr().toString(), "0.0.0.0")
    }

    @TestCase
    public func testConnCapabilitiesDefaults(): Unit {
        let caps = ConnCapabilities()
        @Assert(caps.df, false)
        @Assert(caps.ecn, false)
        @Assert(caps.gso, false)
    }

    @TestCase
    public func testReceivedPacketDefaults(): Unit {
        let pkt = ReceivedPacket()
        @Assert(pkt.data.size, 0)
        @Assert(pkt.remoteAddr, "")
        // ECN 枚举无法通过 @Assert 比较，跳过
    }

    @TestCase
    public func testLinuxUdpInterop(): Unit {
        let fd = linuxCreateUdpSocket(0)
        if (fd < 0) { @Assert(false, true); return }
        let addr: Array<Byte> = Array<Byte>(16, repeat: 0u8)
        addr[0] = 0x02u8; addr[1] = 0x00u8
        addr[2] = 0x48u8; addr[3] = 0x0Cu8
        addr[4] = 0x7Fu8; addr[5] = 0x00u8; addr[6] = 0x00u8; addr[7] = 0x01u8
        let data: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        let n = linuxWriteToFd(fd, data, addr)
        @Assert(n > 0, true)
    }

}
