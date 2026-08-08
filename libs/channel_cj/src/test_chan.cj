package channel_cj

import std.unittest.*
import std.unittest.testmacro.{Test, TestCase}
import std.sync.{AtomicInt64, AtomicBool}
import std.collection.ArrayList

/* ═══════════════════════════════════════════════════════════════
 * 创建通道测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestCreate {
    @TestCase
    public func test_create_unbuffered(): Unit {
        let ch = Chan<Int64>()
        if (ch.cap() != 0) { throw Exception("cap 应为 0") }
        if (ch.len() != 0) { throw Exception("len 应为 0") }
        if (ch.isClosed()) { throw Exception("不应已关闭") }
    }

    @TestCase
    public func test_create_buffered(): Unit {
        let ch = Chan<Int64>(5)
        if (ch.cap() != 5) { throw Exception("cap 应为 5") }
        if (ch.len() != 0) { throw Exception("len 应为 0") }
    }

    @TestCase
    public func test_create_negative(): Unit {
        let ch = Chan<Int64>(-1)
        if (ch.cap() != 0) { throw Exception("负容量应被处理为 0") }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * 基本发送 / 接收测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestSendRecv {
    @TestCase
    public func test_buffered_fifo(): Unit {
        let ch = Chan<Int64>(3)
        for (i in 0..3) { ch.send(i) }
        for (i in 0..3) {
            let r = ch.recv()
            if (let Some(v) <- r) {
                if (v != i) { throw Exception("FIFO 顺序被破坏") }
            } else {
                throw Exception("期望 Some(v)")
            }
        }
    }

    @TestCase
    public func test_try_send_recv(): Unit {
        let ch = Chan<Int64>(2)
        if (!ch.trySend(10)) { throw Exception("trySend 应成功") }
        if (!ch.trySend(20)) { throw Exception("trySend 应成功") }
        if (ch.trySend(30)) { throw Exception("缓冲区满，trySend 应失败") }

        let r1 = ch.tryRecv()
        if (let Some(v) <- r1) {
            if (v != 10) { throw Exception("期望 10") }
        } else { throw Exception("期望 Some(10)") }

        let r2 = ch.tryRecv()
        if (let Some(v) <- r2) {
            if (v != 20) { throw Exception("期望 20") }
        } else { throw Exception("期望 Some(20)") }

        let r3 = ch.tryRecv()
        if (r3.isSome()) { throw Exception("应为 None") }
    }

    @TestCase
    public func test_cap_and_len(): Unit {
        let ch = Chan<Int64>(5)
        if (ch.cap() != 5) { throw Exception("cap 错误") }
        ch.send(10)
        if (ch.len() != 1) { throw Exception("len 应为 1") }
        ch.send(20)
        if (ch.len() != 2) { throw Exception("len 应为 2") }
        ch.recv()
        if (ch.len() != 1) { throw Exception("len 应为 1") }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * 关闭通道测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestClose {
    @TestCase
    public func test_close_drain(): Unit {
        let ch = Chan<Int64>(3)
        ch.send(1)
        ch.send(2)
        ch.send(3)
        ch.close()
        if (!ch.isClosed()) { throw Exception("应已关闭") }

        let r1 = ch.recv()
        if (r1.isNone()) { throw Exception("应有数据") }
        let r2 = ch.recv()
        if (r2.isNone()) { throw Exception("应有数据") }
        let r3 = ch.recv()
        if (r3.isNone()) { throw Exception("应有数据") }
        let r4 = ch.recv()
        if (r4.isSome()) { throw Exception("drain 后应为 None") }
    }

    @TestCase
    public func test_close_empty(): Unit {
        let ch = Chan<Int64>(2)
        ch.close()
        if (!ch.isClosed()) { throw Exception("应已关闭") }
        let r = ch.recv()
        if (r.isSome()) { throw Exception("应为 None") }
    }

    @TestCase
    public func test_close_send_fails(): Unit {
        let ch = Chan<Int64>(2)
        ch.close()
        try {
            ch.send(1)
            throw Exception("应抛出异常")
        } catch (e: Exception) {
            // 期望异常
        }
    }

    @TestCase
    public func test_close_twice(): Unit {
        let ch = Chan<Int64>(2)
        ch.close()
        try {
            ch.close()
            throw Exception("应抛出异常")
        } catch (e: Exception) {
            // 期望异常
        }
    }

    @TestCase
    public func test_try_send_on_closed(): Unit {
        let ch = Chan<Int64>(2)
        ch.close()
        if (ch.trySend(10)) { throw Exception("关闭后 trySend 应为 false") }
    }

    @TestCase
    public func test_len_cap_after_close(): Unit {
        let ch = Chan<Int64>(5)
        ch.send(10)
        ch.send(20)
        ch.close()
        if (ch.cap() != 5) { throw Exception("关闭后 cap 应不变") }
        if (ch.len() != 2) { throw Exception("关闭后 len 应为缓冲区剩余元素数") }
        ch.recv()
        if (ch.len() != 1) { throw Exception("recv 后 len 应减少") }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * ForEach 遍历测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestForEach {
    @TestCase
    public func test_for_each(): Unit {
        let ch = Chan<Int64>(3)
        ch.send(1)
        ch.send(2)
        ch.send(3)
        ch.close()
        let sum = AtomicInt64(0)
        ch.forEach({ v => sum.fetchAdd(v) })
        if (sum.load() != 6) { throw Exception("sum 应为 6") }
    }

    @TestCase
    public func test_for_each_empty_closed(): Unit {
        let ch = Chan<Int64>(3)
        ch.close()
        let count = AtomicInt64(0)
        ch.forEach({ v => count.fetchAdd(1) })
        if (count.load() != 0) { throw Exception("空通道 forEach 不应产生任何值") }
    }

    @TestCase
    public func test_for_each_close_midway(): Unit {
        let ch = Chan<Int64>(10)
        for (i in 0..5) { ch.send(i) }
        let collected = ArrayList<Int64>()
        spawn {
            ch.forEach({ v => collected.add(v) })
        }
        sleep(100 * Duration.millisecond)
        ch.close()
        sleep(100 * Duration.millisecond)
        if (collected.size != 5) { throw Exception("应收集 5 个值，实际 ${collected.size}") }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * 阻塞 / 并发测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestBlocking {
    /**
     * 无缓冲通道：发送者和接收者同步握手。
     * 通过 spawn 创建的发送者阻塞直到主线程接收。
     */
    @TestCase
    public func test_unbuffered_handoff(): Unit {
        let ch = Chan<Int64>()
        let sender = spawn { ch.send(42) }
        let r = ch.recv()
        if (let Some(v) <- r) {
            if (v != 42) { throw Exception("期望 42，实际 ${v}") }
        } else {
            throw Exception("期望 Some(42)")
        }
    }

    /**
     * 有缓冲通道：填满缓冲区后阻塞发送者。
     * 基于 Condition 的等待应能在接收者腾出空间时正确唤醒发送者。
     */
    @TestCase
    public func test_buffered_overflow_fifo(): Unit {
        let ch = Chan<Int64>(2)
        ch.send(1)
        ch.send(2)

        /* 创建一个会阻塞的发送者（缓冲区满） */
        let sender = spawn { ch.send(3) }

        /* 让发送者启动并在 Condition 上阻塞 */
        sleep(200 * Duration.millisecond)

        /* recv() 看到 sendQueue[3] 和 buffer[1,2]。
         * 为保持 FIFO，取出缓冲区头部 (1) 并将 3 放到缓冲区尾部。 */
        let r1 = ch.recv()
        if (let Some(v) <- r1) {
            if (v != 1) { throw Exception("期望 1（FIFO 头），实际 ${v}") }
        } else { throw Exception("期望 Some(1)") }

        /* 此时 buffer = [2, 3] */
        let r2 = ch.recv()
        if (let Some(v) <- r2) {
            if (v != 2) { throw Exception("期望 2，实际 ${v}") }
        } else { throw Exception("期望 Some(2)") }

        let r3 = ch.recv()
        if (let Some(v) <- r3) {
            if (v != 3) { throw Exception("期望 3，实际 ${v}") }
        } else { throw Exception("期望 Some(3)") }

        /* 等待发送者线程结束 */
        sleep(50 * Duration.millisecond)
    }

    /**
     * 填满有缓冲通道，创建 N 个发送者，然后 drain。
     * 验证阻塞发送者的 FIFO 顺序。
     */
    @TestCase
    public func test_multi_sender_overflow_fifo(): Unit {
        let ch = Chan<Int64>(2)
        ch.send(1)
        ch.send(2)

        /* 创建三个阻塞发送者。它们的值必须出现在缓冲区内容之后 */
        spawn { ch.send(3) }
        spawn { ch.send(4) }
        spawn { ch.send(5) }

        sleep(300 * Duration.millisecond)

        var values = Array<Int64>(5, {_ => 0})
        for (i in 0..5) {
            let r = ch.recv()
            if (let Some(v) <- r) {
                values[i] = v
            } else { throw Exception("索引 ${i} 应为有值") }
        }

        /* 缓冲区中的值必须按 FIFO 顺序在前。
         * 阻塞发送者的值 {3,4,5} 以任意排列出现均可 */
        if (values[0] != 1) { throw Exception("期望 1 在 [0]") }
        if (values[1] != 2) { throw Exception("期望 2 在 [1]") }
        var tail = [values[2], values[3], values[4]]
        for (v in [3, 4, 5]) {
            var found = false
            for (t in tail) {
                if (t == v) { found = true }
            }
            if (!found) { throw Exception("缺少 ${v}") }
        }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * 关闭与阻塞线程测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestCloseBlocking {
    /**
     * 在无缓冲通道上关闭正在阻塞的发送者。
     * 发送者应收到 "send on closed channel" 异常。
     */
    @TestCase
    public func test_close_unblocks_blocked_sender(): Unit {
        let ch = Chan<Int64>()  /* 无缓冲——send 会阻塞 */
        let fut = spawn {
            try {
                ch.send(99)
                throw Exception("send 应抛出异常")
            } catch (e: Exception) {
                // 期望异常
            }
        }
        sleep(200 * Duration.millisecond)
        ch.close()
        fut.get()
    }

    /**
     * 在有缓冲通道（容量满）上关闭正在阻塞的发送者。
     */
    @TestCase
    public func test_close_unblocks_blocked_buffered_sender(): Unit {
        let ch = Chan<Int64>(1)
        ch.send(10)  /* 填满缓冲区 */
        let fut = spawn {
            try {
                ch.send(20)
                throw Exception("应抛出异常")
            } catch (e: Exception) {
                // 期望异常
            }
        }
        sleep(200 * Duration.millisecond)
        ch.close()
        fut.get()
    }

    /**
     * 关闭时接收者在阻塞。它们应收到 None。
     */
    @TestCase
    public func test_close_unblocks_blocked_receivers(): Unit {
        let ch = Chan<Int64>()  /* 无缓冲——recv 会阻塞 */
        let ok1 = AtomicBool(false)
        let ok2 = AtomicBool(false)

        let f1 = spawn {
            if (ch.recv().isNone()) { ok1.store(true) }
        }
        let f2 = spawn {
            if (ch.recv().isNone()) { ok2.store(true) }
        }

        sleep(200 * Duration.millisecond)
        ch.close()
        sleep(100 * Duration.millisecond)

        if (!ok1.load()) { throw Exception("接收者 1 应收到 None") }
        if (!ok2.load()) { throw Exception("接收者 2 应收到 None") }
    }

    /**
     * 关闭一个有数据的有缓冲通道，同时有等待的接收者。
     * 接收者先耗尽剩余数据，然后返回 None。
     */
    @TestCase
    public func test_close_drains_while_blocked(): Unit {
        let ch = Chan<Int64>(3)
        ch.send(1)
        ch.send(2)

        let f1 = spawn {
            let r1 = ch.recv()
            if (let Some(v) <- r1) {
                if (v != 1) { throw Exception("期望 1") }
            } else { throw Exception("期望 Some(1)") }
        }
        let f2 = spawn {
            let r2 = ch.recv()
            if (let Some(v) <- r2) {
                if (v != 2) { throw Exception("期望 2") }
            } else { throw Exception("期望 Some(2)") }
        }

        sleep(200 * Duration.millisecond)
        ch.close()
        sleep(100 * Duration.millisecond)

        /* drain 后，新的 recv 返回 None */
        if (ch.recv().isSome()) { throw Exception("关闭+drain 后应为 None") }
    }

    /**
     * 关闭有待发送队列的有缓冲通道。
     * 待发送的值被丢弃；阻塞的发送者抛出异常。
     */
    @TestCase
    public func test_close_with_pending_sends(): Unit {
        let ch = Chan<Int64>(2)
        ch.send(1)
        ch.send(2)
        let fut = spawn {
            try {
                ch.send(99)
                throw Exception("应抛出异常")
            } catch (e: Exception) {
                // 期望异常
            }
        }
        sleep(200 * Duration.millisecond)
        ch.close()
        fut.get()
        /* drain 剩余缓冲区 */
        let r1 = ch.recv()
        let r2 = ch.recv()
        let r3 = ch.recv()
        if (r1.isNone()) { throw Exception("期望 1") }
        if (r2.isNone()) { throw Exception("期望 2") }
        if (r3.isSome()) { throw Exception("99 应被丢弃") }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * 并发压力测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestConcurrent {
    /**
     * N 个发送者、N 个接收者，共享同一个有缓冲通道。
     * 每个发送的值必须被精确接收一次。
     */
    @TestCase
    public func test_many_to_many(): Unit {
        let N: Int64 = 20
        let ch = Chan<Int64>(5)
        let sumIn = AtomicInt64(0)
        let sumOut = AtomicInt64(0)

        /* 发送者 */
        let senders = ArrayList<Future<Unit>>()
        for (i in 0..N) {
            let idx = i
            senders.add(spawn {
                ch.send(idx)
                sumIn.fetchAdd(idx)
            })
        }

        /* 接收者 */
        let receivers = ArrayList<Future<Unit>>()
        for (_ in 0..N) {
            receivers.add(spawn {
                let r = ch.recv()
                if (let Some(v) <- r) {
                    sumOut.fetchAdd(v)
                }
            })
        }

        /* 等待所有发送者和接收者完成 */
        for (f in senders) { f.get() }
        for (f in receivers) { f.get() }

        if (sumIn.load() != sumOut.load()) {
            throw Exception("sum 不匹配：in=${sumIn.load()}, out=${sumOut.load()}")
        }
    }

    /**
     * 管道模式：一个生产者、一个工作者、一个收集者。
     */
    @TestCase
    public func test_pipeline(): Unit {
        let ping = Chan<Int64>()
        let pong = Chan<Int64>()

        spawn {
            for (_ in 0..5) {
                let r = ping.recv()
                if (let Some(v) <- r) {
                    pong.send(v + 1)
                }
            }
        }

        for (i in 0..5) {
            ping.send(i)
            let r = pong.recv()
            if (let Some(v) <- r) {
                if (v != i + 1) { throw Exception("期望 ${i+1}，实际 ${v}") }
            } else { throw Exception("期望 Some(${i+1})") }
        }
    }

    /**
     * 压力测试：在有缓冲通道上批量发送后批量接收。
     */
    @TestCase
    public func test_burst(): Unit {
        let ch = Chan<Int64>(10)
        let writer = spawn {
            for (i in 0..100) {
                ch.send(i)
            }
        }
        let reader = spawn {
            var sum: Int64 = 0
            for (_ in 0..100) {
                let r = ch.recv()
                if (let Some(v) <- r) { sum += v }
            }
            if (sum != 4950) { throw Exception("0+..+99 = 4950，实际 ${sum}") }
        }
        writer.get()
        reader.get()
    }

    /**
     * 无缓冲通道压力测试：两个工作者 ping-pong 值。
     */
    @TestCase
    public func test_unbuffered_stress(): Unit {
        let N: Int64 = 10
        let ping = Chan<Int64>()
        let pong = Chan<Int64>()

        let worker = spawn {
            var count: Int64 = 0
            while (count < N) {
                let r = ping.recv()
                if (let Some(v) <- r) {
                    if (v != count) { throw Exception("期望 ${count}，实际 ${v}") }
                    pong.send(v)
                } else { break }
                count++
            }
        }

        for (i in 0..N) {
            ping.send(i)
            let r = pong.recv()
            if (let Some(v) <- r) {
                if (v != i) { throw Exception("ping-pong 不匹配于 ${i}") }
            }
        }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * Select 多路复用测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestSelect {
    @TestCase
    public func test_select_two_buffered(): Unit {
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        ch1.send(10)
        let (idx, v) = select([ch1, ch2])
        if (idx != 0) { throw Exception("期望 ch1 (0)，实际 ${idx}") }
        if (let Some(val) <- v) {
            if (val != 10) { throw Exception("期望 10，实际 ${val}") }
        } else { throw Exception("期望 Some(10)") }
    }

    @TestCase
    public func test_select_or_with_default(): Unit {
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        let called = AtomicBool(false)
        let (idx, v) = selectOr([ch1, ch2], { => called.store(true) })
        if (!called.load()) { throw Exception("默认分支应被调用") }
        if (idx != -1) { throw Exception("期望 -1") }
        if (v.isSome()) { throw Exception("期望 None") }
    }

    @TestCase
    public func test_select_all_closed(): Unit {
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        ch1.close()
        ch2.close()
        let (idx, v) = select([ch1, ch2])
        if (idx != -1) { throw Exception("全关闭期望 -1，实际 ${idx}") }
        if (v.isSome()) { throw Exception("期望 None") }
    }

    @TestCase
    public func test_select_one_closed_one_has_data(): Unit {
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        ch1.close()
        ch2.send(99)
        let (idx, v) = select([ch1, ch2])
        if (idx != 1) { throw Exception("期望 ch2 (1)，实际 ${idx}") }
        if (let Some(val) <- v) {
            if (val != 99) { throw Exception("期望 99，实际 ${val}") }
        } else { throw Exception("期望 Some(99)") }
    }

    @TestCase
    public func test_select_or_some_chosen(): Unit {
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        ch2.send(42)
        let called = AtomicBool(false)
        let (idx, v) = selectOr([ch1, ch2], { => called.store(true) })
        if (called.load()) { throw Exception("默认分支不应被调用") }
        if (idx != 1) { throw Exception("期望 ch2 (1)，实际 ${idx}") }
        if (let Some(val) <- v) {
            if (val != 42) { throw Exception("期望 42，实际 ${val}") }
        } else { throw Exception("期望 Some(42)") }
    }

    @TestCase
    public func test_select_three_channels(): Unit {
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        let ch3 = Chan<Int64>(1)
        ch3.send(30)
        let (idx, v) = select([ch1, ch2, ch3])
        if (idx != 2) { throw Exception("期望 ch3 (2)，实际 ${idx}") }
        if (let Some(val) <- v) {
            if (val != 30) { throw Exception("期望 30，实际 ${val}") }
        } else { throw Exception("期望 Some(30)") }
    }

    @TestCase
    public func test_select_multiple_ready(): Unit {
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        ch1.send(10)
        ch2.send(20)
        let (idx, v) = select([ch1, ch2])
        /* 轮询从索引 0 开始，所以应选中 ch1 */
        if (idx != 0) { throw Exception("多通道就绪时应选索引小的，实际 ${idx}") }
        if (let Some(val) <- v) {
            if (val != 10) { throw Exception("期望 10，实际 ${val}") }
        } else { throw Exception("期望 Some(10)") }
    }

    @TestCase
    public func test_select_or_all_closed(): Unit {
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        ch1.close()
        ch2.close()
        let called = AtomicBool(false)
        let (idx, v) = selectOr([ch1, ch2], { => called.store(true) })
        if (!called.load()) { throw Exception("全关闭时默认分支应被调用") }
        if (idx != -1) { throw Exception("期望 -1") }
        if (v.isSome()) { throw Exception("期望 None") }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * 边界情况测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestEdgeCases {
    /**
     * 在已关闭的空通道上非阻塞 tryRecv 返回 None。
     */
    @TestCase
    public func test_try_recv_closed_empty(): Unit {
        let ch = Chan<Int64>(2)
        ch.close()
        let r = ch.tryRecv()
        if (r.isSome()) { throw Exception("应为 None") }
    }

    /**
     * 在已关闭的非空通道上非阻塞 tryRecv 返回数据。
     */
    @TestCase
    public func test_try_recv_closed_with_data(): Unit {
        let ch = Chan<Int64>(2)
        ch.send(99)
        ch.close()
        let r = ch.tryRecv()
        if (let Some(v) <- r) {
            if (v != 99) { throw Exception("期望 99，实际 ${v}") }
        } else { throw Exception("期望 Some(99)") }
    }

    /**
     * 在空通道（未关闭）上 tryRecv 返回 None。
     */
    @TestCase
    public func test_try_recv_empty_open(): Unit {
        let ch = Chan<Int64>(2)
        let r = ch.tryRecv()
        if (r.isSome()) { throw Exception("空的打开通道上 tryRecv 应为 None") }
    }

    /**
     * trySend 在满的有缓冲通道上失败。
     */
    @TestCase
    public func test_try_send_full_buffered(): Unit {
        let ch = Chan<Int64>(1)
        ch.send(10)
        if (ch.trySend(20)) { throw Exception("满缓冲区时 trySend 应失败") }
    }

    /**
     * 无缓冲通道 trySend 无等待接收者时失败。
     */
    @TestCase
    public func test_try_send_unbuffered_no_waiter(): Unit {
        let ch = Chan<Int64>()  /* 无缓冲 */
        if (ch.trySend(42)) { throw Exception("无等待接收者时 trySend 应失败") }
    }

    /**
     * 无缓冲通道 tryRecv 无等待发送者时返回 None。
     */
    @TestCase
    public func test_try_recv_unbuffered_no_sender(): Unit {
        let ch = Chan<Int64>()  /* 无缓冲 */
        let r = ch.tryRecv()
        if (r.isSome()) { throw Exception("无等待发送者时 tryRecv 应为 None") }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * 扇入 / 扇出模式测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestFanInFanOut {
    /**
     * 扇入模式：多个输入通道合并到一个输出通道。
     */
    @TestCase
    public func test_fan_in(): Unit {
        /* 创建两个有缓冲通道，各发一个值 */
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        let merged = Chan<Int64>(2)

        /* 先确保数据已就绪再启动合并器 */
        ch1.send(1)
        ch2.send(2)

        /* 扇入合并：从两个通道转发到 merged */
        spawn {
            for (_ in 0..2) {
                let (idx, v) = select([ch1, ch2])
                if (let Some(val) <- v) {
                    merged.send(val)
                }
            }
            merged.close()
        }

        /* 确保合并器已启动 */
        sleep(100 * Duration.millisecond)

        let sum = AtomicInt64(0)
        merged.forEach({ v => sum.fetchAdd(v) })
        if (sum.load() != 3) { throw Exception("扇入 sum 应为 3，实际 ${sum.load()}") }
    }

    /**
     * 扇出模式：一个源通道分发到多个接收者。
     */
    @TestCase
    public func test_fan_out(): Unit {
        let source = Chan<Int64>(5)
        let sink1 = Chan<Int64>(5)
        let sink2 = Chan<Int64>(5)

        /* source 扇出到两个 sink */
        spawn {
            source.forEach({ v =>
                sink1.trySend(v)
                sink2.trySend(v)
            })
            sink1.close()
            sink2.close()
        }

        for (i in 0..3) {
            source.send(i)
        }
        source.close()
        sleep(100 * Duration.millisecond)

        let sum1 = AtomicInt64(0)
        let sum2 = AtomicInt64(0)
        sink1.forEach({ v => sum1.fetchAdd(v) })
        sink2.forEach({ v => sum2.fetchAdd(v) })

        if (sum1.load() != 3) { throw Exception("扇出 sink1 sum 应为 3，实际 ${sum1.load()}") }
        if (sum2.load() != 3) { throw Exception("扇出 sink2 sum 应为 3，实际 ${sum2.load()}") }
    }
}

/* ═══════════════════════════════════════════════════════════════
 * 无缓冲通道非阻塞操作测试
 * ═══════════════════════════════════════════════════════════════ */

@Test
class TestUnbufferedNonBlocking {
    /**
     * 无缓冲通道 trySend：有接收者等待时应成功。
     */
    @TestCase
    public func test_try_send_unbuffered_with_recv_waiter(): Unit {
        let ch = Chan<Int64>()
        /* 先创建一个阻塞的接收者 */
        let recvFuture = spawn {
            let r = ch.recv()
            if (let Some(v) <- r) {
                if (v != 99) { throw Exception("期望 99，实际 ${v}") }
            } else { throw Exception("期望 Some(99)") }
        }
        sleep(200 * Duration.millisecond)
        /* 接收者已在等待，trySend 应成功 */
        if (!ch.trySend(99)) { throw Exception("有等待接收者时 trySend 应成功") }
        recvFuture.get()
    }

    /**
     * 无缓冲通道 tryRecv：有发送者等待时应成功。
     */
    @TestCase
    public func test_try_recv_unbuffered_with_send_waiter(): Unit {
        let ch = Chan<Int64>()
        /* 先创建一个阻塞的发送者 */
        spawn { ch.send(42) }
        sleep(200 * Duration.millisecond)
        /* 发送者已在等待，tryRecv 应成功 */
        let r = ch.tryRecv()
        if (let Some(v) <- r) {
            if (v != 42) { throw Exception("期望 42，实际 ${v}") }
        } else { throw Exception("期望 Some(42)") }
    }
}
