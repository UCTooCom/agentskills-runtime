# 常见问题解答（FAQ）

## 基本问题

### 什么是 quic_cj？

quic_cj 是基于仓颉语言实现的 QUIC 传输协议（RFC 9000）。
它提供了客户端和服务端 QUIC 连接的库 API，支持可靠的面向流 I/O、
拥塞控制（CUBIC + NewReno）以及完整的线缆级帧实现。

### QUIC 相比 TCP 有哪些优势？

1. **更低延迟** — 0-RTT 握手（重复连接时）
2. **无队头阻塞** — 一个流的丢包不影响其他流
3. **连接迁移** — 网络切换时连接保持
4. **内置 TLS 1.3** — 默认加密，无法降级
5. **更好的拥塞控制** — CUBIC + NewReno + 调节器

### quic_cj 当前状态如何？

项目处于开发中阶段（100% 完成），已完成：
- 协议编码/解码（v1 和 v2）
- TLS 1.3 集成
- ACK 处理与丢包检测
- CUBIC 拥塞控制
- 流量控制
- 流管理

已完成：核心引擎、UDP 套接字层、qlog、丢包重传、Stateless Reset、NewReno
未开始：HTTP/3 实现、多平台套接字适配

## 使用问题

### quic_cj 稳定吗？

quic_cj 尚处于开发阶段，API 可能会变化。
目前有 619 个测试用例和 81 个基准测试覆盖主要功能模块（36.7% 行覆盖率）。
生产使用请谨慎评估。

### 如何将 quic_cj 添加到我的项目？

在 `cjpm.toml` 中添加依赖：
```toml
[dependencies]
quic_cj = { git = "https://gitcode.com/changeden/quic_cj.git", output-type = "static" }
```

### 如何验证安装成功？

```bash
cjpm build
cjpm test
```
所有测试通过即表示安装成功。

## 技术问题

### QUIC v1 和 v2 有什么区别？

- QUIC v1（RFC 9000）：标准版本
- QUIC v2（RFC 9369）：使用不同的初始盐值（Initial Salt）
- quic_cj 默认同时支持 v1 和 v2

### 可以只使用 QUIC v1 吗？

```cangjie
let cfg = Config()
cfg.versions = [VERSION_1]  // 仅使用 QUIC v1
```

### quic_cj 支持哪些加密套件？

- AES-128-GCM-SHA256（默认优先）
- ChaCha20-Poly1305-SHA256
- AES-256-GCM-SHA384

### 如何实现一个简单的客户端？

```cangjie
import quic_cj.*

main(): Int64 {
    let (conn, ok) = dial("example.com:4433")
    if (!ok) { return 1 }
    let (stream, ok2) = conn.openStream()
    if (!ok2) { return 1 }
    stream.write([0x48u8, 0x69u8])  // "Hi"
    let response = stream.read()
    0
}
```

## 常见错误

### `TransportError: protocol violation`

通常是因为对端发送了不符合协议的数据包。检查 QUIC 版本兼容性。

### `Connection closed before handshake complete`

握手超时或对端拒绝了连接。增加 `handshakeIdleTimeoutMs` 或检查网络连通性。

### `Stream limit exceeded`

并发流数超限。增加 `maxIncomingStreams` 或等待已有流关闭。

## 贡献与支持

- **源码仓库**：https://gitcode.com/changeden/quic_cj
- **许可证**：Apache 2.0
- **报告问题**：通过 GitCode Issues 提交
