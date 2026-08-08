# JinguiSSL Core 使用手册

JinguiSSL Core 是 JinguiSSL 系列的底层密码学库，使用仓颉编程语言编写。
本手册介绍如何集成、配置和使用该库。

## 目录结构

```
docs/
├── README.md              # 本文件 - 目录与快速指引
├── guide/
│   ├── getting-started.md  # 快速上手指南
│   ├── crypto-primitives.md# 密码原语使用说明
│   ├── tls-protocol.md     # TLS 1.2/1.3 协议说明
│   ├── ssh-protocol.md     # SSH 传输层协议说明
│   ├── x509-certificates.md# X.509 证书处理
│   └── compliance.md       # FIPS 合规性
└── api/
    └── modules.md          # 模块 API 参考
```

## 快速链接

- [快速上手](guide/getting-started.md) — 项目集成、构建配置、首个示例
- [密码原语](guide/crypto-primitives.md) — AES、ChaCha20、RSA、ECC、Ed25519、X25519、SM3、SM4
- [TLS 协议](guide/tls-protocol.md) — TLS 1.2 与 TLS 1.3 握手、记录层、会话管理
- [SSH 协议](guide/ssh-protocol.md) — SSH 传输层握手、主机验证、密钥交换
- [X.509 证书](guide/x509-certificates.md) — 证书解析、链验证、PEM/DER
- [合规性](guide/compliance.md) — FIPS 配置、算法许可管理
- [API 参考](api/modules.md) — 所有 public API 索引

## 示例项目

参见 [sample/](../sample/) 目录下的独立示例项目，包含以下场景：

- 对称密码：**AES**, **ChaCha20**, **SM4**
- 摘要与派生：**Digest** (MD5/SHA/HMAC/HKDF), **SM3**
- 非对称密码：**RSA**, **ECC**, **Ed25519**, **X25519**
- 密钥封装：**KEM** (RSA-KEM, ECDH-KEM)
- 大数运算：**BigNum** (大整数算术与模运算)
- 证书合规：**X.509**, **Compliance** (FIPS profile)
- 协议能力：**TLS** (会话票据), **SSH** (主机密钥指纹)
- 工具：**Utils** (端序转换、安全比较、CSPRNG)

每个场景对应一个子目录，包含可编译运行的 CangJie 项目。
