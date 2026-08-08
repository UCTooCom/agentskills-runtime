# 常用并发模式

## 生产者-消费者

有缓冲通道天然支持生产者-消费者模式。生产者向通道发送数据，消费者从通道接收数据，两者通过缓冲区解耦。

```cangjie
let ch = Chan<String>(10)

// 生产者
spawn {
    for (i in 0..10) {
        ch.send("任务 ${i}")
    }
    ch.close()
}

// 消费者
ch.forEach({ msg => println("处理: ${msg}") })
```

**适用场景：** 任务队列、日志处理、消息推送

---

## 工作池（Worker Pool）

多个 worker 从共享通道中并发消费任务，提高处理吞吐量。

```cangjie
let tasks = Chan<Int64>(10)

// 启动 4 个 worker
for (wid in 0..4) {
    spawn {
        while (true) {
            let r = tasks.recv()
            if (let Some(t) <- r) {
                // 处理任务
            } else { break }  // 通道关闭，退出
        }
    }
}

// 分发任务
for (i in 0..20) { tasks.send(i) }
tasks.close()
```

**适用场景：** 并行计算、批量处理、任务调度

---

## 管道（Pipeline）

用多个通道串联多个处理阶段，每个阶段由一个线程处理。

```cangjie
let stage1 = Chan<Int64>(10)
let stage2 = Chan<Int64>(10)

// 阶段 1：产生数据
spawn {
    for (i in 0..5) { stage1.send(i) }
    stage1.close()
}

// 阶段 2：处理数据
spawn {
    stage1.forEach({ v => stage2.send(v * 2) })
    stage2.close()
}

// 收集结果
stage2.forEach({ v => println("${v}") })
```

**适用场景：** 数据流处理、ETL、图像/音频处理管线

---

## 扇入（Fan-in）

将多个输入通道的数据合并到一个输出通道中。

```cangjie
let ch1 = Chan<Int64>(1)
let ch2 = Chan<Int64>(1)
let merged = Chan<Int64>(2)

// 合并两个输入
spawn {
    let count = 2
    while (count > 0) {
        let (idx, v) = select([ch1, ch2])
        if (let Some(val) <- v) {
            merged.send(val)
        } else {
            count--
        }
    }
    merged.close()
}
```

**适用场景：** 多源数据聚合、日志合并、结果汇总

---

## 扇出（Fan-out）

将一个源通道的数据广播到多个接收通道。

```cangjie
let source = Chan<String>(10)
let sink1 = Chan<String>(10)
let sink2 = Chan<String>(10)

// 广播到所有 sink
spawn {
    source.forEach({ v =>
        sink1.send(v)
        sink2.send(v)
    })
    sink1.close()
    sink2.close()
}
```

**适用场景：** 事件广播、日志分发、通知推送

---

## 线程间同步

无缓冲通道可用于线程之间的同步握手。

```cangjie
let done = Chan<Unit>()

// 工作线程完成后通知
spawn {
    // 执行任务...
    done.send(Unit)
}

// 等待工作线程完成
done.recv()
```

**适用场景：** 等待线程完成、协同启动、屏障同步

---

## 超时与 select

通过 selectOr 可以实现非阻塞的通道操作，或在多个通道中选择：

```cangjie
let ch = Chan<Int64>(1)

// 尝试接收，不阻塞
let (idx, val) = selectOr([ch], { =>
    println("通道无数据，执行其他逻辑")
})
```
