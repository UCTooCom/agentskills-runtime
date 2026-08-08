package quic_cj.util

/// 表示 QUIC 传输错误码（RFC 9000 §20.1）。
public type TransportErrorCode = UInt64

/// 表示 QUIC 应用错误码。
public type ApplicationErrorCode = UInt64

/// 表示 QUIC 流错误码。
public type StreamErrorCode = UInt64

public let NO_ERROR: TransportErrorCode = 0x00u64
public let INTERNAL_ERROR: TransportErrorCode = 0x01u64
public let CONNECTION_REFUSED: TransportErrorCode = 0x02u64
public let FLOW_CONTROL_ERROR: TransportErrorCode = 0x03u64
public let STREAM_LIMIT_ERROR: TransportErrorCode = 0x04u64
public let STREAM_STATE_ERROR: TransportErrorCode = 0x05u64
public let FINAL_SIZE_ERROR: TransportErrorCode = 0x06u64
public let FRAME_ENCODING_ERROR: TransportErrorCode = 0x07u64
public let TRANSPORT_PARAMETER_ERROR: TransportErrorCode = 0x08u64
public let CONNECTION_ID_LIMIT_ERROR: TransportErrorCode = 0x09u64
public let PROTOCOL_VIOLATION: TransportErrorCode = 0x0au64
public let INVALID_TOKEN: TransportErrorCode = 0x0bu64
public let APPLICATION_ERROR: TransportErrorCode = 0x0cu64
public let CRYPTO_BUFFER_EXCEEDED: TransportErrorCode = 0x0du64
public let KEY_UPDATE_ERROR: TransportErrorCode = 0x0eu64
public let AEAD_LIMIT_REACHED: TransportErrorCode = 0x0fu64
public let NO_VIABLE_PATH: TransportErrorCode = 0x10u64
