# Server TLS/HTTPS 配置

## 基础 TLS Server

```cangjie
import http_lib.connection.TlsConfig
import http_lib.server.{HttpServer, HttpServerConfig}

let tlsConfig = TlsConfig.default()
tlsConfig.serverCertPath = "/path/to/cert.pem"
tlsConfig.serverKeyPath = "/path/to/key.pem"
tlsConfig.nextProtos = ["h2", "http/1.1"]  // ALPN negotiation

let config = HttpServerConfig()
config.tlsConfig = tlsConfig
config.enableHttp2 = true  // HTTP/2 over TLS

let server = HttpServer(router, config: config)
server.listenAndServeTls("0.0.0.0", 443)
```

## TLS 配置选项

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `verifyPeer` | Bool | true | 验证对等证书 |
| `verifyHost` | Bool | true | 验证主机名 |
| `caCertPath` | String? | None | CA 证书路径 |
| `clientCertPath` | String? | None | 客户端证书 |
| `clientKeyPath` | String? | None | 客户端密钥 |
| `serverCertPath` | String? | None | 服务器证书 |
| `serverKeyPath` | String? | None | 服务器密钥 |
| `nextProtos` | Array\<String\> | ["h2","http/1.1"] | ALPN 协议列表 |
| `minVersion` | UInt16 | 0 (auto) | 最低 TLS 版本 (0x0301=TLS1.0, 0x0302=TLS1.1, 0x0303=TLS1.2, 0x0304=TLS1.3) |
| `maxVersion` | UInt16 | 0 (auto) | 最高 TLS 版本 |
| `autoLoadSystemCerts` | Bool | true | 自动从系统路径加载 CA/服务器证书 |
| `enableDiagnostics` | Bool | false | 打印 TLS 握手调试日志 |

## HTTP/1.1 Only

```cangjie
let tlsConfig = TlsConfig.http1Only()
tlsConfig.serverCertPath = "/path/to/cert.pem"
tlsConfig.serverKeyPath = "/path/to/key.pem"
```

## 不安全模式（仅开发/测试）

```cangjie
let tlsConfig = TlsConfig.insecure()
tlsConfig.serverCertPath = "/path/to/cert.pem"
tlsConfig.serverKeyPath = "/path/to/key.pem"
```

## mTLS（双向 TLS）

通过 TlsConfig 的 `verifyPeer`、`verifyHost`、`caCertPath` 实现客户端证书验证:

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.serverCertPath = "/path/to/server.pem"
tlsConfig.serverKeyPath = "/path/to/server-key.pem"
tlsConfig.verifyPeer = true       // 验证客户端证书
tlsConfig.verifyHost = true       // 验证客户端主机名
tlsConfig.caCertPath = "/path/to/ca.pem"  // CA 证书，用于验证客户端

let config = HttpServerConfig()
config.tlsConfig = tlsConfig

let server = HttpServer(router, config: config)
server.listenAndServeTls("0.0.0.0", 443)
```

客户端连接时需要提供客户端证书:

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.clientCertPath = "/path/to/client.pem"
tlsConfig.clientKeyPath = "/path/to/client-key.pem"
tlsConfig.caCertPath = "/path/to/ca.pem"
tlsConfig.verifyPeer = true
tlsConfig.verifyHost = true
```

## TLS 版本控制

通过 `minVersion` 和 `maxVersion` 限制 TLS 版本:

```cangjie
let tlsConfig = TlsConfig.default()
tlsConfig.minVersion = 0x0303  // 最低 TLS 1.2
tlsConfig.maxVersion = 0x0304  // 最高 TLS 1.3

// 常用值: 0x0301 = TLS 1.0, 0x0302 = TLS 1.1,
//         0x0303 = TLS 1.2, 0x0304 = TLS 1.3
// 设为 0 表示自动选择（默认）
```

> **注意**: TLS 1.3 支持计划在未来版本中实现。`minVersion` 和 `maxVersion` 字段已为此做好准备，当前仅支持 TLS 1.2。将其设为 `0x0304` 目前不会启用 TLS 1.3。

## 系统证书自动加载

`TlsConfig` 支持自动探测系统 CA 证书和服务器证书:

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.autoLoadSystemCerts = true  // 默认开启

// 自动从 /etc/ssl/certs/、/etc/pki/tls/certs/ 等标准路径加载
tlsConfig.ensureCaCert()       // 加载系统 CA 证书
tlsConfig.ensureServerCert()   // 自动探测 Let's Encrypt、snakeoil 等证书

// 手动指定（覆盖自动加载）
tlsConfig.caCertPath = "/path/to/custom-ca.pem"
```

探测路径（按顺序）:
- CA 证书: Debian/Ubuntu (`/etc/ssl/certs/ca-certificates.crt`), RHEL/Fedora (`/etc/pki/tls/certs/ca-bundle.crt`), OpenSUSE, Alpine 等
- 服务器证书: Let's Encrypt (`/etc/letsencrypt/live/`), Debian snakeoil, 通用路径

## 诊断模式

开启 TLS 握手调试日志:

```cangjie
let tlsConfig = TlsConfig.default()
tlsConfig.enableDiagnostics = true  // 打印完整握手过程日志

// 输出示例:
// [TLS-Server] Starting TLS 1.2 ECDHE server handshake...
// [TLS-Server] ClientHello received (245 bytes)
// [TLS-Server] Client ALPN: [h2, http/1.1]
// [TLS-Server] Negotiated ALPN: h2
```

## ALPN 协商

Server 使用 `negotiateProtocol()` 从客户端支持的协议列表中选择:
- 优先 h2（如果客户端支持）
- 否则回退到 http/1.1

```cangjie
let tlsConfig = TlsConfig.default()
tlsConfig.supportsH2()    // true
tlsConfig.supportsHttp1() // true

let negotiated = tlsConfig.negotiateProtocol(["h2", "http/1.1"])
// 返回 "h2" 或 "http/1.1"
```

### 客户端 ALPN

`connectionState().negotiatedProtocol` 现在在 TLS 握手后从客户端侧正确返回 ALPN 协商的协议:

```cangjie
// 客户端: TLS 握手后获取协商协议
let tlsConn = TlsConnection(tcpSocket, tlsConfig)
tlsConn.connect()
let negotiated = tlsConn.connectionState().negotiatedProtocol
// 返回 "h2" 或 "http/1.1"
```

## 密码套件

当前支持:
- TLS 1.2 ECDHE-RSA-AES-128-GCM-SHA256
- TLS 1.2 ECDHE-RSA-AES-256-GCM-SHA384

基于 JinguiSSL 的 ECDHE P-256 密钥交换 + AES-GCM 加密。

## ResponseBuilder TLS 集成 (新增 v0.3)

ResponseBuilder 支持 TLS 响应构建，与标准 Handler 完全兼容:

```cangjie
let handler = wrapResponseBuilderHandler({req, rw =>
    rw.header("Strict-Transport-Security", "max-age=31536000")
    rw.writeString("HTTPS Response")
})
```

## 服务端读取超时

TLS 服务端 `readExact()` 现在有超时保护，默认 30 秒。这可以防止慢客户端通过缓慢发送数据无限期保持连接打开。
