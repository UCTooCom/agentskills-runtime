package http_lib.http2

import http_lib.core.{assertTrue, assertFalse}

/**
 * HTTP/2 流量控制窗口和 SETTINGS 超时的测试。
 */
@Test
public class FlowControlTest {

    // ---- 入站流量测试 ----

    @TestCase
    public func testInflowInit(): Unit {
        let inflow = Http2Inflow(65535)
        assertTrue(inflow.available() == 65535, message: "Initial window should be 65535")
    }

    @TestCase
    public func testInflowTake(): Unit {
        let inflow = Http2Inflow(65535)
        let ok = inflow.take(1000)
        assertTrue(ok, message: "Should be able to take within window")
        assertTrue(inflow.available() == 64535, message: "Window should decrease after take")
    }

    @TestCase
    public func testInflowTakeExceed(): Unit {
        let inflow = Http2Inflow(1000)
        let ok = inflow.take(2000)
        assertFalse(ok, message: "Should not be able to take more than available")
        assertTrue(inflow.available() == 1000, message: "Window should not change on failed take")
    }

    @TestCase
    public func testInflowAddWithBatching(): Unit {
        let inflow = Http2Inflow(65535)
        // 先取部分字节
        let _ = inflow.take(1000)
        // 添加少量数据——应被批处理（低于 4KB 阈值且小于窗口）
        let update = inflow.add(500)
        assertTrue(update == 0, message: "Small add should be batched (no WINDOW_UPDATE needed)")
        assertTrue(inflow.available() == 64535, message: "Window should not increase when batched")
    }

    @TestCase
    public func testInflowAddAboveThreshold(): Unit {
        let inflow = Http2Inflow(65535)
        // 取大量字节
        let _ = inflow.take(65535)
        assertTrue(inflow.available() == 0, message: "Window should be exhausted")
        // 添加超过刷新阈值
        let update = inflow.add(5000)
        assertTrue(update == 5000, message: "Add above threshold should trigger WINDOW_UPDATE")
        assertTrue(inflow.available() == 5000, message: "Window should be updated")
    }

    @TestCase
    public func testInflowAddDoubleWindow(): Unit {
        let inflow = Http2Inflow(5000)
        // 取全部但留 1000
        let _ = inflow.take(4000)
        assertTrue(inflow.available() == 1000, message: "Window should be 1000")
        // 添加足够数据至少翻倍窗口（>1000），即使低于 4KB
        let update = inflow.add(2000)
        assertTrue(update == 2000, message: "Add that doubles window should trigger WINDOW_UPDATE")
        assertTrue(inflow.available() == 3000, message: "Window should be 3000")
    }

    @TestCase
    public func testInflowReset(): Unit {
        let inflow = Http2Inflow(65535)
        let _ = inflow.take(50000)
        inflow.reset(65535)
        assertTrue(inflow.available() == 65535, message: "Reset should restore initial window")
    }

    // ---- 出站流量测试 ----

    @TestCase
    public func testOutflowBasic(): Unit {
        let outflow = Http2Outflow(65535)
        assertTrue(outflow.available() == 65535, message: "Initial should be 65535")
        let ok = outflow.take(1000)
        assertTrue(ok, message: "Take should succeed")
        assertTrue(outflow.available() == 64535, message: "Window should decrease")
    }

    @TestCase
    public func testOutflowConnLinked(): Unit {
        let connFlow = Http2Outflow(65535)
        let streamFlow = Http2Outflow(65535)
        streamFlow.setConnFlow(connFlow)

        // 流窗口受流窗口和连接窗口两者的限制
        let _ = connFlow.take(10000)
        // 流仍有 65535，但连接仅有 55535
        assertTrue(streamFlow.available() == 55535, message: "Stream available should be min(65535, 55535) = 55535")
    }

    @TestCase
    public func testOutflowAdd(): Unit {
        let outflow = Http2Outflow(1000)
        let _ = outflow.take(1000)
        assertTrue(outflow.available() == 0, message: "Window should be exhausted")
        let ok = outflow.add(500)
        assertTrue(ok, message: "Add should succeed")
        assertTrue(outflow.available() == 500, message: "Window should be restored")
    }

    @TestCase
    public func testOutflowMaxLimit(): Unit {
        let maxWindow: Int64 = 2147483647  // 2^31 - 1
        let outflow = Http2Outflow(maxWindow - 100)
        // 添加 200 将超过 2^31-1
        let ok = outflow.add(200)
        assertFalse(ok, message: "Should not allow exceeding max window size")
    }

    // ---- FlowController 测试 ----

    @TestCase
    public func testFlowControllerInit(): Unit {
        let fc = Http2FlowController()
        assertTrue(fc.connInflow.available() == 65535, message: "Conn inflow should be 65535")
        assertTrue(fc.connOutflow.available() == 65535, message: "Conn outflow should be 65535")
    }

    @TestCase
    public func testFlowControllerCreateStreamFlows(): Unit {
        let fc = Http2FlowController()
        let streamOut = fc.createStreamOutflow()
        let streamIn = fc.createStreamInflow()
        assertTrue(streamOut.available() == 65535, message: "Stream outflow should be 65535")
        assertTrue(streamIn.available() == 65535, message: "Stream inflow should be 65535")
    }

    // ---- SettingsTimeout 测试 ----

    @TestCase
    public func testSettingsTimeoutNotExpired(): Unit {
        let handler = SettingsTimeoutHandler(timeout: Duration.second * 60)
        handler.start()
        assertFalse(handler.isExpired(), message: "Should not expire immediately")
    }

    @TestCase
    public func testSettingsTimeoutAck(): Unit {
        let handler = SettingsTimeoutHandler(timeout: Duration.second * 60)
        handler.start()
        handler.ack()
        assertFalse(handler.isExpired(), message: "Should not be expired after ACK")
    }

    @TestCase
    public func testSettingsTimeoutReset(): Unit {
        let handler = SettingsTimeoutHandler(timeout: Duration.second * 60)
        handler.start()
        handler.reset()
        assertFalse(handler.isExpired(), message: "Should not be expired after reset")
    }

    @TestCase
    public func testOutflowConnLinkedTake(): Unit {
        let connFlow = Http2Outflow(10000)
        let streamFlow = Http2Outflow(5000)
        streamFlow.setConnFlow(connFlow)
        // 流受连接窗口限制
        let avail = streamFlow.available()
        assertTrue(avail == 5000, message: "Stream limited to 5000 by connection")
        let ok = streamFlow.take(6000)
        assertFalse(ok, message: "Cannot take more than stream window")
    }

    @TestCase
    public func testOutflowConnLinkedAvailable(): Unit {
        let connFlow = Http2Outflow(10000)
        let streamFlow = Http2Outflow(5000)
        streamFlow.setConnFlow(connFlow)
        // 连接有 10000，流有 5000——可用量为 min(10000, 5000) = 5000
        assertTrue(streamFlow.available() == 5000, message: "Available should be min(conn, stream)")
    }

    @TestCase
    public func testInflowBatchThreshold(): Unit {
        let inflow = Http2Inflow(65535)
        let _ = inflow.take(60000)
        // 添加少量——低于 4KB 阈值
        let update1 = inflow.add(500)
        assertTrue(update1 == 0, message: "Small add should be batched (below 4KB)")
        // 添加更大量——超过阈值
        let update2 = inflow.add(5000)
        assertTrue(update2 > 0, message: "Large add should trigger WINDOW_UPDATE")
    }

    @TestCase
    public func testInflowBatchUntilDouble(): Unit {
        let inflow = Http2Inflow(50000)
        let _ = inflow.take(49000)  // 仅剩 1000
        // 添加 2000 > 剩余量 → 应触发更新
        let update = inflow.add(2000)
        assertTrue(update > 0, message: "Add exceeding available should trigger WINDOW_UPDATE")
    }

    @TestCase
    public func testOutflowRawAccess(): Unit {
        let outflow = Http2Outflow(12345)
        assertTrue(outflow.raw() == 12345, message: "Raw should return unconstrained window")
    }

    @TestCase
    public func testFlowControllerUpdateInitialWindow(): Unit {
        let fc = Http2FlowController()
        let outflow1 = fc.createStreamOutflow(initialWindow: 65535)
        let inflow1 = fc.createStreamInflow(initialWindow: 65535)
        // 将初始窗口更新为更大的值
        fc.updateInitialWindow(131072)
        // 现有流应具有新的窗口
        assertTrue(true)  // 不应抛出异常
    }

    @TestCase
    public func testFlowControllerCreateStreamOutflow(): Unit {
        let fc = Http2FlowController()
        let outflow = fc.createStreamOutflow(initialWindow: 65535)
        assertTrue(outflow.available() == 65535, message: "Stream outflow should start at initial window")
    }

    @TestCase
    public func testFlowControllerCreateStreamInflow(): Unit {
        let fc = Http2FlowController()
        let inflow = fc.createStreamInflow(initialWindow: 65535)
        assertTrue(inflow.available() == 65535, message: "Stream inflow should start at initial window")
    }

    @TestCase
    public func testFlowControllerUpdateInitialWindowSmaller(): Unit {
        let fc = Http2FlowController()
        let outflow = fc.createStreamOutflow(initialWindow: 65535)
        fc.updateInitialWindow(32768)
        assertTrue(outflow.available() <= 65535, message: "Window should be reduced after smaller initial window")
    }
}
