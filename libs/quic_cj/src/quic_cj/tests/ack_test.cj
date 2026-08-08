package quic_cj.tests

import quic_cj.ack.{AckHandler, newAckHandler, SendMode, SentPacket}
import quic_cj.ack.{ReceivedPacketHistory, SequentialPacketNumberGenerator, ReceivedPacketTracker}
import quic_cj.ack.{LostPacketTracker, SentPacketHandler, newSentPacketHandler}
import quic_cj.protocol.{EncryptionLevel, ECN}
import quic_cj.congestion.CubicSender

@Test
public class AckTestSuite {
    @TestCase
    public func testNewAckHandler(): Unit {
        let h = newAckHandler()
        let modeAny = match (h.sendMode()) { case SendMode.Any => true; case _ => false }
        @Assert(modeAny, true)
        @Assert(h.getLossDetectionTimeout(), -1)
    }

    @TestCase
    public func testSentPacketDefaults(): Unit {
        let p = SentPacket()
        @Assert(p.packetNumber, 0)
        @Assert(p.outstanding(), false)
    }

    @TestCase
    public func testSequentialGenerator(): Unit {
        let gen = SequentialPacketNumberGenerator(0)
        @Assert(gen.peek(), 0)
        let (skipped, pn) = gen.pop()
        @Assert(skipped, false)
        @Assert(pn, 0)
        @Assert(gen.peek(), 1)
    }

    @TestCase
    public func testReceivedPacketHistoryBasics(): Unit {
        let hist = ReceivedPacketHistory()
        let isNew = hist.receivedPacket(5)
        @Assert(isNew, true)
        let isDup = hist.receivedPacket(5)
        @Assert(isDup, false)
    }

    @TestCase
    public func testReceivedPacketHistoryDeleteBelow(): Unit {
        let hist = ReceivedPacketHistory()
        hist.receivedPacket(1)
        hist.receivedPacket(2)
        hist.receivedPacket(5)
        hist.deleteBelow(3)
        let isPotDup = hist.isPotentiallyDuplicate(1)
        @Assert(isPotDup, true)  // 删除 3 以下
        let notDup = hist.isPotentiallyDuplicate(4)
        @Assert(notDup, false)   // 不在范围内
    }

    @TestCase
    public func testReceivedPacketTracker(): Unit {
        let tracker = ReceivedPacketTracker()
        tracker.receivedPacket(1, ECN.Non, true)
        if (let Some(ack) <- tracker.getAckFrame()) {
            @Assert(ack.largestAcked, 1)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testSentPacketHandler(): Unit {
        let handler = newSentPacketHandler()
        let modeAny2 = match (handler.sendMode()) { case SendMode.Any => true; case _ => false }
        @Assert(modeAny2, true)
    }

    @TestCase
    public func testLostPacketTracker(): Unit {
        let cc = CubicSender()
        let tracker = LostPacketTracker(cc)
        tracker.onPacketLost(1, 100, 1000)
        let lost = tracker.getLostPackets()
        @Assert(lost.size, 1)
        @Assert(lost[0], 1)
    }

    @TestCase
    public func testLostPacketTrackerMultiple(): Unit {
        let cc = CubicSender()
        let tracker = LostPacketTracker(cc)
        tracker.onPacketLost(1, 100, 1000)
        tracker.onPacketLost(3, 200, 2000)
        let lost = tracker.getLostPackets()
        @Assert(lost.size, 2)
        @Assert(lost[0], 1)
        @Assert(lost[1], 3)
    }

    @TestCase
    public func testReceivedPacketHistoryRangeMerging(): Unit {
        let hist = ReceivedPacketHistory()
        hist.receivedPacket(1)
        hist.receivedPacket(2)
        hist.receivedPacket(3)
        hist.receivedPacket(5)
        hist.receivedPacket(6)
        let ranges = hist.backwardGetRanges()
        @Assert(ranges.size, 2)
    }

    @TestCase
    public func testReceivedPacketHistoryDeleteMultiple(): Unit {
        let hist = ReceivedPacketHistory()
        hist.receivedPacket(1)
        hist.receivedPacket(2)
        hist.receivedPacket(5)
        hist.receivedPacket(10)
        hist.deleteBelow(8)
        @Assert(hist.isPotentiallyDuplicate(5), true)
        @Assert(hist.isPotentiallyDuplicate(9), false)
    }

}
