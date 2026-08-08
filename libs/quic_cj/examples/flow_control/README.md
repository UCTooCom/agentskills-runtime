# 流量控制

演示 QUIC 协议的流级别和连接级别流量控制机制。
涵盖窗口更新、自动扩缩和阻塞检测。

## 关键概念

- `StreamFlowController` — 流级别流量控制器
- `ConnectionFlowController` — 连接级别流量控制器
- `BaseFlowController` — 流量控制基类（窗口管理、自动调节）
- 发送窗口与接收窗口的协同
- `isNewlyBlocked` — 阻塞状态检测

## 运行

```bash
cjpm run
```
