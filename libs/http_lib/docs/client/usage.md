# Client 使用指南

## 快速开始

### 基础请求

```cangjie
import http_lib.client.{HttpClient, HttpClientConfig}

main() {
    let client = HttpClient()

    // GET
    let resp = client.get("https://httpbin.org/get")
    println(resp.bodyAsString())

    // POST with JSON
    let resp2 = client.postJson("https://httpbin.org/post", "{\"key\":\"value\"}")

    // POST with form
    let form = HashMap<String, String>()
    form["name"] = "test"
    form["age"] = "25"
    let resp3 = client.postForm("https://httpbin.org/post", form)

    client.close()
}
```

### 更多 HTTP 方法

```cangjie
let client = HttpClient()

// HEAD
let headers = client.head("https://httpbin.org/get")
println("Content-Type: ${headers.headers.get("content-type")}")

// OPTIONS
let options = client.options("https://httpbin.org/")

// PATCH with body
let patchResp = client.patch("https://httpbin.org/patch", body: unsafe {"{\"update\":\"value\"}".rawData()})

// DELETE
let delResp = client.delete("https://httpbin.org/delete")

// Close idle connections proactively
client.cleanIdleConnections()

client.close()
```

### 带配置的 Client

```cangjie
import std.time.Duration

let config = HttpClientConfig()
config.connectTimeout = Duration.second * 10
config.readTimeout = Duration.second * 30
config.writeTimeout = Duration.second * 30
config.followRedirects = true
config.maxRedirects = 10
config.connectionPoolEnabled = true
config.maxConnectionsPerHost = 5
config.connectionIdleTimeout = Duration.second * 90
config.cookieJarEnabled = true
config.enableHttp2 = true
config.enableExpectContinue = true

let client = HttpClient(config: config)
```

## 请求构建

### HttpRequestBuilder

```cangjie
import http_lib.client.HttpRequestBuilder

let req = HttpRequestBuilder()
    .get()
    .withUrl("https://httpbin.org/headers")
    .withHeader("Authorization", "Bearer token")
    .withHeader("X-Custom", "value")
    .build()

let resp = client.send(req)
```

### POST/PUT 请求体

```cangjie
// JSON body
let req = HttpRequestBuilder()
    .post()
    .withUrl("https://httpbin.org/post")
    .withJson("{\"data\":\"test\"}")
    .build()

// Form body
let form = HashMap<String, String>()
form["q"] = "search term"
let req2 = HttpRequestBuilder()
    .post()
    .withUrl("https://httpbin.org/post")
    .withForm(form)
    .build()

// Raw bytes
let req3 = HttpRequestBuilder()
    .put()
    .withUrl("https://httpbin.org/put")
    .withBody(rawBytes)
    .build()

// Multipart / File upload
let req4 = HttpRequestBuilder()
    .post()
    .withUrl("https://httpbin.org/post")
    .withFile("file", "/path/to/file.pdf", "application/pdf")
    .build()
```

### 所有 HTTP 方法

```cangjie
HttpRequestBuilder().get()     .withUrl(url).build()
HttpRequestBuilder().post()    .withUrl(url).build()
HttpRequestBuilder().put()     .withUrl(url).build()
HttpRequestBuilder().delete()  .withUrl(url).build()
HttpRequestBuilder().patch()   .withUrl(url).build()
HttpRequestBuilder().head()    .withUrl(url).build()
HttpRequestBuilder().options() .withUrl(url).build()
HttpRequestBuilder().connect() .withUrl(url).build()
HttpRequestBuilder().trace()   .withUrl(url).build()
```

## 响应处理

```cangjie
let resp = client.get("https://httpbin.org/json")

// 状态
resp.status.code          // UInt16
resp.status.toString()    // "200 OK"
resp.isSuccess()          // true (2xx)
resp.isRedirect()         // false (3xx)

// Headers
resp.headers.get("content-type")  // Some("application/json")
resp.headers.getAll("set-cookie") // Array<String>

// Body
resp.bodyAsString()       // UTF-8 字符串
resp.bodyAsBytes()        // 原始字节

// Keep-Alive
resp.isKeepAlive()        // 连接是否可复用
```

## 重定向

```cangjie
let config = HttpClientConfig()
config.followRedirects = true
config.maxRedirects = 10

let client = HttpClient(config: config)

// RFC 7231 语义:
// 303 → 自动切换为 GET
// 301/302 → 历史原因切换为 GET
// 307/308 → 保持原始方法和 body
```

## HTTP/2

```cangjie
let config = HttpClientConfig()
config.enableHttp2 = true  // 对 HTTPS 连接启用 HTTP/2

let client = HttpClient(config: config)
let resp = client.get("https://http2.example.com/")
// Client 自动完成 HTTP/2 升级握手 (preface + SETTINGS)
```

### 重复连接预防

对同一主机的并发请求不再创建重复的 HTTP/2 连接。传输层同步 HTTP/2 连接建立过程，确保多个并发请求共享同一主机的单个 HTTP/2 连接。

## 认证

### Basic Auth

```cangjie
import http_lib.client.{HttpAuthCredentials, HttpAuthScheme}

let creds = HttpAuthCredentials.basic("username", "password")
let config = HttpClientConfig()
config.authCredentials = creds
```

### Bearer Token

```cangjie
let creds = HttpAuthCredentials.bearer("my-token-value")
```

### Digest Auth

```cangjie
import http_lib.client.{parseDigestChallenge, computeDigestResponse, buildDigestAuthHeader}

// 从 401 响应解析 challenge
let challenge = resp.headers.get("www-authenticate")
match (challenge) {
    case Some(ch) =>
        let params = parseDigestChallenge(ch)
        let authHeader = buildDigestAuthHeader(
            "username", "password",
            params["realm"],
            params["nonce"],
            "GET", "/protected",
            opaque: params["opaque"],
            qop: params["qop"]
        )
    case None => ()
}
```

#### Nonce Count 跟踪

Digest auth 现在按 nonce 值正确跟踪 nonce 计数（nc）。每次使用同一 nonce 重试时自动递增 nc 值，符合 RFC 7616 防重放保护要求。之前 nc 被硬编码为 "00000001"。

```cangjie
// 第一次请求：nc = "00000001"
// 使用同一 nonce 的第二次请求：nc = "00000002"
// 依此类推
```

cnonce 生成也得到了改进，使用更好的熵值增强了安全性。

## Cookie 管理

```cangjie
let config = HttpClientConfig()
config.cookieJarEnabled = true  // 自动储存和发送 Cookie

let client = HttpClient(config: config)

// Cookie 自动在请求间保持
client.get("https://example.com/login")
client.get("https://example.com/dashboard")  // 自动携带 Cookie
```

### 线程安全的 Cookie Jar

`HttpClientCookieJar` 现在使用 `Mutex` 实现线程安全的 Cookie 操作，可在并发请求中安全使用。Cookie 的提取、获取和应用操作均已同步。

## 连接池

```cangjie
let config = HttpClientConfig()
config.connectionPoolEnabled = true
config.maxConnectionsPerHost = 5
config.connectionIdleTimeout = Duration.second * 90

let client = HttpClient(config: config)

// 对同一 host 的多次请求复用连接
client.get("https://api.example.com/endpoint1")
client.get("https://api.example.com/endpoint2")  // 复用连接
```

### 空闲连接延迟驱逐

空闲连接现在在借用时延迟驱逐：当池尝试复用连接时，如果空闲超时已过期，会自动清理过期连接，无需单独的维护线程。

## 压缩

```cangjie
// Client 自动声明 Accept-Encoding
// 自动解压 gzip 和 deflate 响应
// 通过 config 控制:
config.disableAutoDecompress = true  // 禁用自动解压（HttpTransport 中）
```

### 错误处理

`decompressGzip()` 和 `decompressDeflate()` 现在在遇到损坏或格式错误的压缩数据时抛出 `ProtocolException`（而不是静默返回原始字节）。应用程序在处理压缩响应时应捕获此异常。

Brotli：`brotliDecompress()` 在 brotli 不可用时抛出 `UnsupportedOperationException`（而不是静默返回压缩数据）。调用前应通过特性检测检查可用性。

## 线程安全

客户端实现是线程安全的，支持并发使用：

- **HttpTransport**：空闲连接访问和活跃连接计数均已正确同步，允许安全并发请求调度。
- **HttpClientCookieJar**：Cookie 操作（提取、获取、应用）使用 `Mutex` 同步，实现线程安全的 Cookie 管理。
- **HTTP/2 连接**：重复连接预防确保对同一主机的并发请求共享一个多路复用连接。

```cangjie
// 可在线程/协程间安全共享客户端
let client = HttpClient(config: config)

// 并发请求是安全的
task1 = spawn { client.get("https://api.example.com/1") }
task2 = spawn { client.get("https://api.example.com/2") }

let r1 = task1.get()
let r2 = task2.get()
```

## 配置参考

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `connectTimeout` | Duration | 30s | 连接超时 |
| `readTimeout` | Duration | 30s | 读超时 |
| `writeTimeout` | Duration | 30s | 写超时 |
| `maxResponseHeaderBytes` | Int64 | - | 最大响应头 |
| `followRedirects` | Bool | true | 跟随重定向 |
| `maxRedirects` | Int64 | 10 | 最大重定向数 |
| `tlsConfig` | TlsConfig? | None | TLS 配置 |
| `connectionPoolEnabled` | Bool | false | 连接池 |
| `maxConnectionsPerHost` | Int64 | 5 | 每 host 最大连接 |
| `connectionIdleTimeout` | Duration | 90s | 空闲连接超时 |
| `cookieJarEnabled` | Bool | false | Cookie 管理 |
| `enableExpectContinue` | Bool | false | 100-continue |
| `authCredentials` | ? | None | 认证凭证 |
| `enableHttp2` | Bool | false | HTTP/2 |

## 流式响应读取 (v0.1.0)

### 按行读取 (SSE/流式 API)
```cangjie
let resp = client.send(request)
while (true) {
    match (resp.readLine()) {
        case Some(line) =>
            if (line.startsWith("data: ")) { println(line) }
        case None => break
    }
}
resp.resetRead()  // 重置读取位置
```

### 按缓冲区读取
```cangjie
let buf = Array<UInt8>(4096, repeat: 0)
while (true) {
    let n = resp.readBody(buf)
    if (n <= 0) { break }
}
```

### 真实 SSE 示例
```cangjie
let req = HttpRequestBuilder()
    .post().withUrl("https://opencode.ai/zen/v1/chat/completions")
    .withHeader("Content-Type", "application/json")
    .withJson("{\"messages\":[{\"content\":\"当前知识日期\",\"role\":\"user\"}],\"model\":\"deepseek-v4-flash-free\",\"stream\":true,\"temperature\":1}")
    .build()
let resp = client.send(req)
// resp.status.code == 200, readLine() 读取 SSE 行
```

## HTTP/2 客户端 (v0.1.0)

自动为 HTTPS 连接启用 HTTP/2：
```cangjie
let config = HttpClientConfig()
config.enableHttp2 = true  // 默认启用
let client = HttpClient(config: config)
let resp = client.get("https://http2.example.com/api")
// 自动通过 HTTP/2 多路复用发送请求
```

## RequestExecutor 接口 (v0.1.0)

```cangjie
import http_lib.client.{RequestExecutor, HttpTransport}
let transport = HttpTransport()
transport.proxyUrl = Some("http://proxy:8080")
let resp = transport.roundTrip(request)
```

## Digest 认证 SHA-256 (v0.1.0)

```cangjie
import http_lib.client.{sha256Hex, computeDigestResponse, buildDigestAuthHeader}
let response = computeDigestResponse(
    username, password, realm, nonce, method, uri,
    qop: Some("auth"), algorithm: "SHA-256"
)
let header = buildDigestAuthHeader(
    username, password, realm, nonce, method, uri,
    algorithm: Some("SHA-256")
)
```

## 代理自动检测 (v0.1.0)

从环境变量自动检测代理配置：
- `HTTP_PROXY` — HTTP 代理
- `HTTPS_PROXY` — HTTPS 代理
- `NO_PROXY` — 代理排除列表

```cangjie
let transport = HttpTransport()  // 自动调用 detectProxy()
```

## MASQUE 代理 (RFC 9298)

基于 QUIC 隧道传输技术，实现 HTTP Datagrams 和 Capsule 协议的代理能力：

```cangjie
import http_lib.client.MasqueTunnel

let tunnel = MasqueTunnel()
tunnel.connect("proxy.example.com", 443)
tunnel.send("target.example.com", 80, requestData)
let response = tunnel.receive()
tunnel.close()
```

## HTTP 请求追踪

追踪 HTTP 请求生命周期中的各阶段耗时：

```cangjie
import http_lib.client.TraceInfo

let client = HttpClient()
client.traceEnabled = true  // 启用追踪
let resp = client.get("https://example.com/")

// 获取追踪信息
match (client.lastTrace) {
    case Some(trace) =>
        println("总耗时: ${trace.totalTime}")
        println("DNS 解析: ${trace.dnsDone - trace.dnsStart}")
        println("TCP 连接: ${trace.connectDone - trace.connectStart}")
        println("TLS 握手: ${trace.tlsDone - trace.tlsStart}")
    case None => ()
}
```
