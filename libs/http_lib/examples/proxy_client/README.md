# HTTP 代理客户端示例

演示带有代理支持的 HTTP 客户端，包括用于 HTTPS 的 CONNECT 隧道。

## 构建和运行

```bash
cd sample/proxy_client
cjpm build
cjpm run
```

通过环境变量设置代理：`HTTP_PROXY=http://proxy:8080 cjpm run`

## 主要特性

- 支持 HTTP 和 HTTPS 代理
- 用于 HTTPS 目标的 CONNECT 隧道
- 从 HTTP_PROXY、HTTPS_PROXY、NO_PROXY 环境变量自动检测
- 通过 `HttpTransport` 手动配置代理

```cangjie
let transport = HttpTransport()
// transport.proxyUrl = Some("http://proxy.example.com:8080")
```

## 预期输出

示例检查代理环境变量，并通过配置的代理（或未设置代理时直接连接）尝试请求。
