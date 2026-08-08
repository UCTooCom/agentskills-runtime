# SSH 协议支持说明

`jinguissl_core.crypto.ssh` 提供 SSH 传输层握手、主机验证和密钥交换。

## 整体架构

```
SSH Layer
├── Version Banner (version exchange)
├── Key Exchange (KEX)
│   ├── KEX_INIT → KEX_REPLY
│   ├── ECDH key exchange
│   ├── Host key verification
│   └── Derived session keys
├── Encryption Layer
│   ├── Packet protection (AES-CTR, ChaCha20)
│   ├── Sequence numbering
│   └── MAC/ETM
└── Transport Protocol
    ├── Packet framing
    ├── Compression (deflate)
    └── Rekeying
```

## 核心类型

### SshVersionBanner

SSH 版本交换。

```cangjie
let banner = SshVersionBanner("SSH-2.0-JinguiSSL_1.0")
```

### SshKexInitMessage / SshKexEcdhInitMessage / SshKexEcdhReplyMessage

KEX 初始化消息。

### SshNegotiatedAlgorithms

协商的算法集合，包含：
- 密钥交换算法
- 主机密钥算法
- 加密算法（C2S, S2C）
- MAC 算法（C2S, S2C）
- 压缩算法

### SshHandshakeCoordinator

协调完整的 SSH 握手流程。

### SshHostVerificationConfig / SshHostVerificationPolicy / SshHostVerificationResult

主机验证配置与结果。

### SshPacketProtectionLayer

SSH 传输层包保护。

### SshDerivedSessionKeys / SshDirectionKeyMaterial

导出的 SSH 会话密钥材料。

## 使用流程

```
1. 版本交换 (Version Banner)
2. KEX 初始化 (发送 KEX_INIT)
3. KEX 回复 (接收 KEX_REPLY)
4. ECDH 密钥交换
5. 主机密钥验证
6. 派生会话密钥
7. 加密通信
```
