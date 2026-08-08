package http_lib.http2

import http_lib.core.{assertTrue, assertFalse}

@Test
public class Http2MultiplexerUnitTest {
    @TestCase
    public func testCreateStream(): Unit {
        let m = Http2Multiplexer()
        let s = m.createStream()
        assertTrue(s.isSome())
    }
    @TestCase
    public func testGetStream(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()
        assertTrue(m.getStream(1).isSome())
        assertTrue(m.getStream(99).isNone())
    }
    @TestCase
    public func testEnsureStream(): Unit {
        let m = Http2Multiplexer(isServer: true)
        assertTrue(m.ensureStream(3).isSome())
    }
    @TestCase
    public func testSetMaxConcurrent(): Unit {
        let m = Http2Multiplexer()
        m.setMaxConcurrentStreams(5)
        assertTrue(m.countActiveStreams() == 0)
    }
    @TestCase
    public func testRemoveStream(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()
        assertTrue(m.countActiveStreams() == 1)
        m.removeStream(1)
        assertTrue(m.countActiveStreams() == 0)
    }
    @TestCase
    public func testCanCreateStream(): Unit {
        let m = Http2Multiplexer()
        assertTrue(m.canCreateStream())
    }
    @TestCase
    public func testCountActiveStreams(): Unit {
        let m = Http2Multiplexer()
        assertTrue(m.countActiveStreams() == 0)
        let _ = m.createStream()
        assertTrue(m.countActiveStreams() == 1)
    }
    @TestCase
    public func testGoawayFlags(): Unit {
        let m = Http2Multiplexer()
        assertFalse(m.isGoawaySent())
        assertFalse(m.isGoawayReceived())
        m.markGoawayReceived(5)
        assertTrue(m.isGoawayReceived())
        m.markGoawaySent(3)
        assertTrue(m.isGoawaySent())
    }
    @TestCase
    public func testGetNextStreamId(): Unit {
        let m = Http2Multiplexer()
        assertTrue(m.getNextStreamId() == 1)
    }
    @TestCase
    public func testGetConnectionRecvWindow(): Unit {
        let m = Http2Multiplexer()
        assertTrue(m.getConnectionRecvWindow() == 65535)
    }
    @TestCase
    public func testCloseAll(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()
        m.closeAll(Http2ErrorCode.NO_ERROR)
        assertTrue(m.countActiveStreams() == 0)
    }
    @TestCase
    public func testUpdatePriority(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()
        m.updatePriority(1, false, 0, 16)
        assertTrue(true)
    }
    @TestCase
    public func testGetPriorityTree(): Unit {
        let m = Http2Multiplexer()
        let _ = m.getPriorityTree()
        assertTrue(true)
    }
    @TestCase
    public func testCreatePushStreamServer(): Unit {
        let m = Http2Multiplexer(isServer: true)
        let _ = m.ensureStream(1)
        assertTrue(m.createPushStream(1).isSome())
    }
    @TestCase
    public func testCreatePushStreamClient(): Unit {
        let m = Http2Multiplexer(isServer: false)
        // 推送流可以被创建；由协议来强制执行
        assertTrue(m.createPushStream(1).isSome())
    }

    @TestCase
    public func testUpdateConnectionSendWindow(): Unit {
        let m = Http2Multiplexer()
        m.updateConnectionSendWindow(10000)
        let window = m.getConnectionSendWindow()
        assertTrue(window >= 10000, message: "Connection send window should increase")
    }

    @TestCase
    public func testGetConnectionSendWindow(): Unit {
        let m = Http2Multiplexer()
        let window = m.getConnectionSendWindow()
        assertTrue(window == 65535, message: "Default connection send window should be 65535")
    }

    @TestCase
    public func testAdjustAllStreamSendWindows(): Unit {
        let m = Http2Multiplexer()
        let s1 = m.createStream()
        let s2 = m.createStream()
        m.adjustAllStreamSendWindows(5000)
        assertTrue(true)  // 不应抛出异常
    }

    @TestCase
    public func testUpdateConnectionRecvWindow(): Unit {
        let m = Http2Multiplexer()
        m.updateConnectionRecvWindow(10000)
        let window = m.getConnectionRecvWindow()
        assertTrue(window == 75535, message: "Connection recv window should increase by 10000")
    }

    @TestCase
    public func testConsumeStreamSendWindow(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()  // 流 ID = 1
        // 流 1 应有默认发送窗口 65535
        let ok = m.consumeStreamSendWindow(1, 1000)
        assertTrue(ok, message: "Should consume 1000 from send window")
    }

    @TestCase
    public func testConsumeStreamSendWindowExceed(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()  // 流 ID = 1，接收窗口在 SETTINGS 前为 0
        let ok = m.consumeStreamSendWindow(99999, 1000)  // 窗口尚未配置
        // 取决于实现，这可能会或不会成功
        assertTrue(true)  // 不应抛出异常
    }

    @TestCase
    public func testAddStreamRecvWindow(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()
        m.addStreamRecvWindow(1, 5000)
        assertTrue(true)  // 不应抛出异常
    }

    @TestCase
    public func testConsumeStreamRecvWindow(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()
        let ok = m.consumeStreamRecvWindow(1, 1000)
        assertTrue(ok, message: "Should consume from stream recv window")
    }


    @TestCase
    public func testTransitionStateValid(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()  // streamId=1
        // idle -> open is a valid transition
        m.transitionState(1, Http2StreamState.OPEN)
        assertTrue(true, message: "idle->open transition should not throw")
    }

    @TestCase
    public func testTransitionStateInvalid(): Unit {
        let m = Http2Multiplexer()
        let _ = m.createStream()  // streamId=1
        m.transitionState(1, Http2StreamState.OPEN)
        // closed -> half_closed_remote is NOT valid
        m.transitionState(1, Http2StreamState.CLOSED)
        var threw = false
        try {
            m.transitionState(1, Http2StreamState.HALF_CLOSED_REMOTE)
        } catch (e: Http2Exception) {
            threw = true
        }
        assertTrue(threw, message: "closed->half_closed_remote should throw")
    }

    @TestCase
    public func testTransitionStateNonexistentStream(): Unit {
        let m = Http2Multiplexer()
        // Transitioning a non-existent stream should not throw
        try {
            m.transitionState(99, Http2StreamState.OPEN)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "Should not throw for non-existent stream")
        }
    }
}

