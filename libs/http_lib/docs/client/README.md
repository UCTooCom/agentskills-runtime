# Client 文档


## 目录

- [Client 使用指南](usage.md) — 快速入门、HTTP/2、请求构建
- [高级 Client](advanced.md) — Cookie 管理、认证、代理、连接池

## 快速参考

```cangjie
import http_lib.client.{HttpClient, HttpClientConfig, HttpRequestBuilder}
```

## 新特性 (v0.1.0)

### 线程安全的客户端
客户端完全支持并发安全使用：
- **HttpTransport** 同步空闲连接访问和活跃连接计数
- **HttpClientCookieJar** 使用 Mutex 实现线程安全的 Cookie 操作
- **HTTP/2** 对同一主机防止重复连接创建

### HTTP/1.1 管道 (Pipelining)

在单个持久连接上发送多个请求，然后按 FIFO 顺序读取响应：

```cangjie
// 方式一：手动管道控制
let p = client.pipeline("https://api.example.com")
p.send(HttpRequest(method: HttpMethod.GET, url: "/resource1"))
p.send(HttpRequest(method: HttpMethod.GET, url: "/resource2"))
let r1 = p.recv()  // FIFO: 先发送先接收
let r2 = p.recv()
p.close()

// 方式二：批量管道
let requests = ArrayList<HttpRequest>()
requests.add(HttpRequest(method: HttpMethod.GET, url: "/a"))
requests.add(HttpRequest(method: HttpMethod.GET, url: "/b"))
let responses = client.pipelineBatch(requests)
```

注意：
- 管道仅适用于 HTTP/1.1 (Connection: keep-alive)
- 不支持 HTTP/2 升级
- 不支持通过代理的管道（当前限制）

### 流式响应读取
```cangjie
let resp = client.send(request)
// 按行读取 (SSE / 流式 API)
while (true) {
    match (resp.readLine()) {
        case Some(line) =>
            if (line.startsWith("data: ")) { println(line) }
        case None => break
    }
}
// 或按缓冲区读取
let buf = Array<UInt8>(4096, repeat: 0)
while (true) {
    let n = resp.readBody(buf)
    if (n <= 0) { break }
}
// 重置读取位置
resp.resetRead()
```

### RequestExecutor 接口
```cangjie
public interface RequestExecutor {
    func roundTrip(request: HttpRequest): HttpResponse
}
// HttpTransport 是默认实现，支持代理、连接池、超时
```

### Digest 认证 SHA-256
```cangjie
import http_lib.client.{sha256Hex, computeDigestResponse}
let hash = sha256Hex(data)
let response = computeDigestResponse(
    username, password, realm, nonce, method, uri,
    algorithm: "SHA-256"
)
```

Nonce count（nc）现在按 nonce 值正确跟踪，重试时自动递增，cnonce 生成具有更好的熵值。

### HTTP/2 自动升级
```cangjie
let config = HttpClientConfig()
config.enableHttp2 = true  // 默认启用
// HTTPS 连接自动尝试 HTTP/2 升级
```

### 代理自动检测
支持从环境变量自动检测代理配置：
`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`

### 连接池延迟驱逐
空闲连接在借用时通过空闲超时检查自动延迟驱逐，无需单独的维护线程。

### 压缩错误处理
`decompressGzip()`/`decompressDeflate()` 对损坏数据抛出 `ProtocolException`。
`brotliDecompress()` 在 brotli 不可用时抛出 `UnsupportedOperationException`。
