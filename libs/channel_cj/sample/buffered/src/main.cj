package sample_buffered

import channel_cj.*

/**
 * 有缓冲通道演示
 *
 * 演示：
 *  - 不同容量的通道
 *  - FIFO 顺序保证
 *  - len（当前元素数）与 cap（容量）
 *  - 生产者-消费者模式
 */
main() {
    println("=== 1. FIFO 顺序验证 ===")
    let ch = Chan<Int64>(5)
    for (i in 0..5) {
        ch.send(i * 10)
    }
    println("  cap=${ch.cap()}, len=${ch.len()}")
    while (ch.len() > 0) {
        let r = ch.recv()
        if (let Some(v) <- r) {
            println("  接收: ${v}")   // 期望输出 0, 10, 20, 30, 40
        }
    }

    println("\n=== 2. 生产者-消费者模式 ===")
    let buf = Chan<String>(3)
    /* 生产者 */
    spawn {
        for (i in 0..5) {
            buf.send("消息-${i}")
            println("  [生产者] 发送: 消息-${i}（len=${buf.len()}）")
        }
        buf.close()
    }
    /* 消费者 */
    buf.forEach({ v =>
        println("  [消费者] 处理: ${v}（len=${buf.len()}）")
    })

    println("\n有缓冲通道示例运行完毕。")
}
