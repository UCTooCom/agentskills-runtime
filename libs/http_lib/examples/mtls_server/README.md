# mTLS 服务器示例

演示需要客户端证书认证的相互 TLS（mTLS）服务器。

## 构建和运行

```bash
cd sample/mtls_server
# 首先生成证书
openssl req -x509 -newkey rsa:2048 -keyout server.key -out server.crt -days 365 -nodes
openssl req -x509 -newkey rsa:2048 -keyout client.key -out client.crt -days 365 -nodes
cp server.crt ca.crt  # 演示用服务器证书作为 CA
cjpm build
cjpm run
```

测试：`curl --cacert server.crt --cert client.crt --key client.key https://localhost:8443/`

## 主要特性

- 使用 `verifyPeer: true` 进行客户端证书验证
- 客户端可分辨名称（DN）提取
- 服务器端点：/（安全）、/public、/health

```cangjie
let tlsConfig = TlsConfig()
tlsConfig.serverCertPath = "server.crt"
tlsConfig.serverKeyPath = "server.key"
tlsConfig.caCertPath = "ca.crt"
tlsConfig.verifyPeer = true
tlsConfig.verifyHost = true
```

## 预期输出

服务器在 8443 端口启动，启用 mTLS。只有持有有效证书的客户端可以访问端点。
