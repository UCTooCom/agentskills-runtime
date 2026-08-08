package sample_select

import channel_cj.*

/**
 * select 多路复用演示
 *
 * 演示：
 *  - select：从多个通道中读取第一个就绪的数据
 *  - selectOr：带默认分支的非阻塞 select
 *  - 通道关闭时的 select 行为
 */
main() {
    println("=== 1. select：多路接收 ===")
    let ch1 = Chan<Int64>(1)
    let ch2 = Chan<Int64>(1)
    ch2.send(100)
    let (idx, val) = select([ch1, ch2])
    if (let Some(v) <- val) {
        println("  从 ch${idx} 收到: ${v}")
    }

    println("\n=== 2. selectOr：带默认分支 ===")
    let empty1 = Chan<Int64>(1)
    let empty2 = Chan<Int64>(1)
    let (idx2, val2) = selectOr([empty1, empty2], { =>
        println("  默认分支：所有通道为空，执行其他操作")
    })
    if (val2.isNone()) {
        println("  selectOr 返回 None（执行了默认分支）")
    }

    println("\n=== 3. 通道关闭时的 select ===")
    let openCh = Chan<Int64>(1)
    let closedCh = Chan<Int64>(1)
    closedCh.close()
    openCh.send(42)
    let (idx3, val3) = select([openCh, closedCh])
    if (let Some(v) <- val3) {
        println("  从 ch${idx3} 收到: ${v}（已跳过已关闭通道）")
    }

    println("\n=== 4. 全关闭通道 ===")
    let ca = Chan<Int64>(1)
    let cb = Chan<Int64>(1)
    ca.close()
    cb.close()
    let (idx4, val4) = select([ca, cb])
    println("  全关闭后 select 返回: (${idx4}, isSome=${val4.isSome()})")

    println("\nselect 示例运行完毕。")
}
