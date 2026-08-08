# HTTP/2 协议模块（http2）

## 概述

`http2` 模块提供 HTTP/2 (RFC 7540) 协议的完整实现，包括帧编码/解码、
HPACK 头部压缩（RFC 7541）、流多路复用、流量控制、优先级调度、
服务端推送、扩展 CONNECT（RFC 8441 WebSocket 隧道）和胶囊协议（RFC 9298）。

## 主要子模块

| 模块 | 说明 |
|------|------|
| `frame.cj` | HTTP/2 帧编码/解码（DATA、HEADERS、SETTINGS、PRIORITY、PUSH_PROMISE、GOAWAY 等 10 种帧类型） |
| `hpack.cj` | HPACK 头部压缩（Huffman 编码/解码、动态表、静态表、RFC 7541） |
| `connection.cj` | HTTP/2 连接管理（前导、流创建/关闭、帧 I/O、SETTINGS 协调、GOAWAY 优雅关闭） |
| `multiplexer.cj` | 流多路复用器（流状态机、并发控制、流 ID 管理） |
| `flow_control.cj` | 流量控制（Inflow/Outflow 窗口管理、WINDOW_UPDATE 调度、RFC 7540 §6.9） |
| `priority.cj` | 优先级树管理（依赖树、权重分配、循环依赖检测） |
| `write_scheduler.cj` | 写入调度器（RoundRobin / PriorityWriteScheduler 策略） |
| `capsule.cj` | 胶囊协议（RFC 9298 DATAGRAM / CLOSE 帧编解码） |
| `extended_connect.cj` | 扩展 CONNECT（RFC 8441 WebSocket over HTTP/2 隧道） |
| `common.cj` | 常量、错误码、SETTINGS 标识符、帧类型/标志定义 |
| `varint.cj` | QUIC 变长整数编解码 |

## 关键类型

| 类型 | 说明 |
|------|------|
| `Http2Connection` | HTTP/2 连接主类（帧 I/O、请求/响应、推送、扩展 CONNECT） |
| `Http2FrameHeader` | 9 字节帧头（长度、类型、标志、流 ID） |
| `Http2FrameType` | 帧类型枚举（DATA、HEADERS、PRIORITY、RST_STREAM 等） |
| `Http2SettingsId` | SETTINGS 参数枚举 |
| `Http2ErrorCode` | 错误码枚举 |
| `HPACK` | HPACK 压缩/解压缩引擎 |
| `Http2Inflow` / `Http2Outflow` | 流控入站/出站窗口 |
| `PriorityTree` | 流优先级依赖树 |
| `PriorityWriteScheduler` | 基于权重的写调度器 |
| `RoundRobinWriteScheduler` | 轮询写调度器 |
| `Capsule` | 胶囊帧（DATAGRAM、CLOSE） |
| `H2WebSocketTunnel` | 扩展 CONNECT WebSocket 隧道 |

## 快速参考

```cangjie
import http_lib.http2.{Http2Connection, Http2FrameHeader, encodeFrame}
import http_lib.http2.{HPACK, Http2Inflow, Http2Outflow}
import http_lib.http2.{PriorityWriteScheduler, RoundRobinWriteScheduler}
import http_lib.http2.{Capsule, CapsuleType, encodeCapsule, decodeCapsule}
import http_lib.http2.{H2WebSocketTunnel, establishWebSocketTunnel}

// 帧编解码
let header = Http2FrameHeader(128, Http2FrameType.HEADERS, flags: 0x4, streamId: 1)
let frame = encodeFrame(header, payload)

// HPACK 压缩
let hpack = HPACK()
let encoded = hpack.encode(headers)
let decoded = hpack.decode(encoded)

// 流量控制
let inflow = Http2Inflow(65535)
inflow.take(1000)
inflow.add(5000)

// 优先级调度
let sched = PriorityWriteScheduler()
sched.openStream(1, weight: 16, parent: None)
sched.push(Http2FrameWriteRequest(1, frameData))
let nextWrite = sched.pop()

// 胶囊协议
let cap = Capsule(CapsuleType.DATAGRAM, udpPayload)
let encodedCapsule = encodeCapsule(cap)

// 扩展 CONNECT WebSocket 隧道
let tunnel = establishWebSocketTunnel(h2conn, "example.com", 443)
tunnel.send(wsData)
let (data, closed) = tunnel.recv()
tunnel.close()
```

## 详细说明

请参阅 [HTTP/2 概览](overview.md) 获取 HTTP/2 协议的完整架构说明、
连接生命周期、流状态机、流控窗口管理、SETTINGS 参数、错误码、
HPACK、h2c 升级、ALPN 协商和协议合规等详细内容。

## 连接管理示例

```cangjie
// 客户端 HTTP/2 连接
let h2conn = Http2Connection(tcpConn, isServer: false)
h2conn.connect()

// 发送请求
let streamId = h2conn.sendRequest(request)

// 接收响应
let response = h2conn.recvResponse(streamId)

// 服务端推送
h2conn.onPushPromise = Some({ pushReq: HttpRequest =>
    // 接受或拒绝推送
    None  // 拒绝
})

// 优雅关闭
h2conn.gracefulShutdown()
```

## 参考

- [RFC 7540 — HTTP/2](https://www.rfc-editor.org/rfc/rfc7540)
- [RFC 7541 — HPACK: Header Compression for HTTP/2](https://www.rfc-editor.org/rfc/rfc7541)
- [RFC 8441 — Bootstrapping WebSockets with HTTP/2](https://www.rfc-editor.org/rfc/rfc8441)
- [RFC 9298 — Proxying UDP in HTTP](https://www.rfc-editor.org/rfc/rfc9298)
- [HTTP/2 概览](overview.md)
