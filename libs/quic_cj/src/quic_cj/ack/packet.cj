package quic_cj.ack

import quic_cj.protocol.{PacketNumber, EncryptionLevel}
import quic_cj.wire.Frame

/// 表示已发送到网络上的包。
public class SentPacket {
    public var packetNumber: PacketNumber = 0
    public var frames: Array<Frame> = []
    public var encLevel: EncryptionLevel = EncryptionLevel.Initial
    public var size: Int64 = 0
    public var sendTime: Int64 = 0
    public var largestAcked: PacketNumber = -1
    public var isPathMTUProbe: Bool = false
    public var isPathProbe: Bool = false

    /// 如果此包仍在等待 ACK，返回 true。
    public func outstanding(): Bool {
        !isPathMTUProbe && !isPathProbe && isAckEliciting()
    }

    /// 如果此包包含触发 ACK 的帧，返回 true。
    public func isAckEliciting(): Bool {
        frames.size > 0
    }
}
