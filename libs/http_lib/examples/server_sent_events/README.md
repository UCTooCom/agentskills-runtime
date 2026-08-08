# 服务器推送事件 (SSE)

演示使用分块传输编码向客户端推送事件流，Content-Type 设置为 text/event-stream。

## 使用方法

```bash
cjpm build && ./target/release/bin/main
# 测试: curl -N http://localhost:8090/events
```
