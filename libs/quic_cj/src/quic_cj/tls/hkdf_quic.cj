package quic_cj.tls

import jinguissl_core.crypto.digest.{HashAlgorithm, hkdfExtract, hkdfExpand}

/// 为 QUIC 密钥派生执行 HKDF-Extract。
public func quicHkdfExtract(salt: Array<Byte>, ikm: Array<Byte>): Array<Byte> {
    hkdfExtract(HashAlgorithm.SHA256, salt, ikm)
}

/// 为 QUIC 执行 HKDF-Expand-Label（RFC 9001 §5.2）。
public func quicHkdfExpandLabel(secret: Array<Byte>, label: String, context: Array<Byte>, outputLen: Int64): Array<Byte> {
    let labelBytes = ("tls13 " + label).toArray()
    let infoSize = 2 + 1 + labelBytes.size + 1 + context.size
    let info = Array<Byte>(infoSize, repeat: 0)
    info[0] = UInt8((outputLen >> 8) & 0xff)
    info[1] = UInt8(outputLen & 0xff)
    info[2] = UInt8(labelBytes.size)
    var i: Int64 = 0
    while (i < labelBytes.size) {
        info[3 + i] = labelBytes[i]
        i += 1
    }
    info[3 + labelBytes.size] = UInt8(context.size)
    i = 0
    while (i < context.size) {
        info[4 + labelBytes.size + i] = context[i]
        i += 1
    }
    hkdfExpand(HashAlgorithm.SHA256, secret, info, outputLen)
}
