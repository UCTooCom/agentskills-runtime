package quic_cj.util

import quic_cj.protocol.TIMER_GRANULARITY_MS

// RTT 平滑常量（定点：alpha=0.125 -> 128/1024，beta=0.25 -> 256/1024）
private let RTT_ALPHA_FP: Int64 = 128   // 0.125 * 1024
private let ONE_MINUS_ALPHA_FP: Int64 = 896 // 0.875 * 1024
private let RTT_BETA_FP: Int64 = 256    // 0.25 * 1024
private let ONE_MINUS_BETA_FP: Int64 = 768 // 0.75 * 1024
private let FP_SCALE: Int64 = 1024

/// 默认初始 RTT，在测量之前使用（100 毫秒）。
public let DEFAULT_INITIAL_RTT_US: Int64 = 100000  // 微秒

/// RTTStats 提供用于丢包检测和拥塞控制的往返时间统计。
public class RTTStats {
    private var hasMeasurement: Bool = false
    private var minRttUs: Int64 = DEFAULT_INITIAL_RTT_US
    private var latestRttUs: Int64 = DEFAULT_INITIAL_RTT_US
    private var smoothedRttUs: Int64 = DEFAULT_INITIAL_RTT_US
    private var meanDeviationUs: Int64 = 0
    private var maxAckDelayUs: Int64 = 25000 // 默认 25 毫秒

    /// 返回最小 RTT。
    public func minRtt(): Int64 { minRttUs }

    /// 返回最新的 RTT 测量值。
    public func latestRtt(): Int64 { latestRttUs }

    /// 返回平滑 RTT。
    public func smoothedRtt(): Int64 { smoothedRttUs }

    /// 返回平均偏差。
    public func meanDeviation(): Int64 { meanDeviationUs }

    /// 返回最大 ACK 延迟。
    public func maxAckDelay(): Int64 { maxAckDelayUs }

    /// 计算探测超时持续时间。
    public func pto(includeMaxAckDelay: Bool): Int64 {
        if (!hasMeasurement) { return 2 * DEFAULT_INITIAL_RTT_US / 1000 }
        var ptoMs = smoothedRttUs / 1000 + 4 * (meanDeviationUs / 1000)
        if (ptoMs < TIMER_GRANULARITY_MS) { ptoMs = TIMER_GRANULARITY_MS }
        if (includeMaxAckDelay) { ptoMs += maxAckDelayUs / 1000 }
        ptoMs
    }

    /// 使用新的 RTT 样本（微秒）更新统计信息。
    public func updateRtt(sendDeltaUs: Int64, ackDelayUs: Int64): Unit {
        if (sendDeltaUs <= 0) { return }

        // 更新最小 RTT（使用原始发送增量，而不是 ACK 延迟修正后的值）
        if (!hasMeasurement || minRttUs > sendDeltaUs) {
            minRttUs = sendDeltaUs
        }

        // 如果可能，修正 ACK 延迟
        var sampleUs = sendDeltaUs
        if (sampleUs - minRttUs >= ackDelayUs) {
            sampleUs -= ackDelayUs
        }
        latestRttUs = sampleUs

        if (!hasMeasurement) {
            hasMeasurement = true
            smoothedRttUs = sampleUs
            meanDeviationUs = sampleUs / 2
        } else {
            // smoothedRTT = (1 - alpha) * smoothedRTT + alpha * sample
            let newSmoothed = (smoothedRttUs * ONE_MINUS_ALPHA_FP + sampleUs * RTT_ALPHA_FP) / FP_SCALE
            // meanDev = (1 - beta) * meanDev + beta * |smoothedRTT - sample|
            let absDiff = if (smoothedRttUs > sampleUs) { smoothedRttUs - sampleUs } else { sampleUs - smoothedRttUs }
            let newMeanDev = (meanDeviationUs * ONE_MINUS_BETA_FP + absDiff * RTT_BETA_FP) / FP_SCALE
            smoothedRttUs = newSmoothed
            meanDeviationUs = newMeanDev
        }
    }

    /// 返回是否已进行 RTT 测量。
    public func hasMeas(): Bool { hasMeasurement }

    /// 设置最大 ACK 延迟。
    public func setMaxAckDelay(madUs: Int64): Unit { maxAckDelayUs = madUs }

    /// 设置初始 RTT（如果已有测量则忽略）。
    public func setInitialRtt(rttUs: Int64): Unit {
        if (hasMeasurement) { return }
        smoothedRttUs = rttUs
        latestRttUs = rttUs
    }

    /// 为新路径清除 RTT 状态。
    public func resetForPathMigration(): Unit {
        hasMeasurement = false
        minRttUs = DEFAULT_INITIAL_RTT_US
        latestRttUs = DEFAULT_INITIAL_RTT_US
        smoothedRttUs = DEFAULT_INITIAL_RTT_US
        meanDeviationUs = 0
    }
}

/// 使用默认初始 RTT 创建 RTTStats。
public func newRTTStats(): RTTStats {
    RTTStats()
}
