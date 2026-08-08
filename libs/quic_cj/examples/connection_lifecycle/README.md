# 连接生命周期

演示 QUIC 连接从创建、握手、数据传输到关闭的完整生命周期。

## 关键概念

- `dial()` / `listen()` — 客户端/服务端入口
- `Conn` — 连接句柄，管理连接状态
- `openStream()` / `acceptStream()` — 流的创建与接受
- `closeWithError()` — 带错误码的连接关闭
- `getConnState()` — 获取连接状态信息

## 运行

```bash
cjpm run
```
