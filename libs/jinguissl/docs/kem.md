# KEM（密钥封装机制）API 参考

## 概述

KEM（Key Encapsulation Mechanism）是后量子密码储备模块。JinguiSSL 当前支持 RSA-KEM 和 ECDH-KEM 的合规检查，主打量子安全 ML-KEM（Kyber）暂无产品路线图。

### contractKemProfile(): ContractKemProfile
返回 KEM 模块配置信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| `available` | Bool | KEM 功能是否可用 |
| `algoHint` | String | 算法提示（如 "ML-KEM / Kyber"） |
| `detail` | String | 详细描述 |

```cangjie
let kem = contractKemProfile()
println("KEM available: ${kem.available}")
println("Algo: ${kem.algoHint}")
```

### contractTryKemProfile(): ContractKemProfileOutcome
非抛出版本。

## 用途说明

KEM 在当前版本中保持为储备能力：
- 主线程证书/签名路径仍使用传统 KEX（X25519、ECDHE）
- ML-KEM 的标准化尚未关闭，产品化时间线待定
- 可通过 `contractKemProfile()` 查询当前可用性状态

## 相关函数

- `rsaKemRequireAllowed()`: 检查 RSA-KEM 是否允许
- `ecdhKemRequireAllowed()`: 检查 ECDH-KEM 是否允许

这些函数在 `jinguissl_core.crypto.kem` 模块中提供。
