package quic_cj.tls

 import jinguissl_core.crypto.tls.{
     tls13CipherSuiteKeyLen,
     tls13CipherSuiteIvLen,
     tls13CipherSuiteHashAlgorithm,
     tls13CipherSuiteHashLen
 }
 import jinguissl_core.crypto.digest.HashAlgorithm
 
/// TLS 1.3 密码套件 ID（RFC 8446 §B.4）
public let TLS_AES_128_GCM_SHA256: UInt16 = 0x1301u16
public let TLS_AES_256_GCM_SHA384: UInt16 = 0x1302u16
public let TLS_CHACHA20_POLY1305_SHA256: UInt16 = 0x1303u16

/// 默认密码套件（按优先级排序）
public let DEFAULT_CIPHER_SUITES: Array<UInt16> = [
    TLS_AES_128_GCM_SHA256,
    TLS_CHACHA20_POLY1305_SHA256,
    TLS_AES_256_GCM_SHA384
]

/// 表示 TLS 1.3 密码套件。
public class CipherSuite {
    public var id: UInt16
    public var keyLen: Int64
    public var ivLen: Int64
    public var tagLen: Int64
    public var isChaCha: Bool
     public var hashAlg: HashAlgorithm = HashAlgorithm.SHA256

    public init(id: UInt16) {
        this.id = id

        // 使用 jinguissl_core 查询密码套件属性
        var resolved: (Int64, Int64, HashAlgorithm) = (16, 12, HashAlgorithm.SHA256)
        if (let Some((kLen, iLen, hash)) <- resolveCipherSuiteProperties(id)) {
            resolved = (kLen, iLen, hash)
        }
        keyLen = resolved[0]
        ivLen = resolved[1]
        hashAlg = resolved[2]
        tagLen = 16
        isChaCha = (id == TLS_CHACHA20_POLY1305_SHA256)
    }
 }
 
/// 使用 jinguissl_core 解析密码套件属性。
/// 回退到合理默认值。
private func resolveCipherSuiteProperties(
    id: UInt16
): Option<(Int64, Int64, HashAlgorithm)> {
    try {
        let keyLen = tls13CipherSuiteKeyLen(Int64(id))
        let ivLen = tls13CipherSuiteIvLen(Int64(id))
        let hashAlg = tls13CipherSuiteHashAlgorithm(Int64(id))
        Some((keyLen, ivLen, hashAlg))
    } catch (_: Exception) {
        // 回退到硬编码默认值
        if (id == TLS_AES_128_GCM_SHA256) {
            Some((16, 12, HashAlgorithm.SHA256))
        } else if (id == TLS_AES_256_GCM_SHA384) {
            Some((32, 12, HashAlgorithm.SHA384))
        } else if (id == TLS_CHACHA20_POLY1305_SHA256) {
            Some((32, 12, HashAlgorithm.SHA256))
        } else {
            Some((16, 12, HashAlgorithm.SHA256))
        }
    }
}

/// 选择第一个双方都支持的密码套件。
public func selectCipherSuite(ours: Array<UInt16>, theirs: Array<UInt16>): Option<UInt16> {
    for (our in ours) {
        for (their in theirs) {
            if (our == their) { return Some(our) }
        }
    }
    return None
}
