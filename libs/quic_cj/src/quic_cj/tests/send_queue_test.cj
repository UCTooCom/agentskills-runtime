package quic_cj.tests

import quic_cj.core.{SendQueue, newSendQueue}
import quic_cj.protocol.ECN
import quic_cj.wire.PacketBuffer

@Test
public class SendQueueTestSuite {
    @TestCase
    public func testNewQueueEmpty(): Unit {
        let sq = newSendQueue()
        @Assert(sq.len(), 0)
        @Assert(sq.isClosed(), false)
        @Assert(sq.available(), true)
    }

    @TestCase
    public func testSendAndLen(): Unit {
        let sq = newSendQueue()
        let buf = PacketBuffer(100)
        let ok = sq.send(buf, 0u16, ECN.Unsupported)
        @Assert(ok, true)
        @Assert(sq.len(), 1)
    }

    @TestCase
    public func testWouldBlockWhenFull(): Unit {
        let sq = newSendQueue()
        var i: Int64 = 0
        while (i < 8) {
            let buf = PacketBuffer(100)
            sq.send(buf, 0u16, ECN.Unsupported)
            i += 1
        }
        @Assert(sq.wouldBlock(), true)
        @Assert(sq.available(), false)
    }

    @TestCase
    public func testCloseDrainsQueue(): Unit {
        let sq = newSendQueue()
        var i: Int64 = 0
        while (i < 3) {
            let buf = PacketBuffer(50)
            sq.send(buf, 0u16, ECN.Unsupported)
            i += 1
        }
        @Assert(sq.len(), 3)
        sq.close()
        @Assert(sq.isClosed(), true)
        @Assert(sq.len(), 0)
    }

    @TestCase
    public func testCloseOnceOnly(): Unit {
        let sq = newSendQueue()
        sq.close()
        @Assert(sq.isClosed(), true)
        let buf = PacketBuffer(10)
        let ok = sq.send(buf, 0u16, ECN.Unsupported)
        @Assert(ok, true)
    }

    @TestCase
    public func testAvailableAfterSend(): Unit {
        let sq = newSendQueue()
        @Assert(sq.available(), true)
        var i: Int64 = 0
        while (i < 8) {
            let buf = PacketBuffer(10)
            sq.send(buf, 0u16, ECN.Unsupported)
            i += 1
        }
        @Assert(sq.available(), false)
    }
}
