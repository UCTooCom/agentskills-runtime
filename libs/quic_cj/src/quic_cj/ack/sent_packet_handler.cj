package quic_cj.ack

import quic_cj.protocol.{PacketNumber, EncryptionLevel, ECN}
import quic_cj.wire.{AckFrame, Frame}
import quic_cj.congestion.{CongestionAlgorithm, CubicSender, newCubicSender}
/// 处理传出包的 ACK 和丢包检测。
public class SentPacketHandler {
    private var sentPacketHistory: SentPacketHistory = SentPacketHistory()
    private var congestion: CongestionAlgorithm = newCubicSender()
    private var largestAcked: PacketNumber = -1
    private var largestReceivedAck: PacketNumber = -1
    
    /// 替换拥塞控制算法。必须在发送任何包之前调用。
    public func setCongestionAlgorithm(algo: CongestionAlgorithm): Unit {
        congestion = algo
    }
    
    /// 记录已发送的包。
    public func sentPacket(pn: PacketNumber, frames: Array<Frame>, encLevel: EncryptionLevel, size: Int64): Unit {
        let pkt = SentPacket()
        pkt.packetNumber = pn
        pkt.frames = frames
        pkt.encLevel = encLevel
        pkt.size = size
        sentPacketHistory.sentPacket(pn, pkt)
    }

    /// 处理传入的 ACK 帧，检测丢包，返回丢失帧列表。
    /// 已确认的包会从历史记录中移除，丢失的帧会被收集回来。
    public func receivedAck(frame: AckFrame, encLevel: EncryptionLevel): Array<Frame> {
        var lostFrames: Array<Frame> = []
        let largest = frame.largestAcked
        if (largest <= largestReceivedAck) { return lostFrames }
        largestReceivedAck = largest

        // 构建已确认 PN 的区间列表
        let count = frame.ackRangeCount
        var ackedStart: Array<Int64> = Array<Int64>(count, repeat: 0)
        var ackedEnd: Array<Int64> = Array<Int64>(count, repeat: 0)
        var i: Int64 = 0
        while (i < count) {
            let (s, e) = frame.getAckRange(i)
            ackedStart[i] = s
            ackedEnd[i] = e
            i += 1
        }

        // 遍历已发送历史，删除已确认的包，收集丢失的帧
        var entries = sentPacketHistory.getOutstandingEntries()
        var j: Int64 = 0
        while (j < entries.size) {
            let pn = entries[j].packetNumber
            let pkt = entries[j].packet
            if (isInAckedRanges(pn, ackedStart, ackedEnd, count)) {
                sentPacketHistory.remove(pn)
            } else if (pn <= largest) {
                if (pkt.outstanding() && pkt.frames.size > 0) {
                    var k: Int64 = 0
                    while (k < pkt.frames.size) {
                        lostFrames = appendLostFrame(lostFrames, pkt.frames[k])
                        k += 1
                    }
                }
                sentPacketHistory.remove(pn)
            }
            j += 1
        }

        lostFrames
    }

    /// SendMode 确定当前发送模式。
    public func sendMode(): SendMode {
        if (!congestion.canSend(0)) { return SendMode.PacingLimited }
        SendMode.Any
    }

    /// 返回下一个包可以发送的时间。
    public func timeUntilSend(): Int64 { congestion.timeUntilSend(0) }

    /// 丢包检测定时器到期时调用。
    public func onLossDetectionTimeout(): Unit {}

    /// 返回下一个超时时间（毫秒），如果没有则返回 -1。
    public func getLossDetectionTimeout(): Int64 { -1 }

    /// 返回已发送包历史。
    public func getHistory(): SentPacketHistory { sentPacketHistory }

    /// 检查指定 PN 是否在已确认区间中。
    private func isInAckedRanges(pn: PacketNumber, starts: Array<Int64>, ends: Array<Int64>, count: Int64): Bool {
        var i: Int64 = 0
        while (i < count) {
            if (pn >= starts[i] && pn <= ends[i]) { return true }
            i += 1
        }
        false
    }
}

/// 创建已发送包处理器。
public func newSentPacketHandler(): SentPacketHandler {
    SentPacketHandler()
}

/// 将一个 Frame 追加到 Array<Frame>。
internal func appendLostFrame(arr: Array<Frame>, f: Frame): Array<Frame> {
    let n = arr.size
    var out = Array<Frame>(n + 1, repeat: Frame())
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = f
    out
}
