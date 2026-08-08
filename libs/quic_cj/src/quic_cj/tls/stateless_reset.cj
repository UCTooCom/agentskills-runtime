package quic_cj.tls

import jinguissl_core.crypto.quic.{quicHpAesEncrypt as aesEcbEncrypt}

/// STATELESS_RESET_TOKEN_SIZE = 16 字节（AES 块大小，RFC 9000 §10.3）
public let STATELESS_RESET_TOKEN_SIZE: Int64 = 16

/// 为连接 ID 创建无状态重置令牌。
/// key：16 字节 AES-128 密钥
/// connId：要保护的连接 ID
public func generateStatelessResetToken(key: Array<Byte>, connId: Array<Byte>): Array<Byte> {
    let input = padConnectionId(connId)
    let (firstByte, rest) = aesEcbEncrypt(input, key)
    var token = Array<Byte>(16, repeat: 0)
    token[0] = firstByte
    var i: Int64 = 0
    while (i < 15 && i < rest.size) {
        token[1 + i] = rest[i]
        i += 1
    }
    token
}

/// 检查令牌是否与给定的密钥和连接 ID 匹配。
public func verifyStatelessResetToken(key: Array<Byte>, connId: Array<Byte>, token: Array<Byte>): Bool {
    if (token.size != STATELESS_RESET_TOKEN_SIZE) { return false }
    let expected = generateStatelessResetToken(key, connId)
    var i: Int64 = 0
    while (i < STATELESS_RESET_TOKEN_SIZE) {
        if (token[i] != expected[i]) { return false }
        i += 1
    }
    true
}

private func padConnectionId(connId: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(16, repeat: 0)
    let copyLen = if (connId.size > 16) { 16 } else { connId.size }
    var i: Int64 = 0
    while (i < copyLen) {
        out[i] = connId[i]
        i += 1
    }
    out
}
