package quic_cj.tls

import std.random.Random
import jinguissl_core.crypto.digest.{HashAlgorithm, hkdfExtract, hkdfExpand}
import jinguissl_core.crypto.quic.{quicAeadEncrypt, quicAeadDecrypt, QuicAeadAlgorithm}

/// 用于加密重试和会话恢复令牌的密钥（32 字节）。
public type TokenProtectorKey = Array<Byte>

public let TOKEN_KEY_SIZE: Int64 = 32
public let TOKEN_SALT_SIZE: Int64 = 32
public let TOKEN_NONCE_SIZE: Int64 = 12

/// 使用 AES-256-GCM 加密和解密地址令牌。
/// 令牌线路格式：random_salt(32) + random_nonce(12) + 密文（明文 + 16 字节标签）
public class TokenProtector {
    private var key: TokenProtectorKey

    public init(key: TokenProtectorKey) {
        this.key = key
    }

    /// 将数据加密为不透明令牌。
    public func newToken(data: Array<Byte>): Array<Byte> {
        let rand = Random()
        let salt = randomBytes(rand, TOKEN_SALT_SIZE)
        let prk = hkdfExtract(HashAlgorithm.SHA256, key, salt)
        let encKey = hkdfExpand(HashAlgorithm.SHA256, prk, "quic-go token source".toArray(), 32)
        let nonce = randomBytes(rand, TOKEN_NONCE_SIZE)
        // 将 nonce 作为 "iv" 且 pn=0 传递，因此 nonce = 0 XOR nonce = nonce
        let ciphertext = quicAeadEncrypt(encKey, nonce, 0, data, [], QuicAeadAlgorithm.Aes256Gcm)
        assembleToken(salt, nonce, ciphertext)
    }

    /// 将令牌解密回原始数据。
    /// 失败时返回空数组。
    public func decodeToken(encrypted: Array<Byte>): Array<Byte> {
        if (encrypted.size < TOKEN_SALT_SIZE + TOKEN_NONCE_SIZE + 16) {
            return []
        }
        let salt = encrypted[..TOKEN_SALT_SIZE]
        let nonce = encrypted[TOKEN_SALT_SIZE..(TOKEN_SALT_SIZE + TOKEN_NONCE_SIZE)]
        let ct = encrypted[(TOKEN_SALT_SIZE + TOKEN_NONCE_SIZE)..]
        let prk = hkdfExtract(HashAlgorithm.SHA256, key, salt)
        let encKey = hkdfExpand(HashAlgorithm.SHA256, prk, "quic-go token source".toArray(), 32)
        try {
            quicAeadDecrypt(encKey, nonce, 0, ct, [], QuicAeadAlgorithm.Aes256Gcm)
        } catch (_: Exception) {
            []
        }
    }
}

/// 使用给定密钥创建 TokenProtector。
public func newTokenProtector(key: TokenProtectorKey): TokenProtector {
    TokenProtector(key)
}

private func randomBytes(rand: Random, count: Int64): Array<Byte> {
    let out = Array<Byte>(count, repeat: 0)
    var i: Int64 = 0
    while (i < count) {
        out[i] = UInt8(rand.nextInt64() & 0xFFi64)
        i += 1
    }
    out
}

private func assembleToken(salt: Array<Byte>, nonce: Array<Byte>, ct: Array<Byte>): Array<Byte> {
    let total = salt.size + nonce.size + ct.size
    var out = Array<Byte>(total, repeat: 0)
    var i: Int64 = 0
    while (i < salt.size) { out[i] = salt[i]; i += 1 }
    i = 0
    while (i < nonce.size) { out[salt.size + i] = nonce[i]; i += 1 }
    i = 0
    while (i < ct.size) { out[salt.size + nonce.size + i] = ct[i]; i += 1 }
    out
}
