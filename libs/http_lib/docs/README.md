# http_lib 文档

[![cjc](https://img.shields.io/badge/cjc-1.0.5-blue)](https://developer.huawei.com/consumer/cn/cangjie/)
[![cjpm](https://img.shields.io/badge/cjpm-1.0.5-blue)](https://developer.huawei.com/consumer/cn/cangjie/)
[![HTTP/1.x](https://img.shields.io/badge/HTTP-1.x-green)](./)
[![HTTP/2](https://img.shields.io/badge/HTTP-2.0-green)](./)
[![HTTP/3](https://img.shields.io/badge/HTTP-3.0-green)](./)
[![Tests](https://img.shields.io/badge/tests-1921%20passed-brightgreen)](./)

仓颉 HTTP 协议封装库 — 基于 TCP 实现 HTTP/1.x 与 HTTP/2 的 Server + Client，并提供 HTTP/3 (QUIC) 协议类型定义、帧编解码和 QPACK 头部压缩。


## 快速入门

**Server** — 5 行启动:
```cangjie
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.router.Router
import http_lib.core.{HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

let router = Router()
router.get("/", { req => HttpResponse.text(HttpStatus.OK, "Hello, World!") })
HttpServer(handler: router.handler()).listenAndServe("0.0.0.0", 8080)
```

- `router.handler()` 创建一个分发函数，自动应用中间件、匹配路由，对未匹配的路由返回 404/405，并处理尾部斜杠重定向。
- 通过 `router.use()` 注册的中间件在处理器链中正确应用。

**Client** — 3 行请求:
```cangjie
import http_lib.client.HttpClient

let client = HttpClient()
let resp = client.get("https://httpbin.org/json")
println(resp.bodyAsString())
client.close()
```

## 目录

### Server
- [Server 目录](server/README.md)
- [Server 使用指南](server/usage.md)
- [安全配置](server/security.md)
- [TLS/HTTPS](server/tls.md)

### Connection
- [Connection 目录](connection/README.md)

### Buffer
- [Buffer 目录](buffer/README.md)

### Utils
- [Utils 目录](utils/README.md)

### Testutil
- [Testutil 目录](testutil/README.md)

### Client
- [Client 目录](client/README.md)
- [Client 使用指南](client/usage.md)
- [高级 Client](client/advanced.md)

### 核心模块
- [核心模块目录](core/README.md)
- [核心 API 参考](core/api.md)

### HTTP/2
- [HTTP/2 目录](http2/README.md)
- [HTTP/2 概览](http2/overview.md)

### HTTP/3
- [HTTP/3 支持](http3/README.md)
- [胶囊协议与 WebSocket 隧道](http3/capsule.md)
- [HTTP/3 优先级](http3/priority.md)

### Message
- [Message 使用指南](message/usage.md)
- [Message 目录](message/README.md)

### Router
- [Router 目录](router/README.md)

### 参考
- [完整手册 (中文)](manual.md)

