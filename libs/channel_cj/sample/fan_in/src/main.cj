package sample_fan_in

import channel_cj.*
import std.sync.AtomicInt64

/**
 * 扇入（Fan-in）模式演示
 *
 * 将多个输入通道的数据合并到一个输出通道中。
 * 类似于 Go 中的扇入模式，使用 select 实现多路合并。
 */
main() {
    println("=== 扇入模式：多路合并 ===")

    /* 创建两个输入通道 */
    let input1 = Chan<Int64>(5)
    let input2 = Chan<Int64>(5)
    let merged = Chan<Int64>(10)

    /* 输入源 1 */
    spawn {
        for (i in 0..3) {
            input1.send(i)
            println("  [输入1] 发送: ${i}")
            sleep(30 * Duration.millisecond)
        }
        input1.close()
    }

    /* 输入源 2 */
    spawn {
        for (i in 10..13) {
            input2.send(i)
            println("  [输入2] 发送: ${i}")
            sleep(50 * Duration.millisecond)
        }
        input2.close()
    }

    /* 合并器：使用 select 从两个输入中转发到 merged */
    spawn {
        var input1Alive = true
        var input2Alive = true
        while (input1Alive || input2Alive) {
            let channels = if (input1Alive && input2Alive) {
                [input1, input2]
            } else if (input1Alive) {
                [input1]
            } else {
                [input2]
            }
            let (idx, v) = select(channels)
            if (let Some(val) <- v) {
                merged.send(val)
                println("  [合并器] 转发: ${val}")
            } else {
                if (input1Alive) { input1Alive = false }
                if (input2Alive) { input2Alive = false }
            }
        }
        merged.close()
    }

    /* 收集结果 */
    let sum = AtomicInt64(0)
    merged.forEach({ v =>
        sum.fetchAdd(v)
        println("  [收集器] 收到: ${v}")
    })
    println("  总数之和: ${sum.load()}（期望: 0+1+2+10+11+12=36）")

    println("\n扇入模式示例运行完毕。")
}
