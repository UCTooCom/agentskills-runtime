package channel_bench

import channel_cj.*

/**
 * 基准测试：重复执行操作，使用 Duration 进行计时
 * DateTime 和 Duration 通过 std.time 使用
 */
import std.time.DateTime

func bench(count: Int64, name: String, action: () -> Unit): Unit {
    for (_ in 0..50) { action() }

    let start = DateTime.now()
    for (_ in 0..count) { action() }
    let elapsed = DateTime.now() - start
    let nanos = elapsed.toNanoseconds() / count
    let opsPerSec = 1_000_000_000 / nanos

    println("  ${name}:")
    println("    单次耗时: ${nanos} ns")
    println("    吞吐量:   ${opsPerSec} ops/s")
}

/* 通道创建基准 */
func benchCreate(name: String, cap: Int64, count: Int64): Unit {
    bench(count, name, { =>
        let ch = Chan<Int64>(cap)
        let _ = ch.cap()
    })
}

/* 基本操作基准 */
func benchTrySend(cap: Int64, count: Int64): Unit {
    bench(count, "trySend（有空位）", { =>
        let ch = Chan<Int64>(cap)
        let _ = ch.trySend(42)
    })
}

func benchSend(cap: Int64, count: Int64): Unit {
    bench(count, "send（有空位）", { =>
        let ch = Chan<Int64>(cap)
        ch.send(42)
    })
}

func benchTryRecv(cap: Int64, count: Int64): Unit {
    bench(count, "tryRecv（空通道）", { =>
        let ch = Chan<Int64>(cap)
        let _ = ch.tryRecv()
    })
}

func benchTrySendFull(count: Int64): Unit {
    bench(count, "trySend（缓冲区满）", { =>
        let ch = Chan<Int64>(1)
        ch.send(1)
        let _ = ch.trySend(2)
    })
}

func benchTrySendNoWaiter(count: Int64): Unit {
    bench(count, "trySend（无缓冲无等待者）", { =>
        let ch = Chan<Int64>()
        let _ = ch.trySend(42)
    })
}

func benchTryRecvNoSender(count: Int64): Unit {
    bench(count, "tryRecv（无缓冲无等待者）", { =>
        let ch = Chan<Int64>()
        let _ = ch.tryRecv()
    })
}

func benchLenCap(count: Int64): Unit {
    bench(count, "len + cap", { =>
        let ch = Chan<Int64>(10)
        ch.send(5)
        let _ = ch.len() + ch.cap()
    })
}

func benchIsClosed(count: Int64): Unit {
    bench(count, "isClosed", { =>
        let ch = Chan<Int64>(10)
        let _ = ch.isClosed()
        ch.close()
        let _ = ch.isClosed()
    })
}

func benchFifo1(count: Int64): Unit {
    bench(count, "send/recv 1 对", { =>
        let ch = Chan<Int64>(10)
        ch.send(100)
        let r = ch.recv().getOrThrow()
        let _ = r
    })
}

func benchFifo3(count: Int64): Unit {
    bench(count, "send/recv 3 对 FIFO", { =>
        let ch = Chan<Int64>(10)
        ch.send(1)
        ch.send(2)
        ch.send(3)
        let r1 = ch.recv().getOrThrow()
        let r2 = ch.recv().getOrThrow()
        let r3 = ch.recv().getOrThrow()
        let _ = r1 + r2 + r3
    })
}

func benchSelect2(count: Int64): Unit {
    bench(count, "select（2 通道，1 有数据）", { =>
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        ch2.send(99)
        let (idx, v) = select([ch1, ch2])
        let _ = idx
    })
}

func benchSelect3(count: Int64): Unit {
    bench(count, "select（3 通道，1 有数据）", { =>
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        let ch3 = Chan<Int64>(1)
        ch3.send(99)
        let (idx, v) = select([ch1, ch2, ch3])
        let _ = idx
    })
}

func benchSelectOr(count: Int64): Unit {
    bench(count, "selectOr（全空，执行默认）", { =>
        let ch1 = Chan<Int64>(1)
        let ch2 = Chan<Int64>(1)
        let (idx, v) = selectOr([ch1, ch2], { => })
        let _ = idx
    })
}

func benchClose(count: Int64): Unit {
    bench(count, "close（空通道）", { =>
        let ch = Chan<Int64>(10)
        ch.close()
    })
}

func benchCloseAndIsClosed(count: Int64): Unit {
    bench(count, "close + isClosed", { =>
        let ch = Chan<Int64>(10)
        ch.close()
        let _ = ch.isClosed()
    })
}


func benchCloseWithData(count: Int64): Unit {
    bench(count, "close + drain（有数据）", { =>
        let ch = Chan<Int64>(10)
        ch.send(1)
        ch.send(2)
        ch.send(3)
        ch.close()
        ch.forEach({ v => })
    })
}

func benchTryRecvSuccess(count: Int64): Unit {
    bench(count, "tryRecv（非空通道）", { =>
        let ch = Chan<Int64>(10)
        ch.trySend(42)
        let r = ch.tryRecv()
        let _ = r.isSome()
    })
}

func benchForEachSmall(count: Int64): Unit {
    bench(count, "forEach（3 项后关闭）", { =>
        let ch = Chan<Int64>(10)
        ch.send(1)
        ch.send(2)
        ch.send(3)
        ch.close()
        ch.forEach({ v => })
    })
}

func benchCloseTwice(count: Int64): Unit {
    bench(count, "close × 2（异常路径）", { =>
        let ch = Chan<Int64>(10)
        ch.close()
        try { ch.close() } catch (e: Exception) { }
    })
}

main() {
    let N: Int64 = 5000

    println("============================================================")
    println("  channel_cj 性能基准测试")
    println("  每次测试 ${N} 次迭代")
    println("============================================================")
    println()

    println("【通道创建】")
    benchCreate("Chan<Int64>() 无缓冲", 0, N)
    benchCreate("Chan<Int64>(10) 有缓冲", 10, N)
    benchCreate("Chan<Int64>(1000) 有缓冲", 1000, N)
    println()

    println("【基本操作】")
    benchTrySend(100, N)
    benchSend(100, N)
    benchTryRecv(100, N)
    println()

    println("【非阻塞失败路径】")
    benchTrySendFull(N)
    benchTrySendNoWaiter(N)
    benchTryRecvNoSender(N)
    println()

    println("【查询操作】")
    benchLenCap(N)
    benchIsClosed(N)
    println()

    println("【FIFO 操作】")
    let N2 = N / 5
    benchFifo1(N2)
    benchFifo3(N2)
    println()

    println("【select 多路复用】")
    benchSelect2(N)
    benchSelect3(N)
    benchSelectOr(N)
    println()

    println("【关闭操作】")
    benchClose(N)
    benchCloseAndIsClosed(N)
    println()
    benchCloseWithData(N / 5)
    benchForEachSmall(N / 5)
    benchCloseTwice(N)
    println()
    println("【进阶操作】")
    benchTryRecvSuccess(N)

    println()
    println()
    println("============================================================")
    println("  基准测试完成")
    println("============================================================")
}
