# Server 文档


## 目录

- [Server 使用指南](usage.md) — 路由、中间件、配置、启动
- [安全配置](security.md) — HSTS、CSP、速率限制、安全头
- [TLS/HTTPS](tls.md) — 证书配置、HTTP/2 over TLS、ALPN

## 快速参考

```cangjie
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.router.{Router, Handler}
```

## 新特性 (v0.1.0)

### 空闲超时
```cangjie
let config = HttpServerConfig()
config.idleTimeout = Duration.second * 60  // 60秒无请求则关闭连接
```

### 优雅关闭
```cangjie
// HTTP/2 连接自动发送 GOAWAY 帧
server.shutdown()  // 等待进行中的请求完成
```

### 目录列表
```cangjie
let config = FileServerConfig()
config.listingEnabled = true  // 启用目录浏览
let handler = serveStatic("/var/www", config: config)
```

### HTTP/2 服务端推送
```cangjie
let h2conn = Http2Connection(conn, isServer: true)
let pushId = h2conn.pushPromise(streamId, pushRequest)
h2conn.sendPushResponse(pushId, pushResponse)
```

### WebSocket 升级
自动检测 `Upgrade: websocket` 头并执行 RFC 6455 升级握手。

### 简化的路由集成
```cangjie
let server = HttpServer(handler: router.handler())
```
中间件、路径参数、尾部斜杠处理、404/405 响应均由路由自动处理。
 ### 相关模块
 - [Connection 文档](../connection/README.md) — TCP/TLS 连接层
 - [Buffer 文档](../buffer/README.md) — ByteBuffer 基础 I/O
 - [Utils 文档](../utils/README.md) — 工具函数
