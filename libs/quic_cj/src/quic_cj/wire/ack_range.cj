package quic_cj.wire

/// AckRange 表示连续的已确认包范围。
public class AckRange {
    public var smallest: Int64 = 0
    public var largest: Int64 = 0

    public func len(): Int64 { largest - smallest + 1 }
}
