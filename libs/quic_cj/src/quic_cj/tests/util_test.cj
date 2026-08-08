package quic_cj.tests

import quic_cj.util.{RTTStats, newRTTStats, RingBuffer, NO_ERROR, INTERNAL_ERROR, PROTOCOL_VIOLATION}
import quic_cj.util.{CONNECTION_REFUSED, FLOW_CONTROL_ERROR, STREAM_LIMIT_ERROR, STREAM_STATE_ERROR, FINAL_SIZE_ERROR}
import quic_cj.util.{FRAME_ENCODING_ERROR, TRANSPORT_PARAMETER_ERROR, CONNECTION_ID_LIMIT_ERROR, INVALID_TOKEN}
import quic_cj.util.{APPLICATION_ERROR, CRYPTO_BUFFER_EXCEEDED, KEY_UPDATE_ERROR, AEAD_LIMIT_REACHED, NO_VIABLE_PATH}

@Test
public class UtilTestSuite {
    @TestCase
    public func testRttStatsInitialValues(): Unit {
        let rtt = newRTTStats()
        @Assert(rtt.minRtt(), 100000)  // 默认 100 毫秒
        @Assert(rtt.latestRtt(), 100000)
        @Assert(rtt.smoothedRtt(), 100000)
        @Assert(rtt.hasMeas(), false)
    }

    @TestCase
    public func testRttStatsUpdate(): Unit {
        let rtt = newRTTStats()
        rtt.updateRtt(80000, 5000)  // 80 毫秒采样，5 毫秒 ACK 延迟（第一次测量）
        @Assert(rtt.hasMeas(), true)
        // 在第一个样本上，minRTT == sample，因此根据 RFC 9000 不需要 ACK 延迟修正
        @Assert(rtt.latestRtt(), 80000)
        // 第二次测量：minRTT=80000，sample-minRTT=10000 >= ackDelay 5000 → 修正生效
        rtt.updateRtt(90000, 5000)
        @Assert(rtt.latestRtt(), 85000)  // 90000 - 5000 = 85000
    }

    @TestCase
    public func testRttStatsPto(): Unit {
        let rtt = newRTTStats()
        rtt.updateRtt(50000, 5000)
        let pto = rtt.pto(false)
        @Assert(pto > 0, true)
    }

    @TestCase
    public func testRingBufferPushPop(): Unit {
        let rb = RingBuffer(10, 0)
        @Assert(rb.isEmpty(), true)
        @Assert(rb.push(42), true)
        @Assert(rb.isEmpty(), false)
        @Assert(rb.len(), 1)
        @Assert(rb.peek(), 42)
        let val = rb.pop(0)
        @Assert(val, 42)
        @Assert(rb.isEmpty(), true)
    }

    @TestCase
    public func testRingBufferFull(): Unit {
        let rb = RingBuffer(4, 0)
        @Assert(rb.push(1), true)
        @Assert(rb.push(2), true)
        @Assert(rb.push(3), true)
        @Assert(rb.push(4), true)
        @Assert(rb.isFull(), true)
        @Assert(rb.push(5), false)  // full
    }

    @TestCase
    public func testRingBufferWrapAround(): Unit {
        let rb = RingBuffer(4, 0)
        rb.push(1)
        rb.push(2)
        rb.push(3)
        rb.push(4)
        @Assert(rb.pop(0), 1)
        @Assert(rb.push(5), true)  // 循环回绕
        @Assert(rb.get(0), 2)
        @Assert(rb.get(1), 3)
        @Assert(rb.get(2), 4)
        @Assert(rb.get(3), 5)
    }

    @TestCase
    public func testErrorCodes(): Unit {
        @Assert(NO_ERROR, 0x00u64)
        @Assert(INTERNAL_ERROR, 0x01u64)
        @Assert(CONNECTION_REFUSED, 0x02u64)
        @Assert(FLOW_CONTROL_ERROR, 0x03u64)
        @Assert(STREAM_LIMIT_ERROR, 0x04u64)
        @Assert(STREAM_STATE_ERROR, 0x05u64)
        @Assert(FINAL_SIZE_ERROR, 0x06u64)
        @Assert(FRAME_ENCODING_ERROR, 0x07u64)
        @Assert(TRANSPORT_PARAMETER_ERROR, 0x08u64)
        @Assert(CONNECTION_ID_LIMIT_ERROR, 0x09u64)
        @Assert(PROTOCOL_VIOLATION, 0x0au64)
        @Assert(INVALID_TOKEN, 0x0bu64)
        @Assert(APPLICATION_ERROR, 0x0cu64)
        @Assert(CRYPTO_BUFFER_EXCEEDED, 0x0du64)
        @Assert(KEY_UPDATE_ERROR, 0x0eu64)
        @Assert(AEAD_LIMIT_REACHED, 0x0fu64)
        @Assert(NO_VIABLE_PATH, 0x10u64)
    }
}
