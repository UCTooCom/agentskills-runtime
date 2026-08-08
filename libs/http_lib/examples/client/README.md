# HTTP 客户端示例

演示 `http_lib` 提供的所有 HTTP 客户端方法。

## 构建和运行

```bash
cd sample/client
cjpm build
cjpm run
```

> 注意：需要在 `http://127.0.0.1:8080` 运行一个服务器。可使用 `cd sample/combined && cjpm run` 快速启动测试服务器。

## 主要特性

- GET、POST（JSON/表单/多部分）、PUT、DELETE、PATCH、HEAD、OPTIONS
- 流畅的 `HttpClient` API：`client.get()`、`client.postJson()`、`client.postForm()`
- 通过 `HttpRequestBuilder` 设置自定义头

```cangjie
let client = HttpClient()
demoGet(client, base)
demoPostJson(client, base)
demoPostForm(client, base)
```

## 预期输出

示例向目标服务器发送所有 HTTP 方法的请求，并打印每个响应的状态码和响应体。
