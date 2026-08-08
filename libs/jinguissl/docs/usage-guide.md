# JinguiSSL Contract 使用手册

## 目录

1. [概述](#1-概述)
2. [依赖集成](#2-依赖集成)
3. [快速开始](#3-快速开始)
4. [核心模块](#4-核心模块)
5. [错误处理模式](#5-错误处理模式)
6. [Outcome 模式](#6-outcome-模式)
7. [构建与测试](#7-构建与测试)
8. [常见问题](#8-常见问题)

## 1. 概述

JinguiSSL 是面向仓颉（Cangjie）应用的密码学、证书、TLS 与 SSH 契约层。仓库定位：

| 仓库 | 角色 |
|------|------|
| JinguiSSL-contract | 稳定 facade / contract（本仓库） |
| JinguiSSL-core | 算法与协议底层 |
| JinguiSSL-bridge | 动态桥接与运行时接入辅助 |

### 当前能力矩阵

| 领域 | API 集合 | 状态 |
|------|----------|------|
| Digest / HMAC / HKDF | SHA-256/384/512, MD5, SHA-1, HMAC, HKDF | Stable |
| ChaCha20 / Poly1305 | 流加密、AEAD (RFC 8439) | Stable |
| X25519 | 密钥对生成、公钥推导、密钥协商 | Stable |
| X.509 / PEM | 证书链验证、pin 计算、信任材料 | Stable |
| HTTP/TLS 启动材料 | 服务端/客户端配置验证 | Stable |
| SSH 启动捆绑包 | KEX 握手、主机验证策略 | Stable |
| AES 后端探测 | 硬件挂载点、引擎解析、release plan | Stable |
| QUIC | 初始密钥派生、Header Protection、Retry | Stable |
| TLS 会话缓存 | 有限容量 LRU 缓存 | Stable |
| 提供商门禁 | 错误描述、降级决策、消费路径 | Stable |
| ECC / Ed25519 / RSA | 能力包探测 | Stable |
| 国密 SM3 / SM4 | 能力包探测 | Stable |
| KEM | 密钥封装机制（储备） | Experimental |

## 2. 依赖集成

### cjpm.toml

```toml
[dependencies]
jinguissl = { git = "https://gitcode.com/cinyu/jinguiSSL.git" }
```

### import 方式

```cangjie
// 导入全部 contract 类型和函数
import jinguissl.contract.*

// 导入 live 层（TLS 握手、SSH 运行时等）
import jinguissl.live.*

// 按需导入 core 层（仅当直接使用底层算法时）
import jinguissl_core.crypto.digest.{sha256, bytesToHexLower}
```

## 3. 快速开始

### SHA-256 摘要

```cangjie
import jinguissl.contract.*

main() {
    let data = "hello jingui".toArray()
    let digest = contractSha256(data)
    println(contractBytesToHexLower(digest))
}
```

### X25519 密钥协商

```cangjie
import jinguissl.contract.*

main() {
    let alice = contractX25519GenerateKeyPair()
    let bob = contractX25519GenerateKeyPair()

    let shared1 = contractX25519DeriveKeyAgreement(alice.privateKey, bob.publicKey)
    let shared2 = contractX25519DeriveKeyAgreement(bob.privateKey, alice.publicKey)
    println("Match: ${shared1.sharedSecret == shared2.sharedSecret}")
}
```

### 证书链验证

```cangjie
import jinguissl.contract.*

main() {
    let result = contractVerifyServerCertificateChainPem(
        chainPem, rootPem, hostname: "example.com"
    )
    println("Chain: ${result.chainLength}, anchor: ${result.trustAnchorCommonName}")
}
```

## 4. 核心模块

参考各模块的独立文档：

| 文档 | 说明 |
|------|------|
| [getting-started.md](getting-started.md) | 快速开始 + 完整示例 |
| [overview.md](overview.md) | 项目总览 |
| [digest.md](digest.md) | Digest / HMAC / HKDF |
| [chacha20-poly1305.md](chacha20-poly1305.md) | ChaCha20 / Poly1305 AEAD |
| [x25519.md](x25519.md) | X25519 密钥协商 |
| [x509-and-http-tls.md](x509-and-http-tls.md) | X.509 证书 / HTTP/TLS |
| [ssh.md](ssh.md) | SSH 启动捆绑包 |
| [quic.md](quic.md) | QUIC 初始密钥派生 |
| [aes-readiness.md](aes-readiness.md) | AES 后端探测 |
| [tls-session-cache.md](tls-session-cache.md) | TLS 会话缓存 |
| [provider-gate.md](provider-gate.md) | 提供商门禁 |
| [error-handling.md](error-handling.md) | 错误处理模型 |
| [ecc-ed25519-rsa.md](ecc-ed25519-rsa.md) | ECC / Ed25519 / RSA |
| [china-crypto.md](china-crypto.md) | 国密 SM3 / SM4 |
| [kem.md](kem.md) | KEM 密钥封装机制 |

## 5. 错误处理模式

JinguiSSL 使用分层错误模型：

```
ContractException
  └── code: ContractErrorCode
  └── message: String
```

捕获方式：

```cangjie
try {
    let result = contractRequireAesAcceleratedBackend()
} catch (e: ContractException) {
    println("Error: ${e.code.toString()} — ${e.message}")
}
```

`ContractErrorCode` 包括：`BadInput`, `KeyNotFound`, `VerifyFailed`, `CryptoUnavailable`, `ComplianceRejected`, `Unsupported`, `InternalError`。

详细文档：[error-handling.md](error-handling.md)

## 6. Outcome 模式

JinguiSSL 为关键操作提供了 `try-` 前缀的非抛出变体，返回 `Outcome` 类型：

```cangjie
let outcome = contractTryX25519DeriveKeyAgreement(alicePriv, bobPub)
if (outcome.ok) {
    let result = outcome.result  // ?ContractX25519KeyAgreementResult
} else {
    let code = outcome.code      // ?ContractErrorCode
}
```

所有 Outcome 类型共有的字段：
- `ok: Bool` — 操作是否成功
- `message: String` — 描述信息
- `code: ?ContractErrorCode` — 错误码（成功时为 None）
- `igniteCode: ?ContractIgniteCryptoErrorCode` — Ignite 框架错误码
- `result: ?ResultType` — 成功时的结果（类型因操作而异）

## 7. 构建与测试

```bash
# 构建
cjpm build

# 运行所有测试
cjpm test

# 运行示例（详见 sample/ 目录）
cd sample/<scenario>
cjpm run

# 基准测试
cd benchmark
cjpm build
cjpm run
```

## 8. 常见问题

### Q: contract 和 live 有什么区别？
A: `contract` 包（jinguissl.contract.\*）提供纯 API facade、DTO 定义和依赖轻量的探测功能，不依赖运行时 TLS/SSH 握手实现。`live` 包（jinguissl.live.\*）包含完整的握手实现和运行时状态管理，依赖更重。一般场景优先使用 `contract.*`。

### Q: AES 硬件加速如何启用？
A: 通过 `contractAesProbeHardware()` 探测硬件支持，使用 `contractResolveAesEngine(requestedEngine: Hardware)` 请求硬件加速引擎。不满足时自动回退到软件实现。

### Q: 如何为生产环境配置 JinguiSSL？
A: 使用 `contractRequireHttpSshStartupReadiness(ContractHttpSshStartupProfile.ProductionAccelerated)` 确保所有生产所需功能就绪，包括 AES 硬件加速。

### Q: Outcome 模式有什么好处？
A: 避免 try/catch 控制流，将错误作为值显式传递，更适合组合式调用和异步编程模式。
