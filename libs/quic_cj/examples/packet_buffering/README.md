# 包缓冲

演示 QUIC 协议中的包缓冲机制。
包括帧排序、重传队列和缓冲区管理。

## 关键概念

- `FrameSorter` — 帧重排序器，处理乱序到达的帧
- `RetransmissionQueue` — 重传队列，管理需要重传的帧
- `BufferPool` — UDP 缓冲区池管理
- `RingBuffer` — 环形缓冲区实现
- `DatagramQueue` — 数据报队列

## 运行

```bash
cjpm run
```
