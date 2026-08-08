# TLS 协议支持说明

`jinguissl_core.crypto.tls` 提供 TLS 1.2 和 TLS 1.3 的握手、记录层和会话管理。

## 整体架构

```
TLS Layer
├── Handshake (tls12.cj, tls13.cj)
│   ├── ClientHello / ServerHello
│   ├── Certificate / CertificateVerify
│   ├── Key Exchange (ECDHE, X25519)
│   └── Finished
├── Record (record.cj)
│   ├── Content types (handshake, application data, alert)
│   ├── Encryption / Decryption
│   └── SeqNum management
├── Session (session.cj)
│   ├── Session state
│   ├── Cipher suite negotiation
│   └── Key schedule
└── HTTP (http.cj)
    └── Application data encoding
```

## TLS 1.3 支持

### Cipher Suites

| Suite | 值 | 状态 |
|:--|:--|:--|
| TLS_AES_128_GCM_SHA256 | 0x1301 | 已实现 |
| TLS_AES_256_GCM_SHA384 | 0x1302 | 已实现 |
| TLS_CHACHA20_POLY1305_SHA256 | 0x1303 | 已实现 |

### 常量

| 名称 | 值 | 说明 |
|:--|:--|:--|
| `TLS13_CIPHER_SUITE_AES_128_GCM_SHA256` | 0x1301 | |
| `TLS13_CIPHER_SUITE_AES_256_GCM_SHA384` | 0x1302 | |
| `TLS13_CIPHER_SUITE_CHACHA20_POLY1305_SHA256` | 0x1303 | |
| `TLS13_SHA256_HASH_LEN` | 32 | |
| `TLS13_SHA384_HASH_LEN` | 48 | |
| `TLS13_DEFAULT_AEAD_KEY_LEN` | 16 | |
| `TLS13_DEFAULT_AEAD_IV_LEN` | 12 | |

### 签名算法

| 名称 | 值 |
|:--|:--|
| `TLS13_SIG_SCHEME_ECDSA_SECP256R1_SHA256` | 0x0403 |
| `TLS13_SIG_SCHEME_ECDSA_SECP384R1_SHA384` | 0x0503 |
| `TLS13_SIG_SCHEME_RSA_PSS_RSAE_SHA256` | 0x0804 |

### 密钥更新

```cangjie
let TLS13_KEY_UPDATE_NOT_REQUESTED: Int64 = 0
let TLS13_KEY_UPDATE_REQUESTED: Int64 = 1
```

### 客户端 Hello 互操作检测

```cangjie
import jinguissl_core.crypto.tls.*

let summary = tls13SummarizeClientHello(encodedClientHello)
// 或
let summary = tls13SummarizeDecodedClientHello(clientHello)
```

## TLS 1.2 支持

TLS 1.2 提供完整的握手流，支持 ECDHE 密钥交换和服务端/客户端证书。

### 握手状态

```
TLS 1.2 Handshake
├── ClientHello → ServerHello
├── Certificate → ServerKeyExchange → CertificateRequest
├── ServerHelloDone
├── ClientCertificate → ClientKeyExchange → CertificateVerify
└── ChangeCipherSpec → Finished
```

## 记录层

`record.cj` 提供 TLS 记录层的加密和解密。

### 记录层功能
- 内容类型编码（handshake, alert, application_data, change_cipher_spec）
- 记录序列号管理
- AEAD 加密与解密
- 记录分片与重组

## 会话管理

`session.cj` 管理 TLS 会话状态，包括：
- 会话 ID
- 密码套件协商
- 密钥计划
- 会话恢复
