<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-JinguiSSL%20Core-c96b2c?style=for-the-badge&labelColor=1f2430" alt="JinguiSSL Core" />
  <img src="https://img.shields.io/badge/package-static-2f855a?style=for-the-badge&labelColor=1f2430" alt="Static Package" />
  <img src="https://img.shields.io/badge/focus-crypto%20%2B%20protocol-3182ce?style=for-the-badge&labelColor=1f2430" alt="Crypto and Protocol" />
  <img src="https://img.shields.io/badge/license-LGPL--3.0--only-1f9d55?style=for-the-badge&labelColor=1f2430" alt="LGPL-3.0-only" />
</p>
<div align="center">
<span style="font-weight:300;font-size:36px">JinguiSSL Core</span><br/>
<span style="font-weight:100;font-size:24px">JinguiSSL 的算法与协议底层实现</span>
<p align="center">
  <strong>面向需要直接控制密码原语、X.509、TLS 与 SSH 细节的仓颉开发者</strong><br/>
  <sub>AES · ChaCha20-Poly1305 · RSA · ECC · Ed25519 · X25519 · X.509 · TLS · SSH</sub>
</p>
</div>

## 这是什么

`JinguiSSL-core` 是 JinguiSSL 系列的底层仓。

如果 `JinguiSSL-contract` 解决的是“应用层怎么稳定地接入安全能力”，那 `JinguiSSL-core` 解决的就是：

- 算法原语怎么实现
- 证书链、TLS、SSH 等协议细节怎么落地
- 更底层、更直接的密码学 API 如何在仓颉里组织

如果你需要自己掌控协议流、握手细节、密钥派生、record 层或结构化签名校验，这里才是主战场。

## 能力范围

- 对称密码：`AES`、`ChaCha20`、`Poly1305`、`SM4`
- 摘要与派生：`MD5`、`SHA-1`、`SHA-256/384/512`、`HMAC`、`HKDF`
- 非对称密码：`RSA`、`ECC`、`Ed25519`、`X25519`
- 证书与合规：`X.509`、PEM/DER 解析、证书链验证、FIPS profile
- 协议能力：`TLS 1.2`、`TLS 1.3`、`SSH transport / handshake`
- 工具与性能：大数兼容层、性能基准、测试向量与协议流测试

### TLS 1.3 当前边界

`crypto/tls` 当前覆盖的 TLS 1.3 cipher suite 包括：

- `TLS_AES_128_GCM_SHA256`
- `TLS_AES_256_GCM_SHA384`
- `TLS_CHACHA20_POLY1305_SHA256`

HTTP X25519 ClientHello 会优先携带 `TLS_AES_256_GCM_SHA384`。当前不声明 `X25519MLKEM768` key share 支持，也不把本地握手/record 测试等同于浏览器、OpenSSL 或 curl 线上互通成功。

### 关于 RC4

`RC4` 不属于当前适配主线。JinguiSSL-core 当前聚焦现代密码与协议能力，例如 `AES`、`ChaCha20-Poly1305`、`ECC`、`X25519`、`X.509`、`TLS 1.2/1.3` 与 `SSH`。

RC4 已不适合作为现代 TLS / HTTPS 的默认兼容方向；如果未来确有历史系统互通需求，应作为单独的 legacy compatibility 线路评估，而不是并入长期维护主线。

## 快速开始

### 依赖

公开仓库默认使用远程 Git 依赖；本地 sibling checkout 仅建议作为开发时的临时覆盖。

```toml
[dependencies]
jinguissl_core = { git = "https://gitcode.com/CjKu/JinguiCore.git" }
```

### 示例：Ed25519 签名与验签

```cangjie
import jinguissl_core.crypto.digest.bytesToHexLower
import jinguissl_core.crypto.ed25519.*

main() {
    let seed = ed25519GeneratePrivateKeySeed()
    let publicKey = ed25519PublicKeyFromSeed(seed)
    let message = "hello jingui".toArray()
    let signature = ed25519Sign(seed, message)

    println(bytesToHexLower(publicKey))
    println(ed25519Verify(publicKey, message, signature))
}
```

## 模块分层

| 模块 | 内容 |
|:--|:--|
| `crypto/aes` | AES block / CTR / GCM 相关实现 |
| `crypto/chacha20` | ChaCha20 / Poly1305 / AEAD |
| `crypto/digest` | Hash、HMAC、HKDF |
| `crypto/rsa` / `crypto/ecc` / `crypto/ed25519` / `crypto/x25519` | 主流非对称能力 |
| `crypto/x509` | 证书、私钥、链验证 |
| `crypto/tls` | TLS handshake、record、session |
| `crypto/ssh` | SSH transport、host verification、KEX |
| `compat/bn` | 大数兼容与基础支持 |

## 系统证书信任材料

`JinguiSSL-core` 当前会处理一部分系统证书路径，但不是“全平台原生信任库自动接管”。

- Linux / OpenHarmony 同内核目标：通过常见 PEM bundle 候选路径加载信任锚，并支持调用方额外传入 PEM bundle 路径。
- macOS：通过常见 PEM bundle 候选路径加载信任锚，并支持调用方额外传入 PEM bundle 路径；当前不声明原生 Keychain 集成。
- Windows：当前不声明原生 Root Store 枚举；调用方可以传入导出的 PEM bundle 路径。
- HarmonyOS：当前按 Linux aarch64 代理证明只能称为准支持，真实设备信任材料验证完成前不声明正式支持。

如果你需要在应用层创建系统信任策略，可以使用：

```cangjie
import jinguissl_core.crypto.x509.{x509CreateSystemTrustPolicy, x509SystemTrustMaterialSupportKind}

main() {
    println(x509SystemTrustMaterialSupportKind())
    let policy = x509CreateSystemTrustPolicy(extraPemBundlePaths: ["./roots.pem"])
    println(policy.trustAnchors.size)
}
```

## 什么时候该直接使用 Core

- 你在写 TLS / SSH / PKI 相关中间层或框架
- 你要自己组织 handshake / record / transcript / key schedule
- 你需要原始算法能力，而不是应用层 facade
- 你在写 benchmark、协议实验、兼容层或桥接层

如果你只是想把 TLS / 证书能力接进业务服务，通常更推荐先从 `JinguiSSL-contract` 开始。

## 构建与测试

```bash
cjpm build
cjpm test
```

## 目录结构

```text
JinguiSSL-core/
├── src/jinguissl_core/
│   ├── compat/
│   ├── crypto/
│   └── tests/
├── testdata/
├── .github/workflows/ci.yml
├── cjpm.toml
└── README.md
```

## 当前定位

这是一个偏库级、偏底层的仓库。  
它适合作为：

- 上层 contract/facade 的实现基础
- 框架或中间件的密码与协议功能底座
- 仓颉生态里可复用的协议与密码能力参考实现

## 安全姿态说明

### 当前已知限制

本仓库的私钥密码操作**尚未通过恒定时间（constant-time）安全认证**。以下路径当前依赖可变时间（variable-time）算术与分支逻辑：

- ECDSA 签名（nonce 标量乘法、模逆运算）
- ECDH 共享秘密协商
- RSA 签名与私钥解密（modPow 底层委托）
- Ed25519 签名与标量运算
- X25519 密钥交换

这些路径在现有向量测试与协议流测试覆盖下可以通过，但**不应被视为具备侧信道攻击抗性**。

### 当前可宣称的定位

本仓库在当前发布阶段可诚实宣称：

- **功能性密码学与协议实现** — 验证算法与协议在仓颉生态中的可落地性
- **实验性密码底座** — 可被上层框架或中间件引用，但尚未完成生产级侧信道加固
- **审计与测试靶面** — 欢迎社区审计与贡献，但暂不自称"生产级密码学后端"或"OpenSSL 替代"

所有公开发布的代码适用于评估、实验与集成验证场景。不推荐直接用于需要侧信道防护的生产环境。

## 许可证

当前源码线采用 `LGPL-3.0-only`。详见 `LICENSE`。

自本许可切换版本起，JinguiSSL Core 的后续维护、安全修复、兼容适配、协议演进与项目责任边界，均以当前 `LGPL-3.0-only` 源码线为准。

历史上已经以 `Apache-2.0` 发布的版本，其既有授权继续有效；本项目不撤回已发布版本的既有授权。但这些历史发布版本属于旧发布线，不再代表当前 JinguiSSL Core 的维护状态、安全状态或兼容性承诺。

继续使用历史 `Apache-2.0` 发布线的代码，视为使用旧版本代码；JinguiSSL Core 当前维护线不对旧发布线提供维护承诺、安全修复承诺、兼容适配承诺或生产可用性保证。
