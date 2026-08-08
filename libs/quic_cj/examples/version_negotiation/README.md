# 版本协商

演示 QUIC 协议的版本协商机制（RFC 9000 §6）。
涵盖版本有效性检查、版本选择、版本协商包组合与解析。

## 关键概念

- `VERSION_1` / `VERSION_2` — QUIC v1 和 v2 版本常量
- `isValidVersion()` — 版本有效性检查
- `chooseSupportedVersion()` — 版本匹配选择
- `composeVersionNegotiation()` — 构造版本协商包
- `parseVersionNegotiationPacket()` — 解析版本协商包
- `isVersionNegotiationPacket()` — 版本协商包识别

## 运行

```bash
cjpm run
```
