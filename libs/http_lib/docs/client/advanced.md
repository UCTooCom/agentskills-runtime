# 高级 Client

## 认证详解

### Digest Auth 流程

```cangjie
import http_lib.client.{parseDigestChallenge, computeDigestResponse, buildDigestAuthHeader}

func makeDigestRequest(client: HttpClient, url: String, method: String, username: String, password: String): HttpResponse {
    // 首次请求（无认证）
    let initialResp = client.get(url)

    match (initialResp.headers.get("www-authenticate")) {
        case Some(header) =>
            let params = parseDigestChallenge(header)
            let nonce = match (params["nonce"]) { case Some(n) => n case None => return initialResp }
            let realm = match (params["realm"]) { case Some(r) => r case None => return initialResp }

            let authHeader = buildDigestAuthHeader(
                username, password, realm, nonce,
                method, url,
                opaque: params["opaque"],
                qop: params["qop"],
                algorithm: params["algorithm"]
            )

            let req = HttpRequestBuilder()
                .get().withUrl(url)
                .withHeader("Authorization", authHeader)
                .build()

            client.send(req)
        case None => initialResp
    }
}
```

### Nonce Count 跟踪

Digest auth 现在按 nonce 值正确跟踪 nonce 计数（nc）。每次使用同一 nonce 重试时自动递增 nc 值，符合 RFC 7616 防重放保护要求：

```cangjie
import http_lib.client.{computeDigestResponse, buildDigestAuthHeader}

// 第一次使用 nonce "abc123" 重试：nc = "00000001"
let resp1 = buildDigestAuthHeader(
    username, password, realm, "abc123",
    "GET", "/protected",
    qop: Some("auth")
)
// 使用同一 nonce "abc123" 第二次重试：nc = "00000002"
let resp2 = buildDigestAuthHeader(
    username, password, realm, "abc123",
    "GET", "/protected",
    qop: Some("auth")
)
```

cnonce 生成也得到了改进，使用更好的熵值增强了安全性。

### MD5 实现

本库使用 JinguiSSL 的真实 MD5 实现进行 Digest Auth 计算，
符合 RFC 7616 规范，可与标准 HTTP 服务器互操作。

### SHA-256 支持 (v0.1.0)

```cangjie
import http_lib.client.{sha256Hex, computeDigestResponse, buildDigestAuthHeader}

// SHA-256 哈希
let hash = sha256Hex(data)

// 使用 SHA-256 算法
let response = computeDigestResponse(
    username, password, realm, nonce, method, uri,
    qop: Some("auth"), algorithm: "SHA-256"
)

// 构建头时传递算法
let header = buildDigestAuthHeader(
    username, password, realm, nonce, method, uri,
    algorithm: Some("SHA-256")
)
```

## 连接池管理

### 线程安全的连接池

`HttpTransport` 现在正确同步了空闲连接访问和活跃连接计数，可在并发任务中安全使用。

### 手动管理连接

```cangjie
import http_lib.client.ConnectionPool

let pool = ConnectionPool(maxPerHost: 5, idleTimeout: Duration.second * 90)

// 借用连接
let conn = pool.borrow("api.example.com", 443, true)
// 使用连接...
// 归还连接
pool.release("api.example.com", 443, true, conn, true)

// 清理空闲连接
pool.closeIdle()

// 关闭所有连接
pool.closeAll()
```

### 空闲连接延迟驱逐

空闲连接在借用时被延迟驱逐：当池尝试复用空闲超时已过期的连接时，该连接会被自动关闭和移除。无需单独的维护线程。

### HttpClient 直接管理 (v0.2.0)

```cangjie
let client = HttpClient()

// 关闭所有空闲连接
client.cleanIdleConnections()
// 完全关闭客户端（释放所有连接、清空 Cookie）
client.close()
```

`cleanIdleConnections()` 仅关闭空闲连接，不影响正在使用的连接；
`close()` 关闭所有连接并清空内部状态（Cookie、HTTP/2 连接）。

### HttpTransport（低级 API）

```cangjie
import http_lib.client.HttpTransport

let transport = HttpTransport()
transport.maxIdleConns = 100
transport.maxIdleConnsPerHost = 5
transport.maxConnsPerHost = 10
transport.idleConnTimeout = Duration.second * 90
transport.connectTimeout = Duration.second * 30
transport.tlsTimeout = Duration.second * 10
transport.responseTimeout = Duration.second * 30
transport.continueTimeout = Duration.second * 1
transport.disableKeepAlive = false
transport.disableAutoDecompress = false
transport.forceHttp2 = true

// 直接发送请求
let resp = transport.roundTrip(request)

// 清理
transport.cleanIdleConnections()
transport.closeAll()
```

`HttpTransport` 现在是线程安全的：空闲连接访问和活跃连接计数均已正确同步，支持并发使用。

## Cookie 管理详解

```cangjie
import http_lib.client.HttpClientCookieJar

let jar = HttpClientCookieJar()

// 从响应提取 Cookie
jar.extractCookies("example.com", "/", true, response)

// 获取匹配的 Cookie 头
let cookieHeader = jar.getCookieHeader("example.com", "/", true, false)

// 应用到请求
jar.applyCookies("example.com", "/", true, request)

// 清空
jar.clear()
```

### 线程安全操作

`HttpClientCookieJar` 现在使用 `Mutex` 同步所有 Cookie 操作，可在并发请求中安全使用。Cookie 提取、头生成和应用操作都是线程安全的。

## 代理支持

```cangjie
import http_lib.client.HttpTransport

let transport = HttpTransport()

// HTTP 代理
transport.proxyUrl = "http://proxy.example.com:8080"

// 代理认证
let authHeader = HttpAuthCredentials.basic("proxyuser", "proxypass")
transport.proxyConnectHeader = authHeader.toHeaderValue()

let resp = transport.roundTrip(request)
```

对于 HTTPS 目标，客户端通过 `CONNECT` 隧道建立连接。

## Expect: 100-Continue

```cangjie
let config = HttpClientConfig()
config.enableExpectContinue = true

let client = HttpClient(config: config)

// 发送大 body 前先发送 headers，等待服务器 100 Continue 响应
let req = HttpRequestBuilder()
    .post().withUrl("https://example.com/upload")
    .withBody(largeBody)
    .build()
let resp = client.send(req)
```

## 自动解压

```cangjie
// 开启（默认）:
let client = HttpClient()
// 响应自动解压 gzip / deflate

// 关闭（获取原始压缩数据）:
let transport = HttpTransport(disableAutoDecompress: true)
```

### 错误处理

`decompressGzip()` 和 `decompressDeflate()` 现在在遇到损坏或格式错误的数据时抛出 `ProtocolException`（而不是静默返回原始字节）。`brotliDecompress()` 在 brotli 不可用时抛出 `UnsupportedOperationException`。

## TLS 配置（Client 端）

```cangjie
import http_lib.connection.TlsConfig

// 默认（验证对等证书和主机名）
let tlsConfig = TlsConfig.default()

// 不安全（仅开发/测试）
let tlsConfig = TlsConfig.insecure()

// 仅 HTTP/1.1（禁用 HTTP/2）
let tlsConfig = TlsConfig.http1Only()
```

## 性能调优

```cangjie
let config = HttpClientConfig()

// 减少超时
config.connectTimeout = Duration.second * 5
config.readTimeout = Duration.second * 15

// 启用连接池
config.connectionPoolEnabled = true
config.maxConnectionsPerHost = 10
config.connectionIdleTimeout = Duration.second * 60

// 启用 HTTP/2 多路复用
config.enableHttp2 = true

let client = HttpClient(config: config)
// 多个请求可共享同一 TCP 连接
```

### HTTP/2 重复连接预防

对同一主机的并发请求不再创建重复的 HTTP/2 连接。传输层同步 HTTP/2 连接建立过程，确保高效多路复用：

```cangjie
// 对同一主机的多个并发请求安全共享一个 HTTP/2 连接
task1 = spawn { client.get("https://api.example.com/1") }
task2 = spawn { client.get("https://api.example.com/2") }
task3 = spawn { client.get("https://api.example.com/3") }
// 三个请求使用同一个 HTTP/2 连接
```

## 更多便捷方法 (v0.2.0)

HttpClient 除 `get()`、`post()`、`put()`、`delete()` 外，还支持以下便捷方法：

### HEAD

```cangjie
let resp = client.head("https://api.example.com/resource")
// HEAD 响应不含 body，仅返回 headers（状态码、Content-Type 等）
println(resp.status.code)          // 200
println(resp.headers.get("content-type"))  // Some("application/json")
```

HEAD 请求仅获取响应头，不传输响应体，适合探测资源是否存在、检查最后修改时间等。

### OPTIONS

```cangjie
let resp = client.options("https://api.example.com/resource")
// 查看服务器支持的 HTTP 方法
match (resp.headers.get("allow")) {
    case Some(methods) => println("允许的方法: ${methods}")
    case None => ()
}
```

OPTIONS 请求用于查询服务器对特定资源所支持的 HTTP 方法，常用于 CORS 预检请求。

### PATCH

```cangjie
// 无 body 的 PATCH
let resp = client.patch("https://api.example.com/resource/1")

// 带 body 的 PATCH
let data = unsafe { "{\"name\": \"new name\"}".rawData() }
let resp = client.patch("https://api.example.com/resource/1", body: data)
```

PATCH 请求用于对资源进行部分修改，与 PUT 的区别在于 PATCH 是增量更新。

### HttpRequestBuilder 全方法支持

`HttpRequestBuilder` 支持所有 9 种标准 HTTP 方法：

```cangjie
let req = HttpRequestBuilder()
    .get()                          // GET
    .post()                         // POST
    .put()                          // PUT
    .delete()                       // DELETE
    .patch()                        // PATCH
    .head()                         // HEAD
    .options()                      // OPTIONS
    .connect()                      // CONNECT
    .trace()                        // TRACE
    .withUrl("https://example.com")
    .withHeader("Accept", "application/json")
    .build()

let resp = client.send(req)
```

通过 `send(req)` 方法可发送使用任意方法构建的请求。

## 流式响应读取 (v0.1.0)

```cangjie
// 按行读取 SSE 流
while (true) {
    match (resp.readLine()) {
        case Some(line) =>
            if (line.startsWith("data: ")) { println(line) }
        case None => break
    }
}
resp.resetRead()  // 重新读取

// 按缓冲区读取
let buf = Array<UInt8>(4096, repeat: 0)
while (true) {
    let n = resp.readBody(buf)
    if (n <= 0) { break }
}
```

## RequestExecutor 接口 (v0.1.0)

```cangjie
import http_lib.client.{RequestExecutor, HttpTransport}

// 自定义传输层
class MyTransport <: RequestExecutor {
    public func roundTrip(request: HttpRequest): HttpResponse {
        // 自定义逻辑
    }
}

// 默认 HttpTransport 支持代理、连接池、超时
let transport = HttpTransport()
transport.maxIdleConns = 100  // 全局空闲连接上限
transport.proxyUrl = Some("http://proxy:8080")
```

## 响应体大小限制 (v0.1.0)

```cangjie
let config = HttpClientConfig()
config.maxResponseBodyBytes = 10 * 1024 * 1024  // 10MB 上限
// 超过限制时抛出 ProtocolException
```

## ConnectionState (v0.1.0)

```cangjie
match (conn.connectionState()) {
    case Some(state) =>
        println("TLS: ${state.version}, ${state.cipherSuite}")
        println("ALPN: ${state.negotiatedProtocol}")
    case None => ()  // 非 TLS 连接
}
```

## HEAD 请求体抑制 (v0.1.0)

ResponseBuilder 自动抑制 HEAD 请求的响应体 (RFC 7231 §4.3.2)：
```cangjie
let w = ResponseBuilder(conn, suppressBody: true)
w.writeHeader(HttpStatus.OK)
w.writeString("this will be suppressed")  // 返回 0
w.finish()
```
