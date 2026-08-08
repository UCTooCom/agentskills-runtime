/**
 * HTTP/3 Extensible Priorities 单元测试（RFC 9218）。
 *
 * 覆盖：
 * - Http3Priority 默认值、自定义值、范围截断
 * - Priority 头部解析与编码
 * - 从 HttpHeaders 提取优先级
 * - 优先级比较（越低越优）
 * - PriorityScheduler 流调度
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse, HttpHeaders}

// ======== 优先级测试 ========

@Test
public class Http3PriorityTest {

    @TestCase
    public func testDefaultPriority(): Unit {
        let p = Http3Priority.defaultPriority()
        assertTrue(p.urgency == 3u8, message: "Default urgency should be 3")
        assertFalse(p.incremental, message: "Default incremental should be false")
    }

    @TestCase
    public func testCustomPriority(): Unit {
        let p = Http3Priority(urgency: 0u8, incremental: true)
        assertTrue(p.urgency == 0u8, message: "Custom urgency should be 0")
        assertTrue(p.incremental, message: "Custom incremental should be true")
    }

    @TestCase
    public func testPriorityRangeClamping(): Unit {
        let low = Http3Priority(urgency: 10u8)
        assertTrue(low.urgency == 7u8, message: "Urgency 10 should clamp to 7")
        let high = Http3Priority(urgency: 255u8)
        assertTrue(high.urgency == 7u8, message: "Urgency 255 should clamp to 7")
    }

    @TestCase
    public func testParsePriorityHeader(): Unit {
        let p1 = parsePriorityHeader("u=0, i=?1")
        assertTrue(p1.urgency == 0u8, message: "Parsed urgency should be 0")
        assertTrue(p1.incremental, message: "Parsed incremental should be true")

        let p2 = parsePriorityHeader("u=7")
        assertTrue(p2.urgency == 7u8, message: "Parsed urgency should be 7")
        assertFalse(p2.incremental, message: "Default incremental should be false")
    }

    @TestCase
    public func testParsePriorityHeaderDefault(): Unit {
        let p = parsePriorityHeader("")
        assertTrue(p.urgency == 3u8, message: "Empty header should use default urgency")
        assertFalse(p.incremental, message: "Empty header should use default incremental")
    }

    @TestCase
    public func testEncodePriorityHeader(): Unit {
        let p1 = Http3Priority(urgency: 0u8, incremental: true)
        let encoded1 = encodePriorityHeader(p1)
        assertTrue(encoded1 == "u=0, i=?1", message: "Encoded should be 'u=0, i=?1'")

        let p2 = Http3Priority(urgency: 5u8, incremental: false)
        let encoded2 = encodePriorityHeader(p2)
        assertTrue(encoded2 == "u=5, i=?0", message: "Encoded should be 'u=5, i=?0'")
    }

    @TestCase
    public func testExtractPriorityFromHeaders(): Unit {
        let headers = HttpHeaders()
        headers.set("priority", "u=1, i=?1")
        let p = extractPriorityFromHeaders(headers)
        assertTrue(p.urgency == 1u8, message: "Extracted urgency should be 1")
        assertTrue(p.incremental, message: "Extracted incremental should be true")
    }

    @TestCase
    public func testCompareTo(): Unit {
        let low = Http3Priority(urgency: 0u8)
        let high = Http3Priority(urgency: 7u8)
        assertTrue(low.compareTo(high) < 0, message: "Lower urgency has higher priority")
        assertTrue(high.compareTo(low) > 0, message: "Higher urgency has lower priority")
    }
}

// ======== 优先级调度器测试 ========

@Test
public class PrioritySchedulerTest {

    @TestCase
    public func testAddAndNext(): Unit {
        let s = PriorityScheduler()
        s.addStream(1, priority: Http3Priority(urgency: 0u8))
        s.addStream(2, priority: Http3Priority(urgency: 5u8))
        let first = s.nextHighest()
        match (first) {
            case Some(id) => assertTrue(id == 1, message: "Urgency 0 should be first")
            case None => assertTrue(false, message: "Should have a stream")
        }
    }

    @TestCase
    public func testHasPending(): Unit {
        let s = PriorityScheduler()
        assertFalse(s.hasPending())
        s.addStream(1)
        assertTrue(s.hasPending())
        let _ = s.nextHighest()
        assertFalse(s.hasPending())
    }

    @TestCase
    public func testRemoveStream(): Unit {
        let s = PriorityScheduler()
        s.addStream(1, priority: Http3Priority(urgency: 0u8))
        s.addStream(2, priority: Http3Priority(urgency: 0u8))
        s.removeStream(1)
        let first = s.nextHighest()
        match (first) {
            case Some(id) => assertTrue(id == 2, message: "After removing 1, next should be 2")
            case None => assertTrue(false, message: "Should have a stream")
        }
    }

    @TestCase
    public func testGetPendingCount(): Unit {
        let s = PriorityScheduler()
        assertTrue(s.getPendingCount() == 0, message: "Empty scheduler should have 0 pending")
        s.addStream(1)
        s.addStream(2)
        assertTrue(s.getPendingCount() == 2, message: "After adding 2 streams, pending count should be 2")
        let _ = s.nextHighest()
        assertTrue(s.getPendingCount() == 1, message: "After consuming 1 stream, pending count should be 1")
    }

    @TestCase
    public func testClear(): Unit {
        let s = PriorityScheduler()
        s.addStream(1, priority: Http3Priority(urgency: 0u8))
        s.addStream(2, priority: Http3Priority(urgency: 5u8))
        assertTrue(s.hasPending(), message: "Should have pending streams before clear")
        s.clear()
        assertFalse(s.hasPending(), message: "Should have no pending streams after clear")
        assertTrue(s.getPendingCount() == 0, message: "Pending count should be 0 after clear")
    }

    @TestCase
    public func testClearEmptyScheduler(): Unit {
        let s = PriorityScheduler()
        // 清除空调度器不应产生错误
        try {
            s.clear()
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "clear() on empty scheduler should not throw")
        }
    }
}

// ======== Http3Priority ToString 测试 ========
@Test



public class PriorityToStringTest {
    @TestCase
    public func testPriorityToString(): Unit {
        let p1 = Http3Priority(urgency: 0u8, incremental: true)
        let s1 = p1.toString()
        assertTrue(s1.contains("u=0"), message: "toString should contain 'u=0'")
        assertTrue(s1.contains("?1"), message: "toString should contain '?1'")

        let p2 = Http3Priority(urgency: 5u8, incremental: false)
        let s2 = p2.toString()
        assertTrue(s2.contains("u=5"), message: "toString should contain 'u=5'")
        assertTrue(s2.contains("?0"), message: "toString should contain '?0'")
    }
}
