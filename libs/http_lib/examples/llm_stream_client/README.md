# LLM 流式客户端

演示使用 `HttpResponse.readLine()` 消费 LLM API 的 Server-Sent Events (SSE) 流式响应。

展示如何：
- 发送流式聊天补全请求
- 逐行处理每个 SSE `data:` 事件
- 从流中解析 JSON delta 内容

## 使用方法

```bash
cjpm build && ./target/release/bin/main
```

修改 `src/main.cj` 中的 `apiUrl` 和 `apiKey` 以使用真实的 API 端点。
