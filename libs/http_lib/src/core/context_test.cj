package http_lib.core

import std.time.DateTime

/**
 * RequestContext 测试：取消、截止时间和值 API。
 *
 * 覆盖：
 * - 默认状态（未过期、未取消、无截止时间、缺失键返回 None）
 * - 设置并检查截止时间（未来 = 未过期，过去 = 已过期）
 * - 无原因取消
 * - 带原因取消
 * - 设置并获取单个值
 * - 设置并获取多个值
 * - 覆盖已有键
 * - 缺失键返回 None
 */

@Test
public class ContextTest {

    // ── 默认状态 ────────────────────────────────────────────────────────────

    @TestCase
    public func testDefaultState(): Unit {
        let ctx = RequestContext()
        assertFalse(ctx.isExpired())
        assertFalse(ctx.isCancelled())
        assertTrue(ctx.getDeadline().isNone())
        assertTrue(ctx.getCancelReason().size == 0)
        assertTrue(ctx.getValue("any-key").isNone())
    }

    // ── 截止时间（未来） ────────────────────────────────────────────────────

    @TestCase
    public func testSetDeadlineFuture(): Unit {
        let ctx = RequestContext()
        let future = DateTime.now() + Duration.second * 3600  // 距现在 1 小时
        ctx.setDeadline(future)
        assertFalse(ctx.isExpired())

        match (ctx.getDeadline()) {
            case Some(dl) => assertTrue(dl == future)
            case None => assertTrue(false)
        }
    }

    // ── 截止时间（过去） ────────────────────────────────────────────────────

    @TestCase
    public func testSetDeadlinePast(): Unit {
        let ctx = RequestContext()
        let past = DateTime.now() - Duration.second * 1  // 1 秒前
        ctx.setDeadline(past)
        assertTrue(ctx.isExpired())
    }

    // ── 取消（无原因） ──────────────────────────────────────────────────────

    @TestCase
    public func testCancelWithoutReason(): Unit {
        let ctx = RequestContext()
        ctx.cancel()
        assertTrue(ctx.isCancelled())
        assertTrue(ctx.isExpired())
        assertTrue(ctx.getCancelReason().size == 0)
    }

    // ── 取消（带原因） ──────────────────────────────────────────────────────

    @TestCase
    public func testCancelWithReason(): Unit {
        let ctx = RequestContext()
        let reason = "request timed out"
        ctx.cancel(reason: reason)
        assertTrue(ctx.isCancelled())
        assertTrue(ctx.isExpired())
        assertTrue(ctx.getCancelReason() == reason)
    }

    // ── 取消覆盖截止时间（取消优先） ────────────────────────────────────────

    @TestCase
    public func testCancelledBeforeDeadlineIsExpired(): Unit {
        let ctx = RequestContext()
        let future = DateTime.now() + Duration.second * 3600
        ctx.setDeadline(future)
        ctx.cancel()
        assertTrue(ctx.isCancelled())
        assertTrue(ctx.isExpired())
    }

    // ── 单个值 ──────────────────────────────────────────────────────────────

    @TestCase
    public func testSetAndGetValue(): Unit {
        let ctx = RequestContext()
        ctx.setValue("user-id", "42")
        match (ctx.getValue("user-id")) {
            case Some(v) => assertTrue(v == "42")
            case None => assertTrue(false)
        }
    }

    // ── 多个值 ──────────────────────────────────────────────────────────────

    @TestCase
    public func testMultipleValues(): Unit {
        let ctx = RequestContext()
        ctx.setValue("trace-id", "abc-123")
        ctx.setValue("span-id", "def-456")
        ctx.setValue("origin", "gateway")

        match (ctx.getValue("trace-id")) {
            case Some(v) => assertTrue(v == "abc-123")
            case None => assertTrue(false)
        }
        match (ctx.getValue("span-id")) {
            case Some(v) => assertTrue(v == "def-456")
            case None => assertTrue(false)
        }
        match (ctx.getValue("origin")) {
            case Some(v) => assertTrue(v == "gateway")
            case None => assertTrue(false)
        }
    }

    // ── 覆盖已有键 ──────────────────────────────────────────────────────────

    @TestCase
    public func testOverwriteValue(): Unit {
        let ctx = RequestContext()
        ctx.setValue("key", "initial")
        ctx.setValue("key", "overwritten")
        match (ctx.getValue("key")) {
            case Some(v) => assertTrue(v == "overwritten")
            case None => assertTrue(false)
        }
    }

    // ── 缺失键返回 None ─────────────────────────────────────────────────────

    @TestCase
    public func testGetMissingKeyReturnsNone(): Unit {
        let ctx = RequestContext()
        assertTrue(ctx.getValue("non-existent").isNone())
    }

    // ── 取消后截止时间仍然保留 ──────────────────────────────────────────────

    @TestCase
    public func testDeadlineStillAccessibleAfterCancel(): Unit {
        let ctx = RequestContext()
        let dl = DateTime.now() + Duration.second * 60
        ctx.setDeadline(dl)
        ctx.cancel()
        // 即使取消后，截止时间值仍应可获取
        match (ctx.getDeadline()) {
            case Some(dl2) => assertTrue(dl == dl2)
            case None => assertTrue(false)
        }
    }
}
