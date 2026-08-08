# ECC / Ed25519 / RSA 能力包 API 参考

## ECC（椭圆曲线密码学）

### contractEccCapability(): ContractEccCapability
返回 ECC 模块能力信息，包括可用曲线（P-256、P-384、P-521）、ECDSA/ECDH 可用状态、FIPS 合规曲线。

```cangjie
let ecc = contractEccCapability()
println("Curves: ${ecc.supportedCurves}")
```

### contractTryEccCapability(): ContractEccCapabilityOutcome
非抛出版本的 capability 查询，返回 Outcome 类型。

### contractRequireEccCapability(): ContractEccCapability
要求 ECC 功能可用，不可用时抛出 `CryptoUnavailable`。

---

## Ed25519

### contractEd25519SigningCapability(): ContractEd25519SigningCapability
返回 Ed25519 签名能力：种子长度（32）、公钥长度（32）、签名长度（64）。

```cangjie
let ed = contractEd25519SigningCapability()
println("Seed length: ${ed.seedLen}")
```

### contractTryEd25519SigningCapability(): ContractEd25519SigningCapabilityOutcome
非抛出版本。

### contractRequireEd25519SigningCapability(): ContractEd25519SigningCapability
要求 Ed25519 可用。

---

## RSA

### contractRsaCapability(): ContractRsaCapability
返回 RSA 能力信息：支持的密钥长度、签名方案、哈希算法、FIPS 合规信息。

```cangjie
let rsa = contractRsaCapability()
println("Key sizes: ${rsa.supportedKeySizes}")
```

### contractTryRsaCapability(): ContractRsaCapabilityOutcome
非抛出版本。

### contractRequireRsaCapability(): ContractRsaCapability
要求 RSA 可用。

## DTO 验证规则

所有 Capability DTO 在构造时执行输入验证：
- `detail` 不可为空
- 正数约束（key length、curve count 等）
- Outcome 类型中 `ok = true` 时 `code` 必须为 `None`
