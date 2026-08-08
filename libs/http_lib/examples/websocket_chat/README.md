# WebSocket 聊天

演示使用 ConnectionConnectionHijacker API 进行基于 HTTP Upgrade 的 WebSocket 握手（RFC 6455）。服务器响应 101 Switching Protocols 以进行双向通信。

## 使用方法

```bash
cjpm build
./target/release/bin/main
# 测试: 使用 WebSocket 客户端连接 ws://localhost:8080/chat
```
