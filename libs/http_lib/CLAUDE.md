# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

- **Name**: `http_lib` — 仓颉 HTTP 封装库
- **Language**: 仓颉 (Cangjie) v1.0.5 (cjc v1.0.5, cjpm v1.0.5)
- **Type**: 静态库 (`output-type = "static"`)
- **Goal**: 基于 TCP 实现 HTTP/1.x + HTTP/2 全协议封装，提供 Server + Client 能力

- 所有注释应为简体中文
- 所有文档分为两份，`*.md`为简体中文，`*.en.md`为英文

## Build & Test

```bash
cjpm build                    # 构建
cjpm build -i                 # 增量构建
cjpm test                     # 运行所有单元测试 (1921 个)
cjpm test --filter <name>     # 运行单个测试 (匹配 TestCase 方法名或 Test 类名)
cjpm update                   # 更新依赖（需在 jinguissl_core 变更后运行）
```

### Running Benchmarks

```bash
cjpm bench               # 性能基准测试 (基于 @Bench 宏)
```

Benchmark sources live under `src/*/*benchmark_test.cj`. They are compiled and run by `cjpm bench`.

### Test Directory Structure

```
test/
├── benchmark/       # 性能基准测试 (已废弃，改用 cjpm bench)
├── integration/     # 集成测试 (端到端 Server+Client)
├── http2_integration/  # HTTP/2 集成测试
├── http2_push_integration/  # HTTP/2 Server Push 集成测试
├── stress/          # 压力测试
└── doctest/         # 文档示例测试
```

- 编译选项: `-Woff unused`
- 单元测试文件使用 `@Test`(类) + `@TestCase`(方法) 注解，位于各源码目录下的 `*_test.cj`
- 断言使用自定义辅助函数: `assertTrue()`, `assertFalse()` (在 `src/core/test_helpers.cj`)
- **注意**: 比较 `Option<T>` 不能用 `==`，需用 `isSome()`/`isNone()` + match 展开

## Architecture

```
src/
├── core/          # HTTP 核心类型
│   ├── method.cj       HttpMethod enum (Hashable + Equatable, 9 methods)
│   ├── status.cj       HttpStatus class + 53 static constants
│   ├── version.cj      HttpVersion enum (HTTP_1_0, HTTP_1_1, HTTP_2_0)
│   ├── headers.cj      HttpHeaders (case-insensitive, multi-value)
│   ├── error.cj        HttpException hierarchy (7 classes)
│   ├── constants.cj    Protocol constants + parseDecimal/parseContentLength
│   ├── http_date.cj    RFC 1123/850/ANSI date formatting and parsing
│   ├── context.cj      RequestContext — per-request deadlines, cancellation, values (context pattern)
│   └── test_helpers.cj assertTrue/assertFalse for tests
├── buffer/        # ByteBuffer (growable byte array with read/write positions)
├── message/       # Request/Response 类型与解析
│   ├── request.cj        HttpRequest + fluent builder methods
│   ├── response.cj       HttpResponse + readLine/readBody streaming API
│   ├── body.cj           BodyParser: URL-encoded, JSON, multipart
│   ├── request_parser.cj HttpRequestParser
│   ├── response_parser.cj HttpResponseParser
│   ├── response_writer.cj Streaming chunked ResponseWriter + Hijacker
│   ├── chunked_decoder.cj Chunked transfer decoder with trailer support
│   ├── chunked_encoder.cj Chunked transfer encoder (ChunkedWriter)
│   ├── compression.cj    gzip/deflate compress/decompress
│   ├── brotli.cj         Brotli compress/decompress
│   ├── negotiation.cj    Accept/Accept-Encoding/Accept-Language parsing
│   ├── range.cj          ByteRange + RFC 7233 Range handling
│   ├── conditional.cj    If-Match/If-None-Match/If-Modified-Since evaluation
│   ├── cache_control.cj  RFC 7234 Cache-Control parsing
│   └── json_helper.cj    JSON value construction helpers
├── router/        # Radix Tree 路由器
│   ├── router.cj        Router (9 HTTP methods), radix tree, path params
│   ├── middleware.cj     MiddlewareChain (onion model)
│   ├── handler_utils.cj  PrefixStripper helper
│   └── cors.cj           CorsConfig + corsMiddleware
├── server/        # TCP HTTP Server
│   ├── server.cj        HttpServer (listenAndServe, keep-alive, idle timeout)
│   │                    TLS with ALPN, HTTP/2 upgrade, WebSocket, h2c
│   ├── file_server.cj   serveStatic + directory listing
│   ├── security.cj      HSTS/CSP/X-Frame-Options middleware + rate limiter
│   └── timeout_handler.cj TimedHandler + SizeLimitHandler
├── client/        # HTTP Client
│   ├── client.cj        HttpClient + HttpRequestBuilder (fluent API)
│   ├── transport.cj     HttpTransport (proxy, pooling, timeouts)
│   ├── connection_pool.cj Per-host connection pool
│   ├── cookie_jar.cj    CookieJar wrapping kaca_cookies
│   └── auth.cj          Digest auth (RFC 7616 MD5 + SHA-256)
├── connection/    # TCP/TLS Connection Layer
│   ├── connection.cj    Connection interface
│   ├── abstract_connection.cj AbstractConnection base class
│   ├── tcp_connection.cj TcpConnection wrapping TcpSocket
│   ├── tls_config.cj    TlsConfig (TLS configuration container)
│   ├── tls_connection.cj TLS 1.2 client (ECDHE, AES-GCM)
│   ├── tls_server_connection.cj TLS 1.2 server
│   ├── alpn_parser.cj   ClientHello ALPN extension parser
│   ├── mock_connection.cj Test mock connection
│   └── secure_random.cj CSPRNG helper
├── http2/         # HTTP/2 Implementation
│   ├── common.cj        Constants, Http2ErrorCode, Http2FrameType, Http2SettingsId
│   ├── frame.cj         Frame encode/decode, padding, 6 convenience builders
│   ├── hpack.cj         HPACK encoder/decoder (Huffman + static/dynamic tables)
│   ├── flow_control.cj  Inflow/Outflow/FlowController + SettingsTimedHandler
│   ├── multiplexer.cj   Stream state machine + stream/connection windows
│   ├── priority.cj      PriorityTree with weighted fair scheduling
│   ├── write_scheduler.cj RoundRobin + Priority write schedulers
│   └── connection.cj    Http2Connection (client + server, push, ping, shutdown)
├── utils/         # Utility functions (bytes, hex, parse, URL parsing)
└── testutil/      # TestServer + mock connections for tests
examples/            # 26 示例程序
docs/              # 用户手册（中英文镜像）
├── manual.md              # 完整使用手册（中文）
├── core/api.md            # 核心 API 参考
├── buffer/                # ByteBuffer 文档
├── connection/            # TCP/TLS 连接层文档
├── utils/                 # 工具函数文档
├── testutil/              # TestServer 与测试工具文档
├── server/                # Server 使用指南、安全、TLS
├── client/                # Client 使用指南、高级用法
└── http2/overview.md      # HTTP/2 概览
```

## Key Design Patterns

^- **HTTP protocol alignment**: This library follows commonly-used HTTP library conventions, providing core types like HttpServer, ResponseWriter, HttpTransport, HttpClient and RequestContext for server and client HTTP communication.
- **Streaming responses**: `ResponseWriter` supports `write()`, `writeHeader()`, and `flush()` for chunked/SSE streaming. It implements `Hijacker` for protocol upgrades (WebSocket, h2c).
- **Middleware onion model**: `MiddlewareChain` wraps handlers outermost-first. `router.handler()` auto-applies the chain.
- **Connection pooling**: `HttpTransport` maintains per-host connection pools with max idle limits and idle timeout eviction.

## Cangjie Gotchas

- 阅读[CANGJIE_GUIDE.md](./CANGJIE_GUIDE.md)
- **`jinguissl_core` import 路径**: 使用 `import jinguissl_core.crypto.digest.{...}` 而非 `import jinguissl_core.jinguissl.crypto.digest.{...}` (少一层 `jinguissl.`)

## Dependencies

| Package | Source | Purpose |
|:---|:---|:---|
| `kaca_json` | gitcode.com/cangjie_no_1/kaca_json | JSON 解析 |
| `JinguiSSL` | gitcode.com/cinyu/jinguiSSL | TLS/SSL 门面 |
| `jinguissl_core` | gitcode.com/CjKu/JinguiCore | 加密核心 (AES, digest, X.509, TLS 1.2) |
| `kaca_url` | gitcode.com/cangjie_no_1/kaca_url | URL 类型 |
| `kaca_urlsearchparams` | gitcode.com/cangjie_no_1/kaca_URLSearchParams | URL 查询参数 |
| `kaca_encodeURI` | gitcode.com/cangjie_no_1/kaca_encodeURI | URI 编解码 |
| `kaca_idna` | gitcode.com/cangjie_no_1/kaca_IDNA | 国际化域名 |
| `kaca_cookies` | gitcode.com/cangjie_no_1/kaca_cookies | Cookie 管理 |
| `compress4cj` | gitcode.com/changeden/compress4cj | 压缩 (DEFLATE/zlib/gzip/brotli/bzip2/LZW) |
