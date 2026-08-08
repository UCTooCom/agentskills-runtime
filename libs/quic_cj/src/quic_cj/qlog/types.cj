package quic_cj.qlog

/// QlogEventType 表示 qlog 事件的类型（RFC 9421）。
public enum QlogEventType {
    | ConnectionStarted
    | ConnectionClosed
    | PacketSent
    | PacketReceived
    | PacketLost
    | HandshakeStarted
    | HandshakeCompleted
    | KeyUpdated
    | CongestionUpdated
    | StreamCreated
    | StreamClosed
    | StreamReset
    | TransportError
}

/// QlogEvent 是一个结构化的 QUIC 事件记录。
public class QlogEvent {
    public var eventType: QlogEventType = QlogEventType.ConnectionStarted
    public var timeMs: Int64 = 0
    public var data: String = ""

    public init(eventType: QlogEventType, timeMs: Int64, data: String) {
        this.eventType = eventType
        this.timeMs = timeMs
        this.data = data
    }

    /// 返回事件的简短名称。
    public func name(): String {
        match (eventType) {
            case QlogEventType.ConnectionStarted => "connection_started"
            case QlogEventType.ConnectionClosed => "connection_closed"
            case QlogEventType.PacketSent => "packet_sent"
            case QlogEventType.PacketReceived => "packet_received"
            case QlogEventType.PacketLost => "packet_lost"
            case QlogEventType.HandshakeStarted => "handshake_started"
            case QlogEventType.HandshakeCompleted => "handshake_completed"
            case QlogEventType.KeyUpdated => "key_updated"
            case QlogEventType.CongestionUpdated => "congestion_updated"
            case QlogEventType.StreamCreated => "stream_created"
            case QlogEventType.StreamClosed => "stream_closed"
            case QlogEventType.StreamReset => "stream_reset"
            case QlogEventType.TransportError => "transport_error"
        }
    }
}
