package http_lib.http2

/**
 * HTTP/2 常量、枚举和错误码（RFC 9113）。
 * 包含连接前导字节（PRI * HTTP/2.0 魔法字符串）、帧默认参数、
 * 错误码枚举、帧类型枚举和 SETTINGS 标识符枚举。
 */

// ---- 连接前导 ----

public let HTTP2_CLIENT_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
public let HTTP2_CLIENT_PREFACE_BYTES: Array<UInt8> = unsafe { HTTP2_CLIENT_PREFACE.rawData() }

// ---- 帧默认值 ----

public let DEFAULT_MAX_FRAME_SIZE: UInt32 = 16384       // 16 KB（默认最大帧大小）
public let MAX_FRAME_SIZE_LIMIT: UInt32 = 16777215      // 2^24 -1
public let FRAME_HEADER_SIZE: Int64 = 9
public let DEFAULT_INITIAL_WINDOW_SIZE: Int32 = 65535
public let MAX_INITIAL_WINDOW_SIZE: Int32 = 2147483647  // 2^31 -1

// ---- 错误码（RFC 9113 第 7 节）----

public enum Http2ErrorCode <: ToString & Equatable<Http2ErrorCode> {
    | NO_ERROR              // 0x0（无错误）
    | PROTOCOL_ERROR        // 0x1（协议错误）
    | INTERNAL_ERROR        // 0x2（内部错误）
    | FLOW_CONTROL_ERROR    // 0x3（流量控制错误）
    | SETTINGS_TIMEOUT      // 0x4（SETTINGS 超时）
    | STREAM_CLOSED         // 0x5（流已关闭）
    | FRAME_SIZE_ERROR      // 0x6（帧大小错误）
    | REFUSED_STREAM        // 0x7（拒绝流）
    | CANCEL                // 0x8（连接关闭）
    | COMPRESSION_ERROR     // 0x9（连接错误）
    | CONNECT_ERROR         // 0xa（增强的流关闭）
    | ENHANCE_YOUR_CALM     // 0xb（HTTP/1.1 必需）
    | INADEQUATE_SECURITY   // 0xc（流错误）
    | HTTP_1_1_REQUIRED     // 0xd（不合理的帧）

    public func toUInt32(): UInt32 {
        match (this) {
            case NO_ERROR => 0x0
            case PROTOCOL_ERROR => 0x1
            case INTERNAL_ERROR => 0x2
            case FLOW_CONTROL_ERROR => 0x3
            case SETTINGS_TIMEOUT => 0x4
            case STREAM_CLOSED => 0x5
            case FRAME_SIZE_ERROR => 0x6
            case REFUSED_STREAM => 0x7
            case CANCEL => 0x8
            case COMPRESSION_ERROR => 0x9
            case CONNECT_ERROR => 0xa
            case ENHANCE_YOUR_CALM => 0xb
            case INADEQUATE_SECURITY => 0xc
            case HTTP_1_1_REQUIRED => 0xd
        }
    }

    public static func fromUInt32(code: UInt32): Http2ErrorCode {
        match (code) {
            case 0x0 => NO_ERROR
            case 0x1 => PROTOCOL_ERROR
            case 0x2 => INTERNAL_ERROR
            case 0x3 => FLOW_CONTROL_ERROR
            case 0x4 => SETTINGS_TIMEOUT
            case 0x5 => STREAM_CLOSED
            case 0x6 => FRAME_SIZE_ERROR
            case 0x7 => REFUSED_STREAM
            case 0x8 => CANCEL
            case 0x9 => COMPRESSION_ERROR
            case 0xa => CONNECT_ERROR
            case 0xb => ENHANCE_YOUR_CALM
            case 0xc => INADEQUATE_SECURITY
            case 0xd => HTTP_1_1_REQUIRED
            case _ => PROTOCOL_ERROR
        }
    }

    public func toString(): String {
        match (this) {
            case NO_ERROR => "NO_ERROR"
            case PROTOCOL_ERROR => "PROTOCOL_ERROR"
            case INTERNAL_ERROR => "INTERNAL_ERROR"
            case FLOW_CONTROL_ERROR => "FLOW_CONTROL_ERROR"
            case SETTINGS_TIMEOUT => "SETTINGS_TIMEOUT"
            case STREAM_CLOSED => "STREAM_CLOSED"
            case FRAME_SIZE_ERROR => "FRAME_SIZE_ERROR"
            case REFUSED_STREAM => "REFUSED_STREAM"
            case CANCEL => "CANCEL"
            case COMPRESSION_ERROR => "COMPRESSION_ERROR"
            case CONNECT_ERROR => "CONNECT_ERROR"
            case ENHANCE_YOUR_CALM => "ENHANCE_YOUR_CALM"
            case INADEQUATE_SECURITY => "INADEQUATE_SECURITY"
            case HTTP_1_1_REQUIRED => "HTTP_1_1_REQUIRED"
        }
    }

    public func hashCode(): Int64 {
        Int64(toUInt32())
    }

    public operator func ==(that: Http2ErrorCode): Bool {
        this.toUInt32() == that.toUInt32()
    }

    public operator func !=(that: Http2ErrorCode): Bool {
        this.toUInt32() != that.toUInt32()
    }
}

// ---- 帧类型（RFC 9113 第 6 节）----

public enum Http2FrameType <: ToString & Hashable & Equatable<Http2FrameType> {
    | DATA           // 0x0（无错误）
    | HEADERS        // 0x1（协议错误）
    | PRIORITY       // 0x2（内部错误）
    | RST_STREAM     // 0x3（流量控制错误）
    | SETTINGS       // 0x4（SETTINGS 超时）
    | PUSH_PROMISE   // 0x5（流已关闭）
    | PING           // 0x6（帧大小错误）
   | GOAWAY         // 0x7（拒绝流）
   | WINDOW_UPDATE  // 0x8（连接关闭）
   | CONTINUATION   // 0x9（连接错误）
    | ORIGIN          // 0xA (RFC 8336 Origin 帧)
    | ALTSVC          // 0xB (RFC 7838 替代服务帧)
    | PRIORITY_UPDATE  // 0xC (RFC 9218 优先级更新帧)

    public func toUInt8(): UInt8 {
        match (this) {
           case DATA => 0x0
           case HEADERS => 0x1
           case PRIORITY => 0x2
           case RST_STREAM => 0x3
           case SETTINGS => 0x4
           case PUSH_PROMISE => 0x5
           case PING => 0x6
           case GOAWAY => 0x7
           case WINDOW_UPDATE => 0x8
           case CONTINUATION => 0x9
            case ORIGIN => 0xA
            case ALTSVC => 0xB
            case PRIORITY_UPDATE => 0xC
        }
    }

    public static func fromUInt8(v: UInt8): ?Http2FrameType {
        match (v) {
           case 0x0 => Some(DATA)
           case 0x1 => Some(HEADERS)
           case 0x2 => Some(PRIORITY)
           case 0x3 => Some(RST_STREAM)
           case 0x4 => Some(SETTINGS)
           case 0x5 => Some(PUSH_PROMISE)
           case 0x6 => Some(PING)
           case 0x7 => Some(GOAWAY)
           case 0x8 => Some(WINDOW_UPDATE)
           case 0x9 => Some(CONTINUATION)
            case 0xA => Some(ORIGIN)
            case 0xB => Some(ALTSVC)
            case 0xC => Some(PRIORITY_UPDATE)
            case _ => None
        }
    }

    public func toString(): String {
        match (this) {
           case DATA => "DATA"
           case HEADERS => "HEADERS"
           case PRIORITY => "PRIORITY"
           case RST_STREAM => "RST_STREAM"
           case SETTINGS => "SETTINGS"
           case PUSH_PROMISE => "PUSH_PROMISE"
           case PING => "PING"
           case GOAWAY => "GOAWAY"
           case WINDOW_UPDATE => "WINDOW_UPDATE"
           case CONTINUATION => "CONTINUATION"
            case ORIGIN => "ORIGIN"
            case ALTSVC => "ALTSVC"
            case PRIORITY_UPDATE => "PRIORITY_UPDATE"
        }
    }

    public func hashCode(): Int64 {
        match (this) {
           case DATA => 0
           case HEADERS => 1
           case PRIORITY => 2
           case RST_STREAM => 3
           case SETTINGS => 4
           case PUSH_PROMISE => 5
           case PING => 6
           case GOAWAY => 7
           case WINDOW_UPDATE => 8
           case CONTINUATION => 9
            case ORIGIN => 10
            case ALTSVC => 11
            case PRIORITY_UPDATE => 12
        }
    }

    public operator func ==(that: Http2FrameType): Bool {
        match ((this, that)) {
           case (DATA, DATA) => true
           case (HEADERS, HEADERS) => true
           case (PRIORITY, PRIORITY) => true
           case (RST_STREAM, RST_STREAM) => true
           case (SETTINGS, SETTINGS) => true
           case (PUSH_PROMISE, PUSH_PROMISE) => true
           case (PING, PING) => true
           case (GOAWAY, GOAWAY) => true
           case (WINDOW_UPDATE, WINDOW_UPDATE) => true
           case (CONTINUATION, CONTINUATION) => true
            case (ORIGIN, ORIGIN) => true
            case (ALTSVC, ALTSVC) => true
            case (PRIORITY_UPDATE, PRIORITY_UPDATE) => true
            case _ => false
        }
    }

    public operator func !=(that: Http2FrameType): Bool {
        !(this == that)
    }
}

// ---- 设置标识符（RFC 9113 第 6.5.2 节）----

public enum Http2SettingsId <: ToString & Hashable & Equatable<Http2SettingsId> {
    | HEADER_TABLE_SIZE       // 0x1（协议错误）
    | ENABLE_PUSH             // 0x2（内部错误）
    | MAX_CONCURRENT_STREAMS  // 0x3（流量控制错误）
    | INITIAL_WINDOW_SIZE     // 0x4（SETTINGS 超时）
    | MAX_FRAME_SIZE          // 0x5（流已关闭）
    | MAX_HEADER_LIST_SIZE    // 0x6（帧大小错误）
    | ENABLE_CONNECT_PROTOCOL // 0x8（连接关闭）（RFC 8441 WebSocket 连接）
    | NO_RFC7540_PRIORITIES   // 0x9（RFC 9218 可扩展优先级，替代 RFC 7540 优先级方案）

    public func toUInt16(): UInt16 {
        match (this) {
            case HEADER_TABLE_SIZE => 0x1
            case ENABLE_PUSH => 0x2
            case MAX_CONCURRENT_STREAMS => 0x3
            case INITIAL_WINDOW_SIZE => 0x4
            case MAX_FRAME_SIZE => 0x5
            case MAX_HEADER_LIST_SIZE => 0x6
            case ENABLE_CONNECT_PROTOCOL => 0x8
            case NO_RFC7540_PRIORITIES => 0x9
        }
    }

    public static func fromUInt16(v: UInt16): ?Http2SettingsId {
        match (v) {
            case 0x1 => Some(HEADER_TABLE_SIZE)
            case 0x2 => Some(ENABLE_PUSH)
            case 0x3 => Some(MAX_CONCURRENT_STREAMS)
            case 0x4 => Some(INITIAL_WINDOW_SIZE)
            case 0x5 => Some(MAX_FRAME_SIZE)
            case 0x6 => Some(MAX_HEADER_LIST_SIZE)
            case 0x9 => Some(NO_RFC7540_PRIORITIES)
            case 0x8 => Some(ENABLE_CONNECT_PROTOCOL)
            case _ => None
        }
    }

    public func toString(): String {
        match (this) {
            case HEADER_TABLE_SIZE => "HEADER_TABLE_SIZE"
            case ENABLE_PUSH => "ENABLE_PUSH"
            case MAX_CONCURRENT_STREAMS => "MAX_CONCURRENT_STREAMS"
            case INITIAL_WINDOW_SIZE => "INITIAL_WINDOW_SIZE"
            case MAX_FRAME_SIZE => "MAX_FRAME_SIZE"
            case MAX_HEADER_LIST_SIZE => "MAX_HEADER_LIST_SIZE"
            case NO_RFC7540_PRIORITIES => "NO_RFC7540_PRIORITIES"
            case ENABLE_CONNECT_PROTOCOL => "ENABLE_CONNECT_PROTOCOL"
        }
    }

    public func hashCode(): Int64 {
        match (this) {
            case HEADER_TABLE_SIZE => 1
            case ENABLE_PUSH => 2
            case MAX_CONCURRENT_STREAMS => 3
            case INITIAL_WINDOW_SIZE => 4
            case MAX_FRAME_SIZE => 5
            case MAX_HEADER_LIST_SIZE => 6
            case NO_RFC7540_PRIORITIES => 9
            case ENABLE_CONNECT_PROTOCOL => 8
        }
    }

    public operator func ==(that: Http2SettingsId): Bool {
        match ((this, that)) {
            case (HEADER_TABLE_SIZE, HEADER_TABLE_SIZE) => true
            case (ENABLE_PUSH, ENABLE_PUSH) => true
            case (MAX_CONCURRENT_STREAMS, MAX_CONCURRENT_STREAMS) => true
            case (INITIAL_WINDOW_SIZE, INITIAL_WINDOW_SIZE) => true
            case (MAX_FRAME_SIZE, MAX_FRAME_SIZE) => true
            case (MAX_HEADER_LIST_SIZE, MAX_HEADER_LIST_SIZE) => true
            case (ENABLE_CONNECT_PROTOCOL, ENABLE_CONNECT_PROTOCOL) => true
            case (NO_RFC7540_PRIORITIES, NO_RFC7540_PRIORITIES) => true
            case _ => false
        }
    }

    public operator func !=(that: Http2SettingsId): Bool {
        !(this == that)
    }
}

// ---- Http2 异常 ----

public class Http2Exception <: Exception {
    public let errorCode: Http2ErrorCode

    public init(errorCode: Http2ErrorCode, message: String) {
        super(message)
        this.errorCode = errorCode
    }
}
