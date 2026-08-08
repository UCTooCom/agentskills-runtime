package sample_fan_out

import channel_cj.*

/**
 * 扇出（Fan-out）模式演示
 *
 * 将一个源通道的数据分发到多个接收通道。
 * 适用于广播、日志分发、事件通知等场景。
 */
main() {
    println("=== 扇出模式：一源多播 ===")

    let source = Chan<String>(10)
    let sink1 = Chan<String>(10)
    let sink2 = Chan<String>(10)
    let sink3 = Chan<String>(10)

    /* 分发器：从 source 读取并广播到所有 sink */
    spawn {
        source.forEach({ v =>
            println("  [分发器] 广播: ${v}")
            sink1.send(v)
            sink2.send(v)
            sink3.send(v)
        })
        sink1.close()
        sink2.close()
        sink3.close()
    }

    /* 三个接收者分别从各自的 sink 读取 */
    spawn {
        sink1.forEach({ v => println("  [接收者 A] 收到: ${v}") })
    }
    spawn {
        sink2.forEach({ v => println("  [接收者 B] 收到: ${v}") })
    }
    spawn {
        sink3.forEach({ v => println("  [接收者 C] 收到: ${v}") })
    }

    /* 发送数据 */
    for (i in 0..3) {
        source.send("事件-${i}")
        println("  [主线程] 发布: 事件-${i}")
        sleep(50 * Duration.millisecond)
    }
    source.close()

    sleep(300 * Duration.millisecond)

    println("\n扇出模式示例运行完毕。")
}
