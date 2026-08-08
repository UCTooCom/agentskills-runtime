# HTTP/2 客户端示例

演示通过单个连接复用多个请求的 HTTP/2 客户端。

## 构建和运行

```bash
cd sample/http2_client
cjpm build
cjpm run
```

## 主要特性

- 通过带有 `h2` ALPN 协商的 TLS 使用 HTTP/2 协议
- 连接池复用（单个连接上的多个并发请求）
- 通过 `HttpClientConfig.enableHttp2` 配置

```cangjie
let tlsConfig = TlsConfig.default()
tlsConfig.nextProtos = ["h2"]
let config = HttpClientConfig()
config.enableHttp2 = true
config.tlsConfig = tlsConfig
```

## 预期输出

示例向 HTTP/2 端点发送 5 个请求并打印每个响应的状态码。通过复用，所有请求在单个连接上高效完成。
