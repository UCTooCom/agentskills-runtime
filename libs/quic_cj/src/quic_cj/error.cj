package quic_cj

import quic_cj.util.{TransportErrorCode, StreamErrorCode, NO_ERROR, PROTOCOL_VIOLATION, FLOW_CONTROL_ERROR, FINAL_SIZE_ERROR}

/// 表示应用层协议错误。
public class ApplicationError {
    public var errorCode: UInt64 = 0u64
    public var reason: String = ""

    public init(errorCode: UInt64, reason: String) {
        this.errorCode = errorCode
        this.reason = reason
    }
}

/// QError 表示 QUIC 错误（传输层或应用层）。
public class QError {
    public var transportCode: TransportErrorCode = 0u64
    public var appCode: UInt64 = 0u64
    public var isTransport: Bool = true
    public var errorMessage: String = ""

    public init(code: TransportErrorCode, message: String) {
        this.transportCode = code
        this.isTransport = true
        this.errorMessage = message
    }
}

/// StreamError 表示流取消错误，由流的 Read/Write 方法返回。
public class StreamError {
    public var streamId: Int64 = 0
    public var errorCode: StreamErrorCode = 0u64
    public var remote: Bool = false

    public init(streamId: Int64, errorCode: StreamErrorCode, remote: Bool) {
        this.streamId = streamId
        this.errorCode = errorCode
        this.remote = remote
    }
}

/// DatagramTooLargeError 在 DATAGRAM 帧负载过大时返回。
public class DatagramTooLargeError {
    public var maxDatagramPayloadSize: Int64 = 0

    public init(maxDatagramPayloadSize: Int64) {
        this.maxDatagramPayloadSize = maxDatagramPayloadSize
    }
}

/// 创建传输层 QError。
public func newTransportError(code: TransportErrorCode, msg: String): QError {
    QError(code, msg)
}

/// 创建应用层 QError。
public func newApplicationError(code: UInt64, msg: String): QError {
    let e = QError(0u64, msg)
    e.isTransport = false
    e.appCode = code
    e
}

/// CryptoError 表示 TLS 1.3 加密/握手过程中的错误。
public class CryptoError {
    public var alert: UInt8 = 0u8  // TLS alert code
    public var message: String = ""

    public init(alert: UInt8, message: String) {
        this.alert = alert
        this.message = message
    }
}

/// 创建加密错误。
public func newCryptoError(alert: UInt8, msg: String): CryptoError {
    CryptoError(alert, msg)
}

/// 使用标准传输错误码创建传输层错误。
public func newTransportErrorWithCode(code: TransportErrorCode, msg: String): QError {
    QError(code, msg)
}

/// 使用 PROTOCOL_VIOLATION 创建传输层协议违规错误。
public func newProtocolViolation(msg: String): QError {
    QError(PROTOCOL_VIOLATION, msg)
}

/// 使用 FLOW_CONTROL_ERROR 创建流控错误。
public func newFlowControlError(msg: String): QError {
    QError(FLOW_CONTROL_ERROR, msg)
}

/// 使用 FINAL_SIZE_ERROR 创建 final size 错误。
public func newFinalSizeError(msg: String): QError {
    QError(FINAL_SIZE_ERROR, msg)
}
