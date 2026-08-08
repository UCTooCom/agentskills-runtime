# HTTPS 服务器示例

演示带有 TLS 加密、HTTP/2 支持和自动压缩的 HTTPS 服务器。

## 构建和运行

```bash
cd sample/https_server
# 首先生成自签名证书
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=localhost"
cjpm build
cjpm run
```

测试：`curl -k https://127.0.0.1:8443/`

## 主要特性

- 使用 `listenAndServeTls()` 的 TLS 1.2 加密
- 基于 TLS 的 HTTP/2
- 响应自动压缩
- 安全头支持

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.serverCertPath = "cert.pem"
tlsConfig.serverKeyPath = "key.pem"
let serverConfig = HttpServerConfig()
serverConfig.tlsConfig = Some(tlsConfig)
serverConfig.enableHttp2 = true
server.listenAndServeTls("127.0.0.1", 8443)
```

## 预期输出

服务器在 8443 端口启动，启用 HTTPS。根路径返回 "Hello, Secure World!" HTML 页面。
