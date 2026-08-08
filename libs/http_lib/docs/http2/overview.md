# HTTP/2 概览

## 架构

HTTP/2 连接层由以下组件组成:

```
┌──────────────────────────────────────────┐
│          Http2Connection                  │
│  (连接管理、帧 I/O、请求/响应、推送)       │
├──────────────────────────────────────────┤
│  Frame     │  HPACK        │  Multiplexer│
│ (编解码)   │ (Huffman+表)  │ (流状态机)  │
├──────────────────────────────────────────┤
│  FlowControl      │  PriorityWriteScheduler│
│  (Inflow/Outflow) │  (RoundRobin/Priority) │
└──────────────────────────────────────────┘
```

## 连接生命周期

### 客户端 (connect)

1. 发送 HTTP/2 连接前导 (`PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n`)
2. 发送本地 SETTINGS 帧，启动 SETTINGS 超时计时器
3. 等待服务端 SETTINGS 帧（含设置值）
4. 回复 SETTINGS ACK
5. 连接就绪，可发送/接收请求

### 服务端 (accept)

1. 读取客户端前导字节
2. 发送本地 SETTINGS 帧，启动 SETTINGS 超时计时器
3. 等待客户端 SETTINGS 帧
4. 回复 SETTINGS ACK
5. 如果有客户端 ACK，继续等待；否则等待客户端 SETTINGS
6. 连接就绪

### 自动检测 (h2c 前导)

非 TLS 连接上，服务端先读取前 24 字节与 HTTP/2 前导比较:
- 匹配 → HTTP/2 连接
- 不匹配 → 将前导字节回吐给 HTTP/1.1 处理路径

## 关键限制

### 流控制
- 连接级窗口: 默认 65535 字节
- 流级窗口: 默认 65535 字节
- 通过 `WINDOW_UPDATE` 帧动态更新
- Inflow 批量处理: 累积不足 4KB 时不发送 WINDOW_UPDATE，减少小帧数量
- 窗口最大值: 2^31 - 1 (2147483647)

### 并发流
- 默认最多 100 个并发流
- 由 `SETTINGS_MAX_CONCURRENT_STREAMS` 协商

### 帧大小
- 默认最大帧大小: 16384 字节
- 可协商至 16777215 字节 (2^24 - 1)

### HPACK
- 动态表最大大小: 4096 字节（默认）
- 通过 `SETTINGS_HEADER_TABLE_SIZE` 协商
- 支持 Huffman 编码/解码 (RFC 7541 Appendix B)
- 静态表: 61 条常用头部条目

## 支持的帧类型

| 帧类型 | RFC | 说明 |
|--------|-----|------|
| DATA | 7540 §6.1 | 请求/响应体数据 |
| HEADERS | 7540 §6.2 | 请求/响应头 |
| PRIORITY | 7540 §6.3 | 流优先级 |
| RST_STREAM | 7540 §6.4 | 终止流 |
| SETTINGS | 7540 §6.5 | 连接参数协商 |
| PUSH_PROMISE | 7540 §6.6 | 服务器推送承诺 |
| PING | 7540 §6.7 | 连接活性检测 |
| GOAWAY | 7540 §6.8 | 优雅关闭 |
| WINDOW_UPDATE | 7540 §6.9 | 流控制窗口更新 |
| CONTINUATION | 7540 §6.10 | 头块延续 |

### 帧标志

| 标志 | 值 | 适用帧类型 |
|------|-----|-----------|
| ACK | 0x1 | SETTINGS, PING |
| END_STREAM | 0x1 | DATA, HEADERS |
| END_HEADERS | 0x4 | HEADERS, CONTINUATION, PUSH_PROMISE |
| PADDED | 0x8 | DATA, HEADERS, PUSH_PROMISE |
| PRIORITY | 0x20 | HEADERS |

### 帧填充

DATA / HEADERS / PUSH_PROMISE 帧支持 PADDED 标志:
- 首字节为 Pad Length（填充长度）
- 末尾 padLength 个字节为填充数据
- HEADERS + PADDED + PRIORITY 组合: 首字节 Pad Length，随后 5 字节优先级字段
- 填充数据接收时自动剥离

### SETTINGS 参数

| 标识符 | ID | 默认值 | 说明 |
|--------|----|--------|------|
| HEADER_TABLE_SIZE | 0x1 | 4096 | HPACK 动态表最大大小 |
| ENABLE_PUSH | 0x2 | 1 | 是否启用服务端推送 |
| MAX_CONCURRENT_STREAMS | 0x3 | (无限制) | 最大并发流数 |
| INITIAL_WINDOW_SIZE | 0x4 | 65535 | 初始流控窗口大小 |
| MAX_FRAME_SIZE | 0x5 | 16384 | 单帧最大负载字节数 |
| MAX_HEADER_LIST_SIZE | 0x6 | (无限制) | 头部列表最大字节数 |
| ENABLE_CONNECT_PROTOCOL | 0x8 | 0 | 扩展 CONNECT 协议 (RFC 8441) |
| NO_RFC7540_PRIORITIES | 0x9 | 0 | RFC 9218 可扩展优先级方案 |

## 流状态机

每个 HTTP/2 流遵循 RFC 7540 Section 5.1 的状态转换:

```
                        ┌──────┐
                        │ IDLE │
                        └──┬───┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        发送 HEADERS  接收 HEADERS   PUSH_PROMISE
              │            │            │
              ▼            ▼            ▼
       ┌──────────┐  ┌──────────┐  ┌──────────┐
       │ OPEN     │  │ OPEN     │  │ RESERVED │
       └────┬─────┘  └────┬─────┘  └────┬─────┘
            │              │             │
       END_STREAM     END_STREAM   接收/send
        (发送侧)       (接收侧)    HEADERS/RESPONSE
            │              │             │
            ▼              ▼             ▼
   HALF_CLOSED_LOCAL  HALF_CLOSED_REMOTE    OPEN
            │              │
            └──────┬───────┘
                   │
              END_STREAM
                   │
                   ▼
               ┌──────┐
               │CLOSED│
               └──────┘
```

| 状态 | 说明 |
|------|------|
| IDLE | 初始状态，未开始任何请求/响应 |
| RESERVED_LOCAL | 本地 PUSH_PROMISE 已发送，等待响应 |
| RESERVED_REMOTE | 收到对端 PUSH_PROMISE，等待推送响应 |
| OPEN | 双方均可发送 HEADERS 和 DATA |
| HALF_CLOSED_LOCAL | 本地 END_STREAM 已发送，仅接收数据 |
| HALF_CLOSED_REMOTE | 对端 END_STREAM 已收到，仅发送数据 |
| CLOSED | 流结束，不再处理 |

## 流控制

基于 RFC 7540 标准的流控窗口模式:

```cangjie
import http_lib.http2.{Http2FlowController, Http2Inflow, Http2Outflow}

let fc = Http2FlowController(initialWindow: 65535)

// 连接级流入/流出
let connInflow = fc.connInflow
let connOutflow = fc.connOutflow

// 创建流级流出（自动关联连接级窗口）
let streamOutflow = fc.createStreamOutflow()
```

### Inflow（接收窗口）
- 批量累加未发送的 WINDOW_UPDATE 字节
- 直到累积超过 4KB 或达到窗口翻倍阈值才发送
- 防止过多的 WINDOW_UPDATE 小帧

### Outflow（发送窗口）
- 流级窗口与连接级窗口联动
- 流消耗同时减少连接级窗口
- 窗口不足时 DATA 帧排队等待 WINDOW_UPDATE

### 窗口耗尽处理
当发送窗口不足时，DATA 帧数据排队到 `pendingData`:
- 收到 `WINDOW_UPDATE` 后自动恢复发送
- 同时检查连接级和流级窗口（取较小值）
- 分片大小不超过对端 `MAX_FRAME_SIZE`

## SETTINGS 超时

RFC 7540 Section 6.5.3 要求: 发送 SETTINGS 后若未收到 ACK，应在超时后断开连接。

```cangjie
import http_lib.http2.SettingsTimedHandler

let timeout = SettingsTimedHandler(timeout: Duration.second * 2)
timeout.start()
if (timeout.isExpired()) {
    throw Http2Exception(Http2ErrorCode.SETTINGS_TIMEOUT, "SETTINGS timeout")
}
timeout.ack()  // 收到 SETTINGS ACK 后确认
```

默认超时: 2 秒。超时未收到 ACK 时抛出 `SETTINGS_TIMEOUT` 错误。

## 错误码

RFC 7540 Section 7 定义的错误码:

| 错误码 | 值 | 说明 |
|--------|-----|------|
| NO_ERROR | 0x0 | 正常关闭 |
| PROTOCOL_ERROR | 0x1 | 协议违规 |
| INTERNAL_ERROR | 0x2 | 内部错误 |
| FLOW_CONTROL_ERROR | 0x3 | 流控窗口溢出 |
| SETTINGS_TIMEOUT | 0x4 | SETTINGS ACK 超时 |
| STREAM_CLOSED | 0x5 | 收到已关闭流的数据 |
| FRAME_SIZE_ERROR | 0x6 | 帧大小超限 |
| REFUSED_STREAM | 0x7 | 拒绝创建流 |
| CANCEL | 0x8 | 取消流 |
| COMPRESSION_ERROR | 0x9 | HPACK 解压失败 |
| CONNECT_ERROR | 0xa | 连接建立失败 |
| ENHANCE_YOUR_CALM | 0xb | 请求过多 |
| INADEQUATE_SECURITY | 0xc | 安全等级不足 |
| HTTP_1_1_REQUIRED | 0xd | 需要降级到 HTTP/1.1 |

### RST_STREAM

流错误通过 `RST_STREAM` 帧终止，使用 `cancelPush()` 发送:

```cangjie
// 取消推送流（客户端）
h2conn.cancelPush(promisedStreamId, errorCode: Http2ErrorCode.CANCEL)

// 服务端在多路复用器中自动处理拒绝的流
// 并发流超限时自动发送 REFUSED_STREAM
```

`RST_STREAM` 接收时根据错误码处理: `CANCEL` 正常取消、`REFUSED_STREAM` 可重试、其余错误码视为协议错误。

### RST_STREAM 流清理

服务端 `recvRequest()` 和 `recvRequestBody()` 现在正确处理 RST_STREAM：
- 收到 RST_STREAM 时立即从多路复用器中移除该流
- 释放流占用的窗口和跟踪资源
- 如果 HEADERS 仍在处理中，重置 pendingStreamId 和头部片段缓冲区
- 防止等待已取消流的后续帧导致协议错误

## PING 活性检测

用于连接健康检查和 RTT 测量:

```cangjie
// 发送 PING 并等待 ACK（返回 true 表示收到 ACK）
let ok = h2conn.ping([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01])
```

- PING 帧负载固定为 8 字节
- 收到 PING 后自动回复 PING ACK
- `ping()` 方法同步等待对端 ACK

## 优雅关闭

### GOAWAY 帧

发送 GOAWAY 通知对端即将关闭连接:

```cangjie
// 优雅关闭 — 允许已有流完成
h2conn.gracefulShutdown()
// 可选: 指定错误码和调试数据
h2conn.gracefulShutdown(
    errorCode: Http2ErrorCode.NO_ERROR,
    debugData: [0x62, 0x79, 0x65]  // "bye" 的 utf-8
)

// 检查是否在 draining 状态
if (h2conn.isDraining()) { ... }

// 立即关闭
h2conn.close()
```

### 服务端优雅关闭

```cangjie
server.shutdown()  // 停止接受新请求，等待已有请求完成（超时后强制关闭）
server.close()     // 立即关闭所有连接
```

## h2c (Cleartext HTTP/2)

RFC 7540 Section 3.2: 从 HTTP/1.1 Upgrade 升级到 HTTP/2:

```cangjie
// 客户端升级请求 (HTTP/1.1 → HTTP/2)
GET / HTTP/1.1
Host: example.com
Connection: Upgrade, HTTP2-Settings
Upgrade: h2c
HTTP2-Settings: <base64url encoding of SETTINGS payload>

// 服务端响应
HTTP/1.1 101 Switching Protocols
Connection: Upgrade
Upgrade: h2c
```

服务端自动处理 h2c 升级:
- 检测 `Upgrade: h2c` 请求头
- 验证 `HTTP2-Settings` 头存在
- 回复 101 Switching Protocols
- 切换到 HTTP/2 帧读写模式
- 需要 `enableHttp2: true`（默认开启）

### HTTP/2 连接检测

非 TLS 连接上，服务端自动检测 HTTP/2 前导:
- 读取前 24 字节
- 与 `PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n` 比较
- 匹配 → 直接作为 HTTP/2 处理
- 不匹配 → 回退到 HTTP/1.1

## 写调度器

两种内置写调度策略:

### RoundRobinWriteScheduler

简单轮询: 每个流轮流发送，控制帧优先:

```cangjie
import http_lib.http2.RoundRobinWriteScheduler

let sched = RoundRobinWriteScheduler()
sched.openStream(streamId)
sched.push(Http2FrameWriteRequest(streamId, frameData))
let wr = sched.pop()  // 按轮询顺序取出
```

### PriorityWriteScheduler

基于权重和依赖树的优先级调度:

```cangjie
import http_lib.http2.PriorityWriteScheduler

let sched = PriorityWriteScheduler()
sched.openStream(streamId, weight: 16, parent: None)
sched.push(Http2FrameWriteRequest(streamId, frameData))
// 权重越高，调度频率越大
// score = weight / (writeCount + 1)，选取最高分
```

控制帧（PING、SETTINGS、GOAWAY、RST_STREAM、WINDOW_UPDATE）始终优先于 DATA 帧发送。

## 客户端使用

```cangjie
import http_lib.http2.Http2Connection

let h2conn = Http2Connection(tcpConn, isServer: false)
h2conn.connect()

// 发送请求
let streamId = h2conn.sendRequest(request)

// 接收响应
let response = h2conn.recvResponse(streamId)
```

### 服务端推送接收

```cangjie
// 设置推送回调
h2conn.onPushPromise = {pushRequest =>
    println("收到推送: ${pushRequest.url}")
    // 返回 None 忽略推送, 返回 Some(response) 接收
    None
}

// 接收推送响应
let pushResp = h2conn.recvPushResponse(promisedStreamId)

// 取消推送
h2conn.cancelPush(promisedStreamId)
```

## 服务端推送

```cangjie
// Server 端推送资源
let h2conn = Http2Connection(conn, isServer: true)
let pushStreamId = h2conn.pushPromise(mainStreamId, pushRequest)
h2conn.sendPushResponse(pushStreamId, pushResponse)
```

## 扩展 CONNECT (RFC 8441)

扩展 CONNECT 允许在 HTTP/2 流上建立非 HTTP 隧道，如 WebSocket over HTTP/2。

### SETTINGS_ENABLE_CONNECT_PROTOCOL

对端必须接受 0 或 1，其余值被视为 PROTOCOL_ERROR。

```cangjie
// 服务端接受扩展 CONNECT
h2conn.acceptExtendedConnect(streamId, "websocket")
```

### 客户端发起 WebSocket 隧道

```cangjie
import http_lib.http2.{establishWebSocketTunnel, H2WebSocketTunnel}

let tunnel = establishWebSocketTunnel(h2conn, "example.com", 443)
tunnel.send(websocketFrameBytes)
let (data, closed) = tunnel.recv()
tunnel.close()
```

### 服务端接受扩展 CONNECT

服务端在 `server.cj` 的 H2 循环中自动检测扩展 CONNECT 请求 (`:method=CONNECT` + `:protocol` 头存在)：

```cangjie
// 服务端自动处理流程:
// 1. recvRequest() 检测 :protocol → isExtendedConnect
// 2. h2.acceptExtendedConnect(sid, protocol) 发送 200 响应
// 3. H2WebSocketTunnel 存入 req.metadata，处理器可取用
```

处理器通过 `req.metadata` 获取隧道引用进行双向 I/O：

```cangjie
match (req.metadata) {
    case Some(m) =>
        let tunnel = m as H2WebSocketTunnel
        let data = tunnel.recv()
        tunnel.send(response)
    case None => ()
}
```

隧道数据通过 HTTP/2 DATA 帧传输，受流控制窗口约束。

### Capsule Protocol (RFC 9298)

用于在 HTTP 流上传输 UDP 数据报：

```cangjie
import http_lib.http2.{encodeCapsule, decodeCapsule, Capsule, CapsuleType}

let cap = Capsule(CapsuleType.DATAGRAM, udpPayload)
let encoded = encodeCapsule(cap)
let decoded = decodeCapsule(encoded)
```

## 优先级

HTTP/2 支持流优先级调度，基于权重（1-256）和依赖树:

```cangjie
// PRIORITY 帧格式:
// Exclusive (1 bit) + Stream Dependency (31 bits) + Weight (8 bits)
multiplexer.updatePriority(streamId, exclusive: false, streamDep: 0, weight: 16)
```

## 协议合规

本实现遵循:
- **RFC 7540** — HTTP/2 协议
- **RFC 7541** — HPACK 头压缩
- **RFC 8336** — ORIGIN 帧
- **RFC 7838** — ALTSVC 帧
- **RFC 8441** — 扩展 CONNECT (WebSocket over HTTP/2)
- **RFC 9218** — 可扩展优先级 (PRIORITY_UPDATE 帧)
- **RFC 9298** — Capsule Protocol / HTTP Datagrams
- 完整流状态机验证（Section 5.1）
- 流控制窗口严格实施（Section 6.9）
- `SETTINGS_INITIAL_WINDOW_SIZE` 正确传播至已有流 (§6.9.2)
- `HEADERS` 帧 `PRIORITY` 标志解析（§6.2）
- 流级发送窗口检查 + 接收窗口补充（§6.9.1）
- `GOAWAY` 帧调试数据提取（§6.8）
- 未知帧类型静默忽略（Section 4.1）
- GOAWAY 正确处理（Section 6.8）

## 已修复的合规问题 (v0.1.0)

1. **INITIAL_WINDOW_SIZE 传播**: 当对端通过 SETTINGS 改变初始窗口大小时，所有已有流的发送窗口现在正确调整差值
2. **HEADERS PRIORITY 标志**: `recvRequest()` 和 `recvResponse()` 现在正确解析 HEADERS 帧中的 PRIORITY 字段（5 字节：E+StreamDependency+Weight）
3. **流级发送窗口**: `sendDataFrames()` 现在同时检查流级和连接级窗口
4. **流级接收窗口**: DATA 接收后正确补充流级 WINDOW_UPDATE
5. **WINDOW_UPDATE 路由**: 流级窗口更新现在正确更新流的 `sendWindow` 而非连接级
6. **GOAWAY 调试数据**: `handleGoaway()` 提取并存储调试数据

## 近期改进

### 流控制修复

- **WINDOW_UPDATE 阈值**: 修复了因比较阈值错误导致流级窗口更新从未发送的问题。流接收窗口现在在消费数据达到阈值时正确触发 WINDOW_UPDATE。
- **双重扣除修复**: 修复了发送窗口记账将字节同时从连接级窗口和流窗口扣除导致重复计数的问题。现在正确遵循 RFC 7540 Section 6.9。
- **RFC 7540 Section 6.9 合规**: 全面符合流控制要求，包括正确的窗口管理和更新帧调度。

### 优先级调度

- **PRIORITY 帧传播**: PRIORITY 帧现在正确更新多路复用器流状态和写调度器优先级树，确保调度行为一致。
- **循环依赖检测**: 增加了优先级依赖的循环检测，防止依赖树中出现无限循环。
- **写入计数器上限**: 写入计数器现在有上限以防止无限制增长，在长连接上维持调度公平性。

### HPACK 安全

- **敏感头部保护**: `authorization`、`set-cookie`、`cookie`、`proxy-authorization` 等头部现在使用 Literal Never Indexed 编码。防止凭据通过同一连接上不同流之间共享的 HPACK 动态表泄露。

### 帧验证

- **WINDOW_UPDATE 零增量**: 收到增量为零的 WINDOW_UPDATE 现在正确产生 PROTOCOL_ERROR (RFC 7540 Section 6.9)。
- **GOAWAY last-stream-id 单调性**: last-stream-id 非单调递增的 GOAWAY 帧现在被拒绝并产生 PROTOCOL_ERROR (RFC 7540 Section 6.8)。
- **HEADERS 无效填充**: 填充长度无效的 HEADERS 帧现在产生 PROTOCOL_ERROR。
- **CONTINUATION 顺序**: CONTINUATION 帧顺序现在严格按照 RFC 7540 Section 6.10 执行，拒绝在头块之外到达的帧。

### 状态机修复

- **RESERVED_LOCAL 转换**: 收到推送响应后，RESERVED_LOCAL 状态现在正确转换为 HALF_CLOSED_REMOTE，符合 RFC 7540 Section 5.1。

### PING 处理

- **PING 帧隔离**: 等待 PING ACK 期间不再消费中间帧，防止帧处理延迟。

## 与 HTTP/1.x 的差异

HTTP/2 不支持:
- `Transfer-Encoding` (自动去除)
- `Connection` 特定头 (hop-by-hop)
- `Upgrade` 头 (通过 HTTP/2 SETTINGS 处理)
- Chunked 编码 (使用 DATA 帧分片)
- 请求行 (使用 `:method`, `:path`, `:scheme`, `:authority` 伪头)

## ResponseBuilder 与 HTTP/2 (新增 v0.3)

ResponseBuilder 兼容 HTTP/2 响应构建，在 HTTP/2 连接上自动处理帧分片:

```cangjie
let handler = wrapResponseBuilderHandler({req, rw =>
    rw.header("Content-Type", "text/plain")
    rw.writeString("HTTP/2 compatible response")
})
```
