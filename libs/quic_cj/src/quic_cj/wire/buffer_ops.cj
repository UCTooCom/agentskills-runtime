package quic_cj.wire

/// 返回追加了 b 的新缓冲区。
public func appendByte(buf: Array<Byte>, b: UInt8): Array<Byte> {
    let n = buf.size
    let out = Array<Byte>(n + 1, repeat: 0)
    var i: Int64 = 0
    while (i < n) { out[i] = buf[i]; i += 1 }
    out[n] = b
    out
}

/// 返回追加了 extra 的新缓冲区。
public func appendBytes(buf: Array<Byte>, extra: Array<Byte>): Array<Byte> {
    let n = buf.size
    let m = extra.size
    let out = Array<Byte>(n + m, repeat: 0)
    var i: Int64 = 0
    while (i < n) { out[i] = buf[i]; i += 1 }
    i = 0
    while (i < m) { out[n + i] = extra[i]; i += 1 }
    out
}

// ── 位置写入函数族（预分配 + 原地写入，避免 O(n²) 拷贝） ──

/// 在 buf 的 pos 位置写入单字节，返回新位置。
public func writeByteAt(buf: Array<Byte>, pos: Int64, b: UInt8): Int64 {
    buf[pos] = b
    pos + 1
}

/// 在 buf 的 pos 位置写入字节序列，返回新位置。
public func writeBytesAt(buf: Array<Byte>, pos: Int64, data: Array<Byte>): Int64 {
    var i: Int64 = 0
    while (i < data.size) {
        buf[pos + i] = data[i]
        i += 1
    }
    pos + data.size
}

/// 拷贝 source 的 [start..end) 范围到 buf 的 dstPos 位置，返回新位置。
public func writeSliceAt(buf: Array<Byte>, dstPos: Int64, source: Array<Byte>, start: Int64, end_: Int64): Int64 {
    var i: Int64 = start
    while (i < end_) {
        buf[dstPos + i - start] = source[i]
        i += 1
    }
    dstPos + (end_ - start)
}
