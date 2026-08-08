package quic_cj.tests

import quic_cj.core.{DatagramQueue, newDatagramQueue}
import quic_cj.wire.DatagramFrame

@Test
public class DatagramQueueTestSuite {
    @TestCase
    public func testNewQueueEmpty(): Unit {
        let q = newDatagramQueue()
        @Assert(q.sendLen(), 0)
        @Assert(q.recvLen(), 0)
        @Assert(q.hasSendData(), false)
        @Assert(q.hasRecvData(), false)
    }

    @TestCase
    public func testSendAndPeekPop(): Unit {
        let q = newDatagramQueue()
        let dg = DatagramFrame()
        dg.data = [0x01u8, 0x02u8, 0x03u8]
        let ok = q.add(dg)
        @Assert(ok, true)
        @Assert(q.sendLen(), 1)
        @Assert(q.hasSendData(), true)
        if (let Some(peeked) <- q.peek()) {
            @Assert(peeked.data.size, 3)
            @Assert(peeked.data[0], 0x01u8)
            q.pop()
            @Assert(q.sendLen(), 0)
            @Assert(q.hasSendData(), false)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testReceive(): Unit {
        let q = newDatagramQueue()
        let ok = q.handleDatagramFrame([0x0au8, 0x0bu8])
        @Assert(ok, true)
        @Assert(q.recvLen(), 1)
        @Assert(q.hasRecvData(), true)
        if (let Some(data) <- q.receive()) {
            @Assert(data.size, 2)
            @Assert(data[0], 0x0au8)
            @Assert(q.recvLen(), 0)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testClose(): Unit {
        let q = newDatagramQueue()
        let dg = DatagramFrame()
        @Assert(q.add(dg), true)
        let noneClose = match (q.receive()) { case None => true; case _ => false }
        @Assert(noneClose, true)
    }

    @TestCase
    public func testReceiveEmptyOnClosed(): Unit {
        let q = newDatagramQueue()
        let noneClosed = match (q.receive()) { case None => true; case _ => false }
        @Assert(noneClosed, true)
    }

    @TestCase
    public func testPeekEmpty(): Unit {
        let q = newDatagramQueue()
        let nonePeek = match (q.peek()) { case None => true; case _ => false }
        @Assert(nonePeek, true)
    }

    @TestCase
    public func testReceiveEmpty(): Unit {
        let q = newDatagramQueue()
        let noneEmpty = match (q.receive()) { case None => true; case _ => false }
        @Assert(noneEmpty, true)
    }
}


@Test
public class DatagramQueueMaxPayloadTestSuite {
    @TestCase
    public func testMaxDatagramPayloadRejectsOversized(): Unit {
        let q = newDatagramQueue()
        q.setMaxDatagramPayload(10)
        let dg = DatagramFrame()
        dg.data = Array<Byte>(20, repeat: 0xabu8)
        let ok = q.add(dg)
        @Assert(ok, false)
        @Assert(q.sendLen(), 0)
    }

    @TestCase
    public func testMaxDatagramPayloadAcceptsWithinLimit(): Unit {
        let q = newDatagramQueue()
        q.setMaxDatagramPayload(10)
        let dg = DatagramFrame()
        dg.data = Array<Byte>(5, repeat: 0xabu8)
        let ok = q.add(dg)
        @Assert(ok, true)
        @Assert(q.sendLen(), 1)
    }

    @TestCase
    public func testEmptyDataNotQueued(): Unit {
        let q = newDatagramQueue()
        let dg = DatagramFrame()
        dg.data = []
        let ok = q.add(dg)
        @Assert(ok, true)
        @Assert(q.sendLen(), 0)
    }

    @TestCase
    public func testMaxDatagramPayloadZeroUsesDefault(): Unit {
        let q = newDatagramQueue()
        q.setMaxDatagramPayload(0)  // Should not decrease below default
        let dg = DatagramFrame()
        dg.data = Array<Byte>(50000, repeat: 0xabu8)  // 50000 < 65535
        let ok = q.add(dg)
        @Assert(ok, true)
        @Assert(q.sendLen(), 1)
    }
}
