# Connection 文档

## 概述

`connection` 模块提供了统一的网络连接抽象层，封装 TCP 套接字和 TLS 加密连接，
为 HTTP 协议栈提供底层 I/O 能力。

连接模块围绕 `Connection` 接口设计，支持 TCP 明文连接、TLS 1.2 加密连接（客户端和服务端）、
连接池集成、以及内存模拟连接（测试用）。

## 接口与类层次

```
Connection (接口)
├── TcpConnection              TCP 套接字连接
├── TlsConnection              TLS 客户端连接
├── TlsServerConnection        TLS 服务端连接
├── BufferedConnection         带写入缓冲区的装饰器
├── AbstractConnection         基础实现骨架（复用于 Tcp/Tls）
└── MockConnection             内存模拟连接（测试）
辅助:
├── AlpnParser                 ClientHello ALPN 协议解析
├── TlsConfig                  TLS 配置对象（证书、ALPN、版本）
├── SecureRandom               加密安全随机数生成器
└── TlsUtils                   TLS 记录层编解码工具
```

## 快速参考

```cangjie
import http_lib.connection.*
```

## Connection 接口

所有连接类型实现的核心接口：

```cangjie
// 基础状态
conn.isConnected()
conn.canReuseTransport()    // 连接是否可复用于传输

// 读写操作
conn.read(buf)              // 读取数据到缓冲区
conn.write(data)            // 写入数据
conn.flush()                // 刷新写入缓冲区
conn.writeBuffers(buffers)  // 批量写入（减少系统调用）

// 地址信息
conn.localAddress()
conn.remoteAddress()

// 连接元数据
conn.connectedAt()          // 连接建立时间
conn.lastActivityAt()       // 最后活动时间
conn.updateActivity()       // 更新活动时间

// 超时控制
conn.setReadTimeout(Duration.second * 30)
conn.setWriteTimeout(Duration.second * 30)
conn.setTimeout(Duration.second * 60)

// TLS 状态
conn.connectionState()      // -> Option<ConnectionState>

// 关闭
conn.close()
```

## AbstractConnection（抽象基类）

提供 `Connection` 接口的通用实现骨架，具体连接类型（TcpConnection、TlsConnection 等）
继承此类以减少重复代码：

- 自动跟踪 `connectedAt()` 和 `lastActivityAt()`
- 实现 `updateActivity()`、`isConnected()` 和 `close()`
- 子类只需实现 `read()`、`write()`、`flush()` 等底层 I/O 方法
- 提供通用 `connectionState()` 返回实现

## BufferedConnection

带写入缓冲区的装饰器模式连接，积累小写入后批量发送，减少系统调用次数：

```cangjie
let buffered = BufferedConnection(conn)

// 小数据暂存缓冲区
buffered.write(smallData1)    // 进入缓冲区
buffered.write(smallData2)    // 进入缓冲区

// 强制刷出缓冲区数据到底层连接
buffered.flush()

// 读操作直通底层连接（无缓冲）
buffered.read(buf)
```

适用于需要频繁发送小块数据的场景（如 HTTP/2 帧写入）。

## AlpnParser

直接从 TLS ClientHello 消息二进制解析 ALPN（Application-Layer Protocol Negotiation）
扩展中的协议列表，无需完整解析证书：

```cangjie
let clientHello = tlsHandshakeBytes
let protos = AlpnParser.parse(clientHello)
// 返回 ["h2", "http/1.1"]
```

用于服务端在 TLS 握手前确定 ALPN 协商结果。

## SecureRandom

加密安全的伪随机数生成器（CSPRNG），用于生成随机字节和整数：

```cangjie
// 生成指定长度的随机字节
let bytes = SecureRandom.bytes(32)

// 生成随机 Int64
let randInt = SecureRandom.int64()

// 生成随机 UInt8
let randByte = SecureRandom.uint8()
```

在 HTTP/2 HPACK 防攻击、随机帧填充、Token/Nonce 生成等场景中使用。

## TlsUtils

TLS 记录层编解码辅助函数：

```cangjie
import http_lib.connection.tls_utils

// TLS 头部长度
TlsUtils.TLS_HEADER_LENGTH  // 5

// TLS 最大记录大小
TlsUtils.MAX_TLS_RECORD_SIZE  // 16384

// TLS 内容类型常量
TlsUtils.CONTENT_TYPE_CHANGE_CIPHER_SPEC  // 20 (ChangeCipherSpec)
TlsUtils.CONTENT_TYPE_ALERT               // 21 (Alert)
TlsUtils.CONTENT_TYPE_HANDSHAKE           // 22 (Handshake)
TlsUtils.CONTENT_TYPE_APPLICATION_DATA    // 23 (Application Data)
```

## TcpConnection

TCP 套接字连接，封装 `std.net.TcpSocket`：

```cangjie
// 快速连接（默认 30s 超时）
let conn = TcpConnection.connect("example.com", 80)

// 自定义超时
let conn = TcpConnection.connect("example.com", 443,
    connectTimeout: Duration.second * 10,
    readTimeout: Duration.second * 30,
    writeTimeout: Duration.second * 30)

// 从已有 socket 创建
let socket = TcpSocket("example.com", 80)
socket.noDelay = true
socket.connect(timeout: Duration.second * 30)
let conn = TcpConnection(socket, remoteHost: "example.com", remotePort: 80)
```

特性：
- 自动设置 `TCP_NODELAY` 禁用 Nagle 算法
- 跟踪连接时间和最后活动时间
- 支持连接池集成

## TlsConnection（客户端）

TLS 1.2 客户端加密连接，基于 JinguiSSL 的 ECDHE P-256 + AES-GCM：

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.verifyPeer = true
tlsConfig.verifyHost = true
tlsConfig.caCertPath = "/etc/ssl/certs/ca-certificates.crt"
tlsConfig.nextProtos = ["h2", "http/1.1"]

let tcpConn = TcpConnection.connect("example.com", 443)
let tlsConn = TlsConnection(tcpConn, tlsConfig)
tlsConn.connect()

// 获取连接状态
let state = tlsConn.connectionState()
state.version              // "TLS 1.2"
state.cipherSuite          // 密码套件名称
state.negotiatedProtocol   // ALPN 协商结果，如 "h2"
state.serverName           // SNI 服务器名称
state.isSecure             // true
```

## TlsServerConnection（服务端）

TLS 1.2 服务端加密连接：

```cangjie
let config = TlsConfig()
config.serverCertPath = "/path/to/cert.pem"
config.serverKeyPath = "/path/to/key.pem"

let tcpConn = TcpConnection.connect("0.0.0.0", 443)
let tlsServerConn = TlsServerConnection(tcpConn, config)
tlsServerConn.accept()
```

## TlsConfig

完整的 TLS 配置对象：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `verifyPeer` | Bool | true | 验证对等证书 |
| `verifyHost` | Bool | true | 验证主机名 |
| `enableDiagnostics` | Bool | false | TLS 诊断日志 |
| `caCertPath` | String | "" | CA 证书路径 |
| `clientCertPath` | String | "" | 客户端证书（mTLS） |
| `clientKeyPath` | String | "" | 客户端私钥（mTLS） |
| `serverCertPath` | String | "" | 服务端证书 |
| `serverKeyPath` | String | "" | 服务端私钥 |
| `nextProtos` | Array\<String\> | ["h2","http/1.1"] | ALPN 协议列表 |
| `minVersion` | UInt16 | 0 (auto) | 最低 TLS 版本 |
| `maxVersion` | UInt16 | 0 (auto) | 最高 TLS 版本 |
| `autoLoadSystemCerts` | Bool | true | 自动加载系统证书 |

工厂方法：
- `TlsConfig.default()` — 安全默认配置
- `TlsConfig.insecure()` — 跳过证书验证（仅测试用）
- `TlsConfig.http1Only()` — 禁用 HTTP/2 ALPN

## MockConnection

内存模拟连接，用于单元测试，无需真实网络：

```cangjie
let mock = MockConnection()
mock.writeTestData(b"HTTP/1.1 200 OK\r\n\r\n")
let n = mock.read(buf)       // 读取模拟数据
mock.close()
```

## ConnectionState

TLS 连接握手结果：

```cangjie
let state = conn.connectionState()
match (state) {
    case Some(s) =>
        s.version             // "TLS 1.2"
        s.cipherSuite         // "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        s.negotiatedProtocol  // "h2" 或 "http/1.1"
        s.serverName          // SNI 服务器名称
        s.isSecure            // true
    case None => ()            // 非 TLS 连接
}
```

## 连接池集成

`TcpConnection` 和 `TlsConnection` 实现了 `canReuseTransport()` 方法，
供连接池判断连接是否仍然可复用：

```cangjie
if (conn.canReuseTransport()) {
    pool.release(host, port, isSecure, conn, reusable: true)
} else {
    conn.close()
}
```

## 生命周期钩子

`AbstractConnection` 提供活动时间跟踪：

```cangjie
let conn = TcpConnection.connect("example.com", 80, ...)
conn.connectedAt()        // DateTime — 连接建立时刻
conn.lastActivityAt()     // DateTime — 最近一次 I/O 活动时刻
conn.updateActivity()     // 手动刷新活动时间
```

## 相关模块

- [Buffer 文档](../buffer/README.md) — 底层字节缓冲区
- [Server 文档](../server/README.md) — HTTP 服务器集成
- [Client 文档](../client/README.md) — HTTP 客户端集成
- [Utils 文档](../utils/README.md) — 工具函数

## 参考

- [RFC 5246 — TLS 1.2](https://www.rfc-editor.org/rfc/rfc5246)
- [RFC 7301 — ALPN](https://www.rfc-editor.org/rfc/rfc7301)
- [JinguiSSL — 仓颉 SSL/TLS 库](https://gitcode.com/changeden/jinguissl_core)
