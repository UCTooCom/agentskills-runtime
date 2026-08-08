package quic_cj.wire

import std.random.Random
import quic_cj.protocol.{MAX_CONN_ID_LEN, Version, VERSION_UNKNOWN, isValidVersion}

/// 解析版本协商包。
/// 返回 (destConnId, srcConnId, versions)。
public func parseVersionNegotiationPacket(data: Array<Byte>): Option<(Array<Byte>, Array<Byte>, Array<Version>)> {
    if (data.size < 7) { return None }
    let firstByte = UInt8(data[0])
    if ((firstByte & 0x80u8) == 0u8) { return None }
    let version = UInt32(UInt8(data[1])) << 24 | UInt32(UInt8(data[2])) << 16 |
                  UInt32(UInt8(data[3])) << 8 | UInt32(UInt8(data[4]))
    if (version != 0u32) { return None }
    let destLen = Int64(UInt8(data[5]))
    if (destLen > MAX_CONN_ID_LEN || data.size < 6 + destLen + 1) {
        return None
    }
    let destConnId = data[6..(6 + destLen)]
    let srcLenPos = 6 + destLen
    let srcLen = Int64(UInt8(data[srcLenPos]))
    if (srcLen > MAX_CONN_ID_LEN || data.size < srcLenPos + 1 + srcLen) {
        return None
    }
    let srcConnId = data[(srcLenPos + 1)..(srcLenPos + 1 + srcLen)]
    let versionStart = srcLenPos + 1 + srcLen
    let remaining = data.size - versionStart
    if (remaining == 0 || remaining % 4 != 0) {
        return None
    }
    let versionCount = remaining / 4
    let versions = Array<Version>(versionCount, repeat: 0u32)
    var i: Int64 = 0
    while (i < versionCount) {
        let pos = versionStart + i * 4
        versions[i] = UInt32(UInt8(data[pos])) << 24 | UInt32(UInt8(data[pos + 1])) << 16 |
                      UInt32(UInt8(data[pos + 2])) << 8 | UInt32(UInt8(data[pos + 3]))
        i += 1
    }
    Some((destConnId, srcConnId, versions))
}

/// 组装版本协商包。
public func composeVersionNegotiation(
    destConnId: Array<Byte>,
    srcConnId: Array<Byte>,
    versions: Array<Version>
): Array<Byte> {
    let rand = Random()
    let firstByte = UInt8(0xc0u8) | UInt8(rand.nextInt64() & 63)
    let headerLen = 1 + 4 + 1 + destConnId.size + 1 + srcConnId.size
    let totalLen = headerLen + versions.size * 4
    var buf = Array<Byte>(totalLen, repeat: 0)
    buf[0] = firstByte
    buf[1] = 0u8; buf[2] = 0u8; buf[3] = 0u8; buf[4] = 0u8
    buf[5] = UInt8(destConnId.size)
    var i: Int64 = 0
    while (i < destConnId.size) {
        buf[6 + i] = destConnId[i]; i += 1
    }
    let srcLenPos = 6 + destConnId.size
    buf[srcLenPos] = UInt8(srcConnId.size)
    i = 0
    while (i < srcConnId.size) {
        buf[srcLenPos + 1 + i] = srcConnId[i]; i += 1
    }
    let versionPos = srcLenPos + 1 + srcConnId.size
    i = 0
    while (i < versions.size) {
        let pos = versionPos + i * 4
        let v = versions[i]
        buf[pos] = UInt8((v >> 24) & 0xffu32)
        buf[pos + 1] = UInt8((v >> 16) & 0xffu32)
        buf[pos + 2] = UInt8((v >> 8) & 0xffu32)
        buf[pos + 3] = UInt8(v & 0xffu32)
        i += 1
    }
    buf
}

/// 检查是否是版本协商包。
public func isVersionNegotiationPacket(data: Array<Byte>): Bool {
    if (data.size < 5) { return false }
    let firstByte = UInt8(data[0])
    if ((firstByte & 0x80u8) == 0u8) { return false }
    let version = UInt32(UInt8(data[1])) << 24 | UInt32(UInt8(data[2])) << 16 |
                  UInt32(UInt8(data[3])) << 8 | UInt32(UInt8(data[4]))
    version == 0u32
}
