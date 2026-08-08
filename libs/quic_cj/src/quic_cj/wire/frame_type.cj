package quic_cj.wire

public enum FrameType {
    | Ping
    | Padding
    | Ack
    | AckECN
    | ResetStream
    | StopSending
    | Crypto
    | NewToken
    | Stream
    | StreamFin
    | StreamLen
    | StreamFinLen
    | StreamOff
    | StreamOffFin
    | StreamOffLen
    | StreamOffFinLen
    | MaxData
    | MaxStreamData
    | MaxStreamsBidi
    | MaxStreamsUni
    | DataBlocked
    | StreamDataBlocked
    | StreamsBlockedBidi
    | StreamsBlockedUni
    | NewConnectionID
    | RetireConnectionID
    | PathChallenge
    | PathResponse
    | ConnectionClose
    | ApplicationClose
    | HandshakeDone
    | Datagram
    | DatagramLen
    | AckFrequency
    | ImmediateAck
}

public let FRAME_TYPE_PADDING: UInt8 = 0x00u8
public let FRAME_TYPE_PING: UInt8 = 0x01u8
public let FRAME_TYPE_ACK: UInt8 = 0x02u8
public let FRAME_TYPE_ACK_ECN: UInt8 = 0x03u8
public let FRAME_TYPE_RESET_STREAM: UInt8 = 0x04u8
public let FRAME_TYPE_STOP_SENDING: UInt8 = 0x05u8
public let FRAME_TYPE_CRYPTO: UInt8 = 0x06u8
public let FRAME_TYPE_NEW_TOKEN: UInt8 = 0x07u8
public let FRAME_TYPE_STREAM_BASE: UInt8 = 0x08u8
public let FRAME_TYPE_MAX_DATA: UInt8 = 0x10u8
public let FRAME_TYPE_MAX_STREAM_DATA: UInt8 = 0x11u8
public let FRAME_TYPE_MAX_STREAMS_BIDI: UInt8 = 0x12u8
public let FRAME_TYPE_MAX_STREAMS_UNI: UInt8 = 0x13u8
public let FRAME_TYPE_DATA_BLOCKED: UInt8 = 0x14u8
public let FRAME_TYPE_STREAM_DATA_BLOCKED: UInt8 = 0x15u8
public let FRAME_TYPE_STREAMS_BLOCKED_BIDI: UInt8 = 0x16u8
public let FRAME_TYPE_STREAMS_BLOCKED_UNI: UInt8 = 0x17u8
public let FRAME_TYPE_NEW_CONNECTION_ID: UInt8 = 0x18u8
public let FRAME_TYPE_RETIRE_CONNECTION_ID: UInt8 = 0x19u8
public let FRAME_TYPE_PATH_CHALLENGE: UInt8 = 0x1au8
public let FRAME_TYPE_PATH_RESPONSE: UInt8 = 0x1bu8
public let FRAME_TYPE_CONNECTION_CLOSE: UInt8 = 0x1cu8
public let FRAME_TYPE_APPLICATION_CLOSE: UInt8 = 0x1du8
public let FRAME_TYPE_HANDSHAKE_DONE: UInt8 = 0x1eu8
public let FRAME_TYPE_DATAGRAM: UInt8 = 0x30u8
public let FRAME_TYPE_DATAGRAM_LEN: UInt8 = 0x31u8
public let FRAME_TYPE_ACK_FREQUENCY: UInt8 = 0xafu8
public let FRAME_TYPE_IMMEDIATE_ACK: UInt8 = 0x1fu8

// STREAM 帧类型位
public let STREAM_FIN_BIT: UInt8 = 0x01u8
public let STREAM_LEN_BIT: UInt8 = 0x02u8
public let STREAM_OFF_BIT: UInt8 = 0x04u8
