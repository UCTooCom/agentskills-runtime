# 真实 HTTPS API 请求示例

演示使用 `http_lib` 发起真实世界的 HTTPS API 请求。

## 构建和运行

```bash
cd sample/realworld
cjpm build
cjpm run
```

## 主要特性

- HTTPS POST 到 AI 聊天 API（opencode.ai Zen API）
- HTTPS GET 到公开 API（httpbin.org）
- Bearer Token 认证
- 使用 kaca_json 进行 JSON 请求/响应处理
- 响应检查：版本、状态、头、体

```cangjie
let req = HttpRequestBuilder()
    .post()
    .withUrl(url)
    .withHeader("Content-Type", "application/json")
    .withJson(requestBody)
    .build()
client.send(req)
```

## 预期输出

示例进行三次 API 调用：POST 到 Zen API、GET 到 httpbin.org 和 Bearer 认证请求。每个响应的状态、头和体都被打印出来。
