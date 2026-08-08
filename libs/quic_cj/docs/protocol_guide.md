# QUIC 协议实现指南

本文档详细说明 quic_cj 如何实现 QUIC 传输协议（RFC 9000）。

## 版本支持

| 版本 | 线缆值 | 状态 |
|---------|-----------|--------|
| QUIC v1 | 0x00000001 | 支持 |
| QUIC v2 | 0x6B3343CF | 支持 |
| Draft-29 | 0xFF00001D | 不支持 |

## 包格式

### 长包头（Initial、Retry、Handshake、0-RTT）

```
字节 0：   1 1 T T X X X X    （长包头 + 固定位 + 类型 + 保留位）
字节 1：   版本（32 位）
字节 5：   目标连接 ID 长度
字节 6：   目标连接 ID（变长）
字节 N：   源连接 ID 长度
字节 N+1： 源连接 ID（变长）
```

对于 **Initial** 包：
- 令牌长度（变长整数）
- 令牌（变长）
- 长度（变长整数）
- 包编号（变长）
- 负载（加密）

### 短包头（1-RTT）

```
字节 0：   0 1 K X X X X X    （短包头 + 固定位 + 密钥阶段 + 保留位）
字节 1：   目标连接 ID（已知长度）
字节 N：   包编号（变长）
字节 N：   负载（加密）
```

## 帧类型（共 25 种）

| 类型 | 线缆值 | 类 | 描述 |
|------|-----------|-------|-------------|
| PING | 0x01 | `PingFrame` | 保活 |
| ACK | 0x02 | `AckFrame` | 包确认 |
| ACK_ECN | 0x03 | `AckFrame` | 带 ECN 计数的 ACK |
| RESET_STREAM | 0x04 | `ResetStreamFrame` | 流重置 |
| STOP_SENDING | 0x05 | `StopSendingFrame` | 停止发送请求 |
| CRYPTO | 0x06 | `CryptoFrame` | TLS 握手数据 |
| NEW_TOKEN | 0x07 | `NewTokenFrame` | 地址验证令牌 |
| STREAM | 0x08–0x0F | `StreamFrame` | 流数据 |
| MAX_DATA | 0x10 | `MaxDataFrame` | 连接级流量控制 |
| MAX_STREAM_DATA | 0x11 | `MaxStreamDataFrame` | 流级流量控制 |
| MAX_STREAMS | 0x12-0x13 | `MaxStreamsFrame` | 流数上限提升 |
| DATA_BLOCKED | 0x14 | `DataBlockedFrame` | 连接阻塞 |
| STREAM_DATA_BLOCKED | 0x15 | `StreamDataBlockedFrame` | 流阻塞 |
| STREAMS_BLOCKED | 0x16-0x17 | `StreamsBlockedFrame` | 达到流上限 |
| NEW_CONNECTION_ID | 0x18 | `NewConnectionIDFrame` | 新连接 ID |
| RETIRE_CONNECTION_ID | 0x19 | `RetireConnectionIDFrame` | 废弃连接 ID |
| PATH_CHALLENGE | 0x1A | `PathChallengeFrame` | 路径验证 |
| PATH_RESPONSE | 0x1B | `PathResponseFrame` | 路径验证响应 |
| CONNECTION_CLOSE | 0x1C | `ConnectionCloseFrame` | 传输层错误 |
| APPLICATION_CLOSE | 0x1D | `ApplicationCloseFrame` | 应用层错误 |
| HANDSHAKE_DONE | 0x1E | `HandshakeDoneFrame` | 服务端握手完成 |
| DATAGRAM | 0x30-0x31 | `DatagramFrame` | 不可靠数据传输 |
| ACK_FREQUENCY | 0xAF | `AckFrequencyFrame` | ACK 频率控制 |
| IMMEDIATE_ACK | 0x1F | `ImmediateAckFrame` | 请求立即 ACK |

## 变长整数编码（RFC 9000 §16）

QUIC 使用紧凑的变长整数编码：

| 前缀 | 长度 | 取值范围 |
|--------|--------|-------------|
| 00 | 1 字节 | 0–63 |
| 01 | 2 字节 | 0–16383 |
| 10 | 4 字节 | 0–1073741823 |
| 11 | 8 字节 | 0–2^62-1 |

### 编码示例

```cangjie
// 值 37 → 1 字节：  0x25
// 值 15293 → 2 字节：  0x7B 0xBD
// 值 494878333 → 4 字节：  0x9D 0x7F 0x3E 0x7D
```

## TLS 1.3 集成

### 初始 AEAD

初始密钥通过 HKDF 从目标连接 ID 派生：

```
initial_secret = HKDF-Extract(salt, conn_id)
client_initial_secret = HKDF-Expand-Label(initial_secret, "client in", "", 32)
server_initial_secret = HKDF-Expand-Label(initial_secret, "server in", "", 32)
key = HKDF-Expand-Label(secret, "quic key", "", 16)
iv  = HKDF-Expand-Label(secret, "quic iv", "", 12)
hp  = HKDF-Expand-Label(secret, "quic hp", "", 16)
```

### 包头保护

包头保护使用 HP 密钥掩盖包类型和包编号：

1. 提取从密文第 4 个字节开始的 16 字节样本
2. 使用 HP 密钥加密样本（AES-ECB 或 ChaCha20）
3. 第一个字节：屏蔽类型/固定位（长包头 0x0F，短包头 0x1F）
4. 剩余字节：与包编号进行异或操作


## Stateless Reset（RFC 9000 §10）

Stateless Reset 允许服务端在收到对应已关闭连接的数据包时，发送一个
无状态的重置令牌响应，使客户端快速识别连接已终止。

quic_cj 实现：

- **重置令牌生成：** 基于连接 ID 通过静态密钥派生的 16 字节令牌
- **Stateless Reset 包格式：** 短包头 + 不可区隔的随机负载 + 重置令牌
- **接收端处理：** 检测无效包头时尝试匹配重置令牌，匹配则关闭连接

相关文件：`tls/stateless_reset.cj`

### 密钥更新（RFC 9001 §6）

quic_cj 支持 AEAD 密钥更新，通过 KEY_PHASE 比特翻转驱动：

- **UpdatableAEAD：** 支持密钥派生、回退和包计数限制
- **自动触发：** 可通过连接事件循环调度 `rollKeys()` 调用
- **包头保护：** 密钥更新后同步更新 HP 密钥

相关文件：`tls/updatable_aead.cj`

### 拥塞控制扩展

quic_cj 除默认的 CUBIC（RFC 9438）外，支持可插拔的拥塞控制算法：

- **CUBIC：** 适用于高带宽远距离网络
- **NewReno（RFC 6582）：** 适用于低丢包率环境
- **CongestionAlgorithm 接口：** 可扩展，支持添加 BBRv2 等第三方算法
- **Pacer：** 平滑数据发送，避免突发对网络造成冲击

相关文件：`congestion/interface.cj`、`congestion/cubic_sender.cj`、`congestion/new_reno_sender.cj`

### qlog 结构化事件日志（RFC 9421）

quic_cj 实现 RFC 9421 定义的 QUIC 事件日志框架：

- **Tracer 接口：** 入植到 Connection 中，记录连接级事件
- **事件类型：** 包发送/接收、丢包、状态转换、拥塞状态变更
- **调试用途：** 替代 println 埋点，支持结构化日志分析

相关文件：`qlog/tracer.cj`、`qlog/types.cj`

### 丢包检测与重传

基于 RFC 9002 的丢包检测和重传机制：

- **SentPacketHandler：** 追踪已发送包并检测 ACK 间隙中的丢包
- **RetransmissionQueue：** 丢失包中的帧数据重新排队，优先在下一包中发送
- **计时器驱动：** PTO（Probe Timeout）和 Loss Detection 计时器

相关文件：`core/retransmission_queue.cj`、`ack/sent_packet_handler.cj`
## 连接迁移

quic_cj 支持 RFC 9000 §9 定义的连接迁移机制：

- **路径验证：** 通过 PATH_CHALLENGE/PATH_RESPONSE 帧验证新路径
- **Preferred Address：** 服务端可通过传输参数建议替代地址
- **迁移禁用：** 设置 `disableActiveMigration = true` 可禁用连接迁移
- **多连接 ID：** 支持 NEW_CONNECTION_ID/RETIRE_CONNECTION_ID 帧管理多个连接 ID

## 流多路复用

### 流 ID 布局

| 位 | 用途 |
|------|---------|
| 位 0 | 发起方（0=客户端，1=服务端） |
| 位 1 | 方向（0=双向，1=单向） |
| 位 2+ | 流编号 |

### 流类型

- **双向流：** 客户端和服务端均可发送数据
- **单向流：** 仅发起方发送数据

## 流量控制

### 连接级

- `initialMaxData` — 所有流的最大字节总数
- 当窗口剩余 25% 时发送窗口更新

### 流级

- `initialMaxStreamDataBidiLocal` / `initialMaxStreamDataBidiRemote`
- `initialMaxStreamDataUni`
- 基于消耗速率自动调整窗口
