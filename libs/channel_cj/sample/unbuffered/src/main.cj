package sample_unbuffered

import channel_cj.*

/**
 * 无缓冲通道演示
 *
 * 无缓冲通道的 send 会阻塞直到有接收者就绪，
 * 反之亦然。这使线程间同步变得简单安全。
 *
 * 演示：
 *  - 线程间同步握手
 *  - 阻塞特性
 */
main() {
    println("=== 1. 线程间同步 ===")
    let ch = Chan<Int64>()
    spawn {
        println("  [子线程] 发送前...")
        ch.send(42)
        println("  [子线程] 已发送")
    }
    println("  [主线程] 准备接收...")
    let r = ch.recv()
    if (let Some(v) <- r) {
        println("  [主线程] 收到: ${v}")
    }

    println("\n=== 2. 双工通信（ping-pong）===")
    let ping = Chan<Int64>()
    let pong = Chan<Int64>()

    spawn {
        for (_ in 0..3) {
            let v = ping.recv().getOrThrow()
            println("  [worker] 收到 ping: ${v}")
            pong.send(v + 1)
        }
    }

    for (i in 0..3) {
        println("  [main] 发送 ping: ${i}")
        ping.send(i)
        let v = pong.recv().getOrThrow()
        println("  [main] 收到 pong: ${v}")
    }

    println("\n无缓冲通道示例运行完毕。")
}
