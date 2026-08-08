# JinguiSSL Contract 使用手册

JinguiSSL 是面向仓颉（Cangjie）应用的密码学、证书、TLS 与 SSH 契约层。它以稳定 facade 接口为基础，将底层密码模块统一暴露给应用层使用。

## 仓库定位

| 仓库 | 角色 |
|:--|:--|
| `JinguiSSL-contract` | 稳定 facade / contract（本仓库） |
| `JinguiSSL-core` | 算法与协议底层 |
| `JinguiSSL-bridge` | 动态桥接与运行时接入辅助 |

## 当前能力

- **Digest / HMAC / HKDF**：SHA-256/384/512、MD5、SHA-1、HMAC、HKDF
- **ChaCha20 / Poly1305**：流加密、AEAD（RFC 8439）
- **X25519**：密钥对生成、公钥推导、密钥协商
- **X.509 / PEM**：证书链验证、pin 计算、信任材料准备
- **HTTP/TLS 启动材料**：服务端/客户端配置验证
- **SSH 启动捆绑包**：KEX 握手、主机验证策略
- **AES 后端探测**：硬件挂载点、引擎解析、release plan
- **QUIC**：初始密钥派生、Header Protection、Retry 完整性
- **TLS 会话缓存**：有限容量 LRU 缓存
- **提供商门禁（Provider Gate）**：错误描述、降级决策、消费路径

## 构建与测试

```bash
cjpm build
cjpm test
```

## 基准测试

`JinguiSSL-contract` 包含 `benchmark/` 目录用于性能基准测试。

```bash
cd benchmark && cjpm build && cjpm run
```

测试涵盖 SHA-256/384/512 摘要、HMAC-SHA256、HKDF-SHA256、
ChaCha20-Poly1305 加解密、X25519 密钥对生成与密钥协商等操作。
详细结果见 [README](../README.md#基准测试)。

## 许可证

Apache 2.0。依赖的 `JinguiSSL-core` 采用 LGPL-3.0-only。
