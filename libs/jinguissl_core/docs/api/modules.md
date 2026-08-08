# API 模块参考

## `jinguissl_core.compat.bn`

大数兼容层（OpenSSL BN 风格）。

| API | 说明 |
|:--|:--|
| `BN` | 大数类型 |
| `BN_new()` | 创建新 BN |
| `BN_bin2bin(bn)` | BN → 字节数组 |
| `BN_bin2bn(input)` | 字节数组 → BN |
| `BN_add(a, b)` | 加法 |
| `BN_sub(a, b)` | 减法 |
| `BN_mul(a, b)` | 乘法 |
| `BN_div(a, b)` | 除法 |
| `BN_mod(a, m)` | 模运算 |
| `BN_exp(a, e)` | 幂运算 |
| `BN_mod_exp(a, e, m)` | 模幂 |
| `BN_mod_inverse(a, m)` | 模逆 |
| `BN_lshift(a, bits)` | 左移 |
| `BN_rshift(a, bits)` | 右移 |

## `jinguissl_core.crypto.base`

基础类型和实用工具。

| API | 说明 |
|:--|:--|
| `Endian` | 字节序枚举 |
| `SecureBytes` | 安全字节容器，支持 clear/destroy |
| `ByteBuffer` | 动态字节缓冲区 |

## `jinguissl_core.crypto.bignum`

大数实现（BigNum 类）。

```cangjie
class BigNum <: Equatable<BigNum> & ToString
```

### BigNum 方法

```cangjie
BigNum.fromHex(hex)  // 从十六进制字符串创建
BigNum.fromBytesBE(bytes)  // 从大端字节数组创建
BigNum.zero()  // 0
BigNum.one()   // 1
bn.toBytesBE(paddedLen)  // 转为大端字节数组
bn.mod(other)  // 模运算
bn.exp(exponent)  // 幂运算
bn.modExp(exponent, modulus)  // 模幂
bn.modInverse(modulus)  // 模逆
bn.lshift(bits)  // 左移
bn.rshift(bits)  // 右移
bn.divMod(other)  // 除法与模
bn.toBigInt()  // 转 BigInt (std.math.numeric)
```

## `jinguissl_core.crypto.error`

异常类型。

| API | 说明 |
|:--|:--|
| `CryptoException` | 密码学异常 |
| `CryptoErrorCode` | 错误码枚举 |
| `CryptoErrorCode.InvalidArgument` | 非法参数 |
| `CryptoErrorCode.OutOfBounds` | 越界 |
| `CryptoErrorCode.DivideByZero` | 除以零 |
| `CryptoErrorCode.NoModInverse` | 模逆不存在 |
| `CryptoErrorCode.ComplianceRejected` | 合规拒绝 |
| `CryptoErrorCode.ParseError` | 解析错误 |
| `CryptoErrorCode.Unsupported` | 不支持的操作 |
| `CryptoErrorCode.InternalError` | 内部错误 |

## `jinguissl_core.crypto.utils`

工具函数。

| API | 说明 |
|:--|:--|
| `bytesToUInt32BE(bytes, offset!)` | 大端字节 → UInt32 |
| `bytesToUInt32LE(bytes, offset!)` | 小端字节 → UInt32 |
| `uInt32ToBytesBE(value)` | UInt32 → 大端字节 |
| `uInt32ToBytesLE(value)` | UInt32 → 小端字节 |
| `constantTimeEquals(left, right)` | 恒定时间比较 |
| `secureCopy(source)` | 安全拷贝 |
| `secureCopyInto(source, dest, dstOffset!)` | 安全拷贝到指定位置 |
| `secureZero(bytes)` | 安全清零 |
| `randomSeed(size!)` | 生成随机种子 |
| `csprngIsAvailable()` | 查询 CSPRNG 是否可用 |
| `csprngBytes(size)` | 从 CSPRNG 获取随机字节 |

## `jinguissl_core.crypto.digest`

摘要算法。

| API | 说明 |
|:--|:--|
| `HashAlgorithm` | 哈希算法枚举 |
| `md5(data)` | MD5 哈希（遗留） |
| `sha1(data)` | SHA-1 哈希（遗留） |
| `sha256(data)` | SHA-256 哈希 |
| `sha384(data)` | SHA-384 哈希 |
| `sha512(data)` | SHA-512 哈希 |
| `hash(algorithm, data)` | 通用哈希 |
| `hmac(algorithm, key, data)` | HMAC |
| `hkdf(algorithm, ikm, salt, info, length)` | HKDF |
| `hkdfExtract(algorithm, ikm, salt)` | HKDF 提取 |
| `hkdfExpand(algorithm, prk, info, length)` | HKDF 扩展 |
| `bytesToHexLower(bytes)` | 字节数组 → 小写十六进制 |

## `jinguissl_core.crypto.aes`

AES 加密。

| API | 说明 |
|:--|:--|
| `AesMode` | 加密模式枚举 |
| `AesEngineKind` | 引擎类型 |
| `AesEngine` | AES 引擎 |
| `AesKeySchedule` | 密钥调度 |
| `AesGcmContext` | GCM 上下文 |
| `aesBlockEncrypt(key, block)` | 单块加密 |
| `aesBlockDecrypt(key, block)` | 单块解密 |
| `aesEcbEncrypt(key, plaintext, pkcs7!)` | ECB 加密 |
| `aesEcbDecrypt(key, ciphertext, pkcs7!)` | ECB 解密 |
| `aesCbcEncrypt(key, iv, plaintext)` | CBC 加密 |
| `aesCbcDecrypt(key, iv, ciphertext)` | CBC 解密 |
| `aesCtrCrypt(key, counterBlock, input)` | CTR 模式 |
| `aesGcmEncrypt(key, nonce, plaintext, aad)` | GCM 加密 |
| `aesGcmDecrypt(key, nonce, ciphertext, aad, tag)` | GCM 解密 |
| `aesNewGcmContext(key)` | 创建 GCM 上下文 |
| `aesGcmEncryptWithContext(ctx, ...)` | 使用上下文的 GCM 加密 |
| `aesGcmDecryptWithContext(ctx, ...)` | 使用上下文的 GCM 解密 |
| `pkcs7Pad(input, blockSize!)` | PKCS7 填充 |
| `pkcs7Unpad(input, blockSize!)` | PKCS7 去填充 |

所有 GCM 函数都有对应的 `Checked` 变体（参数校验更严格）和 `Into` 变体（写入到输出缓冲区）。

## `jinguissl_core.crypto.chacha20`

ChaCha20 / Poly1305。

| API | 说明 |
|:--|:--|
| `Chacha20Poly1305Context` | ChaCha20-Poly1305 上下文 |
| `chacha20Block(key, counter, nonce)` | 生成 ChaCha20 块 |
| `chacha20Xor(key, counter, nonce, input)` | ChaCha20 XOR 加密 |
| `chacha20Poly1305Encrypt(key, nonce, plaintext, aad)` | AEAD 加密 |
| `chacha20Poly1305Decrypt(key, nonce, ciphertext, aad, tag)` | AEAD 解密 |
| `chacha20Poly1305NewContext(key)` | 创建上下文 |
| `poly1305Mac(key, message)` | Poly1305 MAC |

## `jinguissl_core.crypto.rsa`

RSA 签名。

| API | 说明 |
|:--|:--|
| `RsaPrivateKey` | RSA 私钥 |
| `RsaPublicKey` | RSA 公钥 |
| `RsaHashAlgorithm` | 哈希算法枚举 |
| `RsaSignatureScheme` | 签名方案枚举 |
| `rsaGenerateKey(bits)` | 密钥生成 |
| `rsaPublicKeyFromHex(modulusHex, exponentHex)` | 从十六进制加载公钥 |
| `rsaPrivateKeyFromHex(modulusHex, exponentHex, privateExponentHex)` | 从十六进制加载私钥 |
| `rsaSignPkcs1v15(key, digest)` | PKCS1v1.5 签名 |
| `rsaVerifyPkcs1v15(key, digest, signature)` | PKCS1v1.5 验签 |
| `rsaSignPkcs1v15WithHash(key, hashAlg, message)` | 含哈希标识的 PKCS1v1.5 签名 |
| `rsaSignPss(key, digest, saltLen!)` | PSS 签名 |
| `rsaVerifyPss(key, digest, signature, saltLen!)` | PSS 验签 |
| `rsaValidateKeyParameters(bits, publicExponent)` | 密钥参数校验 |

## `jinguissl_core.crypto.ecc`

椭圆曲线密码学。

| API | 说明 |
|:--|:--|
| `NamedCurve` | 命名曲线枚举 |
| `EcPrivateKey` | EC 私钥 |
| `EcPublicKey` | EC 公钥 |
| `namedCurveFromText(name)` | 文本 → NamedCurve |
| `isFipsCurve(curve)` | 是否为 FIPS 曲线 |
| `requireFipsCurve(curve)` | 非 FIPS 时抛出异常 |
| `ecPublicFromPrivateKey(key)` | 从私钥派生公钥 |
| `ecdsaSign(key, digest)` | ECDSA 签名 |
| `ecdsaVerify(key, digest, r, s)` | ECDSA 验签 |
| `ecdhDeriveSharedSecret(key, peerKey)` | ECDH 密钥协商 |

### 结构化验证

| API | 说明 |
|:--|:--|
| `Es256P256StructuredVerifyRequest` | 结构化验证请求 |
| `Es256P256StructuredVerifyOutcome` | 结构化验证结果 |
| `es256P256VerifyStructuredRequest(request)` | 执行结构化验证 |
| `tryEs256P256VerifyStructuredRequest(request)` | 尝试结构化验证 |

## `jinguissl_core.crypto.ed25519`

Ed25519 签名。

| API | 说明 |
|:--|:--|
| `ed25519GeneratePrivateKeySeed()` | 生成私钥种子 |
| `ed25519PublicKeyFromSeed(seed)` | 从种子派生公钥 |
| `ed25519Sign(seed, message)` | 签名 |
| `ed25519Verify(publicKey, message, signature)` | 验签 |

## `jinguissl_core.crypto.x25519`

X25519 密钥协商。

| API | 说明 |
|:--|:--|
| `x25519GeneratePrivateKey()` | 生成私钥 |
| `x25519ClampPrivateKey(key)` | 钳制私钥 |
| `x25519PublicFromPrivate(key)` | 从私钥派生公钥 |
| `x25519DeriveSharedSecret(privKey, peerPubKey)` | 派生共享密钥 |
| `x25519ScalarMult(privKey, uCoord)` | 标量乘法 |
| `x25519ValidatePublicKey(pubKey)` | 验证公钥 |

## `jinguissl_core.crypto.sm3`

SM3 哈希（GM/T 0004-2012）。

| API | 说明 |
|:--|:--|
| `sm3(data)` | SM3 哈希，返回 32 字节 |

## `jinguissl_core.crypto.sm4`

SM4 分组密码（GM/T 0002-2012）。

| API | 说明 |
|:--|:--|
| `sm4Encrypt(key, data)` | SM4 ECB 加密 |
| `sm4Decrypt(key, data)` | SM4 ECB 解密 |

## `jinguissl_core.crypto.kem`

密钥封装机制。

| API | 说明 |
|:--|:--|
| `ecdhKemEncapsulate(pubKey)` | ECDH-KEM 封装 |
| `ecdhKemDecapsulate(ciphertext, privKey)` | ECDH-KEM 解封装 |
| `rsaKemEncapsulate(pubKey)` | RSA-KEM 封装 |
| `rsaKemDecapsulate(ciphertext, privKey)` | RSA-KEM 解封装 |

## `jinguissl_core.crypto.x509`

X.509 证书处理（参见 x509 指南文档获取完整 API）。

关键函数：
- `x509ParsePem` / `x509ParseDer` / `x509ParsePemChain`
- `x509DerToPem`
- `x509CreateSelfSignedRsaCertificate` / `x509CreateSelfSignedEcCertificate`
- `x509VerifyCertificateChain` / `x509VerifyCertificateChainWithProfile`
- `x509VerifySignatureWithIssuer`
- `x509LoadSystemTrustAnchors`
- `x509CreateSystemTrustPolicy`
- CRL 解析和验证

## `jinguissl_core.crypto.tls`

TLS 协议（参见 TLS 指南文档获取完整 API）。

关键函数：
- `tls13SummarizeClientHello`
- `tls13PrecheckClientHelloInterop`
- TLS 1.2 和 TLS 1.3 握手流
- 记录层加解密
- 会话管理

## `jinguissl_core.crypto.ssh`

SSH 协议。

关键类型：
- `SshHandshakeCoordinator`
- `SshHandshakeStateMachine`
- `SshHostVerificationConfig / Policy / Result`
- `SshPacketProtectionLayer`
- `SshDerivedSessionKeys`
- `SshNegotiatedAlgorithms`
- `SshVersionBanner`

## `jinguissl_core.crypto.compliance`

合规性管理。

| API | 说明 |
|:--|:--|
| `FipsProfile` | FIPS Profile |
| `TlsVersion` | TLS 版本枚举 |
| `requireAllowed(algorithm)` | 算法许可检查 |
| `TLS_VERSION_1_2` | TLS 1.2 版本常量 |
| `TLS_VERSION_1_3` | TLS 1.3 版本常量 |
