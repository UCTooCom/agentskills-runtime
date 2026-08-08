package quic_cj.qlog

/// Tracer 是 qlog 事件追踪器接口。
/// 实现此接口以消费 QUIC 事件日志。
open public class Tracer {
    /// 记录一个 qlog 事件。
    open public func logEvent(event: QlogEvent): Unit {}

    /// 记录一次连接建立事件。
    public func logConnectionStarted(perspective: String, localAddr: String, remoteAddr: String, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.ConnectionStarted, timeMs,
            "{" + "\"perspective\":\"" + perspective + "\",\"local\":\"" + localAddr + "\",\"remote\":\"" + remoteAddr + "\"}" ))
    }

    /// 记录一次连接关闭事件。
    public func logConnectionClosed(errorCode: UInt64, reason: String, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.ConnectionClosed, timeMs,
            "{" + "\"error_code\":" + Int64(errorCode).toString() + ",\"reason\":\"" + reason + "\"}" ))
    }

    /// 记录一次包发送事件。
    public func logPacketSent(pn: Int64, encLevel: String, size: Int64, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.PacketSent, timeMs,
            "{" + "\"packet_number\":" + pn.toString() + ",\"encryption_level\":\"" + encLevel + "\",\"size\":" + size.toString() + "}" ))
    }

    /// 记录一次包接收事件。
    public func logPacketReceived(pn: Int64, encLevel: String, size: Int64, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.PacketReceived, timeMs,
            "{" + "\"packet_number\":" + pn.toString() + ",\"encryption_level\":\"" + encLevel + "\",\"size\":" + size.toString() + "}" ))
    }

    /// 记录一次丢包事件。
    public func logPacketLost(pn: Int64, encLevel: String, size: Int64, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.PacketLost, timeMs,
            "{" + "\"packet_number\":" + pn.toString() + ",\"encryption_level\":\"" + encLevel + "\",\"size\":" + size.toString() + "}" ))
    }

    /// 记录握手开始事件。
    public func logHandshakeStarted(isV2: Bool, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.HandshakeStarted, timeMs,
            "{" + "\"is_v2\":" + (if (isV2) { "true" } else { "false" }) + "}" ))
    }

    /// 记录握手完成事件。
    public func logHandshakeCompleted(timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.HandshakeCompleted, timeMs, "{}"))
    }

    /// 记录密钥更新事件。
    public func logKeyUpdated(phase: Int64, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.KeyUpdated, timeMs,
            "{" + "\"key_phase\":" + phase.toString() + "}" ))
    }

    /// 记录拥塞状态更新事件。
    public func logCongestionUpdated(cwnd: Int64, ssthresh: Int64, inRecovery: Bool, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.CongestionUpdated, timeMs,
            "{" + "\"cwnd\":" + cwnd.toString() + ",\"ssthresh\":" + ssthresh.toString() + ",\"in_recovery\":" + (if (inRecovery) { "true" } else { "false" }) + "}" ))
    }

    /// 记录传输层错误事件。
    public func logTransportError(errorCode: UInt64, message: String, timeMs: Int64): Unit {
        logEvent(QlogEvent(QlogEventType.TransportError, timeMs,
            "{" + "\"error_code\":" + Int64(errorCode).toString() + ",\"message\":\"" + message + "\"}" ))
    }
}
