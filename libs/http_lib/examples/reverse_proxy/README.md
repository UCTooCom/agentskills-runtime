# 反向代理服务器示例

演示将 HTTP 请求转发到后端服务的反向代理服务器。

## 构建和运行

```bash
cd sample/reverse_proxy
cjpm build
cjpm run
```

测试：`curl http://127.0.0.1:8888/api/users`

## 主要特性

- 基于路径的路由到多个后端
- 头部转发：X-Forwarded-For、X-Forwarded-Host、X-Forwarded-Proto
- 逐跳头部移除
- 后端错误处理，返回 502 Bad Gateway
- 通过 `addRoute()` 配置路由

```cangjie
addRoute("/api/", "http://127.0.0.1:8080")
addRoute("/static/", "http://127.0.0.1:8081")
// 代理处理器构建新请求、转发头部、发送到后端
builder.withUrl(targetUrl)
builder.withHeader("X-Forwarded-For", ip)
```

## 预期输出

服务器在 8888 端口启动。对 /api/* 的请求代理到后端 1，/static/* 和 /files/* 代理到后端 2。/status 端点显示配置的路由。
