# 快速开始

## 依赖配置

在 `cjpm.toml` 中添加：

```toml
[dependencies]
jinguissl = { git = "https://gitcode.com/cinyu/jinguiSSL.git" }
```

## 常用 import

```cangjie
// 导入全部 contract 类型和函数
import jinguissl.contract.*
```

## 示例：SHA-256 摘要

```cangjie
import jinguissl.contract.*

main() {
    let data = "hello jingui".toArray()
    let digest = contractSha256(data)
    println(contractBytesToHexLower(digest))
}
```

## 示例：ChaCha20-Poly1305 AEAD

```cangjie
import jinguissl.contract.*

main() {
    let key = Array<Byte>(32, repeat: 0x01)
    let nonce = Array<Byte>(12, repeat: 0x02)
    let plaintext = "Hello JinguiSSL!".toArray()
    let aad: Array<Byte> = []

    let (ciphertext, tag) = contractChacha20Poly1305Encrypt(key, nonce, plaintext, aad: aad)

    let opened = contractChacha20Poly1305Decrypt(key, nonce, ciphertext, tag, aad: aad)
    println(String.fromUtf8(opened))
}
```

## 示例：X25519 密钥协商

```cangjie
import jinguissl.contract.*

main() {
    let alice = contractX25519GenerateKeyPair()
    let bob = contractX25519GenerateKeyPair()

    let shared1 = contractX25519DeriveKeyAgreement(alice.privateKey, bob.publicKey)
    let shared2 = contractX25519DeriveKeyAgreement(bob.privateKey, alice.publicKey)

    println("Secrets match: ${shared1.sharedSecret == shared2.sharedSecret}")
}
```

## 下一步

- 查看 [sample/](../sample/) 目录获取各模块详细示例
- 查看各模块 API 参考（docs/*.md）获取完整接口说明
