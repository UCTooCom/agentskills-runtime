package quic_cj.ack

import quic_cj.protocol.{PacketNumber, ECN}
import quic_cj.wire.AckFrame

/// 跟踪收到的包并生成 ACK 帧。
public class ReceivedPacketTracker {
    private var packetHistory: ReceivedPacketHistory = ReceivedPacketHistory()
    private var ect0: Int64 = 0
    private var ect1: Int64 = 0
    private var ecnce: Int64 = 0
    private var hasNewAck: Bool = false
    
    // ACK_FREQUENCY 控制参数（RFC 9002 §6）
    private var ackPacketsAfter: Int64 = 1        // 默认每个包都触发 ACK
    private var ackMaxDelayMicro: Int64 = 25000     // 默认 25ms
    private var ackIgnoreOrder: Bool = false        // 默认不忽略乱序
    private var receivedSinceLastAck: Int64 = 0     // 上次 ACK 后收到的包计数

    /// 设置 ACK 频率参数（由 ACK_FREQUENCY 帧触发）。
    public func setAckFrequency(packetsAfter: Int64, maxDelayMicro: Int64, ignoreOrder: Bool): Unit {
        if (packetsAfter > 0) { ackPacketsAfter = packetsAfter }
        if (maxDelayMicro > 0) { ackMaxDelayMicro = maxDelayMicro }
        ackIgnoreOrder = ignoreOrder
    }

    /// 注册收到的包。
    public func receivedPacket(pn: PacketNumber, ecn: ECN, ackEliciting: Bool): Unit {
        let isNew = packetHistory.receivedPacket(pn)
        if (!isNew) { return }
        match (ecn) {
            case ECN.ECT0 => ect0 += 1
            case ECN.ECT1 => ect1 += 1
            case ECN.CE => ecnce += 1
            case _ => ()
        }
        // ACK 频率控制：仅在达到阈值时触发 ACK
        if (ackEliciting || ackIgnoreOrder) {
            receivedSinceLastAck += 1
            if (receivedSinceLastAck >= ackPacketsAfter) {
                hasNewAck = true
            }
        } else if (ackEliciting) {
            hasNewAck = true
        }
    }

    /// 如果有新数据需要 ACK，返回 ACK 帧。
    public func getAckFrame(): Option<AckFrame> {
        if (!hasNewAck) { return None }
        let ack = AckFrame()
        ack.largestAcked = getLargestAcked()
        ack.ackDelay = 0
        ack.ecnECT0 = ect0
        ack.ecnECT1 = ect1
        ack.ecnCE = ecnce
        ack.ackRangeCount = packetHistory.fillBackwardRanges(ack.ackRanges)
        hasNewAck = false
        receivedSinceLastAck = 0
        Some(ack)
    }

    /// 检查 PN 是否可能是重复的。
    public func isPotentiallyDuplicate(pn: PacketNumber): Bool {
        packetHistory.isPotentiallyDuplicate(pn)
    }

    /// 强制触发立即发送 ACK（由 IMMEDIATE_ACK 帧触发，RFC 9002 §5）。
    public func requestImmediateAck(): Unit {
        hasNewAck = true
    }

    private func getLargestAcked(): PacketNumber {
        packetHistory.getLargestAcked()
    }
}
