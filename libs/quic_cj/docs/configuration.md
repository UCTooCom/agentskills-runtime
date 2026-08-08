# 配置指南

## 默认配置

```cangjie
let cfg = defaultConfig()
// 或者
let cfg = Config()
```

两者都产生相同的 RFC 推荐默认值。

## 全部配置选项

| 选项 | 默认值 | 描述 |
|--------|---------|-------------|
| `versions` | `[VERSION_1, VERSION_2]` | 支持的 QUIC 版本 |
| `handshakeIdleTimeoutMs` | 5000 | 握手超时时间（毫秒） |
| `maxIdleTimeoutMs` | 30000 | 连接空闲超时（毫秒） |
| `maxIncomingStreams` | 100 | 最大并发双向流数 |
| `maxIncomingUniStreams` | 100 | 最大并发单向流数 |
| `initialStreamReceiveWindow` | 512KB | 初始流接收窗口 |
| `maxStreamReceiveWindow` | 2MB | 最大流接收窗口 |
| `initialConnectionReceiveWindow` | 8MB | 初始连接接收窗口 |
| `maxConnectionReceiveWindow` | 32MB | 最大连接接收窗口 |
| `initialPacketSize` | 1200 | 初始包大小（字节） |
| `serverName` | "" | TLS SNI 服务器名称 |
| `disableActiveMigration` | false | 禁用连接迁移 |
| `preferredAddressData` | [] | 服务端建议的替代地址数据 |
| `maxDatagramFrameSize` | 0 | DATAGRAM 帧最大负载大小 |

## 典型场景模板

### 通用场景

```cangjie
let cfg = Config()
cfg.versions = [VERSION_1, VERSION_2]
cfg.maxIdleTimeoutMs = 30000
cfg.maxIncomingStreams = 100
```

### 低延迟

```cangjie
let cfg = Config()
cfg.initialStreamReceiveWindow = 1024 * 1024      // 1 MB
cfg.initialConnectionReceiveWindow = 16 * 1024 * 1024  // 16 MB
cfg.initialPacketSize = 1450  // 接近 MTU
```

### 低内存

```cangjie
let cfg = Config()
cfg.maxIncomingStreams = 10
cfg.maxIncomingUniStreams = 10
cfg.initialStreamReceiveWindow = 65536       // 64 KB
cfg.maxStreamReceiveWindow = 262144          // 256 KB
cfg.initialConnectionReceiveWindow = 262144  // 256 KB
cfg.maxIdleTimeoutMs = 15000                 // 15 秒
```

### 高吞吐量

```cangjie
let cfg = Config()
cfg.initialStreamReceiveWindow = 4 * 1024 * 1024       // 4 MB
cfg.maxStreamReceiveWindow = 16 * 1024 * 1024           // 16 MB
cfg.initialConnectionReceiveWindow = 64 * 1024 * 1024   // 64 MB
cfg.maxConnectionReceiveWindow = 256 * 1024 * 1024      // 256 MB
cfg.maxIncomingStreams = 10000
cfg.maxIdleTimeoutMs = 120000  // 2 分钟
```

## 校验规则

`Config.validate()` 检查：
- `versions` 不能为空
- `initialPacketSize` 被限制为 ≥ 1200
- `maxIncomingStreams` 和 `maxIncomingUniStreams` 被限制为 ≤ 2^60
