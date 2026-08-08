package quic_cj.tls

import quic_cj.wire.{readVarint, appendVarint, appendBytes}

/// 区分重试令牌和 NEW_TOKEN 令牌。
public enum TokenType {
    | Retry
    | NewToken
}

/// 保存已验证的地址信息，用于 0-RTT 和重试。
public class Token {
    public var isRetryToken: Bool = false
    public var sentTime: Int64 = 0
    public var encodedRemoteAddr: Array<Byte> = []
    public var rttMicros: Int64 = 0
    public var origDestConnId: Array<Byte> = []
    public var retrySrcConnId: Array<Byte> = []
}

/// 创建和验证地址令牌。
public class TokenGenerator {
    private var protector: TokenProtector

    public init(key: TokenProtectorKey) {
        this.protector = newTokenProtector(key)
    }

    /// 为重试包生成令牌。
    public func newRetryToken(
        remoteAddr: Array<Byte>,
        origDestConnId: Array<Byte>,
        retrySrcConnId: Array<Byte>
    ): Array<Byte> {
        let data = marshalToken(TokenType.Retry, remoteAddr, origDestConnId, retrySrcConnId, 0, 0)
        protector.newToken(data)
    }

    /// 生成要在 NEW_TOKEN 帧中发送的令牌。
    public func newToken(remoteAddr: Array<Byte>, rttMicros: Int64): Array<Byte> {
        let data = marshalToken(TokenType.NewToken, remoteAddr, [], [], rttMicros, 0)
        protector.newToken(data)
    }

    /// 解密并验证令牌。
    /// 返回 Token。
    public func decodeToken(encrypted: Array<Byte>): Option<Token> {
        if (encrypted.size == 0) { return None }
        let data = protector.decodeToken(encrypted)
        if (data.size == 0) { return None }
        unmarshalToken(data)
    }
}

private let TOKEN_FLAG_RETRY: UInt8 = 0x01u8

private func marshalToken(
    ttype: TokenType,
    remoteAddr: Array<Byte>,
    origDestConnId: Array<Byte>,
    retrySrcConnId: Array<Byte>,
    rttMicros: Int64,
    timestamp: Int64
): Array<Byte> {
    var buf: Array<Byte> = []
    let flags = match (ttype) { case TokenType.Retry => TOKEN_FLAG_RETRY; case _ => 0u8 }
    buf = appendVarint(buf, Int64(flags))
    buf = appendVarint(buf, remoteAddr.size)
    buf = appendBytes(buf, remoteAddr)
    buf = appendVarint(buf, timestamp)
    let isRetry = match (ttype) { case TokenType.Retry => true; case _ => false }
    if (isRetry) {
        buf = appendVarint(buf, origDestConnId.size)
        buf = appendBytes(buf, origDestConnId)
        buf = appendVarint(buf, retrySrcConnId.size)
        buf = appendBytes(buf, retrySrcConnId)
    } else {
        buf = appendVarint(buf, rttMicros)
    }
    buf
}

private func unmarshalToken(data: Array<Byte>): Option<Token> {
    if (data.size < 2) { return None }
    let (flags, n1) = readVarint(data)
    if (n1 == 0) { return None }
    var pos = n1
    let remaining = data[pos..]
    let (addrLen, n2) = readVarint(remaining)
    if (n2 == 0) { return None }
    pos += n2
    if (pos + addrLen > data.size) { return None }
    let remoteAddr = data[pos..(pos + addrLen)]
    pos += addrLen
    let timeRemaining = data[pos..]
    let (timestamp, n3) = readVarint(timeRemaining)
    if (n3 == 0) { return None }
    pos += n3
    let t = Token()
    t.isRetryToken = (flags & 1) != 0
    t.encodedRemoteAddr = remoteAddr
    t.sentTime = timestamp
    if (t.isRetryToken) {
        let odRemaining = data[pos..]
        let (odLen, n4) = readVarint(odRemaining)
        if (n4 == 0) { return None }
        pos += n4
        if (pos + odLen > data.size) { return None }
        t.origDestConnId = data[pos..(pos + odLen)]
        pos += odLen
        let rsRemaining = data[pos..]
        let (rsLen, n5) = readVarint(rsRemaining)
        if (n5 == 0) { return None }
        pos += n5
        if (pos + rsLen > data.size) { return None }
        t.retrySrcConnId = data[pos..(pos + rsLen)]
    } else {
        let rttRemaining = data[pos..]
        let (rtt, n4) = readVarint(rttRemaining)
        if (n4 == 0) { return None }
        t.rttMicros = rtt
    }
    Some(t)
}
