package sample_basic

import channel_cj.*

/**
 * 通道基础用法示例
 *
 * 演示：
 *  - 创建有缓冲和无缓冲通道
 *  - 基本发送和接收（send / recv）
 *  - 非阻塞收发（trySend / tryRecv）
 *  - 关闭通道与 forEach 遍历
 */
main() {
    println("=== 1. 有缓冲通道：发送与接收 ===")
    let ch = Chan<Int64>(3)
    for (i in 0..3) {
        ch.send(i)
        println("  发送: ${i}")
    }
    for (_ in 0..3) {
        let r = ch.recv()
        if (let Some(v) <- r) {
            println("  接收: ${v}")
        }
    }

    println("\n=== 2. 非阻塞 trySend / tryRecv ===")
    let nc = Chan<Int64>(2)
    println("  trySend(10): ${nc.trySend(10)}")   // true
    println("  trySend(20): ${nc.trySend(20)}")   // true
    println("  trySend(30): ${nc.trySend(30)}")   // false（已满）

    let r1 = nc.tryRecv()
    if (let Some(v) <- r1) { println("  tryRecv: ${v}") }

    let r2 = nc.tryRecv()
    if (let Some(v) <- r2) { println("  tryRecv: ${v}") }

    let r3 = nc.tryRecv()
    if (r3.isNone()) { println("  tryRecv: None（通道为空）") }

    println("\n=== 3. 关闭与遍历 ===")
    let fc = Chan<String>(3)
    fc.send("hello")
    fc.send("world")
    fc.send("channel")
    fc.close()
    fc.forEach({ v => println("  forEach: ${v}") })

    println("\n示例运行完毕。")
}
