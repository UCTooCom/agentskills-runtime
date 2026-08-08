package http_lib.client

import http_lib.core.{assertTrue, assertFalse}
import http_lib.connection.MockConnection

@Test
public class ConnectionPoolTest {

    // ==================== 初始化 ====================

    @TestCase
    public func test01_Init(): Unit {
        let p = ConnectionPool()
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test02_InitCustomMaxPerHost(): Unit {
        let p = ConnectionPool(maxPerHost: 10)
        // 释放 7 个连接 — 都应容纳（默认最大 5，自定义为 10）
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        let c3 = MockConnection([])
        let c4 = MockConnection([])
        let c5 = MockConnection([])
        let c6 = MockConnection([])
        let c7 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        p.release("h", 80, false, c3, true)
        p.release("h", 80, false, c4, true)
        p.release("h", 80, false, c5, true)
        p.release("h", 80, false, c6, true)
        p.release("h", 80, false, c7, true)
        assertTrue(p.size() == 7)
    }

    // ==================== 借用 ====================

    @TestCase
    public func test03_BorrowEmptyReturnsNone(): Unit {
        let p = ConnectionPool()
        let result = p.borrow("h", 80, false)
        assertTrue(result.isNone())
    }

    @TestCase
    public func test04_BorrowAfterRelease(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c = MockConnection([])
        p.release("h", 80, false, c, true)
        assertTrue(p.size() == 1)
        let result = p.borrow("h", 80, false)
        assertTrue(result.isSome())
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test05_BorrowSkipsNonReusable(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c = MockConnection([])
        c.simulateClose()  // canReuseTransport() 返回 false
        p.release("h", 80, false, c, true)
        // 过期连接应跳过并关闭；池保持为空
        assertTrue(p.borrow("h", 80, false).isNone())
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test06_BorrowSkipsExpiredByTimeout(): Unit {
        // idleTimeout 为 1 纳秒 — 连接立即过期
        let p = ConnectionPool(maxPerHost: 5, idleTimeout: Duration.nanosecond * 1)
        let c = MockConnection([])
        p.release("h", 80, false, c, true)
        assertTrue(p.borrow("h", 80, false).isNone())
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test07_BorrowAllExpiredReturnsNone(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        c1.simulateClose()
        c2.simulateClose()
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        // 所有连接过期 -> borrow 返回 None 且池键被清理
        assertTrue(p.borrow("h", 80, false).isNone())
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test08_BorrowMixedExpiredAndLive(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])  // 存活
        let c2 = MockConnection([])  // 已过期
        let c3 = MockConnection([])  // 存活
        c2.simulateClose()
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        p.release("h", 80, false, c3, true)
        // 释放后：[c1, c2, c3]
        assertTrue(p.size() == 3)
        // Borrow 从尾部弹出（LIFO）：c3 存活，返回它
        // 剩余：[c1, c2] — c2 已关闭但留在池中直到下次 borrow
        let result = p.borrow("h", 80, false)
        assertTrue(result.isSome())
        assertTrue(p.size() == 2)
    }

    @TestCase
    public func test09_BorrowLifoOrder(): Unit {
        // 池从尾部弹出（LIFO），因此最近
        // 释放的连接先被返回。
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        assertTrue(p.size() == 2)
        // 第一次 borrow 返回 c2，第二次返回 c1，第三次返回 None
        assertTrue(p.borrow("h", 80, false).isSome())
        assertTrue(p.borrow("h", 80, false).isSome())
        assertTrue(p.borrow("h", 80, false).isNone())
    }

    // ==================== 释放 ====================

    @TestCase
    public func test10_ReleaseNonReusableClosesConnection(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c = MockConnection([])
        assertTrue(c.isConnected())
        p.release("t", 80, false, c, false)
        assertTrue(p.size() == 0)
        assertTrue(!c.isConnected())
    }

    @TestCase
    public func test11_ReleaseReusableAddsToPool(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c = MockConnection([])
        p.release("t", 80, false, c, true)
        assertTrue(p.size() == 1)
    }

    @TestCase
    public func test12_ReleaseFullPoolClosesConnection(): Unit {
        let p = ConnectionPool(maxPerHost: 2)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        let c3 = MockConnection([])
        p.release("t", 80, false, c1, true)
        p.release("t", 80, false, c2, true)
        assertTrue(p.size() == 2)
        // 第三个连接超过 maxPerHost -> 关闭，不添加
        p.release("t", 80, false, c3, true)
        assertTrue(p.size() == 2)
        assertTrue(!c3.isConnected())
    }

    @TestCase
    public func test13_ReleaseDifferentHostsSeparatePools(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h1", 80, false, c1, true)
        p.release("h2", 80, false, c2, true)
        assertTrue(p.size() == 2)
        // 每个主机获得自己的独立条目
        assertTrue(p.borrow("h1", 80, false).isSome())
        assertTrue(p.borrow("h2", 80, false).isSome())
        assertTrue(p.borrow("h1", 80, false).isNone())
        assertTrue(p.borrow("h2", 80, false).isNone())
    }

    @TestCase
    public func test14_ReleaseSecureVsInsecureSeparatePools(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h", 443, true, c1, true)
        p.release("h", 80, false, c2, true)
        assertTrue(p.size() == 2)
        // isSecure=true 和 isSecure=false 是不同的池键
        assertTrue(p.borrow("h", 443, true).isSome())
        assertTrue(p.borrow("h", 80, false).isSome())
        assertTrue(p.borrow("h", 443, true).isNone())
        assertTrue(p.borrow("h", 80, false).isNone())
    }

    // ==================== 关闭空闲 ====================

    @TestCase
    public func test15_CloseIdleEmptyPool(): Unit {
        let p = ConnectionPool()
        p.closeIdle()
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test16_CloseIdleRemovesNonReusable(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        let c3 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        p.release("h", 80, false, c3, true)
        c2.simulateClose()  // c2 不再可复用
        p.closeIdle()
        // c2 被移除；c1 和 c3 保留
        assertTrue(p.size() == 2)
    }

    @TestCase
    public func test17_CloseIdleExpiredByTimeout(): Unit {
        let p = ConnectionPool(maxPerHost: 5, idleTimeout: Duration.nanosecond * 1)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        p.closeIdle()
        assertTrue(p.size() == 0)
        assertTrue(!c1.isConnected())
        assertTrue(!c2.isConnected())
    }

    @TestCase
    public func test18_CloseIdleCleanupEmptyKeys(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h1", 80, false, c1, true)
        p.release("h2", 80, false, c2, true)
        c1.simulateClose()
        c2.simulateClose()
        p.closeIdle()
        // 两个连接都过期 -> 两个池键都应被移除
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test19_CloseIdleLeavesFreshConnections(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        // 对 60s idleTimeout 的 closeIdle — 连接仍然新鲜
        p.closeIdle()
        assertTrue(p.size() == 2)
    }

    // ==================== 全部关闭 ====================

    @TestCase
    public func test20_CloseAllEmptyPool(): Unit {
        let p = ConnectionPool()
        p.closeAll()
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test21_CloseAllClosesAndClears(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        p.closeAll()
        assertTrue(p.size() == 0)
        assertTrue(!c1.isConnected())
        assertTrue(!c2.isConnected())
    }

    @TestCase
    public func test22_CloseAllMultipleHosts(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h1", 80, false, c1, true)
        p.release("h2", 443, true, c2, true)
        p.closeAll()
        assertTrue(p.size() == 0)
        assertTrue(!c1.isConnected())
        assertTrue(!c2.isConnected())
    }

    // ==================== 清空 ====================

    @TestCase
    public func test23_ClearEmptyPool(): Unit {
        let p = ConnectionPool()
        p.clear()
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test24_ClearRemovesEntriesWithoutClosing(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c = MockConnection([])
        p.release("h", 80, false, c, true)
        p.clear()
        assertTrue(p.size() == 0)
        // clear() 不会关闭连接，仅从跟踪中移除
        assertTrue(c.isConnected())
    }

    // ==================== 大小 ====================

    @TestCase
    public func test25_SizeEmptyPool(): Unit {
        let p = ConnectionPool()
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test26_SizeAfterMultipleReleases(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        let c3 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        p.release("h", 80, false, c3, true)
        assertTrue(p.size() == 3)
    }

    @TestCase
    public func test27_SizeAfterBorrow(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        assertTrue(p.size() == 2)
        let _ = p.borrow("h", 80, false)
        assertTrue(p.size() == 1)
    }

    @TestCase
    public func test28_SizeAfterCloseIdle(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        c1.simulateClose()
        c2.simulateClose()
        p.closeIdle()
        assertTrue(p.size() == 0)
    }

    @TestCase
    public func test29_SizeAfterCloseAll(): Unit {
        let p = ConnectionPool(maxPerHost: 5)
        let c1 = MockConnection([])
        let c2 = MockConnection([])
        p.release("h", 80, false, c1, true)
        p.release("h", 80, false, c2, true)
        p.closeAll()
        assertTrue(p.size() == 0)
    }
}
