package quic_cj.ack

import quic_cj.protocol.PacketNumber
import quic_cj.congestion.CongestionAlgorithm

private let MAX_LOST_PACKETS: Int64 = 64

/// 跟踪丢包并通知拥塞控制器。
public class LostPacketTracker {
    private var congestion: CongestionAlgorithm
    private var lostPackets: Array<PacketNumber> = Array<PacketNumber>(MAX_LOST_PACKETS, repeat: 0)
    private var lostCount: Int64 = 0

    public init(congestion: CongestionAlgorithm) {
        this.congestion = congestion
    }

    /// 确定包已丢失时调用。
    public func onPacketLost(pn: PacketNumber, lostBytes: Int64, priorInFlight: Int64): Unit {
        congestion.onCongestionEvent(lostBytes, priorInFlight)
        if (lostCount < MAX_LOST_PACKETS) {
            lostPackets[lostCount] = pn
            lostCount += 1
        }
    }

    /// 返回丢失的包编号列表。
    public func getLostPackets(): Array<PacketNumber> {
        let result = Array<PacketNumber>(lostCount, repeat: 0)
        var i: Int64 = 0
        while (i < lostCount) {
            result[i] = lostPackets[i]; i += 1
        }
        result
    }

    /// 清除所有跟踪的丢失包。
    public func clear(): Unit { lostCount = 0 }
}
