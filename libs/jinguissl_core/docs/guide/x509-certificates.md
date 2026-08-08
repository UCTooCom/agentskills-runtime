# X.509 证书处理说明

`jinguissl_core.crypto.x509` 提供 X.509 证书的解析、验证和管理。

## 证书解析

### PEM 格式

```cangjie
import jinguissl_core.crypto.x509.*

// 单证书
let cert = x509ParsePem(pemString)

// 证书链（PEM bundle）
let chain = x509ParsePemChain(pemBundle)
```

### DER 格式

```cangjie
let cert = x509ParseDer(derBytes)
```

### DER ↔ PEM 转换

```cangjie
let pem = x509DerToPem(derBytes)
```

## 证书信息提取

### 主体 X509Name

```cangjie
// 查找 CN
let cn = x509NameFindFirstValue(cert.subject, X509_OID_COMMON_NAME)

// 比较 X509Name
let equal = x509NameDerEquals(name1, name2)
```

### 公钥提取

```cangjie
let rsaPubKey = x509ExtractRsaPublicKey(cert)
let ecPubKey = x509ExtractEcPublicKey(cert)
```

### 扩展信息

```cangjie
// 查找扩展
let ext = x509FindExtension(cert, X509_OID_BASIC_CONSTRAINTS)

// 基本约束
let bc = x509DecodeBasicConstraintsFromExtension(ext)
// 或直接 DER 解码
let bc = x509DecodeBasicConstraintsBits(derEncodedSequence)

// 密钥用途
let keyUsageBits = x509DecodeKeyUsageFromExtension(ext)
let isDigitalSig = (keyUsageBits & X509_KEY_USAGE_DIGITAL_SIGNATURE) != 0

// 主题备用名称 DNS
let dnsNames = x509DecodeSubjectAlternativeNameDnsFromExtension(ext)
let dnsNames = x509ExtractSubjectAlternativeDnsNames(cert)

// 颁发者密钥标识
let aki = x509ExtractAuthorityKeyIdentifier(cert)

// 主体密钥标识
let ski = x509ExtractSubjectKeyIdentifier(cert)

// 扩展密钥用途
let ekuOids = x509ExtractExtendedKeyUsageOids(cert)

// CRL 分发点
let crlUris = x509ExtractCrlDistributionPointUris(cert)

// 证书策略
let policyOids = x509ExtractCertificatePolicyOids(cert)
```

## OID 常量

| 名称 | OID |
|:--|:--|
| `X509_OID_COMMON_NAME` | 2.5.4.3 |
| `X509_OID_KEY_USAGE` | 2.5.29.15 |
| `X509_OID_SUBJECT_ALT_NAME` | 2.5.29.17 |
| `X509_OID_SUBJECT_KEY_IDENTIFIER` | 2.5.29.14 |
| `X509_OID_BASIC_CONSTRAINTS` | 2.5.29.19 |
| `X509_OID_AUTHORITY_KEY_IDENTIFIER` | 2.5.29.35 |
| `X509_OID_EXTENDED_KEY_USAGE` | 2.5.29.37 |
| `X509_OID_CRL_DISTRIBUTION_POINTS` | 2.5.29.31 |
| `X509_OID_CERTIFICATE_POLICIES` | 2.5.29.32 |
| `X509_OID_RSA_ENCRYPTION` | 1.2.840.113549.1.1.1 |
| `X509_OID_EC_PUBLIC_KEY` | 1.2.840.10045.2.1 |
| `X509_OID_PRIME256V1` | 1.2.840.10045.3.1.7 |
| `X509_OID_SHA256_WITH_RSA` | 1.2.840.113549.1.1.11 |
| `X509_OID_ECDSA_WITH_SHA256` | 1.2.840.10045.4.3.2 |
| `X509_OID_EKU_SERVER_AUTH` | 1.3.6.1.5.5.7.3.1 |
| `X509_OID_EKU_CLIENT_AUTH` | 1.3.6.1.5.5.7.3.2 |
| `X509_OID_EKU_CODE_SIGNING` | 1.3.6.1.5.5.7.3.3 |

## 密钥用途位

| 常量 | 位 |
|:--|:--|
| `X509_KEY_USAGE_DIGITAL_SIGNATURE` | bit 0 |
| `X509_KEY_USAGE_CONTENT_COMMITMENT` | bit 1 |
| `X509_KEY_USAGE_KEY_ENCIPHERMENT` | bit 2 |
| `X509_KEY_USAGE_DATA_ENCIPHERMENT` | bit 3 |
| `X509_KEY_USAGE_KEY_AGREEMENT` | bit 4 |
| `X509_KEY_USAGE_KEY_CERT_SIGN` | bit 5 |
| `X509_KEY_USAGE_CRL_SIGN` | bit 6 |
| `X509_KEY_USAGE_ENCIPHER_ONLY` | bit 7 |
| `X509_KEY_USAGE_DECIPHER_ONLY` | bit 8 |

## 证书验证

### 自签名证书创建

```cangjie
// RSA 自签名
let config = X509SelfSignedConfig(
    subjectName: "CN=MyCert",
    validDays: 365
)
let rsaCert = x509CreateSelfSignedRsaCertificate(config, rsaPrivateKey)

// EC 自签名
let ecCert = x509CreateSelfSignedEcCertificate(config, ecPrivateKey)
```

### 链验证

```cangjie
let policy = X509VerificationPolicy(trustAnchors: anchors, validationTime: "20250101000000Z")
let result = x509VerifyCertificateChain(leaf, policy)
// 或使用 FIPS profile
let result = x509VerifyCertificateChainWithProfile(leaf, policy, fipsProfile)

// 构建简单链
let chain = x509BuildSimpleChain(leaf, candidates)
```

### 签名验证

```cangjie
x509VerifySignatureWithIssuer(cert, issuerCert)
```

### CRL 验证

```cangjie
let crl = x509ParseCrlPem(crlPemString)
// 或
let crl = x509ParseCrlDer(crlDer)

x509VerifyCrlSignatureWithIssuer(crl, issuerCert)
```

### 时间验证

```cangjie
x509RequireTimeValidAt(cert, "20250101000000Z")
```

### 吊销检查

```cangjie
let revokedSerials: Array<String> = ["01a2b3", "04d5e6"]
x509RequireNotRevoked(cert, revokedSerials)
```

## 私钥解析

```cangjie
// RSA PKCS1 PEM
let rsaPriv = x509ParseRsaPrivateKeyPkcs1Pem(pemString)
// RSA PKCS1 DER
let rsaPriv = x509ParseRsaPrivateKeyPkcs1Der(derBytes)
// RSA PKCS8 PEM
let rsaPriv = x509ParseRsaPrivateKeyPkcs8Pem(pemString)
// RSA PKCS8 DER
let rsaPriv = x509ParseRsaPrivateKeyPkcs8Der(derBytes)
// EC PKCS8 PEM
let ecPriv = x509ParseEcPrivateKeyPkcs8Pem(pemString)
// EC PKCS8 DER
let ecPriv = x509ParseEcPrivateKeyPkcs8Der(derBytes)
```

## 系统信任材料

```cangjie
// 查询系统信任锚支持类型
let supportKind = x509SystemTrustMaterialSupportKind()

// 系统信任锚候选路径
let candidatePaths = x509SystemTrustBundleCandidatePaths()

// 加载系统信任锚
let anchors = x509LoadSystemTrustAnchors(extraPemBundlePaths: ["./extra_roots.pem"])

// 创建系统信任策略
let policy = x509CreateSystemTrustPolicy(extraPemBundlePaths: ["./extra_roots.pem"])
```

## CRL 类型

```cangjie
class X509Crl {
    // 颁发者、本次更新、下次更新
    // 吊销的证书列表
}
```

## CRL 分发点

```cangjie
class X509CrlDistributionPoint {
    // URI 等
}
```

## X509Name 属性

```cangjie
class X509NameAttribute {
    // OID、值
}
```
