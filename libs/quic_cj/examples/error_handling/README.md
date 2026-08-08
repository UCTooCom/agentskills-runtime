# 错误处理

演示 QUIC 协议的传输层和应用层错误处理机制。
涵盖 QError 类型体系、错误码和错误传播。

## 关键概念

- `QError` — 统一的错误类型
- `ApplicationError` — 应用层错误
- `StreamError` — 流级别错误
- `DatagramTooLargeError` — 数据报超限错误
- `newTransportError()` / `newApplicationError()` — 工厂函数
- `TransportErrorCode` — 传输层错误码

## 运行

```bash
cjpm run
```
