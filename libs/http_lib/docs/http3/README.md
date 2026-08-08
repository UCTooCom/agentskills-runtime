# HTTP/3 (QUIC) 支持

[![Tests](https://img.shields.io/badge/tests-1921%20passed-brightgreen)](./)
[![HTTP/3](https://img.shields.io/badge/HTTP-3.0-green)](./)
[![RFC 9114](https://img.shields.io/badge/RFC-9114-blue)](./)


基于 QUIC 传输协议的 HTTP/3（RFC 9114）实现。

## 架构

HTTP/3 连接层由以下组件组成：

```
┌──────────────────────────────────────┐
│         H3Connection / Http3Client   │
│  Http3Server                          │
│  (连接管理、帧 I/O、请求/响应)        │
├──────────────────────────────────────┤
│  Frame       │  QPACK                │
│ (编解码)     │ (动态表+流)           │
├──────────────────────────────────────┤
│  QuicTransportFactory / quic_cj       │
│  (QUIC 传输抽象 + 适配器)            │
└──────────────────────────────────────┘
```

## 功能特性

| 功能 | 状态 |
|------|------|
| HTTP/3 帧编解码（DATA / HEADERS / SETTINGS / GOAWAY / MAX_PUSH_ID / CANCEL_PUSH / PUSH_PROMISE） | ✅ |
| QPACK 头部压缩（编码器 + 解码器 + 动态表 + 阻塞流） | ✅ |
| H3Connection 状态机（INITIAL → CONNECTED → GOAWAY → CLOSED） | ✅ |
| 控制流管理（控制流 + QPACK 编码器/解码器流） | ✅ |
| SETTINGS 帧交换与协调 | ✅ |
| GOAWAY 优雅关闭 | ✅ |
| HTTP 请求/响应流复用 | ✅ |
| Http3Client（基于 QUIC 传输工厂） | ✅ |
| Http3Server（基于 QUIC 传输工厂） | ✅ |
| quic_cj 适配器（桥接 quic_cj 传输层） | ✅ |
| 服务端推送（sendPushPromise / sendPushResponse / CANCEL_PUSH） | ✅ |
| Extended CONNECT（RFC 9220，:protocol 隧道双向中继） | ✅ |
| HTTP/3 优先级（RFC 9218 Priority 头部解析 + 调度器） | ✅ |
| 胶囊协议（RFC 9297，DATAGRAM / DATAGRAM_WITH_CONTEXT / CLOSE） | ✅ |
| WebSocket over HTTP/3（H3WebSocketTunnel + H3WebSocketConnection 适配器） | ✅ |
| HTTP/3 压力测试（帧吞吐量 / QPACK / 连接状态 / 优先级调度 / 多连接并发） | ✅ |

## 连接生命周期

### 客户端
1. 创建 `QuicTransportFactory` 实现（如 `QuicCjTransportFactory`）
2. 创建 `Http3Client` 并设置传输工厂
3. 调用 `connect(host, port)` 建立 QUIC 连接
4. 发送 SETTINGS 帧，启动 QPACK 编码器/解码器流
5. 发送 HTTP 请求（HEADERS + DATA 帧）
6. 接收服务端响应
7. 调用 `close()` 关闭连接

### 服务端
1. 创建 `QuicTransportFactory` 实现
2. 创建 `Http3Server` 并设置传输工厂和请求处理器
3. 调用 `listenAndServe(host, port)` 开始监听
4. 接受 QUIC 连接，创建 H3Connection
5. 接收 SETTINGS 帧，处理控制流
6. 接收请求，调用处理器，发送响应

## 关键限制

### QUIC 传输依赖
- HTTP/3 需要底层的 QUIC 传输层（当前使用 `quic_cj`）
- `quic_cj` 提供 `QuicTransportFactory` / `QuicConnection` / `QuicStream` / `QuicListener` 的完整适配

### QPACK
- 最大动态表容量：4096 字节（可通过 SETTINGS 协商至 65536）
- 阻塞流数量：100
- 最大字段区大小：65536 字节

### 帧
- 帧类型使用 QUIC Varint 编码（非 HTTP/2 的固定 9 字节帧头）
- 不支持 CONTINUATION 帧（QUIC 流保证有序）
- 不支持 PRIORITY 帧（使用 HTTP 优先级信号）

## 文件清单

| 文件 | 说明 |
|------|------|
| `quic_transport.cj` | QUIC 传输层抽象接口 |
| `common.cj` | HTTP/3 常量、错误码、帧类型 |
| `frame.cj` | HTTP/3 帧编码/解码 |
| `qpack.cj` | QPACK 头部压缩 |
| `connection.cj` | H3Connection 状态机 |
| `client.cj` | HTTP/3 客户端 |
| `server.cj` | HTTP/3 服务器 |
| `quic_cj_adapter.cj` | quic_cj 传输适配器 |
| `priority.cj` | HTTP/3 优先级（RFC 9218） |
| `capsule.cj` | 胶囊协议与 WebSocket 隧道（RFC 9297） |
 | `capsule.md` | 胶囊协议与 WebSocket 隧道使用指南 |
 | `priority.md` | HTTP/3 优先级使用指南 |
| `priority_test.cj` | 优先级单元测试 |
| `capsule_test.cj` | 胶囊协议单元测试 |
| `http3_test.cj` | 单元测试（75+ 用例） |
| `http3_benchmark_test.cj` | 基准测试 |
 | `mock_quic.cj` | Mock QUIC 实现（测试用） |

## 参考

- [RFC 9114 — HTTP/3](https://www.rfc-editor.org/rfc/rfc9114)
- [RFC 9000 — QUIC: A UDP-Based Multiplexed and Secure Transport](https://www.rfc-editor.org/rfc/rfc9000)
- [RFC 9204 — QPACK: Field Compression for HTTP/3](https://www.rfc-editor.org/rfc/rfc9204)
- [quic_cj — Cangjie QUIC 实现](https://gitcode.com/changeden/quic_cj)
