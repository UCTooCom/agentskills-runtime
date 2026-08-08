package quic_cj.ack

import quic_cj.protocol.{PacketNumber, EncryptionLevel, ECN}
import quic_cj.wire.{Frame, AckFrame}

/// AckHandler 处理所有加密级别的 ACK 相关操作。
open public class AckHandler {
    /// 记录已发送的包。
    open public func sentPacket(pn: PacketNumber, frames: Array<Frame>, encLevel: EncryptionLevel, size: Int64): Unit {
        throw Exception("AckHandler.sentPacket: not implemented")
    }

    /// 处理传入的 ACK 帧。
    open public func receivedAck(frame: AckFrame, encLevel: EncryptionLevel): Bool {
        throw Exception("AckHandler.receivedAck: not implemented")
    }

    /// 确定可以发送哪种包。
    open public func sendMode(): SendMode {
        SendMode.Any
    }

    /// 返回距离下一个包可以发送的时间（用于调速）。
    open public func timeUntilSend(): Int64 { 0 }

    /// 返回下一个丢包检测超时时间（毫秒）。
    open public func getLossDetectionTimeout(): Int64 { -1 }

    /// 丢包检测定时器触发时调用。
    open public func onLossDetectionTimeout(): Unit {
        throw Exception("AckHandler.onLossDetectionTimeout: not implemented")
    }
}

/// 返回新的 AckHandler 实例（目前为桩）。
public func newAckHandler(): AckHandler {
    AckHandler()
}
