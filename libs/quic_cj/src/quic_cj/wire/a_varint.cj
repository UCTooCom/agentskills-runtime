package quic_cj.wire

public let VARINT_MAX: Int64 = (Int64(1) << 62) - 1
public let VARINT_MAX_1: Int64 = 63
public let VARINT_MAX_2: Int64 = 16383
public let VARINT_MAX_4: Int64 = 1073741823

/// 解码 QUIC 变长整数。
/// 返回 (value, bytes_consumed)。
public func readVarint(data: Array<Byte>): (Int64, Int64) {
    if (data.size < 1) { return (0, 0) }
    let firstByte = UInt8(data[0])
    let len = Int64(1) << Int64((firstByte >> 6) & 0x03u8)
    if (data.size < len) { return (0, 0) }
    if (len == 1) {
        (Int64(firstByte & 0x3fu8), 1)
    } else {
        var v: Int64 = Int64(firstByte & 0x3fu8)
        var i: Int64 = 1
        while (i < len) {
            v = (v << 8) | Int64(UInt8(data[i]))
            i += 1
        }
        (v, len)
    }
}

/// 返回编码 v 所需的字节数。
public func writeVarintLen(v: Int64): Int64 {
    // 使用位宽查表：varlen_from_bit[v >> 6] 的快速版本
    if (v < 0) { 8 }
    else if (v <= VARINT_MAX_1) { 1 }
    else if (v <= VARINT_MAX_2) { 2 }
    else if (v <= VARINT_MAX_4) { 4 }
    else { 8 }
}

/// 将 QUIC varint 追加到 buf 并返回新缓冲区。
public func appendVarint(buf: Array<Byte>, v: Int64): Array<Byte> {
    let extra: Int64
    if (v < 0) { extra = 8 }
    else if (v <= VARINT_MAX_1) { extra = 1 }
    else if (v <= VARINT_MAX_2) { extra = 2 }
    else if (v <= VARINT_MAX_4) { extra = 4 }
    else { extra = 8 }
    let total = buf.size + extra
    let out = Array<Byte>(total, repeat: 0)
    var i: Int64 = 0
    while (i < buf.size) {
        out[i] = buf[i]
        i += 1
    }
    if (extra == 1) {
        out[buf.size] = UInt8(v)
    } else if (extra == 2) {
        out[buf.size] = UInt8(((v >> 8) & 0x3f) | 0x40)
        out[buf.size + 1] = UInt8(v & 0xff)
    } else if (extra == 4) {
        out[buf.size] = UInt8(((v >> 24) & 0x3f) | 0x80)
        out[buf.size + 1] = UInt8((v >> 16) & 0xff)
        out[buf.size + 2] = UInt8((v >> 8) & 0xff)
        out[buf.size + 3] = UInt8(v & 0xff)
    } else {
        out[buf.size] = UInt8(((v >> 56) & 0x3f) | 0xc0)
        out[buf.size + 1] = UInt8((v >> 48) & 0xff)
        out[buf.size + 2] = UInt8((v >> 40) & 0xff)
        out[buf.size + 3] = UInt8((v >> 32) & 0xff)
        out[buf.size + 4] = UInt8((v >> 24) & 0xff)
        out[buf.size + 5] = UInt8((v >> 16) & 0xff)
        out[buf.size + 6] = UInt8((v >> 8) & 0xff)
        out[buf.size + 7] = UInt8(v & 0xff)
    }
    out
}

// ── 位置写入 varint（预分配缓冲区 + 原地写入） ──

/// 在 buf 的 pos 位置写入 varint，返回新位置。
public func writeVarintAt(buf: Array<Byte>, pos: Int64, v: Int64): Int64 {
    let extra: Int64
    if (v < 0) { extra = 8 }
    else if (v <= VARINT_MAX_1) { extra = 1 }
    else if (v <= VARINT_MAX_2) { extra = 2 }
    else if (v <= VARINT_MAX_4) { extra = 4 }
    else { extra = 8 }
    if (extra == 1) {
        buf[pos] = UInt8(v)
    } else if (extra == 2) {
        buf[pos] = UInt8(((v >> 8) & 0x3f) | 0x40)
        buf[pos + 1] = UInt8(v & 0xff)
    } else if (extra == 4) {
        buf[pos] = UInt8(((v >> 24) & 0x3f) | 0x80)
        buf[pos + 1] = UInt8((v >> 16) & 0xff)
        buf[pos + 2] = UInt8((v >> 8) & 0xff)
        buf[pos + 3] = UInt8(v & 0xff)
    } else {
        buf[pos] = UInt8(((v >> 56) & 0x3f) | 0xc0)
        buf[pos + 1] = UInt8((v >> 48) & 0xff)
        buf[pos + 2] = UInt8((v >> 40) & 0xff)
        buf[pos + 3] = UInt8((v >> 32) & 0xff)
        buf[pos + 4] = UInt8((v >> 24) & 0xff)
        buf[pos + 5] = UInt8((v >> 16) & 0xff)
        buf[pos + 6] = UInt8((v >> 8) & 0xff)
        buf[pos + 7] = UInt8(v & 0xff)
    }
    pos + extra
}

// ── 位置读取 varint（避免切片拷贝） ──

/// 在 data 的 offset 位置解码 QUIC 变长整数，不创建切片。
/// 返回 (value, bytes_consumed)。
public func readVarintAt(data: Array<Byte>, offset: Int64): (Int64, Int64) {
    if (offset >= data.size) { return (0, 0) }
    let firstByte = UInt8(data[offset])
    let len = Int64(1) << Int64((firstByte >> 6) & 0x03u8)
    if (data.size < offset + len) { return (0, 0) }
    if (len == 1) {
        (Int64(firstByte & 0x3fu8), 1)
    } else {
        var v: Int64 = Int64(firstByte & 0x3fu8)
        var i: Int64 = 1
        while (i < len) {
            v = (v << 8) | Int64(UInt8(data[offset + i]))
            i += 1
        }
        (v, len)
    }
}
