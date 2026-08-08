package quic_cj.congestion

import quic_cj.protocol.{PacketNumber, INITIAL_PACKET_SIZE}

private let INITIAL_MAX_DATAGRAM_SIZE: Int64 = INITIAL_PACKET_SIZE
private let MIN_CONGESTION_WINDOW_PACKETS: Int64 = 2
private let INITIAL_CONGESTION_WINDOW: Int64 = 32

public class NewRenoSender <: CongestionAlgorithm {
    private var largestSentPacketNumber: PacketNumber = 0
    private var largestSentAtLastCutback: PacketNumber = 0
    private var cwndBytes: Int64 = INITIAL_CONGESTION_WINDOW * INITIAL_MAX_DATAGRAM_SIZE
    private var ssthresh: Int64 = Int64(1 << 62)
    private var maxDatagramSize: Int64 = INITIAL_MAX_DATAGRAM_SIZE
    private var inSlowStartState: Bool = true
    private var inRecoveryState: Bool = false
    private var numAckedPackets: Int64 = 0
    private var pacer: Pacer = Pacer()

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
            if (cwndPackets >= ssthresh / maxDatagramSize) {
                inSlowStartState = false
            }
        } else if (!inRecoveryState) {
            if (numAckedPackets >= cwndBytes / maxDatagramSize) {
                cwndBytes += maxDatagramSize
                numAckedPackets = 0
            }
        }
        updatePacerBandwidth()
    }

    public func onCongestionEvent(lostBytes: Int64, priorInFlight: Int64): Unit {
        if (inRecoveryState) { return }
        inSlowStartState = false
        inRecoveryState = true
        ssthresh = max(cwndBytes / 2, MIN_CONGESTION_WINDOW_PACKETS * maxDatagramSize)
        cwndBytes = ssthresh + lostBytes
        largestSentAtLastCutback = largestSentPacketNumber
        numAckedPackets = 0
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
        let rtt = UInt64(100)
        if (rtt > 0u64) {
            let bw = UInt64(cwndBytes) * 8000u64 / rtt
            pacer.setBandwidth(bw)
        }
    }
}

private func max(a: Int64, b: Int64): Int64 {
    if (a > b) { a } else { b }
}

public func newNewRenoSender(): NewRenoSender {
    NewRenoSender()
}
