# 核心 API 参考

## HttpMethod

HTTP 方法枚举 (RFC 7231 + RFC 5789):

```cangjie
import http_lib.core.HttpMethod

HttpMethod.GET      HttpMethod.HEAD     HttpMethod.POST
HttpMethod.PUT      HttpMethod.DELETE   HttpMethod.CONNECT
HttpMethod.OPTIONS  HttpMethod.TRACE    HttpMethod.PATCH

// 解析字符串
match (HttpMethod.parse("POST")) {
    case Some(m) => m
    case None => HttpMethod.GET  // default
}

// 转字符串
HttpMethod.GET.toString()  // "GET"
```

## HttpStatus

HTTP 状态码类:

```cangjie
import http_lib.core.HttpStatus

// 静态常量
HttpStatus.OK                    // 200
HttpStatus.CREATED               // 201
HttpStatus.NOT_FOUND             // 404
HttpStatus.INTERNAL_SERVER_ERROR // 500

// 属性
let status = HttpStatus.OK
status.code           // 200
status.reasonPhrase   // "OK"
status.toString()     // "200 OK"

// 分类方法
status.isInformational()  // 1xx
status.isSuccess()        // 2xx
status.isRedirection()    // 3xx
status.isClientError()    // 4xx
status.isServerError()    // 5xx

// 自定义状态码
let custom = HttpStatus(418, reasonPhrase: "I'm a teapot")
```

## HttpVersion

```cangjie
import http_lib.core.HttpVersion

HttpVersion.HTTP_1_0
HttpVersion.HTTP_1_1
HttpVersion.HTTP_2_0

// 解析
HttpVersion.parse("HTTP/1.1")  // Some(HTTP_1_1)
HttpVersion.parse("HTTP/2")    // Some(HTTP_2_0)
HttpVersion.parse("HTTP/2.0")  // Some(HTTP_2_0)

// 检查
HttpVersion.HTTP_1_1.isAtLeast11()  // true
HttpVersion.HTTP_1_0.isAtLeast11()  // false
```

## HttpHeaders

不区分大小写的多值 HTTP 头容器:

```cangjie
import http_lib.core.HttpHeaders

let headers = HttpHeaders()

// 添加（追加到已有值，逗号分隔）
headers.add("Content-Type", "application/json")
headers.add("Set-Cookie", "a=1")
headers.add("Set-Cookie", "b=2")  // 多个 Set-Cookie

// 设置（替换）
headers.set("X-Custom", "value")

// 读取（不区分大小写）
headers.get("content-type")      // Some("application/json")
headers.get("CONTENT-TYPE")      // Some("application/json")

// 获取所有值
headers.getAll("set-cookie")     // ["a=1", "b=2"]

// 检查
headers.contains("content-type")  // true
headers.isEmpty()                 // false
headers.size                      // 唯一头名称数量

// 遍历
let entries = headers.entries()          // Array<(String, String)>
headers.forEach({ name, value => println("${name}: ${value}") })

// 删除
headers.remove("x-custom")

// 清空
headers.clear()

// 获取所有头名称
headers.names()  // Array<String>

// 序列化为 HTTP/1.x 格式
headers.toBytes()  // Array<UInt8>
```

## HttpRequest

```cangjie
import http_lib.message.HttpRequest

// 创建带 URL 的请求
let req = HttpRequest(url: "https://example.com/path?q=1")
req.path       // "/path"（从 URL 自动提取，字段访问）
req.pathParams // HashMap<String, String> 路由器提取的路径参数
req.method     // HttpMethod.GET（默认）
req.url        // 完整 URL 字符串

// Builder 模式链式调用
let req2 = HttpRequest()
    .setMethod(HttpMethod.POST)
    .setUrl("https://example.com/api")
    .setHeader("Content-Type", "application/json")
    .setBody(unsafe { "{\"key\":\"value\"}".rawData() })
```

`path` 现在是字段（之前是方法 `path()`），在构造函数中从 URL 自动提取。请使用 `req.path`（字段访问）代替 `req.path()`。`pathParams` 是供路由器提取路径参数的字段。

## HttpDate

```cangjie
import http_lib.core.{formatHttpDate, currentHttpDate, parseHttpDate}

// 格式化
formatHttpDate(DateTime.now())
// "Sun, 06 Nov 1994 08:49:37 GMT"

// 当前时间
currentHttpDate()

// 解析（返回 Unix 秒）
parseHttpDate("Sun, 06 Nov 1994 08:49:37 GMT")      // Some(784111777)
parseHttpDate("Sunday, 06-Nov-94 08:49:37 GMT")      // Some(784111777)
parseHttpDate("Sun Nov  6 08:49:37 1994")            // Some(784111777)
```

## HttpException

```cangjie
import http_lib.core.{HttpException, ProtocolException, ConnectionException, TimeoutException}

throw ProtocolException("invalid request line")
throw ConnectionException("example.com")
throw TimeoutException("read")
```

## 常量

```cangjie
import http_lib.core.{CRLF, MAX_HEADER_SIZE, DEFAULT_BUFFER_SIZE}

CRLF                 // "\r\n"
MAX_HEADER_SIZE      // 65536
MAX_LINE_LENGTH      // 8192
DEFAULT_BUFFER_SIZE  // 8192
```

## 压缩

### Gzip / Deflate

```cangjie
import http_lib.message.{compressGzip, decompressGzip, compressDeflate, decompressDeflate}

// 压缩
let compressed = compressGzip(rawData)
let compressed2 = compressDeflate(rawData)

// 解压
let decompressed = decompressGzip(compressed)
let decompressed2 = decompressDeflate(compressed2)
```

`decompressGzip()` 和 `decompressDeflate()` 现在在遇到损坏或格式错误的压缩数据时抛出 `ProtocolException`（而不是静默返回原始字节）。

### Brotli

```cangjie
import http_lib.message.{brotliCompress, brotliDecompress}

// 压缩
let compressed = brotliCompress(rawData)

// 解压
let decompressed = brotliDecompress(compressed)
```

`brotliDecompress()` 在 brotli 不可用时抛出 `UnsupportedOperationException`（而不是静默返回压缩数据）。在 brotli 可能未安装的环境中调用前应检查可用性。

## Multipart 解析

```cangjie
import http_lib.message.BodyParser

// 使用可配置限制解析 multipart 数据
let result = BodyParser.parseMultipart(body, contentType,
    maxParts: 10,         // 最大部件数量（默认）
    maxPartSize: 10485760, // 每部分最大大小（字节），10MB（默认）
    maxTotalSize: 52428800 // 总 body 最大大小（字节），50MB（默认）
)
```

Multipart 解析器支持可配置的限制以防止资源耗尽：
- `maxParts`：最大部件数量（默认：10）
- `maxPartSize`：每个部件的最大大小（字节，默认：10MB）
- `maxTotalSize`：multipart body 总大小限制（字节，默认：50MB）

## ResponseBuilder（流式响应写入器）

```cangjie
import http_lib.message.ResponseBuilder
import http_lib.connection.Connection

let w = ResponseBuilder(conn, status: HttpStatus.OK)

// 设置状态码
w.setStatus(HttpStatus.OK)

// 设置响应头（链式）
w.setHeader("Content-Type", "application/json")
w.setHeader("X-Custom", "value")

// 获取可变头映射
let headers = w.header()
headers.set("X-Trace-Id", "abc")

// 手动写状态行+头（可选，write() 会自动调用）
w.writeHeader(HttpStatus.OK)

// 写入响应体
w.write(data)          // 写入字节数组，返回字节数
w.writeString("text")  // 写入字符串

// Content-Length 自动检测
w.setHeader("Content-Length", "100")
// 自动禁用 chunked 编码，使用 Content-Length 帧

// 尾部头（Trailer），必须在 writeHeader() 之前声明
w.addTrailer("X-Checksum", "abc123")

// 刷新缓冲
w.flush()

// 完成响应（发送结束块）
w.finish()
```

## HttpResponse 流式读取 (v0.1.0)

```cangjie
// 按行读取（推荐用于 SSE/流式 API）
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
    // 处理 buf[0..n]
}

// 重置读取位置
resp.resetRead()
```

## RequestExecutor 接口 (v0.1.0)

```cangjie
import http_lib.client.{RequestExecutor, HttpTransport}

// 自定义传输实现
class MyTransport <: RequestExecutor {
    public func roundTrip(request: HttpRequest): HttpResponse {
        // 自定义 HTTP 请求执行逻辑
    }
}

// 默认实现: HttpTransport 支持代理、连接池、超时
let transport = HttpTransport()
```

## Router 增强 (v0.1.0)

```cangjie
// 虚拟主机路由
let router = Router()
router.host("api.example.com").get("/v1/users", apiHandler)
router.host("admin.example.com").get("/dashboard", adminHandler)

// 查找时指定主机头
let result = router.findByHost(method, path, "api.example.com")

// 路由分组
let api = router.group("/api/v1")
api.get("/users", listUsers)
api.post("/users", createUser)
// 匹配 /api/v1/users
```

## Digest 认证 SHA-256 (v0.1.0)

```cangjie
import http_lib.client.{sha256Hex, computeDigestResponse, buildDigestAuthHeader}

// SHA-256 hex 摘要
let hash = sha256Hex(data)

// 使用 SHA-256 算法计算 Digest 响应
let response = computeDigestResponse(
    username, password, realm, nonce, method, uri,
    qop: Some("auth"), algorithm: "SHA-256"
)

// 构建 Authorization: Digest 头
let header = buildDigestAuthHeader(
    username, password, realm, nonce, method, uri,
    algorithm: Some("SHA-256")
)
```

## ResponseBuilder

流式响应构建器 (标准 ResponseBuilder 模式):

```cangjie
import http_lib.server.ResponseBuilder

let rw = ResponseBuilder()
rw.writeHeader(200)
rw.header("Content-Type", "application/json")
rw.writeString("{\"status\":\"ok\"}")
let resp = rw.build()  // 生成 HttpResponse
```

## HTTP 辅助函数

HTTP 辅助函数:

```cangjie
import http_lib.server.{HttpError, HttpNotFound, HttpRedirect}

// 错误响应
HttpError(req, "Not Found", 404)

// 404 快捷方式
HttpNotFound(req)

// 重定向
HttpRedirect(req, "/new-path", 301)

// Handler 快捷方式
NotFoundResponder()   // 返回 404 的 Handler
RedirectResponder("/target", 302)  // 返回重定向的 Handler

// 将 ResponseBuilder handler 转为标准 Handler
wrapResponseBuilderHandler({req, rw =>
    rw.writeString("Hello")
})
```

## HttpClient 方法

```cangjie
import http_lib.client.HttpClient

let client = HttpClient()

client.get(url)           // GET 请求
client.post(url)          // POST 请求
client.put(url)           // PUT 请求
client.delete(url)        // DELETE 请求
client.head(url)          // HEAD 请求
client.options(url)       // OPTIONS 请求
client.patch(url)         // PATCH 请求
client.postJson(url, json)    // POST JSON
client.postForm(url, form)    // POST 表单
client.cleanIdleConnections()  // 关闭空闲连接
client.close()                 // 关闭客户端
```

## RequestContext

请求上下文 (v0.3):

```cangjie
import http_lib.core.RequestContext

let ctx = RequestContext()
ctx.setDeadline(DateTime.now() + Duration.second * 5)
ctx.setValue("requestId", "abc-123")
if (ctx.isExpired()) {
    // 超时处理
}
ctx.cancel(reason: "client disconnected")
```

## ServeContent

流式内容服务 (v0.3):

```cangjie
import http_lib.server.ServeContent

let resp = ServeContent(data, req, "text/plain",
    modTime: Some(DateTime.now()))
// 自动处理 Range/If-Modified-Since/ETag
```

## ConnectionController

连接劫持 (v0.3):

```cangjie
// 通过 req.connection 获取底层连接
let conn = match (req.connection) {
    case Some(c) => c
    case None => return HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, "takeover not supported")
}
// 执行原始 I/O ...
```

## Content-Type 嗅探

内容类型嗅探 (v0.3):

```cangjie
import http_lib.server.detectContentType

let mime = detectContentType(data)  // 读取前 512 字节检测
```

## ResponseRecorder

响应记录器 (v0.3):

```cangjie
import http_lib.testutil.ResponseRecorder

let recorder = ResponseRecorder(myHandler)
recorder.serve(HttpRequest(url: "/test"))
assertTrue(recorder.code() == 200u16)
```

## 自定义 Dialer

自定义拨号器 (v0.3):

```cangjie
let config = HttpClientConfig()
config.dialer = Some({host, port, isSecure =>
    TcpConnection.connect(host, port,
        connectTimeout: Duration.second * 10,
        readTimeout: Duration.second * 10,
        writeTimeout: Duration.second * 10)
})
let client = HttpClient(config: config)
```

## ResponseController (v0.1.0+)

统一响应控制接口，对应 Go 的 http.ResponseController。

```cangjie
import http_lib.server.ResponseController
import http_lib.connection.Connection

let ctrl = ResponseController(responseBuilder, conn)

// Flush — 刷新缓冲数据到客户端
ctrl.flush()

// Hijack — 劫持连接，取得底层连接的所有权
let hijackedConn = ctrl.hijack()

// 读取截止时间 — 设置请求体的读取截止时间
ctrl.setReadDeadline(DateTime.now() + Duration.second * 30)

// 写入截止时间 — 设置响应体的写入截止时间
ctrl.setWriteDeadline(DateTime.now() + Duration.second * 30)

// 全双工模式 — 允许在读取请求体的同时写入响应体
ctrl.enableFullDuplex()
```

## HTTP/3 (QUIC) API (v0.1.0+)

HTTP/3 (RFC 9114) 的类型定义与帧编解码。

```cangjie
import http_lib.http3.*

// QUIC 传输层接口
interface QuicStream  // QUIC 流抽象
interface QuicConnection  // QUIC 连接抽象
interface QuicListener  // QUIC 监听器抽象
interface QuicTransportFactory  // QUIC 传输层工厂

// HTTP/3 帧构建
buildH3SettingsFrame([(Http3SettingsId, UInt64)])  // SETTINGS 帧
buildH3GoawayFrame(lastStreamId: UInt64)  // GOAWAY 帧
buildH3MaxPushIdFrame(maxPushId: UInt64)  // MAX_PUSH_ID 帧
buildH3CancelPushFrame(pushId: UInt64)  // CANCEL_PUSH 帧
buildH3PushPromiseFrame(pushId: UInt64, encodedHeaders: Array<UInt8>)  // PUSH_PROMISE 帧
encodeH3Frame(frameType: Http3FrameType, payload: Array<UInt8>)  // 通用帧编码
decodeH3FrameHeader(data)  // 帧头解码

// QPACK 头部压缩 (RFC 9204)
// QpackEncoder — 编码器，管理动态表并生成编码器流指令
// QpackDecoder — 解码器，管理动态表并生成解码器流指令
```

## Capsule 协议 (v0.1.0+)

Capsule Protocol (RFC 9297) 的封装类型。

```cangjie
import http_lib.http2.*

// Capsule 类型枚举
CapsuleType.DATAGRAM  // 数据报胶囊
CapsuleType.DATAGRAM_WITH_CONTEXT  // 带上下文的数据报胶囊
CapsuleType.CLOSE  // 关闭胶囊
CapsuleType.REGISTRATION  // 注册胶囊

// Capsule 封包
Capsule(capsuleType: CapsuleType, payload: Array<UInt8>)

// 编码/解码
encodeCapsule(capsule: Capsule): Array<UInt8>
decodeCapsule(data: Array<UInt8>): Capsule
```

## 请求追踪 (v0.1.0+)

HTTP 请求生命周期追踪。

```cangjie
import http_lib.client.TraceInfo
import http_lib.client.HttpClient

let client = HttpClient()
client.traceEnabled = true  // 启用追踪
client.get("https://example.com/")

// 追踪信息
match (client.lastTrace) {
    case Some(trace) =>
        trace.dnsStart        // DNS 解析开始时间
        trace.dnsDone         // DNS 解析结束时间
        trace.connectStart    // TCP 连接开始时间
        trace.connectDone     // TCP 连接结束时间
        trace.tlsStart        // TLS 握手开始时间
        trace.tlsDone         // TLS 握手结束时间
        trace.gotFirstByte    // 收到首个响应字节时间
       trace.totalTime       // 总耗时
    case None => ()
}
```
