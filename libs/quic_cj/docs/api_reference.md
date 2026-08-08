# API 参考

## 配置

### `Config` 类

连接配置，包含 RFC 推荐的默认值。

```cangjie
public class Config {
    public var versions: Array<Version>           // [VERSION_1, VERSION_2]
    public var handshakeIdleTimeoutMs: Int64      // 5000（5 秒）
    public var maxIdleTimeoutMs: Int64            // 30000（30 秒）
    public var maxIncomingStreams: Int64          // 100
    public var maxIncomingUniStreams: Int64       // 100
    public var initialStreamReceiveWindow: Int64  // 512*1024
    public var maxStreamReceiveWindow: Int64      // initial * 4
    public var initialConnectionReceiveWindow: Int64 // initial * 16
    public var maxConnectionReceiveWindow: Int64  // initial * 64
    public var initialPacketSize: Int64           // 1200
    public var serverName: String                 // ""
    public var disableActiveMigration: Bool      // false
    public var preferredAddressData: Array<Byte>  // []
    public var maxDatagramFrameSize: Int64        // 0
}
```

**方法：**
- `validate()` → `Bool` — 校验配置，应用最小值

### `defaultConfig()` → `Config`

返回具有 RFC 推荐默认值的 `Config`。

---

## 入口函数

### `dial(addr)` → `(Conn, Bool)`

使用默认配置拨号 QUIC 连接。

**参数：**
- `addr: String` — 远端地址（例如 "example.com:4433"）

**返回：**
- `(Conn, Bool)` — 连接句柄和成功标识

### `dialAddr(addr, config)` → `(Conn, Bool)`

使用自定义配置拨号。

### `listen(addr)` → `(Listener, Bool)`

使用默认配置监听入站 QUIC 连接。

### `listenAddr(addr, config)` → `(Listener, Bool)`

使用自定义配置监听。

---

## 传输层

### `Transport` 类

管理 UDP 监听器并分发入站包。

**构造函数：**
```cangjie
Transport(addr: String, config: Config)
```

**方法：**
| 方法 | 描述 |
|--------|-------------|
| `listen()` → `(Listener, Bool)` | 开始接受连接 |
| `dial(addr: String)` → `(Conn, Bool)` | 建立出站连接 |
| `handleReceivedPacket(data, addr, time)` | 将原始 UDP 包路由到处理器 |
| `setHandler(connId, handler) → Bool` | 注册包处理器 |

---

## 连接

### `Conn` 类

QUIC 连接（客户端或服务端）。

**方法：**
| 方法 | 描述 |
|--------|-------------|
| `openStream()` → `(Stream, Bool)` | 打开双向流 |
| `openUniStream()` → `(SendStream, Bool)` | 打开单向发送流 |
| `acceptStream()` → `(Stream, Bool)` | 接受入站双向流 |
| `acceptUniStream()` → `(ReceiveStream, Bool)` | 接受入站单向流 |
| `closeWithError(code, reason)` | 以传输层错误关闭 |
| `localAddr()` → `IPAddress` | 本地 IP 地址 |
| `remoteAddr()` → `String` | 远端套接字地址 |
| `getConnState()` → `ConnState` | 连接状态元数据 |

### `ConnState` 类

| 字段 | 类型 | 描述 |
|-------|------|-------------|
| `version` | `Version` | 正在使用的 QUIC 版本 |
| `handshakeComplete` | `Bool` | TLS 握手是否已完成 |
| `perspective` | `Perspective` | 客户端或服务器 |
| `srcConnId` | `Array<Byte>` | 源连接 ID |
| `destConnId` | `Array<Byte>` | 目标连接 ID |

---

## 监听器

### `Listener` 类

接受入站 QUIC 连接。

**方法：**
| 方法 | 描述 |
|--------|-------------|
| `accept()` → `(Conn, Bool)` | 接受下一个入站连接 |
| `addr()` → `String` | 监听器地址 |
| `close()` | 停止监听 |

---

## 流

### `Stream`（双向流）

| 方法 | 描述 |
|--------|-------------|
| `write(data) → Int64` | 向流写入字节 |
| `read() → Array<Byte>` | 读取可用字节 |
| `close()` | 关闭发送方向 |
| `getStreamId() → Int64` | 流标识符 |

### `SendStream`（单向发送）

| 方法 | 描述 |
|--------|-------------|
| `write(data) → Int64` | 写入字节 |
| `close()` | 关闭发送方向 |
| `getOffset() → Int64` | 当前写入偏移量 |

### `ReceiveStream`（单向接收）

| 方法 | 描述 |
|--------|-------------|
| `read() → Array<Byte>` | 读取可用字节 |
| `isFinReceived() → Bool` | 检查是否已收到 FIN |

---

## 错误处理

### `QError` 类

```cangjie
public class QError {
    public var transportCode: TransportErrorCode
    public var appCode: UInt64
    public var isTransport: Bool
    public var errorMessage: String
}
```
### `ApplicationError` 类

```cangjie
public class ApplicationError {
    public var errorCode: UInt64 = 0u64
    public var reason: String = ""
}
```

### `StreamError` 类

```cangjie
public class StreamError {
    public var streamId: Int64 = 0
    public var errorCode: StreamErrorCode = 0u64
    public var remote: Bool = false
}
```

### `DatagramTooLargeError` 类

```cangjie
public class DatagramTooLargeError {
    public var maxDatagramPayloadSize: Int64 = 0
}
```

### `CryptoError` 类

```cangjie
public class CryptoError {
    public var alert: UInt8 = 0u8
    public var message: String = ""
}
```

}
```

### 构造函数

| 函数 | 描述 |
|----------|-------------|
| `newTransportError(code, msg) → QError` | 创建传输层错误 |
| `newApplicationError(code, msg) → QError` | 创建应用层错误 |
| `newProtocolViolation(msg) → QError` | 创建协议违规错误 |
| `newFlowControlError(msg) → QError` | 创建流控错误 |
| `newFinalSizeError(msg) → QError` | 创建 final size 错误 |
| `newCryptoError(alert: UInt8, msg: String) → CryptoError` | 创建加密错误 |

### 传输层错误码

| 常量 | 值 | 描述 |
|----------|-------|-------------|
| `NO_ERROR` | 0x00 | 无错误 |
| `INTERNAL_ERROR` | 0x01 | 实现错误 |
| `CONNECTION_REFUSED` | 0x02 | 服务器拒绝连接 |
| `FLOW_CONTROL_ERROR` | 0x03 | 流量控制违规 |
| `STREAM_LIMIT_ERROR` | 0x04 | 流数量过多 |
| `STREAM_STATE_ERROR` | 0x05 | 流状态无效 |
| `FINAL_SIZE_ERROR` | 0x06 | 最终大小不匹配 |
| `FRAME_ENCODING_ERROR` | 0x07 | 帧编码错误 |
| `TRANSPORT_PARAMETER_ERROR` | 0x08 | 传输参数错误 |
| `CONNECTION_ID_LIMIT_ERROR` | 0x09 | 连接 ID 限制 |
| `PROTOCOL_VIOLATION` | 0x0a | 协议违规 |
| `INVALID_TOKEN` | 0x0b | 无效令牌 |
| `CRYPTO_BUFFER_EXCEEDED` | 0x0d | 加密缓冲区已满 |
| `KEY_UPDATE_ERROR` | 0x0e | 密钥更新错误 |
| `AEAD_LIMIT_REACHED` | 0x0f | AEAD 使用限制 |
| `NO_VIABLE_PATH` | 0x10 | 无可用网络路径 |

---

## 协议模块

### 版本

```cangjie
public type Version = UInt32
let VERSION_1: Version       // 0x00000001
let VERSION_2: Version       // 0x6B3343CF
let VERSION_DRAFT_29: Version // 0xFF00001D
let VERSION_UNKNOWN: Version  // 0xFFFFFFFF

func isValidVersion(v: Version) -> Bool
func chooseSupportedVersion(ours, theirs) -> (Version, Bool)
```

### 连接 ID

```cangjie
func generateConnectionId(len: Int64) -> Array<Byte>
func isValidConnectionIdLen(len: Int64) -> Bool
```

### 流 ID

```cangjie
func streamNumToStreamId(s, stype, pers) -> StreamId
func streamInitiatedBy(s: StreamId) -> Perspective
func streamType(s: StreamId) -> StreamType
func streamNum(s: StreamId) -> StreamNum
```

### 包编号

```cangjie
func decodePacketNumber(length, largest, truncated) -> PacketNumber
func packetNumberLengthForHeader(pn, largestAcked) -> PacketNumberLen
```

### 包类型

```cangjie
enum PacketType { Initial, Retry, Handshake, ZeroRTT }
func packetTypeToWire(pt: PacketType) -> UInt8
func packetTypeFromWire(v: UInt8) -> PacketType
```

### 加密级别

```cangjie
enum EncryptionLevel { Initial, Handshake, ZeroRTT, OneRTT }
```

### 视角

```cangjie
enum Perspective { Server, Client }
func oppositePerspective(p: Perspective) -> Perspective
```

### ECN

```cangjie
enum ECN { Unsupported, Non, ECT1, ECT0, CE }
```
