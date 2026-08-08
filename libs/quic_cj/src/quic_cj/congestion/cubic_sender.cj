package quic_cj.congestion

import quic_cj.protocol.{PacketNumber, INITIAL_PACKET_SIZE}

private let INITIAL_MAX_DATAGRAM_SIZE: Int64 = INITIAL_PACKET_SIZE
private let MAX_BURST_PACKETS: Int64 = 3
private let MIN_CONGESTION_WINDOW_PACKETS: Int64 = 2
private let INITIAL_CONGESTION_WINDOW: Int64 = 32

/// 实现基于 CUBIC 的拥塞控制。
public class CubicSender <: CongestionAlgorithm {
    private var hybridSlowStart: HybridSlowStart = HybridSlowStart()
    private var cubic: Cubic = Cubic()
    private var pacer: Pacer = Pacer()

    private var largestSentPacketNumber: PacketNumber = 0
    private var largestSentAtLastCutback: PacketNumber = 0
    private var cwndBytes: Int64 = INITIAL_CONGESTION_WINDOW * INITIAL_MAX_DATAGRAM_SIZE
    private var ssthresh: Int64 = Int64(1 << 62)
    private var maxDatagramSize: Int64 = INITIAL_MAX_DATAGRAM_SIZE
    private var inSlowStartState: Bool = true
    private var inRecoveryState: Bool = false
    private var initialCwnd: Int64 = INITIAL_CONGESTION_WINDOW * INITIAL_MAX_DATAGRAM_SIZE
    private var numAckedPackets: Int64 = 0

    public init() {
        updatePacerBandwidth()
    }

    public func canSend(bytesInFlight: Int64): Bool {
        bytesInFlight < cwndBytes
    }

    public func onPacketSent(sentTime: Int64, bytesInFlight: Int64, bytes: Int64): Unit {
        largestSentPacketNumber += 1
        pacer.sentPacket(sentTime, bytes)
    }

    public func onPacketAcked(ackedBytes: Int64, priorInFlight: Int64): Unit {
        numAckedPackets += 1
        if (inSlowStartState) {
            cwndBytes += ackedBytes
            let cwndPackets = cwndBytes / maxDatagramSize
            if (cwndPackets >= INITIAL_CONGESTION_WINDOW) {
                inSlowStartState = false
                ssthresh = cwndBytes
            } else if (hybridSlowStart.shouldExitSlowStart(0, 0, cwndPackets)) {
                inSlowStartState = false
                ssthresh = cwndBytes
            }
        } else {
            if (numAckedPackets >= cwndBytes / maxDatagramSize) {
                cwndBytes += maxDatagramSize
                numAckedPackets = 0
            }
        }
        updatePacerBandwidth()
    }

    public func onCongestionEvent(lostBytes: Int64, priorInFlight: Int64): Unit {
        inSlowStartState = false
        inRecoveryState = true
        ssthresh = cwndBytes * 7 / 10
        cwndBytes = ssthresh
        if (cwndBytes < MIN_CONGESTION_WINDOW_PACKETS * maxDatagramSize) {
            cwndBytes = MIN_CONGESTION_WINDOW_PACKETS * maxDatagramSize
        }
        updatePacerBandwidth()
    }

    public func getCwnd(): Int64 { cwndBytes }
    public func slowStartThreshold(): Int64 { ssthresh }
    public func inSlowStart(): Bool { inSlowStartState }
    public func inRecovery(): Bool { inRecoveryState }

    public func timeUntilSend(bytesInFlight: Int64): Int64 {
        if (bytesInFlight < cwndBytes) { return 0 }
        pacer.timeUntilSend()
    }

    public func hasPacingBudget(now: Int64): Bool {
        pacer.budget(now) >= maxDatagramSize
    }

    private func updatePacerBandwidth(): Unit {
        let rtt = UInt64(100) // 默认 100 毫秒
        if (rtt > 0u64) {
            let bw = UInt64(cwndBytes) * 8000u64 / rtt  // 字节/秒
            pacer.setBandwidth(bw)
        }
    }
}

/// 创建新的 CUBIC 拥塞控制器。
public func newCubicSender(): CubicSender {
    CubicSender()
}
