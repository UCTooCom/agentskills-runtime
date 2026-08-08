package quic_cj.congestion

/// 定义拥塞控制的接口。
open public class CongestionAlgorithm {
    open public func timeUntilSend(bytesInFlight: Int64): Int64 { 0 }
    open public func hasPacingBudget(now: Int64): Bool { true }
    open public func canSend(bytesInFlight: Int64): Bool { true }
    open public func onPacketSent(sentTime: Int64, bytesInFlight: Int64, bytes: Int64): Unit {
        throw Exception("CongestionAlgorithm.onPacketSent: not implemented")
    }
    open public func onPacketAcked(ackedBytes: Int64, priorInFlight: Int64): Unit {
        throw Exception("CongestionAlgorithm.onPacketAcked: not implemented")
    }
    open public func onCongestionEvent(lostBytes: Int64, priorInFlight: Int64): Unit {
        throw Exception("CongestionAlgorithm.onCongestionEvent: not implemented")
    }
    open public func getCwnd(): Int64 { 0 }
    open public func slowStartThreshold(): Int64 { 0 }
    open public func inSlowStart(): Bool { false }
    open public func inRecovery(): Bool { false }
}
