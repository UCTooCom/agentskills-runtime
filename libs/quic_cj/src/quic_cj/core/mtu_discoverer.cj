package quic_cj.core

import quic_cj.protocol.INVALID_BYTE_COUNT
import quic_cj.util.RTTStats

/// MTU 探测完成的最小间隔（20 字节）。
public let MAX_MTU_DIFF: Int64 = 20
/// 探测间隔（RTT 倍数）。
public let MTU_PROBE_DELAY: Int64 = 5
/// 最大丢失 MTU 探测次数。
public let MAX_LOST_MTU_PROBES: Int64 = 3

/// MtuFinder 实现路径 MTU 发现（RFC 8899 PLPMTUD）。
/// 使用二分搜索探测来查找路径支持的最大数据包大小。
public class MtuFinder {
    private var lastProbeTimeNs: Int64 = 0
    private var started: Bool = false
    private var inFlightSize: Int64 = INVALID_BYTE_COUNT
    private var min: Int64 = 1200
    private var lost: Array<Int64> = Array<Int64>(MAX_LOST_MTU_PROBES, repeat: INVALID_BYTE_COUNT)
    private var lastProbeWasLost: Bool = false
    private var generation: UInt8 = 0u8
    private var rttStats: RTTStats = RTTStats()

    public init(rttStats: RTTStats, start: Int64, max: Int64) {
        this.rttStats = rttStats
        this.min = start
        lost[0] = max
        var i: Int64 = 1
        while (i < MAX_LOST_MTU_PROBES) {
            lost[i] = INVALID_BYTE_COUNT
            i += 1
        }
    }

    /// 启动 MTU 发现过程。
    public func start(nowNs: Int64): Unit {
        lastProbeTimeNs = nowNs
        started = true
    }

    /// 是否应发送探测包。
    public func shouldSendProbe(nowNs: Int64): Bool {
        if (!started) { return false }
        if (inFlightSize != INVALID_BYTE_COUNT || done()) { return false }
        let smoothedRtt = rttStats.smoothedRtt()
        let delay = MTU_PROBE_DELAY * (if (smoothedRtt > 0) { smoothedRtt } else { 100000000 })
        nowNs >= lastProbeTimeNs + delay
    }

    /// 获取下一个探测包的大小。
    /// 返回探测包大小。
    public func getProbeSize(nowNs: Int64): Int64 {
        var size: Int64
        if (lastProbeWasLost) {
            size = (min + lost[0]) / 2
        } else {
            size = (min + maxVal()) / 2
        }
        if (size < min + MAX_MTU_DIFF) { size = min + MAX_MTU_DIFF }
        lastProbeTimeNs = nowNs
        inFlightSize = size
        size
    }

    /// 清除当前正在飞行中的探测（表示探测已发送确认）。
    public func clearInFlight(): Unit {
        inFlightSize = INVALID_BYTE_COUNT
    }

    /// 当前确定的 MTU 大小。
    public func currentSize(): Int64 { min }

    /// MTU 探测是否完成。
    public func done(): Bool {
        let m = maxVal()
        m - min <= MAX_MTU_DIFF + 1
    }

    /// 重置发现过程（例如切换路径后）。
    public func reset(nowNs: Int64, start: Int64, max: Int64): Unit {
        generation += 1
        lastProbeTimeNs = nowNs
        lastProbeWasLost = false
        inFlightSize = INVALID_BYTE_COUNT
        min = start
        lost[0] = max
        var i: Int64 = 1
        while (i < MAX_LOST_MTU_PROBES) {
            lost[i] = INVALID_BYTE_COUNT
            i += 1
        }
    }

    /// ACK 处理——探测成功。
    public func onAcked(size: Int64): Unit {
        if (inFlightSize == INVALID_BYTE_COUNT) { return }
        inFlightSize = INVALID_BYTE_COUNT
        min = size
        lastProbeWasLost = false
        // 移除 lost 数组中所有小于 size 的值
        var j: Int64 = 0
        var i: Int64 = 0
        while (i < MAX_LOST_MTU_PROBES) {
            if (size < lost[i]) { j = i; break }
            i += 1
        }
        if (j > 0) {
            i = 0
            while (i < MAX_LOST_MTU_PROBES) {
                if (i + j < MAX_LOST_MTU_PROBES) {
                    lost[i] = lost[i + j]
                } else {
                    lost[i] = INVALID_BYTE_COUNT
                }
                i += 1
            }
        }
    }

    /// 丢失处理——探测丢失。
    public func onLost(): Unit {
        let size = inFlightSize
        if (size == INVALID_BYTE_COUNT) { return }
        lastProbeWasLost = true
        inFlightSize = INVALID_BYTE_COUNT
        var i: Int64 = 0
        while (i < MAX_LOST_MTU_PROBES) {
            if (size < lost[i]) {
                // 将 size 插入到 lost[i] 位置，后面的元素后移
                var j: Int64 = MAX_LOST_MTU_PROBES - 1
                while (j > i) {
                    lost[j] = lost[j - 1]
                    j -= 1
                }
                lost[i] = size
                break
            }
            i += 1
        }
    }

    private func maxVal(): Int64 {
        var i: Int64 = 0
        while (i < MAX_LOST_MTU_PROBES) {
            if (lost[i] == INVALID_BYTE_COUNT) {
                return if (i > 0) { lost[i - 1] } else { lost[0] }
            }
            i += 1
        }
        lost[MAX_LOST_MTU_PROBES - 1]
    }
}

/// 创建 MtuFinder。
public func newMtuFinder(rttStats: RTTStats, start: Int64, max: Int64): MtuFinder {
    MtuFinder(rttStats, start, max)
}
