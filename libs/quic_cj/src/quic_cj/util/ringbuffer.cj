package quic_cj.util

/// 将容量向上舍入到 2 的幂次，使 push/pop 可用位掩码替代取模
private func roundUpPowerOf2(n: Int64): Int64 {
    if (n <= 0) { return 64 }
    var v = n - 1
    v = v | (v >> 1)
    v = v | (v >> 2)
    v = v | (v >> 4)
    v = v | (v >> 8)
    v = v | (v >> 16)
    v = v | (v >> 32)
    v + 1
}

/// RingBuffer 是固定大小的循环缓冲区，用于 Int64 值（由于苍颉限制，非泛型）。
public class RingBuffer {
    private var buf: Array<Int64>
    private var head: Int64 = 0
    private var count: Int64 = 0
    private var mask: Int64 = 63

    public init(capacity: Int64, defaultValue: Int64) {
        let cap = roundUpPowerOf2(capacity)
        this.buf = Array<Int64>(cap, repeat: defaultValue)
        this.mask = cap - 1
    }

    /// 添加一个元素。如果已满，返回 false。
    public func push(value: Int64): Bool {
        if (count >= buf.size) { return false }
        let idx = (head + count) & mask
        buf[idx] = value
        count += 1
        true
    }

    /// 移除并返回前面的元素。如果为空，返回 defaultValue。
    public func pop(defaultValue: Int64): Int64 {
        if (count <= 0) { return defaultValue }
        let val = buf[head]
        head = (head + 1) & mask
        count -= 1
        val
    }

    public func peek(): Int64 { buf[head] }
    public func len(): Int64 { count }
    public func cap(): Int64 { buf.size }
    public func isEmpty(): Bool { count == 0 }
    public func isFull(): Bool { count >= buf.size }

    public func get(i: Int64): Int64 { buf[(head + i) & mask] }
}
