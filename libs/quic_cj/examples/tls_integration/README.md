# TLS 集成

演示 QUIC 中 TLS 1.3 的集成细节。
涵盖初始 AEAD 密钥派生、包头保护、密码套件选择和 TLS 配置。

## 关键概念

- `newInitialAEAD()` / `newInitialAEADV2()` — QUIC v1/v2 初始 AEAD
- `AesHeaderProtector` / `ChaChaHeaderProtector` — 包头保护
- `CipherSuite` — 密码套件（AES-128-GCM、ChaCha20-Poly1305）
- `selectCipherSuite()` — 密码套件协商
- `TlsConfig` / `defaultTlsConfig()` — TLS 配置

## 运行

```bash
cjpm run
```
