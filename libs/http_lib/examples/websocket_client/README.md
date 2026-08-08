# WebSocket 客户端

演示使用 HTTP Upgrade 握手（RFC 6455）连接 WebSocket 服务器。
发送 Sec-WebSocket-Key 并验证 Sec-WebSocket-Accept 响应。

## 使用方法

```bash
# 终端 1: 启动 WebSocket 服务器
cd ../websocket_chat && cjpm build && ./target/release/bin/main

# 终端 2: 运行 WebSocket 客户端
cd ../websocket_client && cjpm build && ./target/release/bin/main
```
