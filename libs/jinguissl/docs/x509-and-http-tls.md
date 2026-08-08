# X.509 与 HTTP/TLS API 参考

## X.509 证书验证

### contractParseX509CertificateFromPem(pem: String): ContractX509Certificate
解析单个 PEM 证书。

### contractVerifyServerCertificatePem(leafPem, trustAnchorsPem, intermediatesPemBundle?, hostname?, validationTime?, pinPolicy?): ContractX509VerifyResult
验证服务端叶子证书。返回验证结果，失败抛出异常。

### contractVerifyServerCertificateChainPem(chainPem, trustAnchorsPem, ...): ContractX509VerifyResult
验证完整证书链。

### contractComputeLeafPinsFromPem(pem: String): (derSha256: Array<Byte>, spkiSha256: Array<Byte>)
计算叶子证书指纹（DER 与 SPKI）。

## HTTP/TLS 服务端

### contractValidateHttpServerTlsConfigInput(certChainPem, privateKeyPem, alpnProtocols, requireHttp2Alpn): ContractHttpServerTlsConfigValidationResult
验证 TLS 配置：证书链、私钥匹配、ALPN 标准化。

### contractPrepareHttpServerTlsMaterial(request): ContractHttpServerTlsMaterial
准备服务端 TLS 启动材料。

### contractTryValidateHttpServerTlsConfigInput(...): ContractHttpServerTlsConfigValidationOutcome
安全的验证版本，返回 Outcome。

## HTTP/TLS 客户端

### contractValidateHttpClientTlsConfigInput(trustAnchorsPem, intermediatesPemBundle, hostname, validationTime, pinPolicy, policy): ContractHttpClientTlsConfigValidationResult
验证客户端 TLS 配置。

### contractPrepareHttpClientTlsTrustMaterial(request): ContractHttpClientTlsTrustMaterial
准备客户端信任材料。

### contractTryValidateHttpClientTlsConfigInput(...): ContractHttpClientTlsConfigValidationOutcome
安全的验证版本，返回 Outcome。

## 错误码

- `VERIFY_FAILED`：证书验证失败、公钥不匹配
- `BAD_INPUT`：输入参数无效
- `COMPLIANCE_REJECTED`：合规检查未通过
