<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-JinguiSSL-c96b2c?style=for-the-badge&labelColor=1f2430" alt="JinguiSSL" />
  <img src="https://img.shields.io/badge/package-static-2f855a?style=for-the-badge&labelColor=1f2430" alt="Static Package" />
  <img src="https://img.shields.io/badge/surface-contract%20first-3182ce?style=for-the-badge&labelColor=1f2430" alt="Contract First" />
  <img src="https://img.shields.io/badge/license-Apache%202.0-1f9d55?style=for-the-badge&labelColor=1f2430" alt="Apache 2.0" />
</p>
<div align="center">
<span style="font-weight:300;font-size:38px">JinguiSSL</span><br/>
<span style="font-weight:100;font-size:24px">面向仓颉应用的密码学、证书、TLS 与 SSH 契约层</span>
<p align="center">
  <strong>先接稳定 facade，再按需下钻到底层实现</strong><br/>
  <sub>Digest · ChaCha20-Poly1305 · X25519 · X.509 · TLS startup material · SSH startup bundle · QUIC</sub>
</p>
</div>

## 为什么是 JinguiSSL

仓颉项目在真正进入网络、安全、证书与协议接入阶段后，最常见的问题不是“有没有算法”，而是：

- 应用层不想直接深挖到底层密码模块
- TLS / X.509 / SSH 的启动材料希望有统一入口
- 上层框架需要稳定一些的错误模型、返回形状与输入约束

`JinguiSSL-contract` 就是为这个场景准备的。
它把常用的密码学、证书、TLS 与 SSH 接口压成更适合应用层消费的 facade，让业务代码优先依赖稳定 contract，而不是直接散落地深 import 各种底层实现。

## 仓库定位

这个仓库是 JinguiSSL 对外最推荐的入口层。

| 仓库 | 角色 | 适合谁 |
|:--|:--|:--|
| `JinguiSSL-contract` | 稳定 facade / contract | 应用、框架、服务接入层 |
| `JinguiSSL-core` | 算法与协议底层 | 需要直接使用密码原语或协议细节的开发者 |
| `JinguiSSL-bridge` | 动态桥接与运行时接入辅助 | 需要动态库、桥接调用、跨层包装的场景 |

如果你只是想把安全能力接进服务，建议先从这个仓库开始。

## 当前分层说明

本仓库**不是纯瘦 facade（thin facade）**。

`src/live/live.cj` 当前包含约 19k 行的活跃编排逻辑，覆盖 TLS / SSH / X.509 / AES 等协议面的启动材料与运行时组合。因此 `JinguiSSL-contract` 当前的实际定位是：

- 对外暴露稳定 facade 接口
- 同时包含非轻量的 live 编排层

没有 `live.cj` 的配合，contract 的许多高层面（TLS startup、SSH bundle、provider orchestration）无法独立运作。后续版本计划对 live 层进行独立的包级重构。在此之前，"stable thin contract facade for all live protocol operations" 是不准确的描述。

如果你需要直接控制 TLS/SSH handshake、record 层或密钥调度，建议回到 `JinguiSSL-core`；如果你需要动态库桥接或运行时接入，建议到 `JinguiSSL-bridge`。

## 当前能力

- Digest / HMAC / HKDF contract：`SHA-256`、`SHA-384`、`SHA-512`、`HMAC`、`HKDF`
- ChaCha20 / Poly1305 contract：流加密、AEAD、RFC 向量测试覆盖
- X25519 contract：key pair、public key derivation、key agreement request/outcome 封装
- X.509 / PEM contract：证书链验证、pin 计算、客户端信任材料准备
- HTTP/TLS startup material：服务端 / 客户端 TLS 输入校验与启动材料整理
- SSH startup bundle：主机验证策略、握手输入整理、库级启动请求封装
- QUIC contract：v1/v2 初始密钥、显式 AEAD 算法、Header Protection、Retry 完整性
- 统一错误口径：`ContractErrorCode`、`ContractException`、Ignite 风格错误映射

## 生产级状态速记

`JinguiSSL-contract` 是当前最推荐的应用接入入口，但它不是对所有密码与协议能力的生产级认证。Digest / HMAC / HKDF、ChaCha20-Poly1305、X25519、证书材料准备、HTTP/TLS 与 SSH startup 表面已有本地测试和稳定 facade；`live.cj` 仍然较厚，TLS/SSH live interop、浏览器级 HTTPS、完整 thin facade、法律认证、安全认证和底层私钥运算恒定时间保证都不从 Contract README 中宣称。

Contract 的安全边界继承 `JinguiSSL-core`：如果 Core 某个私钥路径未完成恒定时间证明，Contract facade 也不能把它升级为已认证的生产级密码后端。

## 快速开始

### 依赖

公开仓库默认使用远程 Git 依赖；本地 sibling checkout 仅建议作为开发时的临时覆盖。

```toml
[dependencies]
jinguissl = { git = "https://gitcode.com/cinyu/jinguiSSL.git" }
```

当前维护线的 `JinguiSSL-contract` 源码采用 `Apache-2.0`，但它依赖当前 `JinguiSSL-core` 源码线，而 Core 采用 `LGPL-3.0-only`。如果你分发包含 Core 的构建产物或组合包，需要同时核对 Core 的许可证要求和本仓库许可证。正式合规判断请以许可证原文和你的发布形态为准。

### 示例：先从 contract 入口拿稳定能力

```cangjie
import jinguissl.contract.*

main() {
    let facade = contractFacadeInfo()
    let digest = contractSha256("hello jingui".toArray())

    println("api=${facade.apiVersion}")
    println(contractBytesToHexLower(digest))
}
```

### 什么时候该继续下钻

下面这些情况，通常说明你应该看 `JinguiSSL-core` 或 `JinguiSSL-bridge`：

- 你需要直接控制 `TLS 1.2 / TLS 1.3` 握手与 record 层
- 你要直接使用 `RSA / ECC / Ed25519 / AES / ChaCha20` 底层原语，或 X25519 scalar multiplication 内部细节
- 你需要动态库桥接、FFI 包装、运行时装配或上层服务桥接

## 常见使用面

### 1. 证书与信任材料

这个仓库提供更偏应用层的证书处理接口，例如：

- `contractComputeLeafPinsFromPem(...)`
- `contractVerifyServerCertificateChainPem(...)`
- `contractPrepareHttpClientTlsTrustMaterial(...)`
- `contractPrepareHttpServerTlsMaterial(...)`

这些 API 适合直接放在 HTTP client/server 启动前做预处理，而不用让上层自己重新拼一套 PEM / chain / pin 逻辑。

### 2. 启动时能力自检

如果你的服务需要在启动阶段确认某类密码能力、硬件能力或消费门禁，这里也已经准备了面向应用层的 facade，例如：

- provider smoke / self-check
- AES backend readiness
- HTTP / SSH startup readiness

## 构建与测试

```bash
cjpm build
cjpm test
```

## 目录结构

```text
JinguiSSL-contract/
├── src/
│   ├── package.cj
│   ├── contract/       # 对外 facade 与 contract
│   ├── live/           # 面向 live 组合的共享实现
│   ├── runtime/        # runtime 兼容与启动表面
│   └── tests/          # contract 级测试
├── examples/           # 完整使用示例
├── benchmark/          # 基准测试
├── testdata/           # 向量、证书与测试素材
├── docs/               # 使用手册
├── scripts/            # 工具脚本
├── .github/
│   └── workflows/      # CI 配置
├── cjpm.toml
└── README.md
```

## 适合什么项目

- 仓颉 Web 服务、网关、客户端 SDK
- 需要把证书、TLS、SSH 启动材料收敛成统一入口的项目
- 希望上层依赖稳定 facade，而不是大面积深 import 密码底层模块的团队

## 许可证

本仓库源码采用 `Apache License 2.0`。详见 `LICENSE`。

依赖边界说明：当前维护线依赖 `JinguiSSL-core`，其源码线采用 `LGPL-3.0-only`。因此本仓库的 Apache 源码许可不取消 Core 依赖在组合分发、静态/动态链接或打包场景中的许可证义务。

## 使用手册与示例

本仓库包含完整的 [使用手册](docs/) 和 [开发示例](examples/)。

### 文档目录 `docs/`

| 文档 | 说明 |
|------|------|
| [overview.md](docs/overview.md) | 项目概览与能力说明 |
| [getting-started.md](docs/getting-started.md) | 快速开始指南 |
| [digest.md](docs/digest.md) | Digest / HMAC / HKDF API 参考 |
| [chacha20-poly1305.md](docs/chacha20-poly1305.md) | ChaCha20 / Poly1305 API 参考 |
| [x25519.md](docs/x25519.md) | X25519 密钥协商 API 参考 |
| [x509-and-http-tls.md](docs/x509-and-http-tls.md) | X.509 证书与 HTTP/TLS API 参考 |
| [aes-readiness.md](docs/aes-readiness.md) | AES 后端探测与引擎选择 API 参考 |
| [ssh.md](docs/ssh.md) | SSH 启动捆绑包 API 参考 |
| [provider-gate.md](docs/provider-gate.md) | 提供商门禁 API 参考 |
| [quic.md](docs/quic.md) | QUIC API 参考 |
| [tls-session-cache.md](docs/tls-session-cache.md) | TLS 会话缓存 API 参考 |
| [error-handling.md](docs/error-handling.md) | 错误处理指南 |
| [ecc-ed25519-rsa.md](docs/ecc-ed25519-rsa.md) | ECC / Ed25519 / RSA 能力包 |
| [china-crypto.md](docs/china-crypto.md) | 国密 SM3/SM4 |
| [kem.md](docs/kem.md) | KEM 密钥封装机制（PQ 储备） |
| [usage-guide.md](docs/usage-guide.md) | 完整使用手册 |

### 示例目录 `examples/`

每个子目录包含一个完整的使用示例：
```
examples/
├── README.md
├── basic/                   基础用法（facade 元数据）
├── digest/                  SHA-256/384/512 摘要、HMAC、HKDF
├── chacha20/                ChaCha20-Poly1305 流加密与 AEAD
├── x25519/                  X25519 密钥协商
├── x509/                    证书链验证与 TLS 信任材料
├── aes/                     AES 硬件探测与引擎解析
├── sm/                      国密 SM3/SM4 能力探测
├── ecc/                     ECC 椭圆曲线能力探测
├── ed25519/                 Ed25519 签名能力探测
├── rsa/                     RSA 能力探测
├── kem/                     KEM 密钥封装机制探测（PQ 储备）
├── hmac-hkdf/               HMAC 消息认证码与 HKDF 密钥派生
├── http_tls/                HTTP/TLS 启动材料验证与整理
├── ssh/                     SSH KEX 启动捆绑包与主机验证
├── quic/                    QUIC 初始密钥派生与 Header Protection
├── provider-gate/           提供商门禁（错误描述、降级决策）
├── tls-session-cache/       TLS 会话缓存（LRU）
├── tls-client/              TLS 客户端 session attach
├── tls-server/              TLS 服务端 session attach
└── contract-application-smoke/  应用级集成冒烟
```

### 测试状态

当前测试覆盖：**282 项**

### 基准测试

以下数据来自非正式环境单轮采样，仅供大致量级参考，不作为性能承诺。实际吞吐与运行环境、工具链版本、负载等因素强相关。

运行方式：

```bash
cd benchmark && cjpm build && cjpm run
```

<sub>* 测试环境: x86_64-unknown-linux-gnu · Cangjie 1.0.5 · 未经当前环境复测 · 仅供参考</sub>
