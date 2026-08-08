package sample_close

import channel_cj.*

/**
 * 通道关闭与生命周期管理演示
 *
 * 演示：
 *  - 正常关闭与 drain（耗尽数据）
 *  - 关闭后接收返回 None
 *  - 关闭后发送抛出异常
 *  - forEach 遍历到关闭
 *  - trySend / tryRecv 在关闭后的行为
 */
main() {
    println("=== 1. 关闭后 drain（读尽数据）===")
    let ch = Chan<Int64>(3)
    ch.send(1)
    ch.send(2)
    ch.send(3)
    ch.close()
    println("  关闭后 len=${ch.len()}")

    /* drain 缓冲区 */
    while (true) {
        let r = ch.recv()
        if (let Some(v) <- r) {
            println("  读出: ${v}")
        } else {
            println("  通道已空，返回 None")
            break
        }
    }

    println("\n=== 2. 关闭后发送失败 ===")
    let dc = Chan<Int64>(2)
    dc.close()
    try {
        dc.send(99)
    } catch (e: Exception) {
        println("  send 抛出异常: ${e.message}")
    }

    println("\n=== 3. 关闭后 trySend / tryRecv ===")
    let ec = Chan<Int64>(2)
    ec.send(10)
    ec.close()
    println("  trySend 返回: ${ec.trySend(20)}")  // false
    let r = ec.tryRecv()
    if (let Some(v) <- r) {
        println("  tryRecv: ${v}")  // 10
    }
    let r2 = ec.tryRecv()
    if (r2.isNone()) {
        println("  第二次 tryRecv: None（通道已空）")
    }

    println("\n=== 4. forEach 自动处理关闭 ===")
    let fc = Chan<String>(2)
    fc.send("开始")
    fc.send("结束")
    fc.close()
    fc.forEach({ v => println("  ${v}") })

    println("\n关闭通道示例运行完毕。")
}
