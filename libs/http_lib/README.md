# http_lib (HTTP 协议封装库)

[![cjc](https://img.shields.io/badge/cjc-1.0.5-blue)](https://developer.huawei.com/consumer/cn/cangjie/)
[![cjpm](https://img.shields.io/badge/cjpm-1.0.5-blue)](https://developer.huawei.com/consumer/cn/cangjie/)
[![HTTP/1.x](https://img.shields.io/badge/HTTP-1.x-green)](./)
[![HTTP/2](https://img.shields.io/badge/HTTP-2.0-green)](./)
[![HTTP/3](https://img.shields.io/badge/HTTP-3.0-green)](./)
[![Tests](https://img.shields.io/badge/tests-1921%20passed-brightgreen)](./)

基于 TCP 的 HTTP/1.x 与 HTTP/2 全协议封装库，为[仓颉编程语言](https://gitcode.com/opencj)提供高性能的 Server + Client 能力。

> **扩展协议：** 本库同时提供 HTTP/3 (QUIC) 协议的类型定义、帧编解码、QPACK 头部压缩、连接状态管理和 quic_cj 传输适配。

[文档首页](docs/README.md) | [API 参考](docs/core/api.md) | [服务器指南](docs/server/usage.md) | [客户端指南](docs/client/usage.md)

---

## 功能特性

### HTTP/1.x 特性
| 功能 | 状态 |
|------|------|
| HTTP/1.0 & HTTP/1.1 — keep-alive、Connection 头处理 | ✅ |
| 分块传输编码 (Chunked Transfer-Encoding) — 流式编码/解码、支持 Trailer | ✅ |
| HTTP/1.1 管道 (Pipelining) — 单连接多请求管道 | ✅ |
| WebSocket RFC 6455 升级握手 + ConnectionController 模式 | ✅ |
| h2c 升级 (RFC 7540 §3.2) — HTTP/1.1 Upgrade 到 HTTP/2 | ✅ |
| 内容协商 — Accept、Accept-Encoding、Accept-Language、Accept-Charset | ✅ |
| 范围请求 (Range Requests) — RFC 7233 字节范围、multipart/byteranges | ✅ |
| 条件请求 — ETag、If-Match、If-None-Match、If-Modified-Since、If-Unmodified-Since、If-Range | ✅ |
| 缓存控制 — RFC 7234 指令解析、新鲜度计算、条件验证 | ✅ |
| Cookie 管理 — RFC 6265 规范、Secure/SameSite/Path 过滤 | ✅ |
| 认证 — Basic、Bearer Token、Digest (RFC 7616 MD5 + SHA-256) | ✅ |
| 代理支持 — HTTP CONNECT 隧道、NO_PROXY 环境变量检测 | ✅ |
| 连接池 — 每主机连接复用、最大空闲连接数限制、空闲超时清理 | ✅ |
| Expect: 100-continue — 客户端 + 服务端双向支持 | ✅ |
| 虚拟主机 — 基于 Host 头的路由分发 | ✅ |
| HTTP/1.0 兼容 — Connection: Keep-Alive 显式声明、版本协商 | ✅ |
| 尾部响应头 (Trailing Headers) — 分块编码后的元数据 | ✅ |

### HTTP/2 特性
| 功能 | 状态 |
|------|------|
| HPACK 头部压缩 — 哈夫曼编码/解码、静态表(61项)、动态表、敏感头部保护 | ✅ |
| 流多路复用 — 并发流管理、流 ID 分配、状态机验证 (RFC 9113 §5.1) | ✅ |
| 流控制 — 连接级 + 流级窗口、自动调优 WINDOW_UPDATE | ✅ |
| 服务端推送 (Server Push) — PUSH_PROMISE 帧、推送流管理、取消推送 | ✅ |
| 扩展 CONNECT (RFC 8441) — WebSocket over HTTP/2 隧道 | ✅ |
| 优先级 — RFC 7540 优先级树 + RFC 9218 可扩展优先级 (PRIORITY_UPDATE 帧) | ✅ |
| 写入调度器 — 轮询 (RoundRobin) + 加权优先级 (PriorityWriteScheduler) | ✅ |
| SETTINGS 协商 — 所有标准参数 (HEADER_TABLE_SIZE、ENABLE_PUSH、MAX_CONCURRENT_STREAMS、INITIAL_WINDOW_SIZE、MAX_FRAME_SIZE、MAX_HEADER_LIST_SIZE、ENABLE_CONNECT_PROTOCOL、NO_RFC7540_PRIORITIES) | ✅ |
| SETTINGS 超时 — RFC 9113 §6.5.3 超时处理器 | ✅ |
| GOAWAY 优雅关闭 — last-stream-id 追踪、调试数据、连接排空状态 | ✅ |
| PING 活性检测 — 同步等待 ACK、中间帧处理 (RFC 9113 §6.7) | ✅ |
| CONTINUATION 帧顺序验证 — RFC 9113 §6.10 严格排序 | ✅ |
| 帧填充 (Padding) — DATA/HEADERS/PUSH_PROMISE 填充字节剥离 | ✅ |
| 未知帧类型 — 按 RFC 9113 §4.1 静默跳过 | ✅ |
| ORIGIN 帧 (RFC 8336) — 来源声明 | ✅ |
| ALTSVC 帧 (RFC 7838) — 替代服务通告 | ✅ |
| Capsule Protocol (RFC 9298) — HTTP Datagrams、DATAGRAM_WITH_CONTEXT、CLOSE 胶囊 | ✅ |
| h2c 明文升级 — 服务端自动识别 HTTP/2 前导字节 | ✅ |
| RST_STREAM 流清理 — 多路复用器及时移除已取消流 | ✅ |
| SETTINGS HEADER_TABLE_SIZE 正确实现 — setMaxTableSize 保留动态表状态 (RFC 7541 §4.2) | ✅ |

### HTTP/3 特性
| 功能 | 状态 |
|------|------|
| QUIC 传输层抽象接口 — QuicStream、QuicConnection、QuicListener、QuicTransportFactory | ✅ |
| HTTP/3 帧类型 — DATA、HEADERS、CANCEL_PUSH、SETTINGS、PUSH_PROMISE、GOAWAY、MAX_PUSH_ID | ✅ |
| QPACK 头部压缩 — 静态表(99项)、动态表、编码器/解码器流、Relative Base 索引 (RFC 9204) | ✅ |
| 连接状态管理 — INITIAL、CONNECTED、GOAWAY_SENT、GOAWAY_RECV、CLOSED 状态机 | ✅ |
| 服务端推送 — PUSH_PROMISE 帧生成、MAX_PUSH_ID 协商、CANCEL_PUSH 取消推送 | ✅ |
| SETTINGS 协商 — QPACK_MAX_TABLE_CAPACITY、MAX_FIELD_SECTION_SIZE、QPACK_BLOCKED_STREAMS | ✅ |
| 控制流 — 管理 SETTINGS/GOAWAY/MAX_PUSH_ID 帧交换 | ✅ |
| HTTP/3 客户端 — 多种 HTTP 方法的便捷调用、重定向跟随 | ✅ |
| HTTP/3 服务器 — 请求处理生命周期、QUIC 监听器集成 | ✅ |
| Mock QUIC 传输 — 内存中模拟 QUIC 流，用于单元测试 | ✅ |
| quic_cj 传输适配 — AdapterQuicStream/Connection/Listener + QuicCjTransportFactory | ✅ |

### 通用特性 (HTTP/1.x + HTTP/2)
| 功能 | 状态 |
|------|------|
| HTTPS/TLS 1.2 — ECDHE 密钥交换、RSA/AES-GCM 加密套件、ALPN (h2, http/1.1) | ✅ |
| TLS 连接复用 — ALPN 协议协商、mTLS 客户端证书验证 | ✅ |
| MASQUE 代理 (RFC 9298) — QUIC 隧道传输，HTTP Datagrams 和 Capsule 协议 | ✅ |
| 静态文件服务 — MIME 类型检测 (前 512 字节魔数)、Range 请求、目录列表 | ✅ |
| ServeContent — 流式内容，支持 Range/ETag/条件请求 | ✅ |
| ServeFile — 单文件服务，支持 Range 请求 | ✅ |
| ResponseBuilder — 流式响应构建器，同时支持 HTTP/1.x 和 HTTP/2 | ✅ |
| 压缩 — gzip、deflate、brotli（解压 + 压缩，含透明压缩中间件） | ✅ |
| SSEWriter 流式传输 — 每个事件立即写入并刷新 | ✅ |
| 103 Early Hints (RFC 8297) — 预加载提示，协助客户端提前连接 | ✅ |
| ResponseController — 流式控制 (Flush、Hijack、读/写截止时间、全双工模式) | ✅ |
| 安全中间件 — HSTS、CSP、X-Frame-Options、速率限制、CSRF 保护 | ✅ |
| 请求日志中间件 — 可配置输出的访问日志 | ✅ |
| CORS 中间件 — 可配置跨域资源共享，预检请求验证 | ✅ |
| 中间件链 — 洋葱模型、支持路由级中间件 | ✅ |
| 基数树路由 — 高性能 URL 匹配、路径参数 (`:id`、`*path`) | ✅ |
| 路由分组 — 前缀路由分组、中间件继承 | ✅ |
| 响应缓存 — 内存缓存、条件过期验证、ETag/Last-Modified 验证 | ✅ |
| 完整 HTTP 方法路由 — GET、POST、PUT、DELETE、PATCH、HEAD、OPTIONS、CONNECT、TRACE | ✅ |
| 尾斜杠重定向 — 自动 301 重定向处理路径尾斜杠不匹配 | ✅ |
| RequestContext — 每个请求的截止时间、取消和值传递 | ✅ |
| 线程安全 — 互斥锁保护路由树、连接池、Cookie jar | ✅ |
| 可配置超时 — 读取超时、写入超时、空闲超时、读取头超时 | ✅ |
| 优雅关闭 — 可配置 drain timeout 的请求耗尽 | ✅ |
| 自动重定向 — 可配置最大重定向次数 (301/302/303/307/308) | ✅ |
| 流式响应读取 — 基于缓冲区和行级的响应体读取（支持 SSE） | ✅ |
| 请求体解析 — URL 编码表单、JSON、multipart/form-data | ✅ |
| HTTP 日期解析与格式化 — RFC 7231 §7.1.1 规范的 Date/Last-Modified 处理 | ✅ |
| 请求跟踪 (Tracing) — 请求生命周期事件钩子 (DNS 解析、TCP 连接、TLS 握手) | ✅ |
| 自动 Date / Server 响应头 — 可配置 | ✅ |

## 快速开始

### 添加依赖

在 `cjpm.toml` 中添加：

```toml
[dependencies]
http_lib = { git = "https://gitcode.com/changeden/http_lib.git", output-type = "static" }
```

### 简单 HTTP 服务器

```cangjie
import http_lib.server.*
import http_lib.message.*

main() {
    let handler = {req: HttpRequest => HttpResponse.text(HttpStatus.OK, "Hello, World!")}
    let server = HttpServer(handler: handler)
    server.listenAndServe("0.0.0.0", 8080)
}
```

### 简单 HTTP 客户端

```cangjie
import http_lib.client.*

main() {
    let client = HttpClient()
    let resp = client.get("http://example.com/")
    println("状态码: ${resp.status.code}")
    println("响应体: ${resp.bodyAsString()}")
    client.close()
}
```

### 路由服务器

```cangjie
import http_lib.router.*
import http_lib.server.*
import http_lib.message.*

main() {
    let router = Router()
    router.get("/api/hello", {req => HttpResponse.json(HttpStatus.OK, "{\"msg\":\"你好\"}")})
    router.post("/api/data", {req => {
        let body = req.bodyAsString()
        HttpResponse.text(HttpStatus.CREATED, "收到: ${body}")
    }})

    let server = HttpServer(handler: router.handler())
    server.listenAndServe("0.0.0.0", 8080)
}
```

> **说明：** `router.handler()` 返回经过中间件包装的 `Handler`，自动分发路由、处理 404/405 响应、尾斜杠重定向，并将路径参数提取到 `req.pathParams` 中。详见 [服务器指南](docs/server/usage.md)。

---

## 架构

```
src/
├── core/          # HTTP 核心类型（Method、Status、Version、Headers、Error、Date）
├── buffer/        # ByteBuffer — 可增长的字节数组、读写位置管理
├── message/       # Request、Response、请求体解析、分块编码、
│                  #   压缩、内容协商、范围请求
├── router/        # 基数树路由、中间件链、CORS
├── server/        # TCP/TLS HTTP 服务器、文件服务器、安全、超时
├── client/        # HTTP 客户端、传输层、连接池、Cookie、认证
├── connection/    # TCP/TLS 连接层、ALPN 解析器
├── http2/         # HTTP/2 帧、HPACK、流量控制、多路复用器、优先级
├── http3/         # HTTP/3 帧、QPACK、QUIC 传输适配
├── utils/         # 工具函数（字节拷贝、URL 解析、min/max）
└── testutil/      # TestServer、Mock 连接（测试辅助）
```

`examples/` 目录包含 32 个示例程序，涵盖服务器、客户端、HTTP/2、WebSocket、HTTP/3 等典型用法。
首次接触本库的开发者建议先阅读 [CANGJIE_GUIDE.md](./CANGJIE_GUIDE.md) 了解仓颉语言要点。

---

## 文档

| 文档 | 说明 |
|------|------|
| [服务器指南](docs/server/usage.md) | 服务器设置、HTTPS、WebSocket、中间件 |
| [服务器安全](docs/server/security.md) | HSTS、CSP、速率限制、IP 提取 |
| [服务器 TLS](docs/server/tls.md) | TLS/HTTPS 配置、mTLS、证书管理 |
| [客户端指南](docs/client/usage.md) | 客户端设置、请求构建、流式响应 |
| [客户端进阶](docs/client/advanced.md) | 认证、Cookie、代理、连接池 |
| [核心 API 参考](docs/core/api.md) | HttpMethod、HttpStatus、HttpHeaders 等 |
| [HTTP/2 概览](docs/http2/overview.md) | HTTP/2 架构、帧类型、流量控制 |
| [HTTP/3 概览](docs/http3/README.md) | HTTP/3 (QUIC) 架构、QPACK、帧类型、QUIC 传输适配 |
| [路由文档](docs/router/README.md) | 基数树路由、中间件链、CORS |
| [消息解析文档](docs/message/README.md) | HTTP 消息解析、请求体、Body、压缩、范围请求 |
| [ByteBuffer 文档](docs/buffer/README.md) | 可增长的字节缓冲区 |
| [Connection 文档](docs/connection/README.md) | TCP/TLS 连接层接口与实现 |
| [Utils 文档](docs/utils/README.md) | 工具函数（字节、Hex、URL 解析等） |
| [Testutil 文档](docs/testutil/README.md) | 测试辅助工具 |
| [完整手册 (中文)](docs/manual.md) | 完整用户手册（简体中文） |

---

## 基准测试

包含 **111 项** 基准测试（共 111 个 @Bench 注解的方法），覆盖所有核心模块（Intel i7 × cjc v1.0.5）：
| 类别 | 基准测试 | 延时 (中位数) | 吞吐量 |
|------|---------|--------------|--------|
| **Core 类型** | HttpMethod.parse | 9.1 ns | 109.9 M ops/s |
|  | HttpMethod 相等性+hashCode | 8.8 ns | 113.1 M ops/s |
|  | HttpStatus 类别检查 | 23.8 ns | 42.0 M ops/s |
|  | HttpHeaders.set (5 个头部) | 1.32 µs | 756 K ops/s |
|  | HttpHeaders.toBytes | 2.50 µs | 400 K ops/s |
|  | HttpHeaders 不区分大小写 | 1.02 µs | 984 K ops/s |
|  | HttpHeaders 多值 add/getAll | 792.6 ns | 1.3 M ops/s |
|  | currentHttpDate | 485.9 ns | 2.1 M ops/s |
|  | parseContentLength | 17.5 ns | 57.1 M ops/s |
| **ByteBuffer** | writeAndRead (64 B) | 1.37 µs | 47 MB/s |
|  | growBuffer (1.28 KB, 10 次写入) | 33.69 µs | 38 MB/s |
|  | fromOwned (1 KB) | 6.51 µs | 157 MB/s |
| **消息解析** | HttpRequestParser.parse (GET ~87 B) | 16.10 µs | 5 MB/s |
|  | HttpRequestParser.parse (POST) | 14.54 µs | 69 K ops/s |
|  | HttpResponseParser.parse (JSON ~73 B) | 14.68 µs | 5 MB/s |
|  | HttpRequest.toBytes (~100 B body) | 11.19 µs | 9 MB/s |
|  | HttpResponse.toBytes | 3.44 µs | 291 K ops/s |
|  | HttpResponse 静态工厂 (6 种) | 8.04 µs | 124 K ops/s |
|  | BodyParser.parseUrlEncoded (~80 B) | 10.43 µs | 8 MB/s |
|  | selectContentType | 10.84 µs | 92 K ops/s |
|  | selectContentEncoding | 7.83 µs | 128 K ops/s |
|  | ChunkedWriter.encodeChunked (11 B) | 752.5 ns | 15 MB/s |
|  | ChunkedDecoder.decode | 1.40 µs | 713 K ops/s |
| **ResponseWriter** | 小 JSON 响应 (~17 B) | 5.42 µs | 184 K ops/s |
|  | 分块写入 800 KB | 243.96 µs | 3.36 GB/s |
|  | 带尾部响应头 (~20 B) | 7.10 µs | 141 K ops/s |
| **路由** | Router.find (静态路由) | 1.28 µs | 780 K ops/s |
|  | Router.find (参数化路由) | 2.10 µs | 476 K ops/s |
|  | Router.find (通配符路由) | 1.97 µs | 508 K ops/s |
|  | Router.allowedMethodsForPath | 3.27 µs | 306 K ops/s |
| **HTTP/2** | HPACK 编码 (5 个头部) | 12.35 µs | 81 K ops/s |
|  | HPACK 解码 | 20.92 µs | 48 K ops/s |
|  | HPACK Huffman 编码 (~42 B url) | 4.97 µs | 8 MB/s |
|  | HTTP/2 帧编码 (~128 B) | 2.09 µs | 478 K ops/s |
|  | HTTP/2 帧头部解析 | 2.24 µs | 446 K ops/s |
|  | HTTP/2 SETTINGS 编码 (4 项) | 896.3 ns | 1.1 M ops/s |
|  | PriorityTree 添加 64 流 | 30.76 µs | 33 K ops/s |
| **客户端** | HttpAuthCredentials.basic | 2.20 µs | 455 K ops/s |
|  | HttpAuthCredentials.bearer | 141.5 ns | 7.1 M ops/s |
|  | HttpHeaders 序列化 (7 头部) | 4.92 µs | 203 K ops/s |
|  | HttpHeaders 设置+获取往返 | 1.50 µs | 669 K ops/s |
|  | HttpHeaders 多值 Set-Cookie (4 项) | 939.4 ns | 1.1 M ops/s |
|  | HttpClient 最小构造 | 1.05 µs | 955 K ops/s |
|  | HttpRequestBuilder (GET) | 1.59 µs | 628 K ops/s |
|  | HttpRequestBuilder (POST + JSON) | 2.23 µs | 448 K ops/s |
|  | HttpResponseParser.parse (小响应) | 6.72 µs | 149 K ops/s |
|  | HttpResponseParser.parse (20 头部) | 55.24 µs | 18 K ops/s |
| **连接** | TlsConfig 默认 + 操作 | 723.1 ns | 1.4 M ops/s |
|  | TlsConfig.negotiateProtocol | 267.8 ns | 3.7 M ops/s |
|  | ALPN ClientHello 解析 | 456.4 ns | 2.2 M ops/s |
|  | secureRandom (32 字节) | 3.24 µs | 308 K ops/s |
| **HTTP/3** | Http3FrameType 类型转换 | 8.0 ns | 124.3 M ops/s |
|  | Http3FrameType 相等性 | 22.9 ns | 43.6 M ops/s |
|  | H3Frame 编码 (SETTINGS 3 项) | 1.17 µs | 857 K ops/s |
|  | H3Frame 编码 (GOAWAY) | 159.6 ns | 6.3 M ops/s |
|  | H3Frame 解码头部 | 1.95 µs | 514 K ops/s |
|  | Http3SettingsId 往返 | 10.9 ns | 92.0 M ops/s |
|  | QPACK 编码 (5 个头部) | 48.05 µs | 21 K ops/s |
|  | QuicStreamType 相等性 | 19.8 ns | 50.6 M ops/s |
|  | Http3Config 构造 | 9.5 ns | 105.6 M ops/s |
|  | QPACK 编码 (1 个头部) | 7.63 µs | 131 K ops/s |
|  | QPACK 编码 (8 个头部) | 34.66 µs | 29 K ops/s |
|  | QPACK 解码 (8 个头部) | 39.24 µs | 25 K ops/s |
|  | H3Frame 解码 (SETTINGS 3 项) | 8.09 µs | 124 K ops/s |
|  | H3Frame 解码 (1 KB DATA) | 21.55 µs | 48 MB/s |
| **WebSocket** | computeWebSocketAcceptKey | 39.55 µs | 25 K ops/s |
|  | equalsIgnoreCase (字节+符文) | 1.60 µs | 626 K ops/s |
|  | WebSocketOpcode 类型转换 | 8.1 ns | 123.7 M ops/s |
|  | WS 帧编码 (小文本 13 B) | 364.0 ns | 36 MB/s |
|  | WS 帧编码 (4 KB 二进制, 掩码) | 265.13 µs | 15 MB/s |
|  | WS 帧解析 (小文本) | 648.2 ns | 20 MB/s |
|  | WS 帧解析 (4 KB 二进制) | 110.98 µs | 37 MB/s |
|  | WS 帧验证 | 7.51 µs | 133 K ops/s |
| **工具函数** | asciiToLower | 3.72 µs | 269 K ops/s |
|  | asciiTrimSpaces | 298.0 ns | 3.4 M ops/s |
|  | formUrlEncode | 4.79 µs | 209 K ops/s |
|  | Base64 编码 (小) | 1.01 µs | 988 K ops/s |
|  | Base64 编码 (中) | 67.17 µs | 15 K ops/s |
|  | Base64 解码 | 2.20 µs | 456 K ops/s |
|  | Base64 字符串编码 | 3.09 µs | 324 K ops/s |
|  | findHeaderEnd | 1.09 µs | 917 K ops/s |
|  | findCrlf | 410.8 ns | 2.4 M ops/s |
|  | findByte | 195.5 ns | 5.1 M ops/s |
|  | skipSpaces | 291.9 ns | 3.4 M ops/s |
|  | findBytesAt | 435.8 ns | 2.3 M ops/s |
|  | hexEncode (小) | 1.80 µs | 557 K ops/s |
|  | hexEncode (中) | 33.45 µs | 30 K ops/s |
|  | hexDecode | 901.5 ns | 1.1 M ops/s |
|  | toHex32 | 730.5 ns | 1.4 M ops/s |
|  | toHex64 | 1.19 µs | 841 K ops/s |
|  | byteToHexChar | 18.4 ns | 54.3 M ops/s |
|  | byteToHexCharUpper | 18.5 ns | 54.0 M ops/s |
|  | parsePort | 294.6 ns | 3.4 M ops/s |
|  | copyBytes | 1.77 µs | 566 K ops/s |
|  | stringToBytes | 29.2 ns | 34.3 M ops/s |
|  | bytesToString | 73.2 ns | 13.7 M ops/s |
|  | equalsIgnoreCase (符文) | 700.4 ns | 1.4 M ops/s |
|  | equalsIgnoreCase (短) | 871.6 ns | 1.1 M ops/s |
|  | equalsIgnoreCase (长) | 2.23 µs | 449 K ops/s |
|  | containsIgnoreCase (找到) | 2.22 µs | 451 K ops/s |
|  | containsIgnoreCase (未找到) | 4.60 µs | 218 K ops/s |
|  | arraysEqual | 410.0 ns | 2.4 M ops/s |
|  | startsWithIgnoreCase | 663.5 ns | 1.5 M ops/s |
|  | URL 解析 (HTTP) | 244.2 ns | 4.1 M ops/s |
|  | URL 解析 (HTTPS) | 214.4 ns | 4.7 M ops/s |
|  | URL 解析 (带端口) | 610.2 ns | 1.6 M ops/s |
|  | URL 解析 (带认证) | 428.6 ns | 2.3 M ops/s |
|  | URL 解析 (IPv6) | 532.8 ns | 1.9 M ops/s |
|  | URL 解析 (根路径) | 239.0 ns | 4.2 M ops/s |
|  | URL 解析 (无路径) | 217.0 ns | 4.6 M ops/s |

运行基准测试：

```bash
cjpm bench
```

---

## 测试

覆盖 **1921 个单元测试**，涵盖所有模块：

```bash
cjpm test
```

关键覆盖率指标：
- **核心类型** — 所有公共函数均已测试
- **消息层** — 90%+ 公共函数已测试
- **路由器** — 所有 HTTP 方法、路由分组、虚拟主机、中间件、CORS
- **HTTP/2** — 帧、HPACK、流量控制、多路复用器、优先级、写入调度器、边界情况、RST_STREAM 流清理、扩展 CONNECT
- **Buffer** — 所有 ByteBuffer 操作均已测试
- **客户端** — Digest 认证、请求构建器、Cookie jar、连接池、传输层生命周期
- **服务器** — 安全中间件、速率限制器、文件服务器 MIME/类型/缓存/Range、超时处理器、TLS 配置
- **连接层** — TCP/TLS 加密套件、ALPN 解析、基于固件的 GCM 密封/开封往返验证

---

## 环境要求

- 仓颉编译器 (cjc) v1.0.5+
- 仓颉包管理器 (cjpm) v1.0.5+
- 依赖：`kaca_json`、`kaca_cookies`、`compress4cj`、`JinguiSSL`、`jinguissl_core`、`quic_cj`

---

## 许可证

本项目基于 MIT 许可证开源。

---

## 贡献指南

欢迎贡献代码！请遵循现有代码风格，并在提交 PR 前确保所有测试通过。
