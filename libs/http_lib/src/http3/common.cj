/**
 * HTTP/3 (QUIC) 常量、枚举和错误码（RFC 9114）。
 * HTTP/3 在 QUIC 基础上运行，提供与 HTTP/2 等效的语义，
 * 但使用不同的传输编码和帧格式。
 *
 * HTTP/3 帧在 QUIC 流上编码，帧头格式为：
 *   Type (varint) + Length (varint) + Payload
 *
 * 注意：本文件定义了 HTTP/3 的类型系统。帧收发和管理在 connection.cj 和
 * quic_io_driver.cj 中实现，这些类型定义了协议常量供运行时使用。
 *
 * @see https://www.rfc-editor.org/rfc/rfc9114
 * @see https://www.rfc-editor.org/rfc/rfc9000 (QUIC)
 */
package http_lib.http3
import std.collection.HashMap


// ======== QL 传输层 ========
// HTTP/3 需要 QUIC (RFC 9000) 传输层支持。
// 当前项目不包含 QUIC 实现，HTTP/3 实际运行需要外部 QUIC 堆栈。

// ======== QUIC 传输错误码（RFC 9000 §20.1）========
public enum QuicTransportErrorCode {
    | NO_ERROR
    | INTERNAL_ERROR
    | CONNECTION_REFUSED
    | FLOW_CONTROL_ERROR
    | STREAM_LIMIT_ERROR
    | STREAM_STATE_ERROR
    | FINAL_SIZE_ERROR
    | FRAME_ENCODING_ERROR
    | TRANSPORT_PARAMETER_ERROR
    | CONNECTION_ID_LIMIT_ERROR
    | PROTOCOL_VIOLATION
    | INVALID_TOKEN
    | APPLICATION_ERROR
    | CRYPTO_BUFFER_EXCEEDED
    | KEY_UPDATE_ERROR
    | AEAD_LIMIT_REACHED
    | NO_VIABLE_PATH
}

// ======== HTTP/3 错误码（RFC 9114 §8）========
public enum Http3ErrorCode <: Equatable<Http3ErrorCode> {
    | H3_NO_ERROR
    | H3_GENERAL_PROTOCOL_ERROR
    | H3_INTERNAL_ERROR
    | H3_STREAM_CREATION_ERROR
    | H3_CLOSED_CRITICAL_STREAM
    | H3_FRAME_UNEXPECTED
    | H3_FRAME_ERROR
    | H3_EXCESSIVE_LOAD
    | H3_ID_ERROR
    | H3_SETTINGS_ERROR
    | H3_MISSING_SETTINGS
    | H3_REQUEST_REJECTED
    | H3_REQUEST_CANCELLED
    | H3_REQUEST_INCOMPLETE
    | H3_MESSAGE_ERROR
    | H3_CONNECT_ERROR
    | H3_VERSION_FALLBACK
    | H3_QPACK_DECOMPRESSION_FAILED
    | H3_QPACK_ENCODER_STREAM_ERROR
    | H3_QPACK_DECODER_STREAM_ERROR

    public func toUInt16(): UInt16 {
        match (this) {
            case H3_NO_ERROR => 0x0100u16
            case H3_GENERAL_PROTOCOL_ERROR => 0x0101u16
            case H3_INTERNAL_ERROR => 0x0102u16
            case H3_STREAM_CREATION_ERROR => 0x0103u16
            case H3_CLOSED_CRITICAL_STREAM => 0x0104u16
            case H3_FRAME_UNEXPECTED => 0x0105u16
            case H3_FRAME_ERROR => 0x0106u16
            case H3_EXCESSIVE_LOAD => 0x0107u16
            case H3_ID_ERROR => 0x0109u16
            case H3_SETTINGS_ERROR => 0x010Au16
            case H3_MISSING_SETTINGS => 0x010Bu16
            case H3_REQUEST_REJECTED => 0x010Cu16
            case H3_REQUEST_CANCELLED => 0x010Du16
            case H3_REQUEST_INCOMPLETE => 0x010Eu16
            case H3_MESSAGE_ERROR => 0x010Fu16
            case H3_CONNECT_ERROR => 0x0110u16
            case H3_VERSION_FALLBACK => 0x0111u16
            case H3_QPACK_DECOMPRESSION_FAILED => 0x0200u16
            case H3_QPACK_ENCODER_STREAM_ERROR => 0x0201u16
            case H3_QPACK_DECODER_STREAM_ERROR => 0x0202u16
        }
    }

    public operator func ==(that: Http3ErrorCode): Bool {
        this.toUInt16() == that.toUInt16()
    }

    public operator func !=(that: Http3ErrorCode): Bool {
        !(this == that)
    }
}

// ======== HTTP/3 帧类型（RFC 9114 §7）========
public enum Http3FrameType <: ToString & Equatable<Http3FrameType> {
    | DATA              // 0x00
    | HEADERS           // 0x01
    | CANCEL_PUSH       // 0x03
    | SETTINGS          // 0x04
    | PUSH_PROMISE      // 0x05
    | GOAWAY            // 0x07
    | MAX_PUSH_ID       // 0x0D

    public func toUInt8(): UInt8 {
        match (this) {
            case DATA => 0x00
            case HEADERS => 0x01
            case CANCEL_PUSH => 0x03
            case SETTINGS => 0x04
            case PUSH_PROMISE => 0x05
            case GOAWAY => 0x07
            case MAX_PUSH_ID => 0x0D
        }
    }

    public static func fromUInt8(v: UInt8): Http3FrameType {
        match (v) {
            case 0x00 => DATA
            case 0x01 => HEADERS
            case 0x03 => CANCEL_PUSH
            case 0x04 => SETTINGS
            case 0x05 => PUSH_PROMISE
            case 0x07 => GOAWAY
            case 0x0D => MAX_PUSH_ID
            case _ => throw Http3Exception(Http3ErrorCode.H3_FRAME_ERROR, "unknown H3 frame type: ${v}")
        }
    }

    public func toString(): String {
        match (this) {
            case DATA => "DATA"
            case HEADERS => "HEADERS"
            case CANCEL_PUSH => "CANCEL_PUSH"
            case SETTINGS => "SETTINGS"
            case PUSH_PROMISE => "PUSH_PROMISE"
            case GOAWAY => "GOAWAY"
            case MAX_PUSH_ID => "MAX_PUSH_ID"
        }
    }

    public operator func ==(that: Http3FrameType): Bool {
        this.toUInt8() == that.toUInt8()
    }

    public operator func !=(that: Http3FrameType): Bool {
        !(this == that)
    }
}

// ======== HTTP/3 SETTINGS 标识符（RFC 9114 §7.2.4）========
public enum Http3SettingsId <: ToString & Equatable<Http3SettingsId> {
    | QPACK_MAX_TABLE_CAPACITY       // 0x01
    | MAX_FIELD_SECTION_SIZE         // 0x06
    | SETTINGS_QPACK_BLOCKED_STREAMS // 0x07
    | ENABLE_CONNECT_PROTOCOL        // 0x08
    | H3_DATAGRAM                    // 0x33

    public func toUInt16(): UInt16 {
        match (this) {
            case QPACK_MAX_TABLE_CAPACITY => 0x01
            case MAX_FIELD_SECTION_SIZE => 0x06
            case SETTINGS_QPACK_BLOCKED_STREAMS => 0x07
            case ENABLE_CONNECT_PROTOCOL => 0x08
            case H3_DATAGRAM => 0x33
        }
    }

    public static func fromUInt16(v: UInt16): ?Http3SettingsId {
        match (v) {
            case 0x01 => Some(QPACK_MAX_TABLE_CAPACITY)
            case 0x06 => Some(MAX_FIELD_SECTION_SIZE)
            case 0x07 => Some(SETTINGS_QPACK_BLOCKED_STREAMS)
            case 0x08 => Some(ENABLE_CONNECT_PROTOCOL)
            case 0x33 => Some(H3_DATAGRAM)
            case _ => None
        }
    }

    public func toString(): String {
        match (this) {
            case QPACK_MAX_TABLE_CAPACITY => "QPACK_MAX_TABLE_CAPACITY"
            case MAX_FIELD_SECTION_SIZE => "MAX_FIELD_SECTION_SIZE"
            case SETTINGS_QPACK_BLOCKED_STREAMS => "SETTINGS_QPACK_BLOCKED_STREAMS"
            case ENABLE_CONNECT_PROTOCOL => "ENABLE_CONNECT_PROTOCOL"
            case H3_DATAGRAM => "H3_DATAGRAM"
        }
    }

    public operator func ==(that: Http3SettingsId): Bool {
        this.toUInt16() == that.toUInt16()
    }

    public operator func !=(that: Http3SettingsId): Bool {
        !(this == that)
    }
}

// ======== HTTP/3 流类型（RFC 9114 §6.2）========
public enum Http3StreamType {
    | CONTROL_STREAM         // 0x00（控制流）
    | PUSH_STREAM            // 0x01（推送流）
    | QPACK_ENCODER_STREAM   // 0x02（QPACK 编码器流）
    | QPACK_DECODER_STREAM   // 0x03（QPACK 解码器流）
}

// ======== HTTP/3 伪头部（RFC 9114 §4.1）========
// HTTP/3 使用与 HTTP/2 相同的伪头部：
//   :method, :scheme, :authority, :path, :status
// 无 :protocol 伪头部（由 CONNECT 方法处理）

/**
 * Extended CONNECT 协议标识符。
 * WebSocket over HTTP/3 (RFC 9220)：:protocol = "websocket"
 * CONNECT-UDP (RFC 9298)：:protocol = "connect-udp"
 */
public let EXTENDED_CONNECT_PROTOCOL_WEBSOCKET: String = "websocket"
public let EXTENDED_CONNECT_PROTOCOL_CONNECT_UDP: String = "connect-udp"
/// WebTransport over HTTP/3 (RFC 9220)：:protocol = "webtransport"
public let EXTENDED_CONNECT_PROTOCOL_WEBTRANSPORT: String = "webtransport"


/**
 * HTTP/3 连接配置。
 * HTTP/3 需要 QUIC 传输层。
 */
public class Http3Config {
    public var maxFieldSectionSize: Int64 = 65536
    public var qpackMaxTableCapacity: Int64 = 4096
    public var qpackBlockedStreams: Int64 = 100
    public var maxPushId: Int64 = 0  // 默认禁用服务端推送
    public var enableConnectProtocol: Bool = true
    public var enableH3Datagram: Bool = false  // HTTP/3 Datagram 支持（RFC 9297）
    public var zeroRttPriorSettings: ?HashMap<UInt16, UInt64> = None

    public init() {}
}

/**
 * HTTP/3 异常。
 */
public class Http3Exception <: Exception {
    public let errorCode: Http3ErrorCode

    public init(errorCode: Http3ErrorCode, message: String) {
        super(message)
        this.errorCode = errorCode
    }
}


// ======== GREASE（RFC 9114 §9.6）========

/**
 * HTTP/3 推荐的 GREASE 帧类型值。
 * 这些值按 RFC 9114 §9.6 推荐使用。
 */
public let GREASE_FRAME_TYPES: Array<UInt64> = [
    0x0Fu64, 0x1Fu64, 0x2Fu64, 0x3Fu64,
    0x4Fu64, 0x5Fu64, 0x6Fu64, 0x7Fu64,
]

/**
 * HTTP/3 推荐的 GREASE 设置标识符值。
 */
public let GREASE_SETTINGS_IDS: Array<UInt16> = [
    0x02u16, 0x03u16, 0x04u16, 0x05u16,
    0x09u16, 0x0Au16, 0x0Bu16, 0x0Cu16,
]

/**
 * HTTP/3 推荐的 GREASE 流类型值。
 */
public let GREASE_STREAM_TYPES: Array<UInt8> = [
    0x04u8, 0x05u8, 0x06u8, 0x07u8,
    0x08u8, 0x09u8, 0x0Au8, 0x0Bu8,
]
