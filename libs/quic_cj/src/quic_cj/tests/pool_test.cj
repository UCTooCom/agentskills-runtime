package quic_cj.tests

import quic_cj.wire.{getPacketBuffer, getLargePacketBuffer, getStreamBuf, putStreamBuf}
import quic_cj.protocol.MAX_PACKET_BUFFER_SIZE

@Test
public class PoolTestSuite {
    @TestCase
    public func testGetPacketBuffer(): Unit {
        let buf = getPacketBuffer()
        @Assert(buf.data.size, 0)
    }

    @TestCase
    public func testGetLargePacketBuffer(): Unit {
        let buf = getLargePacketBuffer()
        @Assert(buf.data.size, 0)
    }

    @TestCase
    public func testGetStreamBufEmpty(): Unit {
        let buf = getStreamBuf(128)
        @Assert(buf.size, 128)
    }

    @TestCase
    public func testStreamBufRoundTrip(): Unit {
        let buf = Array<Byte>(100, repeat: 0x42u8)
        putStreamBuf(buf)
        let recycled = getStreamBuf(100)
        @Assert(recycled.size, 100)
    }

    @TestCase
    public func testRefCountLifecycle(): Unit {
        let buf = getPacketBuffer()
        buf.split()
        buf.split()
        buf.decrement()
        @Assert(buf.getRefCount(), 2)
        buf.decrement()
        @Assert(buf.getRefCount(), 1)
    }
}
