package http_lib.http2

import http_lib.core.{assertTrue, assertFalse}

/**
 * 测试 HTTP/2 写入调度器（轮询和基于优先级的）。
 */
@Test
public class WriteSchedulerTest {

    @TestCase
    public func testRoundRobinBasic(): Unit {
        let sched = RoundRobinWriteScheduler()

        sched.openStream(1)
        sched.openStream(3)

        sched.push(Http2FrameWriteRequest(1, [b'A']))
        sched.push(Http2FrameWriteRequest(3, [b'B']))

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.streamId == 1, message: "First pop should be stream 1, got ${wr.streamId}")
            case None => assertTrue(false, message: "Should have a frame")
        }

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.streamId == 3, message: "Second pop should be stream 3, got ${wr.streamId}")
            case None => assertTrue(false, message: "Should have a frame")
        }
    }

    @TestCase
    public func testRoundRobinControlFramesFirst(): Unit {
        let sched = RoundRobinWriteScheduler()
        sched.openStream(1)

        sched.push(Http2FrameWriteRequest(1, [b'D']))
        sched.push(Http2FrameWriteRequest(0, [b'C'], isControl: true))

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.isControl, message: "Control frame should be popped first")
            case None => assertTrue(false, message: "Should have a frame")
        }
    }

    @TestCase
    public func testRoundRobinCloseStream(): Unit {
        let sched = RoundRobinWriteScheduler()
        sched.openStream(1)
        sched.openStream(3)

        sched.push(Http2FrameWriteRequest(1, [b'A']))
        sched.push(Http2FrameWriteRequest(3, [b'B']))

        sched.closeStream(1)

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.streamId == 3, message: "Only stream 3 should remain after closing stream 1")
            case None => assertTrue(false, message: "Should have a frame")
        }

        match (sched.pop()) {
            case Some(_) => assertTrue(false, message: "Should be empty after all frames consumed")
            case None => ()  // 预期
        }
    }

    @TestCase
    public func testPrioritySchedulerHigherWeightFirst(): Unit {
        let sched = PriorityWriteScheduler()

        sched.openStream(1, weight: 255, parent: None)
        sched.openStream(3, weight: 16, parent: None)
        sched.openStream(5, weight: 1, parent: None)

        sched.push(Http2FrameWriteRequest(5, [b'L']))
        sched.push(Http2FrameWriteRequest(3, [b'M']))
        sched.push(Http2FrameWriteRequest(1, [b'H']))

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.streamId == 1,
                message: "Highest weight stream should be first, got ${wr.streamId}")
            case None => assertTrue(false, message: "Should have a frame")
        }
    }

    @TestCase
    public func testPrioritySchedulerAdjustStream(): Unit {
        let sched = PriorityWriteScheduler()
        sched.openStream(1, weight: 16, parent: None)
        sched.openStream(3, weight: 16, parent: None)

        sched.push(Http2FrameWriteRequest(1, [b'A']))
        sched.push(Http2FrameWriteRequest(3, [b'B']))

        sched.adjustStream(3, false, 0, 255)

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.streamId == 3,
                message: "Adjusted stream should be preferred, got ${wr.streamId}")
            case None => assertTrue(false, message: "Should have a frame")
        }
    }

    @TestCase
    public func testEmptyScheduler(): Unit {
        let sched = RoundRobinWriteScheduler()
        match (sched.pop()) {
            case Some(_) => assertTrue(false, message: "Empty scheduler should return None")
            case None => ()  // 预期
        }
    }

    @TestCase
    public func testPrioritySchedulerCloseStream(): Unit {
        let sched = PriorityWriteScheduler()
        sched.openStream(1, weight: 16, parent: None)
        sched.openStream(3, weight: 16, parent: None)

        sched.push(Http2FrameWriteRequest(1, [b'A']))
        sched.push(Http2FrameWriteRequest(3, [b'B']))

        sched.closeStream(1)

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.streamId == 3,
                message: "Only stream 3 should remain after close, got ${wr.streamId}")
            case None => assertTrue(false, message: "Should have a frame from stream 3")
        }
    }

    @TestCase
    public func testPrioritySchedulerResetCounters(): Unit {
        let sched = PriorityWriteScheduler()
        sched.openStream(1, weight: 16, parent: None)
        sched.push(Http2FrameWriteRequest(1, [b'X']))
        sched.resetCounters()
        assertTrue(true)  // 不应抛出异常
    }

    @TestCase
    public func testPrioritySchedulerMultipleFramesSameStream(): Unit {
        let sched = PriorityWriteScheduler()
        sched.openStream(1, weight: 16, parent: None)

        sched.push(Http2FrameWriteRequest(1, [b'A']))
        sched.push(Http2FrameWriteRequest(1, [b'B']))
        sched.push(Http2FrameWriteRequest(1, [b'C']))

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.streamId == 1 && wr.frameData[0] == b'A',
                message: "First frame should be A")
            case None => assertTrue(false)
        }

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.streamId == 1 && wr.frameData[0] == b'B',
                message: "Second frame should be B")
            case None => assertTrue(false)
        }

        match (sched.pop()) {
            case Some(wr) => assertTrue(wr.frameData[0] == b'C', message: "Third frame should be C")
            case None => assertTrue(false)
        }
    }


    @TestCase
    public func testRoundRobinCleanup(): Unit {
        let sched = RoundRobinWriteScheduler()
        sched.openStream(1)
        sched.openStream(3)
        sched.closeStream(1)
        // cleanup removes stale streams (those in writeCounters but not in streamQueues)
        try {
            sched.cleanup()
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "cleanup should not throw")
        }
    }
}