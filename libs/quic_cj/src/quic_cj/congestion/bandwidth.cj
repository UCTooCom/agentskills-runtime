package quic_cj.congestion

/// 连接的带宽（比特/秒）。
public type Bandwidth = UInt64

public let BITS_PER_SECOND: Bandwidth = 1u64
public let BYTES_PER_SECOND: Bandwidth = 8u64 * BITS_PER_SECOND

/// 根据字节数和时间差（纳秒）计算带宽。
public func bandwidthFromDelta(bytes: Int64, deltaNs: Int64): Bandwidth {
    if (deltaNs <= 0) { return 0u64 }
    let b = UInt64(bytes)
    let d = UInt64(deltaNs)
    b * 1000000000u64 / d * BYTES_PER_SECOND
}
