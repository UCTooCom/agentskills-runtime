package quic_cj.tests

import quic_cj.flow.{StreamFlowController, ConnectionFlowController}

@Test
public class FlowTestSuite {
    @TestCase
    public func testStreamFlowControllerInit(): Unit {
        let fc = StreamFlowController(0)
        @Assert(fc.sendWindowSize() > 0, true)
        @Assert(fc.isBlocked(), false)
    }

    @TestCase
    public func testStreamFlowControllerSendWindow(): Unit {
        let fc = StreamFlowController(4)
        fc.addBytesSent(100)
        @Assert(fc.sendWindowSize() > 0, true)
    }

    @TestCase
    public func testStreamFlowControllerUpdateSendWindow(): Unit {
        let fc = StreamFlowController(0)
        let initialWindow = fc.sendWindowSize()
        fc.addBytesSent(initialWindow)  // 耗尽发送窗口
        @Assert(fc.isBlocked(), true)
        fc.updateSendWindow(1000000)  // 对端提高限制
        @Assert(fc.isBlocked(), false)
        @Assert(fc.sendWindowSize(), 1000000 - initialWindow)
    }

    @TestCase
    public func testConnectionFlowControllerInit(): Unit {
        let fc = ConnectionFlowController()
        @Assert(fc.getReceiveWindow() > 0, true)
    }

    @TestCase
    public func testConnectionFlowControllerWindowUpdate(): Unit {
        let fc = ConnectionFlowController()
        @Assert(fc.hasWindowUpdate(), false)
        fc.addBytesRead(200000)
        @Assert(fc.hasWindowUpdate(), true)
    }

    @TestCase
    public func testStreamFlowControllerBlocked(): Unit {
        let fc = StreamFlowController(4)
        fc.updateSendWindow(500000)
        fc.addBytesSent(300000)
        @Assert(fc.isBlocked(), false)
        fc.addBytesSent(250000)
        @Assert(fc.isBlocked(), true)
    }

    @TestCase
    public func testStreamFlowControllerWindowGrowth(): Unit {
        let fc = StreamFlowController(8)
        fc.updateSendWindow(500000)
        @Assert(fc.sendWindowSize(), 500000)
        fc.addBytesSent(100000)
        @Assert(fc.sendWindowSize(), 400000)
        fc.updateSendWindow(600000)
        @Assert(fc.sendWindowSize(), 500000)
    }

}


@Test
public class FlowExtendedTestSuite {
    @TestCase
    public func testStreamFlowControllerExhaustWindow(): Unit {
        let fc = StreamFlowController(0)
        let initialWindow = fc.sendWindowSize()
        fc.addBytesSent(initialWindow)
        @Assert(fc.sendWindowSize(), 0)
        @Assert(fc.isBlocked(), true)
    }

    @TestCase
    public func testStreamFlowControllerPartialBlocked(): Unit {
        let fc = StreamFlowController(4)
        let initialWindow = fc.sendWindowSize()
        fc.addBytesSent(initialWindow / 2)
        @Assert(fc.isBlocked(), false)
        fc.addBytesSent(initialWindow / 2 + 1)
        @Assert(fc.isBlocked(), true)
    }

    @TestCase
    public func testStreamFlowControllerUpdateIncreasesWindow(): Unit {
        let fc = StreamFlowController(4)
        let initialWindow = fc.sendWindowSize()
        let newWindow = initialWindow * 2
        fc.updateSendWindow(newWindow)
        @Assert(fc.sendWindowSize(), newWindow)
    }

    @TestCase
    public func testStreamFlowControllerSmallerUpdateIgnored(): Unit {
        let fc = StreamFlowController(0)
        let initialWindow = fc.sendWindowSize()
        fc.updateSendWindow(100)  // 小于初始值，应被忽略
        @Assert(fc.sendWindowSize(), initialWindow)
    }

    @TestCase
    public func testConnectionFlowControllerWindowGrowth(): Unit {
        let fc = ConnectionFlowController()
        fc.addBytesRead(1000)
        fc.addBytesRead(2000)
        @Assert(fc.getBytesRead(), 3000)
    }

    @TestCase
    public func testConnectionFlowControllerWindowUpdateTrigger(): Unit {
        let fc = ConnectionFlowController()
        fc.addBytesRead(200000)
        @Assert(fc.hasWindowUpdate(), true)
    }

    @TestCase
    public func testConnectionFlowControllerNoUpdateInitially(): Unit {
        let fc = ConnectionFlowController()
        @Assert(fc.hasWindowUpdate(), false)
    }

    @TestCase
    public func testStreamFlowControllerSentExceedsWindow(): Unit {
        let fc = StreamFlowController(0)
        let initialWindow = fc.sendWindowSize()
        fc.addBytesSent(initialWindow + 100)
        @Assert(fc.sendWindowSize(), 0)
        @Assert(fc.isBlocked(), true)
    }
}

@Test
public class FlowEdgeCaseTestSuite {
    @TestCase
    public func testTryAddBytesSentWhenBlocked(): Unit {
        let fc = StreamFlowController(0)
        let initialWindow = fc.sendWindowSize()
        // 先耗尽窗口
        let added = fc.tryAddBytesSent(initialWindow)
        @Assert(added, true)
        // 再尝试发送更多，应返回 false
        let added2 = fc.tryAddBytesSent(100)
        @Assert(added2, false)
    }

    @TestCase
    public func testIsNewlyBlocked(): Unit {
        let fc = StreamFlowController(0)
        let initialWindow = fc.sendWindowSize()
        @Assert(fc.isNewlyBlocked(), false)
        fc.addBytesSent(initialWindow)
        @Assert(fc.isBlocked(), true)
        @Assert(fc.isNewlyBlocked(), true)
        // 再次检查应返回 false（已消费）
        @Assert(fc.isNewlyBlocked(), false)
    }

    @TestCase
    public func testAbandon(): Unit {
        let fc = StreamFlowController(0)
        
        fc.addBytesSent(100)
        @Assert(fc.getBytesSent(), 100)
        fc.abandon()
        @Assert(fc.getBytesSent(), 100)
    }

    @TestCase
    public func testAbandonWithReceivedData(): Unit {
        let fc = StreamFlowController(0)
        let (ok, _) = fc.updateHighestReceived(1000, false)
        @Assert(ok, true)
        fc.addBytesRead(300)
        @Assert(fc.getBytesRead(), 300)
        @Assert(fc.getHighestReceived(), 1000)
        fc.abandon()
        @Assert(fc.getBytesRead(), 1000)
        @Assert(fc.getHighestReceived(), fc.getBytesRead())
    }

    @TestCase
    public func testGetBytesSentAndSendWindow(): Unit {
        let fc = StreamFlowController(0)
        let initialWindow = fc.sendWindowSize()
        @Assert(fc.getBytesSent(), 0)
        fc.addBytesSent(50)
        @Assert(fc.getBytesSent(), 50)
        @Assert(fc.getSendWindow(), initialWindow)
    }

    @TestCase
    public func testCheckFlowControlViolation(): Unit {
        let fc = StreamFlowController(0)
        @Assert(fc.checkFlowControlViolation(), false)
    }
}
