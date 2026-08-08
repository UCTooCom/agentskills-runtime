# quic_cj — 仓颉语言 QUIC 传输协议

[![cjc](https://img.shields.io/badge/cjc-1.0.5-blue)](https://developer.huawei.com/consumer/cn/cangjie/)
[![cjpm](https://img.shields.io/badge/cjpm-1.0.5-blue)](https://developer.huawei.com/consumer/cn/cangjie/)
[![QUIC v1](https://img.shields.io/badge/QUIC-v1-green)](https://www.rfc-editor.org/rfc/rfc9000)
[![QUIC v2](https://img.shields.io/badge/QUIC-v2-green)](https://www.rfc-editor.org/rfc/rfc9369)
[![Tests](https://img.shields.io/badge/tests-619%20passed-brightgreen)](./)
[![License](https://img.shields.io/badge/license-Apache%202.0-lightgrey)](LICENSE)

 **quic_cj** 是基于仓颉语言实现的 **QUIC 传输协议**（RFC 9000）库，用仓颉语言编写。它提供客户端和服务端 QUIC 连接的库 API，支持可靠的面向流 I/O、**CUBIC + NewReno** 双拥塞控制算法、**TLS 1.3** 原生加密、丢包检测与重传、**qlog** 结构化事件日志（RFC 9421）以及 **Stateless Reset** 机制。

---

## 目录

- [快速开始](#快速开始)
- [用例：客户端](#用例客户端)
- [用例：服务端](#用例服务端)
- [配置](#配置)
- [API 参考](#api-参考)
- [构建](#构建)
- [项目结构](#项目结构)
- [合作者须知：仓颉语言约束](#合作者须知仓颉语言约束)

---

## 快速开始

### 添加依赖

在你的 `cjpm.toml` 中添加：

```toml
[dependencies]
quic_cj = { git = "https://gitcode.com/changeden/quic_cj.git", output-type = "static" }
```

依赖会自动传递解析（`jinguissl_core`、`jinguissl`、`channel_cj`）。

### 一键拨号（客户端）

```cangjie
import quic_cj.*

main(): Int64 {
    let (conn, ok) = dial("example.com:4433")
    if (!ok) { println("连接失败"); return 1 }

    let (stream, ok2) = conn.openStream()
    if (!ok2) { println("打开流失败"); return 1 }

    stream.write("Hello, QUIC!".toArray())
    let response = stream.read()

    conn.closeWithError(0u64, "done")
    0
}
```

### 一键监听（服务端）

```cangjie
import quic_cj.*

main(): Int64 {
    let (listener, ok) = listen("0.0.0.0:4433")
    if (!ok) { println("监听失败"); return 1 }

    let (conn, ok2) = listener.accept()
    if (ok2) {
        let (stream, ok3) = conn.acceptStream()
        if (ok3) {
            let data = stream.read()
            stream.write(data)  // 回显
        }
    }

    listener.close()
    0
}
```

---

## 客户端

```cangjie
import quic_cj.*
```

### `dial` — 一行拨号

```cangjie
// 默认配置
let (conn, ok) = dial("example.com:4433")

// 自定义配置
let cfg = Config()
cfg.maxIdleTimeoutMs = 60000
let (conn, ok) = dialAddr("example.com:4433", cfg)
```

### `Conn` — 连接操作

拨号完成后，你就可以在 `Conn` 上使用：

| 方法 | 作用 |
|--------|---------|
| `openStream()` → `(Stream, Bool)` | 打开双向流 |
| `openUniStream()` → `(SendStream, Bool)` | 打开单向发送流 |
| `acceptStream()` → `(Stream, Bool)` | 接受对端的双向流 |
| `acceptUniStream()` → `(ReceiveStream, Bool)` | 接受对端的单向流 |
| `closeWithError(code, reason)` | 关闭连接 |
| `localAddr()` → `IPAddress` | 本地 IP 地址 |
| `remoteAddr()` → `String` | 对端地址 |
| `getConnState()` → `ConnState` | 连接状态（版本、握手状态等） |

### `Stream` — 读写数据

```cangjie
// 写入
stream.write("Hello".toArray())

// 读取
let data = stream.read()

// 关闭发送方向
stream.close()
```

---

## 服务端

```cangjie
import quic_cj.*
```

### `listen` — 一行监听

```cangjie
// 默认配置
let (listener, ok) = listen("0.0.0.0:4433")

// 自定义配置
let cfg = Config()
cfg.maxIncomingStreams = 1000
let (listener, ok) = listenAddr("0.0.0.0:4433", cfg)
```

### `Listener` — 接受连接和流

```cangjie
// 接受下一个入站 QUIC 连接
let (conn, ok) = listener.accept()

// 在接受后的连接上接受流
let (stream, ok) = conn.acceptStream()
```

### `Transport` — 底层控制

如果你需要更低层级的控制（例如处理自定义 UDP 包分发），可以直接使用 `Transport`：

```cangjie
let transport = Transport("0.0.0.0:4433", cfg)
let (listener, ok) = transport.listen()
transport.handleReceivedPacket(data, addr, time)
transport.setHandler(connId, handler)
```

---

## 配置

`Config` 提供以下可定制字段：

| 字段 | 默认值 | 说明 |
|-------|---------|---------|
| `versions` | `[VERSION_1, VERSION_2]` | 启用的 QUIC 版本 |
| `handshakeIdleTimeoutMs` | `5000` | 握手阶段超时（毫秒） |
| `maxIdleTimeoutMs` | `30000` | 连接空闲超时（毫秒） |
| `maxIncomingStreams` | `100` | 最大入站双向流数 |
| `maxIncomingUniStreams` | `100` | 最大入站单向流数 |
| `initialStreamReceiveWindow` | `262144` | 初始流接收窗口（字节） |
| `maxStreamReceiveWindow` | `1048576` | 最大流接收窗口（字节） |
| `initialConnectionReceiveWindow` | `4194304` | 初始连接接收窗口（字节） |
| `maxConnectionReceiveWindow` | `16777216` | 最大连接接收窗口（字节） |
| `initialPacketSize` | `1200` | 初始包大小（字节） |
| `serverName` | `""` | TLS SNI（客户端设置） |
| `disableActiveMigration` | `false` | 禁用连接迁移 |
| `preferredAddressData` | `[]` | 服务端建议的替代地址 |
| `maxDatagramFrameSize` | `0` | DATAGRAM 帧最大负载（0=禁用） |

使用 `defaultConfig()` 获取全部默认值的实例：

```cangjie
let cfg = defaultConfig()
cfg.maxIdleTimeoutMs = 60000
```

---

## API 参考

### 顶层函数

| 函数 | 用途 |
|----------|---------|
| `dial(addr)` | 默认配置拨号连接 |
| `dialAddr(addr, config)` | 自定义配置拨号连接 |
| `listen(addr)` | 默认配置监听 |
| `listenAddr(addr, config)` | 自定义配置监听 |
| `defaultConfig()` | 返回默认 `Config` |

### 错误类型

| 类型 | 使用场景 |
|------|-----------|
| `QError` | 传输层或应用层错误 |
| `ApplicationError` | 应用层协议错误（含错误码和原因） |
| `StreamError` | 流取消错误（含 streamId、errorCode、remote） |
| `DatagramTooLargeError` | DATAGRAM 帧负载超出限制 |
| `newTransportError(code, msg)` → `QError` | 创建传输层错误 |
| `CryptoError` | TLS 1.3 加密/握手错误（含 alert code） |
| `newProtocolViolation(msg)` → `QError` | 创建协议违规错误 |
| `newFlowControlError(msg)` → `QError` | 创建流控错误 |
| `newFinalSizeError(msg)` → `QError` | 创建 final size 错误 |
| `newApplicationError(code, msg)` → `QError` | 创建应用层错误 |

### `ConnState`

`getConnState()` 返回以下字段：

| 字段 | 说明 |
|-------|-------------|
| `version` | 当前使用的 QUIC 版本 |
| `handshakeComplete` | TLS 握手是否完成 |
| `perspective` | 客户端/服务端 |
| `srcConnId` / `destConnId` | QUIC 连接 ID |

---

## 构建

```bash
# 构建库
cjpm build

# 运行测试
cjpm test

# 清理重建
rm -rf target/release
cjpm build
```

首次构建因编译依赖需要 30–60 秒；增量构建约 3–8 秒。

---

## 项目结构

```
src/quic_cj/
├── client.cj            dial() / dialAddr()
├── server.cj            listen() / listenAddr()
├── transport.cj         Transport 类（UDP 监听器、包路由）
├── config.cj            Config 和 defaultConfig()
├── error.cj             错误类型
├── interface.cj         Conn / Listener / ConnState 基类
├── zz_conn_impl.cj       Conn 实现（包装 core）
├── zz_listener_impl.cj   Listener 实现
│
├── protocol/            QUIC 协议常量和类型（版本、连接 ID、流 ID）
├── wire/                线缆编码：变长整数、包头、25 种帧类型
├── tls/                 TLS 1.3 集成（AEAD、包头保护、HKDF、Stateless Reset、UpdatableAEAD）
├── ack/                 ACK 处理与丢包检测（已发送/已接收追踪、RTT）
├── congestion/          CUBIC + NewReno 拥塞控制（混合慢启动、调节器）
├── flow/                流量控制（逐流 + 逐连接）
├── stream/               流状态机 / SendStream / ReceiveStream
├── core/                连接状态机、打包/解包、帧调度
├── sys/                 UDP 套接字层
├── qlog/                QUIC 事件日志（RFC 9421）
├── util/                RTT 统计、环型缓冲区、传输错误码
 └── tests/               619 个测试用例（64 个测试文件，81 个基准测试）
```

---

## 合作者须知：仓颉语言约束

开发过程中，仓颉语言的若干约束影响了实现风格：

| 约束 | 应对方式 |
|------------|------------|
| 枚举不支持 `==` 比较 | 使用 `match` 模式匹配 |
| `init` 是关键字 | `` super.`init`() `` 或内联默认值 |
| 无 `static` 方法 | 改为自由函数 |
| 泛型 `Array<T>` 不支持下标赋值 | 用具体类型数组替代 |
| `Unit` 不能作为元组值 | 直接返回 `Bool` |
| 不支持类型别名 | 直接使用底层类型 |
| 无 `Maybe`/`Result` 类型 | 使用 `Option<T>` + `if (let Some(v) <- f())` |

---

## 参考

- [RFC 9000](https://www.rfc-editor.org/rfc/rfc9000) — QUIC：基于 UDP 的多路复用安全传输
- [RFC 9001](https://www.rfc-editor.org/rfc/rfc9001) — 使用 TLS 保护 QUIC
- [RFC 9438](https://www.rfc-editor.org/rfc/rfc9438) — CUBIC 拥塞控制算法
- [quic-go](https://github.com/quic-go/quic-go) — Go 参考实现
## 基准测试
所有基准测试结果（Median 中位数，单位：纳秒）：
### 变长整数编码
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| readVarint1Byte | 74.79 ns | ±12.4% |
| appendVarintSmall | 203.2 ns | ±8.7% |
| appendVarintLarge | 406.4 ns | ±9.1% |

### 缓冲区操作
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| appendByteSingle | 180.8 ns | ±9.1% |
| appendBytesSmall | 476.1 ns | ±9.5% |
| appendBytesLarge | 136.5 µs | ±12.2% |

### 协议操作
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| isValidVersionV1 | 11.69 ns | ±9.5% |
| chooseSupportedVersionMatch | 453.2 ns | ±11.2% |
| generateConnIdStandard | 2.884 µs | ±3.0% |

### 帧序列化
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| serializePing | 99.13 ns | ±5.4% |
| serializeCrypto | 5.519 µs | ±8.9% |
| serializeStreamSmall | 3.233 µs | ±6.5% |
| serializeMaxData | 303.0 ns | ±5.2% |
| serializeConnectionClose | 1.561 µs | ±8.9% |

### ACK 处理
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| newAckHandlerCreate | 11.23 ns | ±13.5% |
| ackHandlerSendMode | 18.60 ns | ±15.8% |
| ackHandlerLossTimeout | 22.18 ns | ±10.5% |

### 拥塞控制（CUBIC）
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| cubicInit | 34.07 ns | ±14.3% |
| cubicCongestionEvent | 40.14 ns | ±11.1% |
| cubicPacketAcked | 68.73 ns | ±13.2% |
| cubicSenderNew | 180.8 ns | ±14.0% |
| pacerBudget | 18.13 ns | ±7.8% |
| bandwidthEstimate | 11.27 ns | ±13.3% |

### 流量控制
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| streamFlowControllerNew | 299.9 ns | ±12.5% |
| streamFlowControllerAddBytes | 162.0 ns | ±7.9% |
| connectionFlowControllerNew | 104.4 ns | ±11.9% |
| connectionFlowControllerRead | 74.16 ns | ±9.6% |

### 流操作
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| streamNew | 644.6 ns | ±12.3% |
| sendStreamWriteSmall | 286.8 ns | ±5.3% |
| sendStreamWriteLarge | 71.27 µs | ±6.2% |
| cryptoStreamWriteRead | 965.9 ns | ±18.8% |

### 核心引擎
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| packetNumberSpaceNext | 34.82 ns | ±10.6% |
| packetPackerShortHeader | 651.4 ns | ±10.5% |
| packetPackerLongHeader | 1.801 µs | ±10.2% |
| framerQueueCrypto | 1.821 µs | ±13.1% |
| framerGetFrames | 2.138 µs | ±11.0% |

### 工具
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| ringBufferPush | 1.805 µs | ±10.5% |
| ringBufferPushPop | 2.323 µs | ±10.9% |
| rttStatsUpdate | 46.16 ns | ±10.6% |
| rttStatsMultipleUpdates | 96.41 ns | ±13.1% |

### 密码套件
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| aes128GcmCreation | 83.21 ns | ±10.0% |
| cipherSuiteFieldAccess | 66.73 ns | ±8.5% |

### 流映射
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| createStreamWithId | 432.6 ns | ±7.9% |
| createCryptoStream | 843.5 ns | ±6.7% |
| cryptoStreamWriteRead | 1.312 µs | ±14.4% |

### 连接
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| createConnection | 2.513 ms | ±10.3% |
| connectionGetState | 1.531 ms | ±9.1% |
| connectionClose | 2.193 ms | ±20.1% |

### 配置
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| createDefaultConfig | 146.0 ns | ±14.1% |
| configValidate | 265.4 ns | ±10.7% |
| configModifyAndValidate | 300.6 ns | ±14.9% |

### PathManager
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| newPathManager | 34.41 ns | ±7.9% |
| pathManagerMigrationDisabled | 62.68 ns | ±13.6% |
| pathManagerSwitch | 117.3 ns | ±15.0% |

### Error 类型
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| newProtocolViolationCreate | 52.59 ns | ±10.0% |
| newCryptoErrorCreate | 39.83 ns | ±14.6% |
| newApplicationErrorCreate | 58.55 ns | ±17.0% |

### DatagramQueue
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| createDQ | 277.6 ns | ±15.7% |
| closeDQ | 342.2 ns | ±9.3% |
| recvHandle | 523.9 ns | ±11.7% |
| addFrame | 362.0 ns | ±8.8% |
| peekFrame | 372.1 ns | ±11.1% |
| popFrame | 542.3 ns | ±10.1% |
| querySendLen | 293.1 ns | ±11.6% |
| queryRecvLen | 380.7 ns | ±10.4% |
| queryHasData | 323.5 ns | ±14.7% |
| configureDQ | 237.4 ns | ±9.2% |

### RetransmissionQueue
| 操作 | 中位数 (ns) | 误差 |
|------|------------|------|
| createRQ | 184.0 ns | ±12.5% |
| addInitialCrypto | 426.3 ns | ±11.9% |
| addHandshakeCrypto | 433.5 ns | ±10.5% |
| addAppDataFrame | 221.1 ns | ±5.6% |
| checkHasDataInitial | 259.5 ns | ±3.6% |
| getFrameInitial | 295.7 ns | ±5.5% |
| dropPacketsInitial | 284.1 ns | ±5.4% |
| fullCycle | 639.6 ns | ±3.8% |

## 运行基准测试

```bash
cjpm bench
```

测试环境：81 个基准测试覆盖 19 个模块：变长整数、缓冲区、协议、帧序列化、ACK、拥塞控制（CUBIC）、流量控制、流、流映射、连接、配置、核心引擎、DatagramQueue、RetransmissionQueue、工具、密码套件、错误类型、PathManager、连接日志。
