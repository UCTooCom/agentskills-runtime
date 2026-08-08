package quic_cj.congestion

import quic_cj.protocol.{INITIAL_PACKET_SIZE, TIMER_GRANULARITY_MS}

private let MAX_BURST_SIZE_PACKETS: Int64 = 10
private let INITIAL_MAX_DATAGRAM_SIZE: Int64 = INITIAL_PACKET_SIZE

/// 实现令牌桶调速算法。
public class Pacer {
    private var budgetAtLastSent: Int64 = 0
    private var maxDatagramSize: Int64 = INITIAL_MAX_DATAGRAM_SIZE
    private var lastSentTime: Int64 = 0
    private var currentBw: UInt64 = 0u64  // 字节/秒

    public init() {
        this.budgetAtLastSent = maxBurstSize()
    }

    /// 更新带宽估计值（字节/秒）。
    public func setBandwidth(bw: UInt64): Unit {
        currentBw = bw
    }

    /// 记录已发送的包并更新预算。
    public func sentPacket(sendTime: Int64, size: Int64): Unit {
        let bgt = budget(sendTime)
        if (size >= bgt) {
            budgetAtLastSent = 0
        } else {
            budgetAtLastSent = bgt - size
        }
        lastSentTime = sendTime
    }

    /// 返回给定时间可用的发送预算。
    public func budget(now: Int64): Int64 {
        if (lastSentTime == 0) { return maxBurstSize() }
        let delta = now - lastSentTime
        var added: Int64 = 0
        if (delta > 0) {
            // currentBw (bytes/sec) * delta (ms) / 1000 = bytes added
            if (currentBw > 0u64) {
                added = Int64(UInt64(delta) * currentBw / 1000u64)
                if (added > maxBurstSize()) { added = maxBurstSize() }
            }
        }
        var budget = budgetAtLastSent + added
        if (budget > maxBurstSize()) { budget = maxBurstSize() }
        if (budget < 0) { budget = maxBurstSize() }
        budget
    }

    /// 返回下一个包可以发送的时间（距现在的毫秒数）。
    public func timeUntilSend(): Int64 {
        if (budgetAtLastSent >= maxDatagramSize) { return 0 }
        if (currentBw == 0u64) { return 0 }
        let deficit = maxDatagramSize - budgetAtLastSent
        let delayNs = UInt64(deficit) * 1000000000u64 / currentBw
        let delayMs = Int64(delayNs + 999999u64) / 1000000
        if (delayMs < TIMER_GRANULARITY_MS) { TIMER_GRANULARITY_MS } else { delayMs }
    }

    private func maxBurstSize(): Int64 {
        let burst = MAX_BURST_SIZE_PACKETS * maxDatagramSize
        burst
    }
}
