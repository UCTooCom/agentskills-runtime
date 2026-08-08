# http_lib 消息模块（message）

## 概述

`message` 模块是 `http_lib` 的核心消息处理模块，提供 HTTP 请求与响应的完整表示、
解析、序列化、编码转换和内容处理功能。

## 主要类型

| 类型 | 说明 |
|------|------|
| `HttpRequest` | HTTP 请求封装，包含方法、URL、头部和体数据 |
| `HttpResponse` | HTTP 响应封装，包含状态码、头部和体数据 |
| `Body` | 请求/响应体的抽象，支持内存缓冲和流式读写 |
| `BodyParser` | Multipart 解析器，支持可配置的大小限制 |
| `ResponseBuilder` | 流式响应写入器，支持分块编码、Trailer、SSE |
| `HttpResponseParser` | 原始字节 → HttpResponse 解析器 |
| `HttpRequestParser` | 原始字节 → HttpRequest 解析器 |

## 子模块功能

### 请求/响应表示
- `request.cj`：HttpRequest 类型定义（方法、URL、头、体、路径参数）
- `response.cj`：HttpResponse 类型定义（状态码、头、体、便捷构造器）

### 消息解析
- `request_parser.cj`：HTTP 请求行 + 头部 + 体的完整解析
- `response_parser.cj`：HTTP 状态行 + 头部 + 体的完整解析
- `body.cj`：URL 编码表单 / JSON / Multipart 解析器（含可配置限制）

### 传输编码
- `chunked_encoder.cj`：分块传输编码器（ChunkedWriter）
- `chunked_decoder.cj`：分块传输解码器（ChunkedDecoder）

### 压缩
- `compression.cj`：gzip/deflate 压缩/解压缩
- `brotli.cj`：Brotli 压缩支持

### 内容协商
- `negotiation.cj`：Accept/Accept-Encoding/Accept-Language 头部解析和自动选择

### 范围请求与条件请求
- `range.cj`：Range/Content-Range 解析、多区间 multipart/byteranges 构建
- `conditional.cj`：ETag 生成、If-Modified-Since/If-None-Match/If-Range 评估

### 缓存与 HTTP 头部
- `cache_control.cj`：Cache-Control 指令解析
- `retry_after.cj`：Retry-After 头部解析

### 流式写入与调试
- `response_writer.cj`：流式响应写入、ConnectionController、HTTP 错误辅助函数
- `json_helper.cj`：JSON 序列化/反序列化辅助
- `dump.cj`：请求/响应报文转储调试

## 使用方式

```cangjie
// 构造请求
let req = HttpRequest(method: HttpMethod.GET, url: "/api/data")
req.headers.set("Accept", "application/json")

// 构造响应
let resp = HttpResponse(
    status: HttpStatus.OK,
    headers: HttpHeaders(),
    body: Body.fromString("{\"ok\":true}")
)

// 便捷构造
HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")
HttpResponse.text(HttpStatus.OK, "Hello")
HttpResponse.html(HttpStatus.OK, "<h1>Title</h1>")
HttpResponse.empty(HttpStatus.NO_CONTENT)

// 流式写入
let rb = ResponseBuilder(conn, status: HttpStatus.OK)
rb.setHeader("Content-Type", "text/plain")
rb.writeString("Hello, ")
rb.writeString("World!")
rb.finish()
```

## 详细使用指南

请参阅 [Message 使用指南](usage.md) 获取模块的完整 API 使用说明，包括：

- Request/Response 详细构造与属性
- Body 解析（form、JSON、multipart）与构建
- 分块传输编码（ChunkedEncoder/Decoder）
- Gzip/Deflate/Brotli 压缩
- 内容协商（Accept 头部、自动选择）
- 范围请求与条件请求（ETag、If-Modified-Since、If-Range）
- Cache-Control 解析
- 流式响应写入与 ConnectionController
- 报文转储与调试辅助

## 参考

- [RFC 7230 — HTTP/1.1: Message Syntax and Routing](https://www.rfc-editor.org/rfc/rfc7230)
- [RFC 7231 — HTTP/1.1: Semantics and Content](https://www.rfc-editor.org/rfc/rfc7231)
- [RFC 7232 — HTTP/1.1: Conditional Requests](https://www.rfc-editor.org/rfc/rfc7232)
- [RFC 7233 — HTTP/1.1: Range Requests](https://www.rfc-editor.org/rfc/rfc7233)
- [RFC 7234 — HTTP/1.1: Caching](https://www.rfc-editor.org/rfc/rfc7234)
- [RFC 7692 — Compression Extensions for WebSocket](https://www.rfc-editor.org/rfc/rfc7692)
