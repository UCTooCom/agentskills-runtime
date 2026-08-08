# ChaCha20 / Poly1305 API 参考

## 常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `CHACHA20_KEY_LEN` | 32 | ChaCha20 密钥长度 |
| `CHACHA20_NONCE_LEN` | 12 | ChaCha20 nonce 长度 |
| `CHACHA20_BLOCK_LEN` | 64 | ChaCha20 块输出长度 |
| `POLY1305_KEY_LEN` | 32 | Poly1305 密钥长度 |
| `POLY1305_TAG_LEN` | 16 | Poly1305 标签长度 |
| `CHACHA20_POLY1305_TAG_LEN` | 16 | AEAD 认证标签长度 |

## 函数

### contractChacha20Poly1305AlgorithmName(): String
返回 `"CHACHA20-POLY1305"`。

### contractChacha20Block(key, counter: Int64, nonce): Array<Byte>
生成单个 64 字节 ChaCha20 块。

### contractChacha20Xor(key, nonce, input, initialCounter?: Int64): Array<Byte>
流加密/解密。XOR 输入与 ChaCha20 密钥流。

### contractPoly1305Mac(key, message): Array<Byte>
计算 Poly1305 MAC 标签（16 字节）。

### contractChacha20Poly1305Encrypt(key, nonce, plaintext, aad?: Array<Byte>): (Array<Byte>, Array<Byte>)
ChaCha20-Poly1305 AEAD 加密。返回 `(ciphertext, tag)`。

### contractChacha20Poly1305Decrypt(key, nonce, ciphertext, tag, aad?: Array<Byte>): Array<Byte>
ChaCha20-Poly1305 AEAD 解密。验证失败抛出 `CryptoException`。

## 错误处理

解密时标签不匹配会抛出 `CryptoException`（code=`INVALID_ARGUMENT`）。
