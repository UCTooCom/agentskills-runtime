package quic_cj.congestion

import quic_cj.protocol.PacketNumber

private let HYBRID_START_LOW_WINDOW: Int64 = 16
private let HYBRID_START_MIN_SAMPLES: Int64 = 8
private let HYBRID_START_DELAY_FACTOR_EXP: Int64 = 3
private let HYBRID_START_DELAY_MIN_THRESHOLD_US: Int64 = 4000
private let HYBRID_START_DELAY_MAX_THRESHOLD_US: Int64 = 16000

/// 实现 TCP 混合慢启动（RFC 3742）。
public class HybridSlowStart {
    private var endPacketNumber: PacketNumber = 0
    private var lastSentPacketNumber: PacketNumber = 0
    private var started: Bool = false
    private var currentMinRttUs: Int64 = 0
    private var rttSampleCount: Int64 = 0
    private var hystartFound: Bool = false

    /// 标记新一轮慢启动接收的开始。
    public func startReceiveRound(lastSent: PacketNumber): Unit {
        endPacketNumber = lastSent
        currentMinRttUs = 0
        rttSampleCount = 0
        started = true
    }

    /// 检查此 ACK 是否结束当前接收轮次。
    public func isEndOfRound(ack: PacketNumber): Bool {
        endPacketNumber < ack
    }

    /// 检查是否应根据 RTT 增加退出慢启动。
    public func shouldExitSlowStart(
        latestRttUs: Int64,
        minRttUs: Int64,
        congestionWindowPackets: Int64
    ): Bool {
        if (!started) {
            startReceiveRound(lastSentPacketNumber)
        }
        if (hystartFound) { return true }
        if (congestionWindowPackets < HYBRID_START_LOW_WINDOW) { return false }

        // 延迟增加检测：跟踪每个突发的最小 RTT
        rttSampleCount += 1
        if (rttSampleCount <= HYBRID_START_MIN_SAMPLES) {
            if (currentMinRttUs == 0 || currentMinRttUs > latestRttUs) {
                currentMinRttUs = latestRttUs
            }
        }

        // 收集足够样本后检查阈值
        if (rttSampleCount == HYBRID_START_MIN_SAMPLES) {
            var minRttIncreaseUs = minRttUs >> HYBRID_START_DELAY_FACTOR_EXP
            if (minRttIncreaseUs < HYBRID_START_DELAY_MIN_THRESHOLD_US) {
                minRttIncreaseUs = HYBRID_START_DELAY_MIN_THRESHOLD_US
            }
            if (minRttIncreaseUs > HYBRID_START_DELAY_MAX_THRESHOLD_US) {
                minRttIncreaseUs = HYBRID_START_DELAY_MAX_THRESHOLD_US
            }
            if (currentMinRttUs > (minRttUs + minRttIncreaseUs)) {
                hystartFound = true
                return true
            }
        }
        false
    }

    /// 返回慢启动跟踪是否已开始。
    public func isStarted(): Bool { started }

    /// 返回是否检测到延迟增加。
    public func isFound(): Bool { hystartFound }
}
