# http_lib 使用手册

[![Tests](https://img.shields.io/badge/tests-1921%20passed-brightgreen)](./)

## 概述

`http_lib` 是仓颉编程语言的 HTTP 协议封装库，基于 TCP 实现 HTTP/1.x 和 HTTP/2 的完整 Server 与 Client 能力，并提供 HTTP/3 (QUIC) 的帧编解码、QPACK 头部压缩和传输适配。

## 架构

```
┌────────────────────────────────────────────────────────────┐
│                       http_lib                          │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │  core    │ │  message │ │  buffer  │ │  connection   │  │
│  │  Method  │ │ Request  │ │   Byte   │ │  TCP / TLS    │  │
│  │  Status  │ │ Response │ │  Buffer  │ │  ALPN / mTLS  │  │
│  │  Version │ │  Parser  │ │          │ │               │  │
│  │  Headers │ │   Body   │ └──────────┘ └──────────────┘  │
│  │  Error   │ │ Chunked  │                                  │
│  │  Date    │ │ Compress │ ┌──────────────┐                │
│  └─────────┘ │ Range    │ │    http2      │                │
│              │ Cond.    │ │  Frames/HPACK │                │
│  ┌──────────┐│ Caching  │ │  Multiplexer  │                │
│  │  router  │└──────────┘ │  Flow Control │                │
│  │  Radix   │             │  Priority/Push│                │
│  │  Tree    │ ┌────────┐  └──────────────┘                │
│  │  CORS    │ │ server │  ┌──────────┐                    │
│  └──────────┘ │  TCP   │  │  client  │                    │
│               │  HTTPS │  │  HTTP    │                    │
│               │  H2C   │  │  Pool    │                    │
│               │  WS    │  │  Cookie  │                    │
│               └────────┘  │  Auth    │                    │
│                           └──────────┘                    │
└────────────────────────────────────────────────────────────┘
```



## 快速入门

### HTTP Server

```cangjie
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.router.Router
import http_lib.core.{HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

main() {
    let router = Router()
    router.get("/", { req => HttpResponse.text(HttpStatus.OK, "Hello, World!") })

    let server = HttpServer(handler: router.handler())
    server.listenAndServe("0.0.0.0", 8080)
}
```

### HTTP Client

```cangjie
import http_lib.client.HttpClient

main() {
    let client = HttpClient()
    let resp = client.get("https://api.example.com/users")
    println(resp.status.code)
    println(resp.bodyAsString())
    client.close()
}
```

### HTTPS Server 与 TLS

```cangjie
import http_lib.connection.TlsConfig
import http_lib.server.{HttpServer, HttpServerConfig}

main() {
    let tlsConfig = TlsConfig()
    tlsConfig.serverCertPath = "server.crt"
    tlsConfig.serverKeyPath = "server.key"
    tlsConfig.nextProtos = ["h2", "http/1.1"]

    let config = HttpServerConfig()
    config.tlsConfig = Some(tlsConfig)
    config.enableHttp2 = true

    let router = Router()
    router.get("/", { req => HttpResponse.text(HttpStatus.OK, "Secure Hello!") })

    let server = HttpServer(handler: router.handler(), config: config)
    server.listenAndServeTls("0.0.0.0", 443)
}
```

## 模块说明

### core — 核心类型

提供 HTTP 协议的基础类型定义：

```cangjie
import http_lib.core.*

// HTTP 方法
let method = HttpMethod.GET
let method = HttpMethod.POST   // PUT, DELETE, HEAD, OPTIONS, PATCH, TRACE, CONNECT

// HTTP 状态码
let status = HttpStatus.OK                    // 200
let status = HttpStatus.NOT_FOUND             // 404
let status = HttpStatus.INTERNAL_SERVER_ERROR // 500
status.isSuccess()     // true if 2xx
status.isClientError() // true if 4xx
status.isServerError() // true if 5xx

// HTTP 版本
let version = HttpVersion.HTTP_1_1

// 请求头
let headers = HttpHeaders()
headers.add("Content-Type", "application/json")
headers.set("X-Custom", "value")  // replaces existing
headers.get("content-type")       // case-insensitive → Some("application/json")
```

### message — 请求与响应

```cangjie
import http_lib.message.*

// 构建请求
let req = HttpRequest(method: HttpMethod.POST, url: "/api/users")
req.setJsonBody("{\"name\":\"test\"}")

// 构建响应
let resp = HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")
let resp = HttpResponse.text(HttpStatus.OK, "Hello")
let resp = HttpResponse.empty(HttpStatus.NO_CONTENT)

// 请求解析（服务端）
let req = HttpRequestParser.parse(rawBytes)
req.method      // HttpMethod
req.path        // "/api/users" (字段)
req.headers     // HttpHeaders
req.bodyAsString() // String
req.pathParams  // HashMap<String, String> (路由提取的参数)
req.queryParam("page") // Option<String>

// Body 解析
import http_lib.message.{parseFormBody, parseJsonBody, parseMultipartBody}
let form = parseFormBody(req)           // HashMap<String, String>
let json = parseJsonBody(req)           // String
let files = parseMultipartBody(req)     // HashMap<String, MultipartField>
```

### router — 路由

基于 Radix Tree 的高性能路由器，支持路径参数：

> **注意**：Router 现在是线程安全的，路由树受互斥锁保护。多个线程可以安全地并发注册或查找路由。

```cangjie
import http_lib.router.{Router, Handler}

let router = Router()
router.get("/", indexHandler)
router.post("/users", createUser)
router.get("/users/:id", getUser)
router.get("/files/*path", serveFile)

// 查找路由
let result = router.find(HttpMethod.GET, "/users/42")
result.handler.isSome()  // true
result.params.get("id")  // Some("42")
```

### server — HTTP 服务器

基于 `TcpServerSocket` 的 HTTP/1.x 服务器：

```cangjie
import http_lib.server.{HttpServer, HttpServerConfig}

let server = HttpServer(handler: myHandler)
server.listenAndServe("0.0.0.0", 8080)
server.close()
```

### client — HTTP 客户端

> **线程安全**：HttpClient、传输层和 Cookie 管理器现在都是线程安全的，多个线程可以并发请求而无需外部同步。
>
> **连接池**：空闲连接采用惰性驱逐策略——仅在请求新连接时检查，避免后台定时器开销。HTTP/2 连接也受到保护，防止同一主机创建重复连接。

```cangjie
import http_lib.client.HttpClient

let client = HttpClient()

// 便捷方法
let resp = client.get("http://example.com/")
let resp = client.postJson("http://example.com/api", "{\"key\":\"value\"}")
let resp = client.postForm("http://example.com/form", formMap)

// 自定义请求
let req = HttpRequestBuilder()
    .post().withUrl("http://example.com/api")
    .withJson("{\"data\":\"test\"}")
    .withHeader("Authorization", "Bearer token")
    .build()
let resp = client.send(req)

// 处理响应
resp.status           // HttpStatus
resp.headers          // HttpHeaders
resp.bodyAsString()   // String
resp.isSuccess()      // Bool

client.close()
```


### HTTP/1.1 管道（Pipelining）［v0.4+］

支持在单个 HTTP/1.1 持久连接上发送多个请求而不等待响应，然后按顺序读取响应：

```cangjie
// 手动管道
let p = client.pipeline("https://api.example.com")
p.send(HttpRequest(method: HttpMethod.GET, url: "/resource1"))
p.send(HttpRequest(method: HttpMethod.GET, url: "/resource2"))
let r1 = p.recv()  // FIFO
let r2 = p.recv()
p.close()

// 批量管道
let responses = client.pipelineBatch(requests)
```

注意：仅适用于 HTTP/1.1，不支持 HTTP/2 升级和代理隧道。

## HTTP/2 支持 ［v0.2+］

### 概述

`http_lib` 完整支持 HTTP/2 (RFC 7540)，包括：
- **多路复用 (Multiplexing)**：单一 TCP 连接上同时处理多个请求/响应
- **Header 压缩 (HPACK)**：RFC 7541 Huffman 编码 + 动态表
- **Server Push**：服务器推送资源 (PUSH_PROMISE 帧处理)
- **流控制 (Flow Control)**：连接级和流级窗口管理
- **流优先级 (Priority)**：基于权重的调度
- **ALPN 协商**：HTTPS 环境下通过 `h2` 协议自动升级

> **v0.4 改进**：
> - **流控制**：修复了 DATA 帧填充和 PRIORITY 帧开销的记账问题，连接和流窗口现在精确跟踪
> - **HPACK**：敏感头部（如 Authorization、Cookie）现在受到保护，不会添加到动态表中，防止 HPACK 压缩侧信道泄露
> - **WINDOW_UPDATE**：零增量帧现在被验证并拒绝（RFC 7540 §6.9），防止窗口操纵攻击
> - **GOAWAY**：Last-Stream-ID 单调性检查已实施，拒绝非单调递增的值（RFC 7540 §6.8）
> - **PING**：改进了 ACK 处理，非请求的 PING ACK 现在按规范忽略
> - **CONTINUATION**：帧顺序验证确保 CONTINUATION 帧紧随 HEADERS 或 PUSH_PROMISE 帧
> - **优先级**：改进的 PriorityWriteScheduler 调度公平性，跨依赖级别的权重分布更合理

### 服务端

```cangjie
let config = HttpServerConfig()
config.enableHttp2 = true  // 默认启用

// h2c (明文升级)
// 客户端发送 Upgrade: h2c, HTTP2-Settings 头即可

// HTTPS + ALPN
let tlsConfig = TlsConfig()
tlsConfig.serverCertPath = "/path/to/cert.pem"
tlsConfig.serverKeyPath = "/path/to/key.pem"
tlsConfig.nextProtos = ["h2", "http/1.1"]  // ALPN 协议列表
config.tlsConfig = Some(tlsConfig)

let server = HttpServer(handler: router.handler(), config: config)
server.listenAndServeTls("0.0.0.0", 8443)
// ALPN 自动协商：选择 h2 则使用 HTTP/2，否则 HTTP/1.1
```

### 客户端

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.nextProtos = ["h2", "http/1.1"]

let clientConfig = HttpClientConfig()
clientConfig.enableHttp2 = true
clientConfig.tlsConfig = tlsConfig

let client = HttpClient(config: clientConfig)
// 自动在 HTTPS 连接上尝试 HTTP/2 升级
// HTTP/2 连接复用，多请求共享一条连接
```

### HTTP/2 Frame API

```cangjie
import http_lib.http2.{Http2Connection, Http2FrameHeader, encodeFrame, decodeSettings}

// Frame 编解码 (底层 API)
let header = Http2FrameHeader(128, Http2FrameType.HEADERS, flags: 0x4, streamId: 1)
let frame = encodeFrame(header, payload)  // 9-byte header + payload

// SETTINGS 编解码
let settings = [(Http2SettingsId.ENABLE_PUSH, 0),
                (Http2SettingsId.MAX_CONCURRENT_STREAMS, 100)]
let payload = encodeSettings(settings)
let decoded = decodeSettings(payload)
```

### HPACK 压缩

```cangjie
import http_lib.http2.HPACK

let hpack = HPACK()
let headers = HttpHeaders()
headers.set(":method", "GET")
headers.set(":path", "/")
let encoded = hpack.encode(headers)  // Huffman 编码
let decoded = hpack.decode(encoded)  // 解码
```

### HTTP/2 Server Push (服务端)

```cangjie
// 在 HTTP/2 连接处理中使用
let h2conn = Http2Connection(connection, isServer: true)
let pushStreamId = h2conn.pushPromise(streamId, pushRequest)
h2conn.sendPushResponse(pushStreamId, pushResponse)
```

### 扩展 CONNECT（Extended CONNECT）［v0.4+］

支持 RFC 8441 Extended CONNECT，可在 HTTP/2 流上建立 WebSocket 隧道：
- 服务端自动检测 `:method=CONNECT` + `:protocol` 请求
- 调用 `acceptExtendedConnect()` 建立隧道
- 隧道通过 `H2WebSocketTunnel` 进行双向 DATA 帧传输
- 配合 `SETTINGS_ENABLE_CONNECT_PROTOCOL` 参数协商

### 流控制 (Flow Control)

```cangjie
import http_lib.http2.{Http2Inflow, Http2Outflow, Http2FlowController}

// 入站流控制 (接收窗口)
let inflow = Http2Inflow(65535)
inflow.take(1000)  // 消耗 1000 字节窗口
inflow.add(5000)   // 积累 WINDOW_UPDATE (自动批量发送)

// 出站流控制 (发送窗口) - 连接级/流级联动
let connOutflow = Http2Outflow(65535)
let streamOutflow = Http2Outflow(65535)
streamOutflow.setConnFlow(connOutflow)
streamOutflow.take(2000)  // 同时消耗流和连接窗口
```

### 优先级调度 (Write Scheduler)

```cangjie
import http_lib.http2.{PriorityWriteScheduler, RoundRobinWriteScheduler, PriorityTree}

let tree = PriorityTree()
tree.addStream(3, weight: 16, parent: None)
tree.addStream(5, weight: 8, parent: Some(3))  // stream 5 依赖 stream 3
tree.processPriority(5, exclusive: false, streamDep: 3, weight: 8)

// 优先级写调度器 (权重比例分配带宽)
let sched = PriorityWriteScheduler()
sched.openStream(1, weight: 16, parent: None)
sched.push(Http2FrameWriteRequest(1, frameData))
let nextWrite = sched.pop()  // 按权重选择下一个写的流
```

## Body 格式支持

### JSON

请求：
```cangjie
let req = HttpRequest()
req.setJsonBody("{\"hello\":\"world\"}")
// 自动设置 Content-Type: application/json
```

响应：
```cangjie
HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")
```

### x-www-form-urlencoded

请求（Client）：
```cangjie
let form = HashMap<String, String>()
form["name"] = "test"
form["age"] = "25"
let resp = client.postForm("http://example.com/submit", form)
```

解析（Server）：
```cangjie
let form = parseFormBody(request)
// form["name"] == "test"
```

### multipart/form-data

解析文件上传：
```cangjie
let fields = parseMultipartBody(request)
match (fields.get("file")) {
    case Some(field) =>
        field.fileName  // 原始文件名
        field.data      // 文件内容 (Array<UInt8>)
        field.asString() // 文本内容
        field.headers.get("content-type") // 文件类型
    case None => ()
}
```

## 项目结构

```
http_lib/
├── src/
│   ├── core/           # HTTP 核心类型（Method、Status、Version、Headers、Error、Date）
│   ├── buffer/         # ByteBuffer 可增长字节缓冲区
│   ├── message/        # Request/Response 解析、Body、压缩、Range、条件请求
│   ├── router/         # Radix Tree 路由、中间件链、CORS
│   ├── server/         # TCP/TLS HTTP 服务器、文件服务、安全、超时
│   ├── client/         # HTTP 客户端、传输层、连接池、Cookie、认证
│   ├── connection/     # TCP/TLS 连接层、ALPN 解析
│   ├── http2/          # HTTP/2 帧、HPACK、流量控制、多路复用器、优先级
│   ├── http3/          # HTTP/3 帧、QPACK、QUIC 传输适配
│   ├── utils/          # 工具函数（字节拷贝、URL 解析、Hex/Base64）
│   └── testutil/       # TestServer、MockConnection 测试辅助
├── examples/             # 32 个示例程序
│   ├── server/         # 基本 HTTP 服务器
│   ├── client/         # 基本 HTTP 客户端
│   ├── https_server/   # HTTPS 服务器
│   ├── https_client/   # HTTPS 客户端
│   ├── mtls_server/    # mTLS 服务器
│   ├── http2_client/   # HTTP/2 客户端
│   ├── http2_push/     # HTTP/2 Server Push
│   ├── http2_extended_connect/ # HTTP/2 Extended CONNECT
│   ├── http3_server/   # HTTP/3 服务器
│   ├── websocket_chat/ # WebSocket 聊天
│   ├── websocket_client/ # WebSocket 客户端
│   ├── server_sent_events/ # SSE 服务端
│   ├── llm_stream_client/  # SSE 流式客户端
│   ├── rest_api/       # REST API
│   ├── file_server/    # 静态文件服务
│   ├── file_upload/    # 文件上传
│   ├── chunked_upload/ # 分块上传
│   ├── streaming_file_server/ # 流式文件服务
│   ├── streaming_upload/     # 流式上传
│   ├── graceful_shutdown/    # 优雅关闭
│   ├── reverse_proxy/  # 反向代理
│   ├── proxy_client/   # 代理客户端
│   ├── middleware_demo/ # 中间件
│   ├── cors_security/  # CORS + 安全
│   ├── cookie_demo/    # Cookie 管理
│   ├── digest_auth_client/ # Digest 认证
│   ├── route_group/    # 路由分组
│   ├── pipeline_demo/  # HTTP 管道
│   ├── virtual_hosting/ # 虚拟主机
│   ├── timeout_demo/   # 超时演示
│   ├── realworld/      # 综合示例
│   └── combined/       # Server+Client 联合示例
├── docs/               # 文档
├── test/               # 测试
├── cjpm.toml
└── README.md
```

## 新增模块介绍

### server — 中间件与工具函数 ［v0.2+］

#### 安全中间件 (Security Middleware)

```cangjie
import http_lib.server.{securityHeadersMiddleware, hstsMiddleware, cspMiddleware}

let router = Router()

// 添加安全头 (X-Content-Type-Options, X-Frame-Options, Referrer-Policy)
router.use(securityHeadersMiddleware())

// HSTS (仅限 HTTPS 站点)
router.use(hstsMiddleware(maxAge: 31536000, includeSubDomains: true))

// Content-Security-Policy
router.use(cspMiddleware("default-src 'self'; img-src 'self' https:"))
```

#### 频率限制 (Rate Limiting)

基于滑动窗口的 IP 频率限制器：

```cangjie
import http_lib.server.RateLimiter

// 60 秒窗口内最多 100 次请求
let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 100)
router.use(limiter.middleware())

// 获取某 IP 的当前请求计数
let count = limiter.requestCount("192.168.1.1")

// 重置
limiter.reset()
```

#### 超时处理器 (TimedHandler)

```cangjie
import http_lib.server.TimedHandler

// 5 秒超时，超时后返回 503
let handler = TimedHandler(mySlowHandler, Duration.second * 5, "处理超时")
router.get("/slow", handler)
```

#### 请求体大小限制 (SizeLimitHandler)

```cangjie
import http_lib.server.SizeLimitHandler

// 限制请求体最大 1MB，超出返回 413
let handler = SizeLimitHandler(uploadHandler, 1024 * 1024)
router.post("/upload", handler)
```

#### 请求日志 (Request Logging)

```cangjie
import http_lib.server.loggingMiddleware
router.use(loggingMiddleware())
```

#### 客户端 IP 提取

```cangjie
import http_lib.server.extractClientIp

// 优先检查 X-Forwarded-For，其次 X-Real-IP，默认 127.0.0.1
let ip = extractClientIp(request)
```

### server — 静态文件服务 (File Server) ［v0.2+］

```cangjie
import http_lib.server.{serveStatic, FileServerConfig, mimeTypeByExtension}

let config = FileServerConfig()
config.enableCache = true
config.maxAge = 7200  // 2 小时缓存
config.enableRange = true  // 支持 Range 请求 (断点续传)
config.indexFiles = ["index.html", "index.htm"]  // 默认首页

let router = Router()
router.get("/static/{path}", serveStatic("./public", config: config))

// MIME 类型查询
let mimeType = mimeTypeByExtension("style.css")  // → "text/css; charset=utf-8"
```

支持特性：
- **Content-Type 自动检测**：38 种常见文件类型
- **Range 请求**：RFC 7233 标准，支持断点续传
- **目录遍历防护**：自动过滤 `..` 和 `.` 路径段
- **缓存控制**：Cache-Control + max-age header
- **首页回退**：目录自动查找 index.html

### router — CORS 中间件

```cangjie
import http_lib.router.{corsMiddleware, CorsConfig}

let cors = CorsConfig()
cors.allowOrigins = ["https://example.com", "https://app.example.com"]
cors.allowMethods = ["GET", "POST", "PUT", "DELETE"]
cors.allowHeaders = ["Content-Type", "Authorization"]
cors.allowCredentials = true
cors.maxAge = 86400  // 预检请求缓存 24 小时

router.use(corsMiddleware(cors))
```

### http2 — Server Push (客户端接收) ［v0.2+］

客户端接收服务器推送的 PUSH_PROMISE 帧：

```cangjie
import http_lib.http2.Http2Connection

let h2conn = Http2Connection(connection, isServer: false)
h2conn.onPushPromise = Some({ pushReq: HttpRequest =>
    // 决定是否接受推送
    if (isCached(pushReq.url)) {
        return None  // 拒绝推送 (发送 RST_STREAM)
    }
    // 接受推送，返回处理器负责接收推送响应
    Some(HttpResponse.empty(HttpStatus.OK))
})

// 接收推送响应
let pushResp = h2conn.recvPushResponse(promisedStreamId)

// 取消推送
h2conn.cancelPush(promisedStreamId)
```

### client — Digest 认证 (RFC 7616) ［v0.2+］

```cangjie
import http_lib.client.{parseDigestChallenge, computeDigestResponse, buildDigestAuthHeader, md5Hex}

// 解析 WWW-Authenticate: Digest 质询
let params = parseDigestChallenge(response.headers.get("www-authenticate").getOrThrow())

// 构建 Authorization 头
let authHeader = buildDigestAuthHeader(
    "username", "password",
    params["realm"], params["nonce"],
    "GET", "/protected/resource",
    opaque: params.get("opaque"),
    qop: params.get("qop"),
    algorithm: params.get("algorithm")
)

// 注意：Digest 认证现在正确跟踪每个 nonce 值的计数（nc），
// 每次请求递增，以符合 RFC 7616 的重放保护要求。
```

## 流式响应读取 API

### 按缓冲区读取

```cangjie
let resp = client.send(request)
let buf = Array<UInt8>(4096, repeat: 0)
while (true) {
    let n = resp.readBody(buf)
    if (n <= 0) { break }
    // 处理 buf[0..n]
}
```

### 按行读取（推荐用于 SSE/流式 API）

```cangjie
let resp = client.send(request)
while (true) {
    match (resp.readLine()) {
        case Some(line) =>
            if (line.startsWith("data: ")) {
                println(line)  // SSE 数据行
            }
        case None => break
    }
}
```

### 重置读取位置

```cangjie
resp.resetRead()  // 重新从开头读取 body
```

## SSL/TLS 配置

### HTTPS Server

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.serverCertPath = "/path/to/cert.pem"
tlsConfig.serverKeyPath = "/path/to/key.pem"

// 系统证书自动检测
tlsConfig.autoLoadSystemCerts = true

let config = HttpServerConfig()
config.tlsConfig = Some(tlsConfig)
config.enableHttp2 = true

let server = HttpServer(handler: router.handler(), config: config)
server.listenAndServeTls("0.0.0.0", 443)
```

### mTLS (双向认证)

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.serverCertPath = "server.crt"
tlsConfig.serverKeyPath = "server.key"
tlsConfig.caCertPath = "ca.crt"       // CA 证书用于验证客户端
tlsConfig.verifyPeer = true           // 要求并验证客户端证书
```

### 不安全 TLS（仅测试用）

```cangjie
let tlsConfig = TlsConfig.insecure()  // 跳过证书验证
```

## 中间件与安全

### 内置中间件

```cangjie
// 安全头中间件
let router = Router()
router.use(securityHeadersMiddleware())  // X-Content-Type-Options, X-Frame-Options

// HSTS (仅 HTTPS)
router.use(hstsMiddleware(maxAge: 31536000, includeSubDomains: true))

// CSP
router.use(cspMiddleware("default-src 'self'"))

// 速率限制
let limiter = RateLimiter(window: Duration.minute * 1, maxRequests: 100)
router.use(limiter.middleware())

// 请求日志
router.use(loggingMiddleware())
```

### 超时与限制

```cangjie
// 处理超时 — 现在强制执行真实超时，超时后返回 503
let slowHandler = TimedHandler(myHandler, Duration.second * 5)

// 请求体大小限制
let limitedHandler = SizeLimitHandler(uploadHandler, 10 * 1024 * 1024)  // 10 MB
```

## 优雅关闭

```cangjie
let server = HttpServer(handler: router.handler(), config: config)
// 在独立线程启动服务器
spawn { server.listenAndServe("0.0.0.0", 8080) }

// 优雅关闭（等待进行中的请求完成，最多等待 readTimeout）
// HTTP/2 连接自动发送 GOAWAY 帧
server.shutdown()
```

## 目录列表

```cangjie
let config = FileServerConfig()
config.listingEnabled = true  // 启用目录浏览
config.indexFiles = ["index.html", "index.htm"]

let handler = serveStatic("/var/www", config: config)
router.get("/static/{path}", handler)
```

## ResponseBuilder 响应写入器

`ResponseBuilder` 提供了一种替代 `(HttpRequest) -> HttpResponse` 模式的响应构建方式，流式 HTTP 响应写入器。它允许逐步设置状态码、写入响应头，并以流式方式写入响应体，最后通过 `build()` 方法生成完整的 `HttpResponse` 对象。

### 基本用法

```cangjie
import http_lib.server.{ResponseBuilder, wrapResponseBuilderHandler}

// 手动构建
let rw = ResponseBuilder()
rw.header("Content-Type", "text/plain")
rw.writeHeader(200)
rw.writeString("Hello, World!")
let resp = rw.build()
```

### 与路由结合

`wrapResponseBuilderHandler` 函数将 `(HttpRequest, ResponseBuilder) -> Unit` 风格的处理器转换为标准 `Handler` 类型，便于在 Router 中使用：

```cangjie
let router = Router()

// 使用 ResponseBuilder 风格的处理函数
router.get("/greet/:name", wrapResponseBuilderHandler({req, rw =>
    let name = req.pathParams.get("name").getOrElse("Guest")
    rw.header("Content-Type", "text/plain; charset=utf-8")
    rw.writeHeader(200)
    rw.writeString("Hello, ${name}!")
}))
```

### ResponseBuilder API

| 方法 | 说明 |
|------|------|
| `writeHeader(statusCode)` | 设置响应状态码并标记头部已写入 |
| `header(key, value)` | 设置响应头键值对 |
| `write(data: Array<UInt8>)` | 追加字节数据到响应体 |
| `writeString(s: String)` | 追加字符串到响应体 |
| `build()` | 构建并返回最终的 `HttpResponse` |

注意事项：
- `write()` 或 `writeString()` 会自动调用 `writeHeader(200)`（如果尚未调用）
- 重复调用 `writeHeader()` 仅有第一次生效
- 调用 `build()` 之前可以多次调用 `write()` 累积数据

## HTTP 辅助函数

基于标准 HTTP 库设计模式，提供一组便捷的 HTTP 辅助函数，用于快速生成常见响应。

### HttpError — 错误响应

返回指定状态码和错误信息的纯文本响应：

```cangjie
import http_lib.server.HttpError

// 返回 400 Bad Request
let resp = HttpError(req, "无效的请求参数", 400)

// 返回 500 Internal Server Error
let resp = HttpError(req, "服务器内部错误", 500)
```

自动设置以下响应头：
- `Content-Type: text/plain; charset=utf-8`
- `X-Content-Type-Options: nosniff`
- `Content-Length`（自动计算）

### HttpNotFound — 404 响应

快速返回 404 Not Found 响应：

```cangjie
import http_lib.server.HttpNotFound

let resp = HttpNotFound(req)
// 等同于 HttpError(req, "404 page not found", 404)
```

### HttpRedirect — 重定向

返回 HTTP 重定向响应：

```cangjie
import http_lib.server.HttpRedirect

// 301 永久重定向
let resp = HttpRedirect(req, "/new-location", 301)

// 302 临时重定向
let resp = HttpRedirect(req, "/login", 302)

// 307 临时重定向（保留请求方法）
let resp = HttpRedirect(req, "/maintenance", 307)
```

自动设置：
- `Location` 头为目标 URL
- `Content-Type: text/html; charset=utf-8`
- HTML 格式的点击跳转链接文本

### NotFoundResponder — 404 处理器

返回一个始终返回 404 的 Handler，适合作为默认路由：

```cangjie
import http_lib.server.{Router, NotFoundResponder}

let router = Router()
// 设置兜底路由
router.get("/{path}", NotFoundResponder())
```

### RedirectResponder — 重定向处理器

返回一个将请求重定向到指定 URL 的 Handler：

```cangjie
import http_lib.server.RedirectResponder

let router = Router()

// 将 /old-page 永久重定向到 /new-page
router.get("/old-page", RedirectResponder("/new-page", 301))

// 将 /legacy 临时重定向到 /new-site
router.get("/legacy", RedirectResponder("/new-site", 302))
```

## HttpClient 新增便捷方法

`HttpClient` 新增了四个便捷方法，用于简化常见 HTTP 方法的调用。

### head() — HEAD 请求

发送 HEAD 请求，仅获取响应头而不获取响应体：

```cangjie
import http_lib.client.HttpClient

let client = HttpClient()
let resp = client.head("https://example.com/api/resource")

resp.status            // HttpStatus
resp.headers           // HttpHeaders（包含 Content-Length 等元信息）
resp.bodyAsString()    // 通常为空字符串
```

### options() — OPTIONS 请求

发送 OPTIONS 请求，查询服务器支持的 HTTP 方法或 CORS 策略：

```cangjie
let client = HttpClient()
let resp = client.options("https://api.example.com/resource")

// 检查服务器支持的 HTTP 方法
let allowMethods = resp.headers.get("allow")
// allowMethods.value → "GET, POST, PUT, DELETE, OPTIONS"
```

### patch() — PATCH 请求

发送 PATCH 请求，用于部分更新资源。支持可选请求体：

```cangjie
let client = HttpClient()

// 无请求体的 PATCH
let resp = client.patch("https://api.example.com/resource/1")

// 带请求体的 PATCH
let updates = unsafe ! { "{\"name\":\"new-name\"}".rawData() }
let resp = client.patch("https://api.example.com/resource/1", body: updates)

// 使用 HttpRequestBuilder 自定义 PATCH 请求
let req = HttpRequestBuilder()
    .patch()
    .withUrl("https://api.example.com/resource/1")
    .withJson("{\"status\":\"updated\"}")
    .withHeader("Authorization", "Bearer token")
    .build()
let resp = client.send(req)
```

### cleanIdleConnections() — 关闭空闲连接

关闭连接池中所有空闲的 HTTP 连接，释放系统资源。适用于长时间运行的应用程序在低负载期间清理连接：

```cangjie
let client = HttpClient()

// 执行一系列请求
let resp1 = client.get("https://example.com/api/1")
let resp2 = client.get("https://example.com/api/2")

// 关闭所有空闲连接（不影响正在使用的连接）
client.cleanIdleConnections()

// 后续请求会自动建立新连接
let resp3 = client.get("https://example.com/api/3")
```

与 `client.close()` 的区别：
- `cleanIdleConnections()`：仅关闭空闲连接，不关闭正在使用中的连接，连接池仍然可用
- `close()`：关闭所有连接、清空连接池和 Cookie 存储，客户端不再可用

## HTTP/3 支持 (v0.1.0+)

HTTP/3 (RFC 9114) 基于 QUIC (UDP) 传输层运行，提供与 HTTP/2 等效的语义，但使用不同的帧格式和传输编码。

### QUIC 传输层抽象

HTTP/3 模块定义了标准的 QUIC 传输层接口，可在不同 QUIC 实现间切换：

```cangjie
import http_lib.http3.*

// QUIC 流接口
interface QuicStream {
    func read(buf: Array<UInt8>): Int64
    func write(data: Array<UInt8>): Int64
    func close(): Unit
}

// QUIC 连接接口
interface QuicConnection {
    func openStream(): ?QuicStream
    func acceptStream(): ?QuicStream
    func close(): Unit
}
```

### 帧格式

HTTP/3 帧使用 QUIC varint 编码的变长帧头：

```cangjie
import http_lib.http3.*

// 构建 SETTINGS 帧
let settings = buildH3SettingsFrame([
    (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096u64)
])

// 构建 GOAWAY 帧
let goaway = buildH3GoawayFrame(lastStreamId: 100u64)

// 构建 CANCEL_PUSH / PUSH_PROMISE 帧
let cancel = buildH3CancelPushFrame(pushId: 1u64)
let promise = buildH3PushPromiseFrame(pushId: 2u64, encodedHeaders: qpackData)
```

### QPACK 头部压缩

QPACK (RFC 9204) 是 HPACK 的 QUIC 适配变体，支持编码器/解码器专有流同步动态表状态：

```cangjie
let encoder = QpackEncoder(maxTableCapacity: 4096)
let decoder = QpackDecoder(maxTableCapacity: 4096)

// 编码头部
let encoded = encoder.encode(request.headers)
// 解码头部
let decoded = decoder.decode(encoded)
```

### 连接状态管理

H3Connection 维护完整的连接状态机：

- INITIAL → CONNECTED（SETTINGS 交换完成后）
- CONNECTED → GOAWAY_SENT（发送 GOAWAY）
- CONNECTED → GOAWAY_RECV（收到 GOAWAY）
- GOAWAY_RECV/GOAWAY_SENT → CLOSED（连接关闭）

```cangjie
let h3Conn = H3Connection(quicConn, config: connConfig, isServer: false)
h3Conn.sendSettings()
h3Conn.sendRequest(request)
let response = h3Conn.recvResponse(streamId)
h3Conn.gracefulShutdown()
```

## Capsule 协议与扩展 CONNECT (v0.1.0+)

Capsule Protocol (RFC 9297) 为 HTTP 扩展 CONNECT 提供了统一的隧道和隧道数据封装机制。

### 扩展 CONNECT (RFC 8441)

通过 HTTP/2 建立 WebSocket 或其它协议的隧道：

```cangjie
import http_lib.http2.*
import http_lib.connection.*

// 使用扩展 CONNECT 建立 WebSocket 隧道
let tunnel = H2WebSocketTunnel(h2Conn, ":method", "CONNECT")
tunnel.tunnelProtocol = ":protocol"
tunnel.sendRequest("wss://example.com/ws")
```

### Capsule 帧类型

```cangjie
// 创建 DATAGRAM 胶囊
let capsule = Capsule(CapsuleType.DATAGRAM, payload)

// 创建 CLOSE 胶囊
let closeCapsule = Capsule(CapsuleType.CLOSE, [])
```

## MASQUE 代理 (v0.1.0+)

MASQUE (RFC 9298) 基于 QUIC 隧道传输技术，实现 HTTP Datagrams 和 Capsule 协议的代理能力：

```cangjie
import http_lib.client.MasqueTunnel

// 建立 MASQUE 代理隧道
let tunnel = MasqueTunnel()
tunnel.connect("proxy.example.com", 443)
tunnel.send("target.example.com", 80, requestData)
let response = tunnel.receive()
```

## ResponseController 响应控制接口

统一控制流式响应（对应 Go 的 `http.ResponseController`）：

```cangjie
import http_lib.server.ResponseController
import http_lib.connection.Connection

let ctrl = ResponseController(responseBuilder, conn)
ctrl.flush()                    // 刷新缓冲数据到客户端
let hijacked = ctrl.hijack()    // 劫持连接（协议升级）
ctrl.setReadDeadline(...)       // 设置读取截止时间
ctrl.setWriteDeadline(...)      // 设置写入截止时间
ctrl.enableFullDuplex()         // 启用全双工模式
```

## 103 Early Hints (RFC 8297)

在最终响应之前发送预加载提示，允许客户端提前连接或预加载关键资源：

```cangjie
// 发送 103 Early Hints
responseBuilder.sendEarlyHints([
    ("Link", "</style.css>; rel=preload; as=style"),
    ("Link", "</script.js>; rel=preload; as=script"),
])

// 后续发送最终 200 响应
responseBuilder.writeHeader(HttpStatus.OK)
responseBuilder.write("<html>...")
responseBuilder.finish()
```

## HTTP 请求追踪

跟踪 HTTP 请求生命周期中的各阶段耗时（DNS 解析、TCP 连接、TLS 握手、请求发送、响应接收）：

```cangjie
import http_lib.client.TraceInfo

// TraceInfo 包含各阶段时间戳和耗时
let client = HttpClient()
client.traceEnabled = true
client.get("https://example.com/")

// 获取追踪信息
match (client.lastTrace) {
    case Some(trace) =>
        println("DNS: ${trace.dnsDone - trace.dnsStart}")
        println("Connect: ${trace.connectDone - trace.connectStart}")
        println("TLS: ${trace.tlsDone - trace.tlsStart}")
    case None => ()
}
```


## WebSocket 支持

### WebSocket 帧解析

```cangjie
import http_lib.server.{parseWebSocketFrame, encodeWebSocketFrame, WebSocketOpcode}

// 解析入站帧
let frame = parseWebSocketFrame(rawBytes)
if (frame.opcode == WebSocketOpcode.Text) {
    let text = String.fromUtf8(frame.payloadData)
}

// 编码出站帧
let response = encodeWebSocketFrame(WebSocketOpcode.Text, payload, isMasked: false)
```

### HTTP CONNECT 隧道

```cangjie
import http_lib.server.connectTunnelHandler

router.connect("/", connectTunnelHandler())
// 客户端: curl -x http://proxy:8080 https://example.com
```

## SSE (Server-Sent Events)

### 服务端 SSE 写入

```cangjie
import http_lib.server.SSEWriter
import http_lib.connection.Connection

func sseHandler(req: HttpRequest, conn: Connection): Unit {
    let sse = SSEWriter(resp, conn)
    sse.sendData("hello world")
    sse.sendEvent("update", "some data", id: "42")
    sse.sendComment("heartbeat")
    sse.sendRetry(3000)
    sse.close()
}
```

### 客户端 SSE (EventSource)

```cangjie
import http_lib.client.{SSEClient, SSEEvent}

let client = SSEClient("http://example.com/events")
client.onMessage = {event => println(event.data)}
client.on("update", {event => println("UPDATE: ${event.data}")})
client.onError = {msg => println("Error: ${msg}")}
client.connect()
// ...
client.close()
```

## 反向代理 (ReverseProxy)

```cangjie
import http_lib.client.{ReverseProxy, reverseProxyHandler}

let proxy = ReverseProxy("http://localhost:8080")
proxy.modifyResponse = {req, resp =>
    resp.headers.set("X-Proxy", "http_lib")
    resp
}
router.get("/api/{path}", reverseProxyHandler(proxy))
```

特性：X-Forwarded-For/Proto/Host 头、跳跳头移除、ModifyResponse/ErrorHandler 钩子、连接池。

## StreamedHttpResponse (流式响应读取)

使用 `HttpClient.sendStream()` 获取流式响应，无需将整个 body 缓冲到内存：

```cangjie
let client = HttpClient()
let request = HttpRequest(method: HttpMethod.GET, url: "http://example.com/large-file")
let streamResp = client.sendStream(request)

// 按行读取
match (streamResp.readLine()) {
    case Some(line) => println(line)
    case None => ()
}

// 或按缓冲区读取
let buf = Array<UInt8>(4096, repeat: 0)
let n = streamResp.read(buf)
streamResp.close()
```

## DumpRequest / DumpResponse

HTTP 报文调试转储：

```cangjie
import http_lib.message.{dumpRequest, dumpResponse, dumpResponseToString}

let dump = dumpRequest(request)
println(String.fromUtf8(dump))

let dump = dumpResponse(response, body: true, maxBody: 4096)
println(String.fromUtf8(dump))

let text = dumpResponseToString(response)
println(text)
```

## MaxBytesHandler (请求体大小限制)

```cangjie
import http_lib.server.maxBytesHandler

// 拒绝超过 1MB 的请求体
router.use(maxBytesHandler(1024 * 1024))
// 超限后返回 413 Payload Too Large
```

## 请求体大小限制中间件

```cangjie
import http_lib.server.MaxBytesHandler

let handler = MaxBytesHandler(uploadHandler, 10 * 1024 * 1024)  // 10 MB
router.post("/upload", handler)
```

## ResponseCache (响应缓存中间件)

```cangjie
import http_lib.server.ResponseCache
import std.time.Duration

let cache = ResponseCache(maxSize: 100, ttl: Duration.minute * 5)
router.use(cache.middleware())
// GET 200 响应自动缓存，添加 X-Cache: HIT/MISS 头
```

## Trace 模块 (请求追踪)

```cangjie
import http_lib.utils.{generateTraceId, getTraceId, setTraceId}

let traceId = generateTraceId()
setTraceId(req, traceId)
let id = getTraceId(req)
```

### ClientTrace (请求生命周期钩子)

```cangjie
import http_lib.client.ClientTrace

let trace = ClientTrace()
trace.dnsStartHook = Some({host => println("DNS 解析: ${host}")})
trace.connectStartHook = Some({network, addr => println("连接: ${addr}")})
trace.tlsHandshakeStartHook = Some({ => println("TLS 握手开始")})
trace.gotFirstResponseByteHook = Some({ => println("收到响应首字节")})

let config = HttpClientConfig()
config.trace = trace
let client = HttpClient(config: config)
```

## 测试工具

### TestServer (集成测试)

```cangjie
import http_lib.testutil.TestServer

let server = TestServer(myHandler)
server.start()
let port = server.port()
let resp = server.get("/test")
assertTrue(resp.status.code == 200)
server.stop()
```

### ResponseRecorder

```cangjie
import http_lib.testutil.ResponseRecorder

let recorder = ResponseRecorder(myHandler)
recorder.serve(HttpRequest(url: "/test"))
assertTrue(recorder.code() == 200u16)
assertTrue(recorder.bodyAsString() == "hello")
```

### MockConnection

```cangjie
import http_lib.connection.MockConnection

let mock = MockConnection()
mock.writeTestData(b"HTTP/1.1 200 OK\r\n\r\n")
let n = mock.read(buf)
mock.close()
```

## 错误处理模式

```cangjie
// 处理器内抛出异常会触发 500
router.get("/data", { req =>
    throw Exception("unexpected error")
})

// 通过 HttpError 返回自定义错误
router.get("/items/:id", { req =>
    match (req.pathParams.get("id")) {
        case Some(id) =>
            match (findItem(id)) {
                case Some(item) => HttpResponse.json(HttpStatus.OK, item)
                case None => HttpError(req, "Item not found", 404)
            }
        case None => HttpError(req, "Missing id", 400)
    }
})

// 请求体解析异常
try {
    let form = parseFormBody(req)
} catch (e: Exception) {
    // 返回 400 Bad Request
    HttpError(req, "Invalid form data", 400)
}
```

## 常见问题 (FAQ)

### Q: 如何获取字符串的字符数量？

使用 `String.toRuneArray().size` 而非 `.size`（后者返回字节数）：

```cangjie
let text = "你好"
text.size              // 6 (UTF-8 字节数)
text.toRuneArray().size // 2 (字符数)
```

### Q: 如何设置超时？

```cangjie
let config = HttpServerConfig()
config.readTimeout = Duration.second * 60
config.writeTimeout = Duration.second * 30

let clientConfig = HttpClientConfig()
clientConfig.connectTimeout = Duration.second * 10
clientConfig.readTimeout = Duration.second * 30
```

### Q: 如何处理文件上传？

```cangjie
let fields = parseMultipartBody(request)
match (fields.get("file")) {
    case Some(field) =>
        let filename = field.fileName
        let content = field.data
        // 保存到磁盘或处理
    case None => ()
}
```

### Q: 如何构建反向代理？

```cangjie
let router = Router()
router.get("/api/{path}", {req, ctx =>
    let client = HttpClient()
    let backendUrl = "http://backend:8080${req.url}"
    let proxyReq = HttpRequest(method: req.method, url: backendUrl)
    proxyReq.setBody(req.bodyAsBytes())
    let resp = client.send(proxyReq)
    HttpResponse.text(resp.status, resp.bodyAsString())
})
```

### Q: 如何实现 WebSocket 支持？

使用 `ConnectionController` 在初始 HTTP 升级握手后接管连接：

```cangjie
router.get("/ws", wrapResponseBuilderHandler({req, rw =>
    let controller = ConnectionController(rw)
    let conn = controller.takeover()
    // 此时 conn 是原始连接 — 直接发送/接收 WebSocket 帧
}))
```

## 版本日志 (v0.1.0)

### 已实现
- [x] HTTP/1.0, HTTP/1.1, HTTP/2 完整支持
- [x] 流控窗口传播 (RFC 7540 Section 6.9.2)
- [x] HEADERS PRIORITY 标志解析
- [x] 流级发送/接收窗口管理
- [x] GOAWAY 调试数据提取
- [x] Keep-alive 空闲超时
- [x] HTTP/2 优雅关闭 (GOAWAY)
- [x] 自动 Content-Length vs chunked 选择
- [x] Trailer 时序修正 (RFC 7230 Section 4.1.2)
- [x] ConnectionController 接口实现
- [x] 流式响应 readLine() API
- [x] 32 个示例程序
- [x] 1921 个测试用例（全部通过）
- [x] 各模块性能基准测试

### 新特性 (v0.2+)
- [x] SSE 服务端写入 (SSEWriter)
- [x] WebSocket 帧解析
- [x] HTTP CONNECT 隧道
- [x] ResponseCache 中间件
- [x] ReverseProxy 反向代理
- [x] MaxBytesHandler 请求体大小限制
- [x] DumpRequest/DumpResponse 报文转储
- [x] writeEarlyHints (103 Early Hints)
- [x] SSEClient SSE 客户端 (EventSource)
- [x] StreamedHttpResponse 流式响应读取
- [x] Trace 模块 (请求追踪)
- [x] PrefixStripper 处理器
- [x] ServeContent / ServeFile 文件服务增强
- [x] TestServer / ResponseRecorder 测试工具
- [x] Brotli 压缩支持
