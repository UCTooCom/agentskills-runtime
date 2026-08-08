package quic_cj.tests

import quic_cj.core.{MtuFinder, newMtuFinder}
import quic_cj.util.RTTStats
import quic_cj.core.{MAX_MTU_DIFF}

@Test
public class MtuDiscovererTestSuite {
    @TestCase
    public func testNewFinderDefaults(): Unit {
        let rtt = RTTStats()
        let finder = newMtuFinder(rtt, 1200, 1500)
        @Assert(finder.currentSize(), 1200)
        @Assert(finder.done(), false)
    }

    @TestCase
    public func testNotStartedShouldNotSendProbe(): Unit {
        let rtt = RTTStats()
        let finder = newMtuFinder(rtt, 1200, 1500)
        @Assert(finder.shouldSendProbe(1_000_000_000), false)
    }

    @TestCase
    public func testProbeAfterStart(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(500, 0)
        let finder = newMtuFinder(rtt, 1200, 1500)
        finder.start(0)
        // delay = MTU_PROBE_DELAY(5) * smoothedRtt(500) = 2500
        @Assert(finder.shouldSendProbe(2500), true)
    }

    @TestCase
    public func testProbeTooEarly(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(500, 0)
        let finder = newMtuFinder(rtt, 1200, 1500)
        finder.start(0)
        // 0 < 0 + 2500
        @Assert(finder.shouldSendProbe(0), false)
    }

    @TestCase
    public func testProbeSizeBetweenBounds(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(500, 0)
        let finder = newMtuFinder(rtt, 1200, 1500)
        finder.start(0)
        let size = finder.getProbeSize(2500)
        // binary search: (1200 + 1500) / 2 = 1350
        // constrained to >= min + MAX_MTU_DIFF = 1220
        @Assert(size >= 1220, true)
        @Assert(size <= 1500, true)
    }

    @TestCase
    public func testAckedUpdatesCurrentSize(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(500, 0)
        let finder = newMtuFinder(rtt, 1200, 1500)
        finder.start(0)
        let size = finder.getProbeSize(2500)
        finder.onAcked(size)
        @Assert(finder.currentSize(), size)
    }

    @TestCase
    public func testLostReducesProbeSize(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(500, 0)
        let finder = newMtuFinder(rtt, 1200, 1500)
        finder.start(0)
        let firstSize = finder.getProbeSize(2500)
        finder.onLost()
        let secondSize = finder.getProbeSize(5000)
        @Assert(secondSize < firstSize, true)
    }

    @TestCase
    public func testDoneWhenRangeSmall(): Unit {
        let rtt = RTTStats()
        let finder = newMtuFinder(rtt, 1200, 1221)
        @Assert(finder.done(), true)
    }

    @TestCase
    public func testResetRestoresDefaults(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(500, 0)
        let finder = newMtuFinder(rtt, 1250, 1500)
        finder.start(0)
        let size = finder.getProbeSize(2500)
        finder.onAcked(size)
        finder.reset(0, 1200, 1500)
        @Assert(finder.currentSize(), 1200)
        @Assert(finder.done(), false)
    }

    @TestCase
    public func testStartedDoesNotSendProbeWhileInFlight(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(500, 0)
        let finder = newMtuFinder(rtt, 1200, 1500)
        finder.start(0)
        let _ = finder.getProbeSize(2500)  // sets inFlightSize
        // should not send another probe while one is in flight
        @Assert(finder.shouldSendProbe(100000), false)
    }

    @TestCase
    public func testClearInFlight(): Unit {
        let rtt = RTTStats()
        rtt.updateRtt(500, 0)
        let finder = newMtuFinder(rtt, 1200, 1500)
        finder.start(0)
        let _ = finder.getProbeSize(2500)
        finder.clearInFlight()
        @Assert(finder.shouldSendProbe(100000), true)
    }
}
