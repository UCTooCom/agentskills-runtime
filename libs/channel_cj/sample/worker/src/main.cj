package sample_worker

import channel_cj.*

/**
 * 工作池模式演示
 *
 * 创建多个 worker 线程从共享任务通道中消费任务。
 * 适用于任务分发、并行处理等场景。
 */
main() {
    println("=== 工作池模式 ===")

    let tasks = Chan<Int64>(10)
    let NUM_WORKERS: Int64 = 3
    let NUM_TASKS: Int64 = 9

    /* 启动 worker 池 */
    for (wid in 0..NUM_WORKERS) {
        let id = wid
        spawn {
            while (true) {
                let r = tasks.recv()
                if (let Some(task) <- r) {
                    println("  [worker ${id}] 执行任务 ${task}")
                } else {
                    println("  [worker ${id}] 通道关闭，退出")
                    break
                }
            }
        }
    }

    /* 生产任务 */
    for (i in 0..NUM_TASKS) {
        println("  [主线程] 发布任务 ${i}")
        tasks.send(i)
    }
    tasks.close()

    /* 等待所有 worker 处理完毕 */
    sleep(500 * Duration.millisecond)

    println("\n工作池模式示例运行完毕。")
}
