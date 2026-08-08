# channel_cj — 仓颉通道库 (Go Channel Model)

[![cjc](https://img.shields.io/badge/cjc-1.0.5-blue)](https://developer.huawei.com/consumer/cn/cangjie/)
[![cjpm](https://img.shields.io/badge/cjpm-1.0.5-blue)](https://developer.huawei.com/consumer/cn/cangjie/)
[![Tests](https://img.shields.io/badge/tests-45%20passed-brightgreen)](./src/test_chan.cj)
[![License](https://img.shields.io/badge/license-MIT-green)](./)
[![Go Channel](https://img.shields.io/badge/model-Go%20Channel-orange)](./)

基于 **Go 语言 channel 模型** 的仓颉并发通道库，为仓颉编程语言提供类型安全、FIFO 有序、线程安全的 CSP（Communicating Sequential Processes）通信原语。支持有缓冲 / 无缓冲通道、阻塞 / 非阻塞收发、`select` 多路复用和通道关闭生命周期管理。

> **适用场景：** 协程通信、生产者-消费者、管道流水线、工作池、扇入/扇出、并发同步。

[API 参考](#api-参考) | [使用模式](#使用模式) | [示例](#示例) | [运行测试](#运行测试)

---

## 安装

在 `cjpm.toml` 中添加依赖：

```toml
[dependencies]
channel_cj = { path = "path/to/channel_cj", output-type = "static" }
```

或者通过 Git 引入：

```toml
[dependencies]
channel_cj = { git = "https://gitcode.com/changeden/channel_cj.git", output-type = "static" }
```

---

## 快速开始

### 创建通道

```cangjie
let ch = Chan<Int64>()    // 无缓冲通道（同步握手）
let ch = Chan<Int64>(5)   // 容量为 5 的有缓冲通道（FIFO 队列）
```

### 发送和接收

```cangjie
// ── 阻塞发送 ──
ch.send(42)

// ── 阻塞接收 ──
let result = ch.recv()
if (let Some(v) <- result) {
    println("收到: ${v}")
} else {
    println("通道已关闭且无数据")
}
```

### 非阻塞操作

```cangjie
let ok: Bool = ch.trySend(42)       // 立即返回，不阻塞
let val: Option<Int64> = ch.tryRecv() // 立即返回，不阻塞
```

### select 多路复用

```cangjie
let (idx, value) = select([ch1, ch2])
if (let Some(v) <- value) {
    println("从 ch${idx} 收到: ${v}")
}
```

### 关闭与遍历

```cangjie
ch.close()
ch.forEach({ v => println("${v}") })
```

---

## API 参考

### Chan\<T\>

泛型通道类，`T` 为元素类型。创建实例：

| 构造函数 | 说明 |
|---------|------|
| `Chan<T>()` | 无缓冲通道，send 阻塞直到有对应 recv |
| `Chan<T>(capacity: Int64)` | 有缓冲通道，容量为 capacity（负数等价于 0） |

#### 核心方法

| 方法 | 签名 | 说明 |
|------|------|------|
| **send** | `func send(value: T): Unit` | 阻塞发送。通道满或无接收者时等待。通道关闭后抛出 `Exception`。 |
| **recv** | `func recv(): Option<T>` | 阻塞接收。无数据时等待。通道关闭且数据耗尽时返回 `None`。 |
| **trySend** | `func trySend(value: T): Bool` | 非阻塞发送。成功返回 `true`，否则返回 `false`。 |
| **tryRecv** | `func tryRecv(): Option<T>` | 非阻塞接收。有数据返回 `Some(v)`，否则返回 `None`。 |
| **close** | `func close(): Unit` | 关闭通道。阻塞发送者会收到异常，接收者耗尽剩余数据后返回 `None`。重复 close 抛出 `Exception`。 |
| **forEach** | `func forEach(action: (T) -> Unit): Unit` | 迭代接收，通道关闭且数据耗尽后返回。 |
| **len** | `func len(): Int64` | 当前缓冲区中的元素数量（无缓冲通道始终为 0）。 |
| **cap** | `func cap(): Int64` | 通道容量（无缓冲通道为 0）。 |
| **isClosed** | `func isClosed(): Bool` | 通道是否已关闭。 |

#### 行为细则

| 操作 | 无缓冲通道 | 有缓冲通道 |
|------|-----------|-----------|
| `send(v)` | 阻塞至有接收者就绪 | 缓冲区未满时直接入队；满时阻塞至有接收者 |
| `recv()` | 阻塞至有发送者就绪 | 缓冲区非空时返回队头值；空时阻塞至有发送者 |
| `trySend(v)` | 有等待接收者时成功，否则失败 | 缓冲区未满时成功，否则失败 |
| `tryRecv()` | 有等待发送者时获取值，否则返回 None | 缓冲区非空时返回队头，否则返回 None |
| `close()` | 唤醒所有阻塞线程，后续 recv 返回 None | 清空待发送队列，阻塞发送者抛异常；接收者耗尽缓冲区后返回 None |

### select 函数

```cangjie
public func select<T>(channels: Array<Chan<T>>): (Int64, Option<T>)
```

从多个通道中阻塞读取第一个就绪的数据。等效于 Go 的 `select { case v := <-ch: ... }`。

- 轮询顺序：始终从索引 0 开始轮询
- 返回值：`(index, Some(value))` 表示从第 `index` 个通道收到值；`(-1, None)` 表示所有通道均已关闭

### selectOr 函数

```cangjie
public func selectOr<T>(
    channels: Array<Chan<T>>,
    defaultAction: () -> Unit,
): (Int64, Option<T>)
```

带默认分支的非阻塞 select。没有通道就绪时执行 `defaultAction`。等效于 Go 的：

```go
select {
case v := <-ch0:
case v := <-ch1:
default:
}
```

- 返回值同 `select`，`(-1, None)` 表示执行了默认分支

---

## 使用模式

### 无缓冲通道 — 线程间同步

无缓冲通道要求发送和接收同时就绪，可用于线程之间的同步握手：

```cangjie
let ch = Chan<Int64>()
spawn {
    ch.send(42)  // 阻塞至主线程 ch.recv()
}
let v = ch.recv()
println("${v}")
```

### 有缓冲通道 — 生产者-消费者

有缓冲通道允许发送方在缓冲区满之前不被阻塞，适合解耦生产者和消费者：

```cangjie
let ch = Chan<String>(10)
spawn {
    for (i in 0..5) {
        ch.send("任务 ${i}")
    }
    ch.close()
}
ch.forEach({ msg => println("处理: ${msg}") })
```

### 非阻塞检查

需要在不阻塞当前线程的情况下检查通道状态时使用 `trySend` / `tryRecv`：

```cangjie
if (ch.tryRecv().isSome()) {
    // 收到了数据
} else {
    // 通道无数据，继续做其他事
}
```

### select 多路复用

从多个通道中监听数据：

```cangjie
let ch1 = Chan<Int64>(1)
let ch2 = Chan<Int64>(1)
ch1.send(10)
let (idx, val) = select([ch1, ch2])
```

带默认分支的非阻塞 select：

```cangjie
let (idx, val) = selectOr([ch1, ch2], { =>
    println("无数据可用，处理其他逻辑")
})
```

### 关闭通道与 drain

通道关闭后：
- 缓冲区剩余数据仍能被接收者读出
- 数据耗尽后 recv / tryRecv 返回 `None`
- 阻塞的发送者收到异常
- 阻塞的接收者被唤醒

```cangjie
ch.close()
ch.forEach({ v => println("drain: ${v}") })
// 此时通道已空且已关闭，后续 ch.recv() 返回 None
```

### 管道模式 (Pipeline)

用通道串联多个处理阶段：

```cangjie
let ping = Chan<Int64>()
let pong = Chan<Int64>()
spawn {
    for (_ in 0..5) {
        let v = ping.recv().getOrThrow()
        pong.send(v + 1)
    }
}
for (i in 0..5) {
    ping.send(i)
    let v = pong.recv().getOrThrow()
    println("${i} -> ${v}")  // 0->1, 1->2, ...
}
```

### 工作池模式 (Worker Pool)

多个 worker 从共享通道消费任务：

```cangjie
let tasks = Chan<Int64>(10)
for (_ in 0..4) {
    spawn {
        while (true) {
            let r = tasks.recv()
            if (let Some(t) <- r) {
                println("[worker] 执行任务 ${t}")
            } else { break }
        }
    }
}
for (i in 0..10) { tasks.send(i) }
tasks.close()
```

---

## 线程安全

所有 `Chan<T>` 方法均由内部 `Mutex` + `Condition` 保护，支持任意数量的线程安全并发访问。

- 使用 **Mutex** 保证互斥访问
- 使用 **Condition** 实现阻塞等待 / 唤醒，不存在忙等
- send / recv 在条件满足时直接握手机制，减少不必要的内存拷贝

---

## 示例

参考 [`sample/`](./sample) 目录下的示例程序（每个子目录均为独立的 cjpm 项目，可直接 `cjpm run` 运行）：

| 目录 | 说明 |
|------|------|
| `basic/` | 通道基本用法 |
| `buffered/` | 有缓冲通道 |
| `unbuffered/` | 无缓冲通道 |
| `close/` | 通道关闭与遍历 |
| `pipeline/` | 单向管道流水线模式 |
| `worker/` | 工作池模式 |
| `select/` | select 多路复用与 selectOr |
| `fan_in/` | 扇入模式：多路输入合并 |
| `fan_out/` | 扇出模式：一源多播 |

---

## 文档

详细文档请参考 [`docs/`](./docs) 目录：

| 文档 | 说明 |
|------|------|
| `overview.md` | 通道模型概述与核心概念 |
| `api.md` | 完整 API 参考（Chan、select、selectOr） |
| `patterns.md` | 7 种常用并发模式详解 |
| `faq.md` | 常见问题与对比 Go channel |

---

## 基准测试

包含 **22 项基准测试**，覆盖通道创建、基本操作、非阻塞路径、FIFO 顺序、select 多路复用、关闭操作和进阶场景（Intel i7 × cjc v1.0.5 × 5000 次迭代）：

| 类别 | 基准测试 | 单次耗时 | 吞吐量 |
|------|---------|---------|--------|
| **通道创建** | Chan<Int64>() 无缓冲 | 635 ns | 1.57 M ops/s |
| | Chan<Int64>(10) 有缓冲 | 794 ns | 1.26 M ops/s |
| | Chan<Int64>(1000) 有缓冲 | 655 ns | 1.53 M ops/s |
| **基本操作** | trySend（有空位） | 880 ns | 1.14 M ops/s |
| | send（有空位） | 857 ns | 1.17 M ops/s |
| | tryRecv（空通道） | 526 ns | 1.90 M ops/s |
| **非阻塞失败路径** | trySend（缓冲区满） | 608 ns | 1.64 M ops/s |
| | trySend（无缓冲无等待者） | 471 ns | 2.12 M ops/s |
| | tryRecv（无缓冲无等待者） | 485 ns | 2.06 M ops/s |
| **查询操作** | len + cap | 850 ns | 1.18 M ops/s |
| | isClosed | 744 ns | 1.34 M ops/s |
| **FIFO 操作** | send/recv 1 对 | 2.11 µs | 474 K ops/s |
| | send/recv 3 对 FIFO | 2.19 µs | 456 K ops/s |
| **select** | select（2 通道，1 有数据） | 2.16 µs | 462 K ops/s |
| | select（3 通道，1 有数据） | 3.21 µs | 312 K ops/s |
| | selectOr（全空，执行默认） | 1.80 µs | 556 K ops/s |
| **关闭操作** | close（空通道） | 690 ns | 1.45 M ops/s |
| | close + isClosed | 720 ns | 1.39 M ops/s |
| | close + drain（有数据） | 2.51 µs | 398 K ops/s |
| | forEach（3 项后关闭） | 3.88 µs | 258 K ops/s |
| | close × 2（异常路径） | 3.05 µs | 328 K ops/s |
| **进阶操作** | tryRecv（非空通道） | 778 ns | 1.29 M ops/s |

运行基准测试（需要单独构建 benchmark 项目）：

```bash
cd benchmark && cjpm run
```

### 测试环境

- CPU: Intel i7
- 编译器: cjc v1.0.5
- 迭代次数: 5000 次/项（FIFO 操作 1000 次/项）
- 基准测试源码见 [`benchmark/`](./benchmark) 目录

---

## 运行测试

```bash
cjpm test
```

包含 **45 个单元测试**，覆盖：

| 测试类 | 测试数 | 覆盖内容 |
|--------|--------|---------|
| TestCreate | 3 | 通道创建、容量、负容量处理 |
| TestSendRecv | 3 | FIFO 顺序、trySend/tryRecv、len/cap |
| TestClose | 6 | 关闭后 drain、关闭后 len/cap、重复关闭、关闭后发送 |
| TestForEach | 3 | forEach 遍历、空通道 forEach、关闭中途 forEach |
| TestBlocking | 3 | 无缓冲握手、缓冲溢出 FIFO、多发送者 |
| TestCloseBlocking | 5 | 关闭唤醒阻塞发送者/接收者、pending 发送丢弃 |
| TestConcurrent | 4 | 多对多通信、管道模式、burst 压力、无缓冲压力 |
| TestSelect | 8 | select 双/三通道、selectOr、多就绪、通道关闭组合 |
| TestEdgeCases | 4 | 关闭的空通道 tryRecv、满缓冲 trySend 等边界 |
| TestFanInFanOut | 2 | 扇入、扇出模式 |
| TestUnbufferedNonBlocking | 2 | 无缓冲通道非阻塞收发等待场景 |

### 新增测试场景说明

| 新增测试 | 说明 |
|---------|------|
| `test_len_cap_after_close` | 验证关闭后 len/cap 仍然反映缓冲区状态 |
| `test_for_each_empty_closed` | 空通道 forEach 不应产生任何值 |
| `test_for_each_close_midway` | forEach 中途关闭通道的行为 |
| `test_select_three_channels` | select 在三通道上的工作 |
| `test_select_multiple_ready` | 多个通道就绪时 select 的优先级 |
| `test_select_or_all_closed` | 全关闭通道上 selectOr 调用默认分支 |
| `test_fan_in` | 扇入模式：多路输入合并 |
| `test_fan_out` | 扇出模式：一源多播 |
| `test_try_send_unbuffered_with_recv_waiter` | 有接收者等待时无缓冲 trySend 成功 |
| `test_try_recv_unbuffered_with_send_waiter` | 有发送者等待时无缓冲 tryRecv 成功 |
| `test_try_send_unbuffered_no_waiter` | 无等待者时无缓冲 trySend 失败 |
| `test_try_recv_unbuffered_no_sender` | 无等待者时无缓冲 tryRecv 返回 None |

---

## 环境要求

- 仓颉编译器 (cjc) v1.0.5+
- 仓颉包管理器 (cjpm) v1.0.5+
- 无外部依赖

---

## 许可证

MIT
