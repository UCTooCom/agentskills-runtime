package quic_cj.tests

import quic_cj.congestion.{CubicSender, newCubicSender, Pacer, bandwidthFromDelta, BYTES_PER_SECOND}

@Test
public class CongestionTestSuite {
    @TestCase
    public func testCubicSenderStartsInSlowStart(): Unit {
        let sender = newCubicSender()
        @Assert(sender.inSlowStart(), true)
        @Assert(sender.getCwnd() > 0, true)
    }

    @TestCase
    public func testCanSendWhenBelowWindow(): Unit {
        let sender = newCubicSender()
        @Assert(sender.canSend(100), true)  // 100 字节 < 拥塞窗口
    }

    @TestCase
    public func testCongestionEventReducesWindow(): Unit {
        let sender = newCubicSender()
        let before = sender.getCwnd()
        sender.onCongestionEvent(before / 3, before)
        let after = sender.getCwnd()
        @Assert(after < before, true)
        @Assert(sender.inRecovery(), true)
    }

    @TestCase
    public func testPacerInitialBudget(): Unit {
        let pacer = Pacer()
        pacer.setBandwidth(1000000u64)
        let budget = pacer.budget(0)
        @Assert(budget > 0, true)
    }

    @TestCase
    public func testBandwidthFromDelta(): Unit {
        let bw = bandwidthFromDelta(1000, 100000000)  // 1000 字节在 100 毫秒内
        @Assert(bw > 0u64, true)
    }

    @TestCase
    public func testCubicSenderRecoveryTransition(): Unit {
        let sender = newCubicSender()
        let before = sender.getCwnd()
        sender.onCongestionEvent(before / 3, before)
        @Assert(sender.inRecovery(), true)
        @Assert(sender.canSend(100), true)
    }

    @TestCase
    public func testCubicSenderMultipleCongestionEvents(): Unit {
        let sender = newCubicSender()
        let cwnd1 = sender.getCwnd()
        sender.onCongestionEvent(cwnd1 / 3, cwnd1)
        let cwnd2 = sender.getCwnd()
        @Assert(cwnd2 < cwnd1, true)
        sender.onCongestionEvent(cwnd2 / 3, cwnd2)
        let cwnd3 = sender.getCwnd()
        @Assert(cwnd3 < cwnd2, true)
    }
}


@Test
public class CongestionExtendedTestSuite {
    @TestCase
    public func testCubicSenderCwndMin(): Unit {
        let sender = newCubicSender()
        let cwnd = sender.getCwnd()
        @Assert(cwnd >= 2048, true)
    }

    @TestCase
    public func testCubicSenderCannotSendLarge(): Unit {
        let sender = newCubicSender()
        let tooLarge = sender.getCwnd() * 2
        @Assert(sender.canSend(tooLarge), false)
    }

    @TestCase
    public func testCubicSenderAckIncreasesCwnd(): Unit {
        let sender = newCubicSender()
        let before = sender.getCwnd()
        sender.onPacketAcked(1000, before * 2)
        let after = sender.getCwnd()
        @Assert(after > before, true)
    }

    @TestCase
    public func testCubicSenderEventsDuringRecovery(): Unit {
        let sender = newCubicSender()
        let cwnd = sender.getCwnd()
        sender.onCongestionEvent(cwnd / 3, cwnd)
        @Assert(sender.inRecovery(), true)
        let duringRecovery = sender.getCwnd()
        sender.onPacketAcked(1000, duringRecovery)
        let afterAck = sender.getCwnd()
        @Assert(afterAck, duringRecovery)
    }

    @TestCase
    public func testCubicSenderCongestionEvent(): Unit {
        let sender = newCubicSender()
        let before = sender.getCwnd()
        sender.onCongestionEvent(1000, before)
        let after = sender.getCwnd()
        @Assert(after < before, true)
    }

    @TestCase
    public func testCubicSenderSlowStartExit(): Unit {
        let sender = newCubicSender()
        @Assert(sender.inSlowStart(), true)
        // 足够的 ACK 退出慢启动
        var i: Int64 = 0
        let cwnd = sender.getCwnd()
        while (i < 100) {
            sender.onPacketAcked(cwnd / 100, cwnd)
            i += 1
        }
        @Assert(sender.inSlowStart(), false)
    }

    @TestCase
    public func testPacerBudgetWithTimePassage(): Unit {
        let pacer = Pacer()
        pacer.setBandwidth(2000000u64)
        let budget1 = pacer.budget(0)
        let budget2 = pacer.budget(50000)
        @Assert(budget2 >= budget1, true)
    }

    @TestCase
    public func testPacerSentPacket(): Unit {
        let pacer = Pacer()
        pacer.setBandwidth(1000000u64)
        pacer.sentPacket(0, 100)
        @Assert(true)  // 无崩溃
    }

    @TestCase
    public func testBandwidthFromDeltaZero(): Unit {
        let bw = bandwidthFromDelta(0, 100000000)
        @Assert(bw, 0u64)
    }

    @TestCase
    public func testBandwidthFromDeltaLarge(): Unit {
        let bw = bandwidthFromDelta(1000000, 100000000)
        @Assert(bw > 0u64, true)
    }

    @TestCase
    public func testCubicSenderOnPacketSent(): Unit {
        let sender = newCubicSender()
        sender.onPacketSent(0, 0, 100)
        @Assert(true)  // 无崩溃
    }
}
