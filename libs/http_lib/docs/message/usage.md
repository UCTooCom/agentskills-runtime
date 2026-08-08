
# Message 模块使用指南

## 概述

`message` 模块是 `http_lib` 中处理 HTTP 请求/响应消息的核心模块，涵盖消息的表示、解析、序列化、编码转换、内容协商和流式写入等完整生命周期。

## 目录

- [Request 与 Response 构建](#request-与-response-构建)
- [Body 处理](#body-处理)
- [请求解析](#请求解析)
- [响应解析](#响应解析)
- [分块传输编码](#分块传输编码)
- [压缩与解压缩](#压缩与解压缩)
- [内容协商](#内容协商)
- [范围请求](#范围请求)
- [条件请求](#条件请求)
- [缓存控制](#缓存控制)
- [流式响应写入](#流式响应写入)
- [JSON 辅助](#json-辅助)
- [报文转储](#报文转储)
- [Retry-After 解析](#retry-after-解析)
- [错误处理](#错误处理)

## Request 与 Response 构建

### HttpRequest

```cangjie
import http_lib.message.HttpRequest
import http_lib.core.{HttpMethod, HttpStatus, HttpHeaders}

// 最小化构造
let req = HttpRequest(method: HttpMethod.GET, url: "/api/users")

// 设置请求头
req.headers.set("Accept", "application/json")
req.headers.set("Authorization", "Bearer token123")

// 设置请求体
req.setJsonBody("{\"name\":\"test\"}")
// 或使用原始字节
req.setBody(unsafe { "raw data".rawData() })

// 获取属性
req.method           // HttpMethod
req.url              // String
req.path             // String — 从 URL 自动提取
req.pathParams       // HashMap<String, String> — 路由提取的参数
req.queryParam("page")  // Option<String>
```

### HttpResponse

```cangjie
import http_lib.message.HttpResponse
import http_lib.core.HttpStatus

// 各类便捷构造器
HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")
HttpResponse.text(HttpStatus.OK, "Hello, World!")
HttpResponse.html(HttpStatus.OK, "<h1>Title</h1>")
HttpResponse.empty(HttpStatus.NO_CONTENT)
HttpResponse.bytes(HttpStatus.OK, "image/png", imageBytes)
HttpResponse.redirect("https://example.com/new")

// 链式构造
let resp = HttpResponse.json(HttpStatus.CREATED, "{\"id\": 42}")
    .withHeader("X-Request-Id", "abc-123")
    .withCookie("session", token,
        path: "/",
        httpOnly: true,
        secure: true,
        sameSite: "Lax")

// 读取属性
resp.status.code          // UInt16
resp.status.reasonPhrase  // String
resp.headers.get("content-type")
resp.bodyAsString()       // String
resp.bodyAsBytes()        // Array<UInt8>
resp.isSuccess()          // Bool
resp.isRedirect()         // Bool
resp.isKeepAlive()        // Bool
```

## Body 处理

### Body 抽象

`Body` 类是请求/响应体的抽象，支持内存缓冲和流式两种模式：

```cangjie
import http_lib.message.Body

// 从字节数组创建
let body = Body(data)

// 从字符串创建（UTF-8 编码）
let body = Body.fromString("Hello World")

// 读取属性
body.size()              // Int64 — body 大小
body.isEmpty()           // Bool
body.asString()          // String
body.asBytes()           // Array<UInt8>
```

### URL 编码表单解析

```cangjie
import http_lib.message.{parseFormBody, parseJsonBody, parseMultipartBody}

// 解析 application/x-www-form-urlencoded
let form = parseFormBody(req)
match (form.get("username")) {
    case Some(name) => println("Hello, ${name}")
    case None => println("Missing username")
}
```

### JSON 解析

```cangjie
let json = parseJsonBody(req)
// 返回 std.json.JsonValue，可安全访问
println(json)
```

### Multipart 解析（文件上传）

```cangjie
// 解析 multipart/form-data
let fields = parseMultipartBody(req)
match (fields.get("file")) {
    case Some(field) =>
        field.fileName    // 原始文件名（如 "photo.jpg"）
        field.data        // 文件内容 (Array<UInt8>)
        field.asString()  // 文本内容
        field.headers.get("content-type")  // 文件 MIME 类型
    case None => println("未上传文件")
}
```

### Multipart 解析（可配置限制）

底层 `BodyParser` 提供更精细的控制，防止资源耗尽：

```cangjie
import http_lib.message.BodyParser

let result = BodyParser.parseMultipart(
    body, contentType,
    maxParts: 10,          // 最大部件数量（默认 10）
    maxPartSize: 10485760,  // 每部分最大字节（默认 10MB）
    maxTotalSize: 52428800  // 总 body 最大字节（默认 50MB）
)
```

参数说明：
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `maxParts` | 10 | 最大部件数量，超限截断 |
| `maxPartSize` | 10485760 (10MB) | 每部分最大字节数 |
| `maxTotalSize` | 52428800 (50MB) | 整个 multipart body 最大字节数 |

### 构造 Multipart Body

```cangjie
import http_lib.message.{generateMultipartBoundary, buildMultipartBody, MultipartField}

let boundary = generateMultipartBoundary()
let fields = HashMap<String, MultipPartField>()
fields["file"] = MultipartField(
    data: fileBytes,
    fileName: Some("test.txt"),
    contentType: Some("text/plain")
)
let bodyBytes = buildMultipartBody(fields, boundary)
```

## 请求解析

`HttpRequestParser` 负责将原始 TCP 字节解析为 `HttpRequest` 对象：

```cangjie
import http_lib.message.HttpRequestParser

// 从完整字节解析
let req = HttpRequestParser.parse(rawBytes)
req.method      // HttpMethod
req.path        // String
req.headers     // HttpHeaders
req.bodyAsString() // String
```

头部解析工具函数：
```cangjie
import http_lib.message.parseHeaders

let headers = parseHeaders(data, start, end)
headers.get("content-type")  // Option<String>
```

## 响应解析

`HttpResponseParser` 负责将原始 TCP 字节解析为 `HttpResponse` 对象：

```cangjie
import http_lib.message.HttpResponseParser

let resp = HttpResponseParser.parse(rawBytes)
resp.status.code      // UInt16
resp.headers          // HttpHeaders
resp.bodyAsString()   // String
```

## 分块传输编码

HTTP 分块传输编码（RFC 7230 §4.1）允许服务器在不知道响应体总大小时分块发送数据。

### ChunkedDecoder

解析分块编码数据：

```cangjie
import http_lib.message.ChunkedDecoder

let decoder = ChunkedDecoder()
let result = decoder.decode(chunkedBytes)
// ChunkedDecodeResult 包含解码后的完整数据
```

### ChunkedWriter（编码）

将数据编码为分块格式：

```cangjie
import http_lib.message.ChunkedWriter

let writer = ChunkedWriter()
writer.write(chunk1)   // 写入分块数据
writer.write(chunk2)
let trailer = HttpHeaders()
trailer.set("X-Checksum", "abc123")
writer.finish(Some(trailer))  // 结束分块，可选 trailer
```

### 自动 Content-Length vs Chunked

库自动决定传输编码策略：
- 如果显式设置了 `Content-Length` 头，使用 Content-Length 编码
- 否则自动使用 Transfer-Encoding: chunked
- Trailer 头需要在写入数据前声明

```cangjie
// 强制使用 Content-Length
let w = ResponseBuilder(conn, status: HttpStatus.OK)
w.setHeader("Content-Length", "100")
w.write(data)
w.finish()

// 自动使用 Chunked（未设置 Content-Length）
w.setHeader("Content-Type", "text/plain")
w.writeString("Hello")  // 自动分块
w.writeString("World")
w.finish()
```

## 压缩与解压缩

### Gzip

```cangjie
import http_lib.message.{compressGzip, decompressGzip}

// 压缩
let compressed = compressGzip(rawData)

// 解压缩
let decompressed = decompressGzip(compressed)
```

> **注意**：`decompressGzip()` 在遇到损坏数据时抛出 `ProtocolException`，而非静默返回原始字节。

### Deflate

```cangjie
import http_lib.message.{compressDeflate, decompressDeflate}

let compressed = compressDeflate(rawData)
let decompressed = decompressDeflate(compressed)
```

> **注意**：`decompressDeflate()` 同样在损坏数据时抛出 `ProtocolException`。

### Brotli

```cangjie
import http_lib.message.{brotliCompress, brotliDecompress}

let compressed = brotliCompress(rawData)
let decompressed = brotliDecompress(compressed)
```

> **注意**：`brotliDecompress()` 在 brotli 未安装时抛出 `UnsupportedOperationException`。调用前应检查运行环境是否支持 brotli。

### Compression 工具类

提供统一的压缩/解压缩接口：

```cangjie
import http_lib.message.Compression

// 静态方法
Compression.supportedEncodings()  // Array<String> — 返回支持的编码列表
```

## 内容协商

基于 Accept 系列头部的服务器驱动内容协商。

### 解析 Accept 头部

```cangjie
import http_lib.message.{NegotiationEntry, parseAccept, parseAcceptEncoding,
    parseAcceptLanguage, parseAcceptCharset}

// 解析 Accept: text/html, application/json;q=0.9, */*;q=0.8
let entries = parseAccept(request.headers.get("accept").getOr("*/*"))
for (entry in entries) {
    entry.value       // "text/html"
    entry.quality     // Float64 (0~1)
    entry.params      // HashMap<String, String> — 如 {"level": "1"}
}

// 解析 Accept-Encoding
let encodings = parseAcceptEncoding("gzip, deflate, br;q=0.8")
// 解析 Accept-Language
let langs = parseAcceptLanguage("zh-CN,zh;q=0.9,en;q=0.8")
// 解析 Accept-Charset
let charsets = parseAcceptCharset("utf-8;q=1, iso-8859-1;q=0.5")
```

### 自动选择

```cangjie
import http_lib.message.{selectContentEncoding, selectContentType}

// 选择最佳内容编码
let encoding = selectContentEncoding(
    req.headers.get("accept-encoding"),
    ["gzip", "deflate"]  // 服务端可用编码列表
)
// 返回 "gzip" 或 "identity" 或空字符串

// 选择最佳内容类型
let contentType = selectContentType(
    req.headers.get("accept"),
    ["application/json", "text/html"]
)
// 返回匹配度最高的类型
```

## 范围请求

支持 HTTP 范围请求（RFC 7233），用于断点续传和分片下载。

### 解析 Range 头部

```cangjie
import http_lib.message.{ByteRange, parseRange, extractRange,
    buildContentRange, buildMultipartRanges, acceptRangesHeader}

// 解析 Range: bytes=0-499
let ranges = parseRange("bytes=0-499", fileSize)
for (range in ranges) {
    range.start  // Int64 — 起始字节
    range.end    // Int64 — 结束字节
    range.length // Int64 — 区间长度
}
```

### 提取范围数据

```cangjie
// 从完整数据中提取一个区间
let chunk = extractRange(fullData, ranges[0])
```

### 构建响应头

```cangjie
// 构建 Content-Range 头
let contentRange = buildContentRange(range, totalSize)
// "bytes 0-499/1000"

// 构建 multipart/byteranges 响应（多区间请求）
let multipartData = buildMultipartRanges(
    fullData, ranges, "application/pdf", totalSize
)

// Accept-Ranges 头
acceptRangesHeader()  // "bytes"
```

### 完整 Range 处理流程

```cangjie
func handleRangeRequest(req: HttpRequest, data: Array<UInt8>) : HttpResponse {
    match (req.headers.get("range")) {
        case Some(rangeHeader) =>
            let ranges = parseRange(rangeHeader, data.size)
            if (ranges.size == 0) {
                // 范围无效，返回 416
                return HttpResponse.empty(HttpStatus.RANGE_NOT_SATISFIABLE)
                        .withHeader("Content-Range", "bytes */${data.size}")
            }

            // 单区间请求
            if (ranges.size == 1) {
                let chunk = extractRange(data, ranges[0])
                return HttpResponse.bytes(HttpStatus.PARTIAL_CONTENT,
                    "application/octet-stream", chunk)
                    .withHeader("Content-Range", buildContentRange(ranges[0], data.size))
            }

            // 多区间请求 — 返回 multipart/byteranges
            let multipart = buildMultipartRanges(
                data, ranges, "application/octet-stream", data.size
            )
            return HttpResponse.bytes(HttpStatus.PARTIAL_CONTENT,
                "multipart/byteranges; boundary=${...}", multipart)

        case None =>
            // 普通 200 响应
            HttpResponse.bytes(HttpStatus.OK, "application/octet-stream", data)
    }
}
```

## 条件请求

支持 ETag、If-Modified-Since、If-None-Match、If-Range 条件请求（RFC 7232）。

### ETag 生成

```cangjie
import http_lib.message.{generateETag, generateWeakETag}

// 强 ETag（基于 SHA-256 内容摘要）
let etag = generateETag(data)
// "\"abc123def...\""

// 弱 ETag
let weakEtag = generateWeakETag(data)
// "W/\"abc123def...\""
```

### 条件求值

```cangjie
import http_lib.message.evaluateConditional

// 评估 If-None-Match / If-Modified-Since / If-Unmodified-Since
let shouldReturnBody = evaluateConditional(
    request.headers,
    etag,
    lastModified: DateTime.now()
)
// 返回 true — 资源已变更，返回完整响应
// 返回 false — 资源未变更，返回 304 Not Modified
```

### If-Range 评估

```cangjie
import http_lib.message.evaluateIfRange

// 评估 If-Range 头（用于 Range 请求并发控制）
let isValid = evaluateIfRange(request.headers, etag, lastModified)
// true — 返回 206 Partial Content
// false — 返回 200 完整响应
```

### 快速设置条件请求头

```cangjie
import http_lib.message.setConditionalHeaders

// 为响应设置 ETag + Last-Modified 头
setConditionalHeaders(response.headers, data, lastModified: Some(DateTime.now()))
```

### 日期比较辅助

```cangjie
import http_lib.message.{httpDatesEqual, httpDateLessOrEqual, httpDateGreater}

httpDatesEqual("Mon, 01 Jan 2024 00:00:00 GMT", "Mon, 01 Jan 2024 00:00:00 GMT")  // true
httpDateLessOrEqual("Mon, 01 Jan 2024 00:00:00 GMT", "Tue, 02 Jan 2024 00:00:00 GMT")  // true
```

## 缓存控制

解析 Cache-Control 头部（RFC 7234）：

```cangjie
import http_lib.message.CacheControl

let cc = CacheControl.parse("public, max-age=3600, no-transform")

cc.public           // true
cc.maxAge           // Some(3600)
cc.noTransform      // true
cc.private          // false
cc.noCache          // false
cc.noStore          // false
cc.mustRevalidate   // false

// 支持的指令
// public, private, no-cache, no-store, no-transform
// must-revalidate, proxy-revalidate, max-age, s-maxage
// immutable, stale-while-revalidate, stale-if-error
```

## 流式响应写入

`ResponseBuilder`（message 模块版本）提供基于 TCP 连接的流式写入，适合大文件传输和 SSE 等场景。

### 基本用法

```cangjie
import http_lib.message.ResponseBuilder
import http_lib.core.HttpStatus

// 创建流式写入器（需要 TCP 连接）
let rb = ResponseBuilder(conn, status: HttpStatus.OK)

// 设置状态码
rb.setStatus(HttpStatus.OK)

// 设置响应头
rb.setHeader("Content-Type", "text/plain")
rb.setHeader("X-Custom", "value")

// 获取可变头映射（可链式调用）
rb.header().set("X-Trace-Id", "abc-123")

// 手动写入状态行和头（write() 会自动调用）
rb.writeHeader(None)

// 写入响应体
rb.write(data)            // 写入字节数组
rb.writeString("Hello")   // 写入字符串

// 声明 Trailer 头（必须在 writeHeader 之前）
rb.addTrailer("X-Checksum", "abc123")

// 刷新缓冲
rb.flush()

// 完成响应（发送结束块和 trailer）
rb.finish()
```

### Content-Length 自动检测

```cangjie
rb.setHeader("Content-Length", "500")
// 自动禁用 chunked 编码，使用 Content-Length 模式
```

### HTTP 辅助函数（响应快速构造）

`message` 模块也提供了便捷的错误响应构造器：

```cangjie
import http_lib.message.{HttpError, HttpNotFound, HttpRedirect}

// 错误响应
HttpError(req, "无效请求", 400)

// 404 快捷方式
HttpNotFound(req)

// 重定向
HttpRedirect(req, "/new-path", 301)
```

### ConnectionController

用于协议升级（如 WebSocket），劫持底层连接：

```cangjie
let controller = rb.takeover()
// 取得连接控制权后，可进行原始 I/O
```

## JSON 辅助

```cangjie
import http_lib.message.JsonHelper

// 将对象序列化为 JSON 字符串
let json = JsonHelper.stringify(data)

// 解析 JSON 字符串
let obj = JsonHelper.parse(json)
```

## 报文转储

调试 HTTP 报文时，可使用 `dump` 函数将请求/响应转为可读格式：

```cangjie
import http_lib.message.{dumpRequest, dumpResponse,
    dumpRequestToString, dumpResponseToString, dumpRequestSafe}

// 转储请求（返回字节数组）
let dump = dumpRequest(request)
println(String.fromUtf8(dump))

// 转储响应
let dump = dumpResponse(response, body: true, maxBody: 4096)

// 转储为字符串
let text = dumpRequestToString(request)
let text = dumpResponseToString(response)

// 安全转储（截断敏感数据，默认最大 256 字节 body）
let safeDump = dumpRequestSafe(request, maxBodyLen: 512)
```

## Retry-After 解析

```cangjie
import http_lib.message.parseRetryAfter

// 解析 Retry-After 头（支持 HTTP-date 和 delta-seconds 格式）
match (parseRetryAfter(response.headers)) {
    case Some(seconds) =>
        println("请在 ${seconds} 秒后重试")
    case None =>
        println("未设置 Retry-After")
}
```

## 流式读取（线读取）

`HttpResponse` 支持按行读取响应体，适用于 SSE（Server-Sent Events）和流式 API：

```cangjie
// 按行读取
while (true) {
    match (resp.readLine()) {
        case Some(line) =>
            if (line.startsWith("data: ")) {
                println(line)
            }
        case None => break
    }
}

// 按缓冲区读取
let buf = Array<UInt8>(4096, repeat: 0)
while (true) {
    let n = resp.readBody(buf)
    if (n <= 0) { break }
}

// 重置读取位置（重新读取响应体）
resp.resetRead()
```

## 错误处理

```cangjie
// Body 解析异常
try {
    let form = parseFormBody(req)
} catch (e: Exception) {
    // 返回 400 Bad Request
    HttpError(req, "Invalid form data", 400)
}

// 压缩数据损坏
try {
    let decompressed = decompressGzip(compressedData)
} catch (e: ProtocolException) {
    println("压缩数据已损坏: ${e.message}")
}

// 请求体类型不匹配
if (!req.headers.get("content-type").getOr("").startsWith("multipart/form-data")) {
    return HttpError(req, "Expected multipart/form-data", 415)
}
let fields = parseMultipartBody(req)
```

## 常见模式

### 构建 JSON API 响应

```cangjie
func jsonResponse(data: HashMap<String, String>) : HttpResponse {
    let json = JsonHelper.stringify(data)
    HttpResponse.json(HttpStatus.OK, json)
}
```

### 大文件流式输出

```cangjie
func streamFile(req: HttpRequest, filePath: String, conn: TcpConnection) : Unit {
    let file = File(filePath, FileAccess.Read)
    let rb = ResponseBuilder(conn, status: HttpStatus.OK)
    rb.setHeader("Content-Type", "application/octet-stream")
    rb.writeHeader(None)

    let buf = Array<UInt8>(8192, repeat: 0)
    while (true) {
        let n = file.read(buf)
        if (n <= 0) { break }
        rb.write(buf[0..n])
    }
    rb.finish()
    file.close()
}
```

### Range + Conditional 组合

```cangjie
// 完整的资源服务函数
func serveResource(req: HttpRequest, data: Array<UInt8>, mimeType: String) : HttpResponse {
    // 设置条件头
    let headers = HttpHeaders()
    setConditionalHeaders(headers, data)

    // 评估条件请求
    if (!evaluateConditional(req.headers, headers.get("etag").getOr(""),
                             lastModified: None)) {
        return HttpResponse.empty(HttpStatus.NOT_MODIFIED)
    }

    // 处理 Range 请求
    match (req.headers.get("range")) {
        case Some(_) =>
            if (evaluateIfRange(req.headers, headers.get("etag").getOr(""),
                                lastModified: None)) {
                let ranges = parseRange(req.headers.get("range").getOr(""), data.size)
                if (ranges.size > 0) {
                    let chunk = extractRange(data, ranges[0])
                    return HttpResponse.bytes(HttpStatus.PARTIAL_CONTENT, mimeType, chunk)
                        .withHeader("Content-Range", buildContentRange(ranges[0], data.size))
                }
            }
        case None => ()
    }

    HttpResponse.bytes(HttpStatus.OK, mimeType, data)
}
```

## 参考

- [RFC 7230 — HTTP/1.1: Message Syntax and Routing](https://www.rfc-editor.org/rfc/rfc7230)
- [RFC 7231 — HTTP/1.1: Semantics and Content](https://www.rfc-editor.org/rfc/rfc7231)
- [RFC 7232 — HTTP/1.1: Conditional Requests](https://www.rfc-editor.org/rfc/rfc7232)
- [RFC 7233 — HTTP/1.1: Range Requests](https://www.rfc-editor.org/rfc/rfc7233)
- [RFC 7234 — HTTP/1.1: Caching](https://www.rfc-editor.org/rfc/rfc7234)
- [RFC 7692 — Compression Extensions for WebSocket](https://www.rfc-editor.org/rfc/rfc7692)
- [HTTP 消息模块 README](README.md)
- [核心类型文档](../core/api.md)
