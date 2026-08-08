package sample_pipeline

import channel_cj.*
import std.sync.AtomicInt64

/**
 * 管道流水线模式演示
 *
 * 类似于 Go 的 pipeline 模式，使用通道串联多个
 * 处理阶段。每个阶段由一个 spawn 线程处理数据。
 */
main() {
    println("=== 管道模式：整数流水线 ===")

    /* 阶段 1：产生原始数据 */
    let stage1 = Chan<Int64>(10)
    spawn {
        for (i in 0..5) {
            stage1.send(i)
            println("  [阶段1] 产生: ${i}")
        }
        stage1.close()
    }

    /* 阶段 2：乘以 2 */
    let stage2 = Chan<Int64>(10)
    spawn {
        stage1.forEach({ v =>
            let result = v * 2
            stage2.send(result)
            println("  [阶段2] 转换: ${v} -> ${result}")
        })
        stage2.close()
    }

    /* 阶段 3：累加结果 */
    let stage3 = Chan<String>(10)
    spawn {
        let sum = AtomicInt64(0)
        stage2.forEach({ v =>
            sum.fetchAdd(v)
            stage3.send("当前累加: ${sum.load()}")
        })
        stage3.close()
    }

    /* 收集最终输出 */
    let finalSum = AtomicInt64(0)
    stage3.forEach({ v =>
        println("  [阶段3] ${v}")
    })

    println("\n管道模式示例运行完毕。")
}
