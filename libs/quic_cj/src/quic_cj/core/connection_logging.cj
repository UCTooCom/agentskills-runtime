package quic_cj.core

import quic_cj.protocol.{ECN, PacketNumber}
import quic_cj.wire.{Frame, CryptoFrame, StreamFrame, AckFrame, DatagramFrame}

/// QlogFrame 保存 QUIC 帧的可日志表示，已剥离数据切片。
public class QlogFrame {
    public var frameType: String = "other"
    public var streamId: Int64 = -1
    public var offset: Int64 = -1
    public var length: Int64 = -1
    public var fin: Bool = false

    public init() {}
}

/// QlogPacketType 提供包类型字符串常量。
public class QlogPacketType {
    public static let INITIAL: String = "initial"
    public static let HANDSHAKE: String = "handshake"
    public static let ZERO_RTT: String = "0rtt"
    public static let ONE_RTT: String = "1rtt"
    public static let RETRY: String = "retry"
}

/// ConvertFrame 通过填充字段将 wire Frame 转换为 QlogFrame。
public func toQlogFrame(frame: Frame): QlogFrame {
    let qf = QlogFrame()
    _populateQlogFrame(frame, qf)
    qf
}

private func _populateQlogFrame(frame: Frame, qf: QlogFrame): Unit {
    if (frame is CryptoFrame) {
        qf.frameType = "crypto"
        let r = frame as CryptoFrame
        if (let Some(f) <- r) { qf.offset = f.offset; qf.length = Int64(f.data.size) }
    } else if (frame is StreamFrame) {
        qf.frameType = "stream"
        let r = frame as StreamFrame
        if (let Some(f) <- r) { qf.streamId = f.streamId; qf.offset = f.offset; qf.length = Int64(f.data.size); qf.fin = f.fin }
    } else if (frame is AckFrame) {
        qf.frameType = "ack"
    } else if (frame is DatagramFrame) {
        qf.frameType = "datagram"
        let r = frame as DatagramFrame
        if (let Some(f) <- r) { qf.length = Int64(f.data.size) }
    }
}

/// QlogEcn 将 ECN 值转换为 qlog ECN 字符串。
public func toQlogEcn(ecn: ECN): String {
    match (ecn) {
        case ECN.ECT0 => "ECT0"
        case ECN.ECT1 => "ECT1"
        case ECN.CE => "ECN-CE"
        case _ => "Unsupported"
    }
}

/// QlogPacketTypeStr 将包类型字节转换为 qlog 字符串。
public func toQlogPacketTypeStr(pktType: UInt8): String {
    let highNibble = (pktType >> 4) & 0x0fu8
    match (highNibble) {
        case 0xCu8 => QlogPacketType.INITIAL
        case 0xEu8 => QlogPacketType.RETRY
        case 0xDu8 => QlogPacketType.HANDSHAKE
        case 0xFu8 => QlogPacketType.ZERO_RTT
        case _ => "unknown"
    }
}

/// LogPacketDebug 是记录已发送包调试信息的桩函数。
public func logPacketDebug(prefix: String, pktNum: PacketNumber, size: Int64, connId: String, encLevel: String, ecn: ECN): Unit { () }
public func logFrameDebug(typeName: String, sent: Bool): Unit { () }
public func logConnectionEvent(event: String, connId: String): Unit { () }
