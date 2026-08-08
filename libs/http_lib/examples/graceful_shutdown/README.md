# 优雅关闭示例

演示 HTTP 服务器的优雅关闭，等待正在处理的请求完成后再退出。

## 构建和运行

```bash
cd sample/graceful_shutdown
cjpm build
cjpm run
```

## 主要特性

- `server.shutdown()` — 停止接受新连接，等待活跃请求完成
- `server.close()` — 立即强制关闭
- 模拟慢端点以演示优雅关闭行为
- 可配置的读取超时

## 预期输出

示例解释关闭 API。在实际部署中，会在收到操作系统信号（SIGINT/SIGTERM）时调用 `shutdown()`。
