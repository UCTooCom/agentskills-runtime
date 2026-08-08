# SSH 启动捆绑包 API 参考

## 类型

### ContractSshKexExchangeTranscript
KEX 交互记录：`clientBannerLine`, `serverBannerLine`, `clientKexInitPayload`, `serverKexInitPayload`。

### ContractSshNegotiatedAlgorithms
已协商的 SSH 算法：kex、host key、encryption、MAC、compression。

### ContractSshHostVerificationPolicy
主机验证策略：`negotiatedHostKeyAlgorithm`, `expectedHostKeySha256`, `requireKnownHost`, `requireHostSignature`, `requireVerifiedHost`。

## 服务端函数

### contractPrepareSshServerLibraryStartupX25519RsaPkcs8Request(request): ContractSshServerLibraryStartupBundle
使用 RSA PKCS#8 主机密钥的 SSH 服务端启动。

### contractPrepareSshServerLibraryStartupX25519EcdsaPkcs8Request(request): ContractSshServerLibraryStartupBundle
使用 ECDSA PKCS#8 主机密钥的服务端启动。

### contractPrepareSshServerLibraryStartupX25519Ed25519SeedRequest(request): ContractSshServerLibraryStartupBundle
使用 Ed25519 种子密钥的服务端启动。

## 客户端函数

### contractPrepareSshClientLibraryStartupX25519Request(request): ContractSshClientLibraryStartupBundle
X25519 SSH 客户端启动，包含主机验证策略。

### contractTryPrepareSshServerLibraryStartupX25519RsaPkcs8Request(request): ContractSshServerLibraryStartupOutcome
### contractTryPrepareSshClientLibraryStartupX25519Request(request): ContractSshClientLibraryStartupOutcome
安全的错误处理版本。

## 错误处理

使用 `profile` 不匹配时抛出 `UNSUPPORTED`。建议通过 `contractTry*` 变体安全处理。
