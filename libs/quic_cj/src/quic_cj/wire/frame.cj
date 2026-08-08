package quic_cj.wire

open public class Frame {
    open public func frameType(): UInt8 { 0u8 }
    open public func getStreamId(): Int64 { 0 }
    open public func getData(): Array<Byte> { [] }
    open public func getOffset(): Int64 { 0 }
    open public func getErrorCode(): UInt64 { 0u64 }
    open public func getMaxData(): Int64 { 0 }
    open public func getMaxStreamData(): Int64 { 0 }
    open public func getFinalSize(): Int64 { 0 }
    open public func getFin(): Bool { false }
    open public func getSeq(): Int64 { 0 }
    open public func getRetirePriorTo(): Int64 { 0 }
    open public func getConnId(): Array<Byte> { [] }
    open public func getResetToken(): Array<Byte> { [] }
    open public func getReasonPhrase(): Array<Byte> { [] }
    open public func getTrigFrameType(): Int64 { 0 }
    open public func getLargestAcked(): Int64 { 0 }
    open public func getAckDelay(): Int64 { 0 }
    open public func getAckRangeCount(): Int64 { 0 }
    open public func getEcnECT0(): Int64 { 0 }
    open public func getEcnECT1(): Int64 { 0 }
    open public func getEcnCE(): Int64 { 0 }
    open public func getAckRange(i: Int64): (Int64, Int64) { (0, 0) }
    open public func getMaxStreams(): Int64 { 0 }
}

public class PingFrame <: Frame {
    public func frameType(): UInt8 { FRAME_TYPE_PING }
}
public class PaddingFrame <: Frame {
    public var size: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_PADDING }
    public init() {}
    public init(size: Int64) {
        this.size = size
    }
}

public class ResetStreamFrame <: Frame {
    public var streamId: Int64 = 0
    public var errorCode: UInt64 = 0
    public var finalSize: Int64 = 0
    public func getFinalSize(): Int64 { finalSize }
    public func frameType(): UInt8 { FRAME_TYPE_RESET_STREAM }
    public func getStreamId(): Int64 { streamId }
    public func getErrorCode(): UInt64 { errorCode }
    public init(streamId: Int64, errorCode: UInt64, finalSize: Int64) {
        this.streamId = streamId; this.errorCode = errorCode; this.finalSize = finalSize
    }
}

public class StopSendingFrame <: Frame {
    public var streamId: Int64 = 0
    public var errorCode: UInt64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_STOP_SENDING }
    public func getStreamId(): Int64 { streamId }
    public func getErrorCode(): UInt64 { errorCode }
}

public class CryptoFrame <: Frame {
    public var offset: Int64 = 0
    public var data: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_CRYPTO }
    public func getOffset(): Int64 { offset }
    public func getData(): Array<Byte> { data }
}

public class NewTokenFrame <: Frame {
    public var token: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_NEW_TOKEN }
    public func getData(): Array<Byte> { token }
}

public class MaxDataFrame <: Frame {
    public var maxData: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_MAX_DATA }
    public func getMaxData(): Int64 { maxData }
}

public class MaxStreamDataFrame <: Frame {
    public var streamId: Int64 = 0
    public var maxStreamData: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_MAX_STREAM_DATA }
    public func getStreamId(): Int64 { streamId }
    public func getMaxStreamData(): Int64 { maxStreamData }
}

public class MaxStreamsFrame <: Frame {
    public var maxStreams: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_MAX_STREAMS_BIDI }
    public func getMaxStreams(): Int64 { maxStreams }
}

public class DataBlockedFrame <: Frame {
    public var maxData: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_DATA_BLOCKED }
    public func getMaxData(): Int64 { maxData }
}

public class StreamDataBlockedFrame <: Frame {
    public var streamId: Int64 = 0
    public var maxStreamData: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_STREAM_DATA_BLOCKED }
    public func getStreamId(): Int64 { streamId }
    public func getMaxStreamData(): Int64 { maxStreamData }
}

public class StreamsBlockedFrame <: Frame {
    public var maxStreams: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_STREAMS_BLOCKED_BIDI }
    public func getMaxStreams(): Int64 { maxStreams }
}

public class NewConnectionIDFrame <: Frame {
    public var seq: Int64 = 0
    public var retirePriorTo: Int64 = 0
    public var connectionId: Array<Byte> = []
    public var statelessResetToken: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_NEW_CONNECTION_ID }
    public func getSeq(): Int64 { seq }
    public func getRetirePriorTo(): Int64 { retirePriorTo }
    public func getConnId(): Array<Byte> { connectionId }
    public func getResetToken(): Array<Byte> { statelessResetToken }
}

public class RetireConnectionIDFrame <: Frame {
    public var seq: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_RETIRE_CONNECTION_ID }
    public func getSeq(): Int64 { seq }
}

public class PathChallengeFrame <: Frame {
    public var data: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_PATH_CHALLENGE }
    public func getData(): Array<Byte> { data }
}

public class PathResponseFrame <: Frame {
    public var data: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_PATH_RESPONSE }
    public func getData(): Array<Byte> { data }
}

public class ConnectionCloseFrame <: Frame {
    public var errorCode: UInt64 = 0
    public var trigFrameType: Int64 = 0
    public var reasonPhrase: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_CONNECTION_CLOSE }
    public func getErrorCode(): UInt64 { errorCode }
    public func getTrigFrameType(): Int64 { trigFrameType }
    public func getReasonPhrase(): Array<Byte> { reasonPhrase }
}

public class ApplicationCloseFrame <: Frame {
    public var errorCode: UInt64 = 0
    public var reasonPhrase: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_APPLICATION_CLOSE }
    public func getErrorCode(): UInt64 { errorCode }
    public func getReasonPhrase(): Array<Byte> { reasonPhrase }
}

public class HandshakeDoneFrame <: Frame {
    public func frameType(): UInt8 { FRAME_TYPE_HANDSHAKE_DONE }
}

public let MAX_ACK_RANGES: Int64 = 64

public class AckFrame <: Frame {
    public var largestAcked: Int64 = 0
    public var ackDelay: Int64 = 0
    public var ackRanges: Array<(Int64, Int64)> = Array<(Int64, Int64)>(MAX_ACK_RANGES, repeat: (0, 0))
    public var ackRangeCount: Int64 = 0
    public var ecnECT0: Int64 = 0
    public var ecnECT1: Int64 = 0
    public var ecnCE: Int64 = 0
    public func frameType(): UInt8 { FRAME_TYPE_ACK }
    public func getLargestAcked(): Int64 { largestAcked }
    public func getAckDelay(): Int64 { ackDelay }
    public func getAckRangeCount(): Int64 { ackRangeCount }
    public func getEcnECT0(): Int64 { ecnECT0 }
    public func getEcnECT1(): Int64 { ecnECT1 }
    public func getEcnCE(): Int64 { ecnCE }
    public func getAckRange(i: Int64): (Int64, Int64) {
        if (i >= 0 && i < ackRangeCount) { ackRanges[i] } else { (0, 0) }
    }
}

public class StreamFrame <: Frame {
    public var streamId: Int64 = 0
    public var offset: Int64 = 0
    public var fin: Bool = false
    public var data: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_STREAM_BASE }
    public func getStreamId(): Int64 { streamId }
    public func getOffset(): Int64 { offset }
    public func getFin(): Bool { fin }
    public func getData(): Array<Byte> { data }
}

public class DatagramFrame <: Frame {
    public var data: Array<Byte> = []
    public func frameType(): UInt8 { FRAME_TYPE_DATAGRAM }
    public func getData(): Array<Byte> { data }
}

public class AckFrequencyFrame <: Frame {
    public var seq: Int64 = 0
    public var packetsAfter: Int64 = 0
    public var maxAckDelayMicro: Int64 = 0
    public var ignoreOrder: Bool = false
    public func frameType(): UInt8 { FRAME_TYPE_ACK_FREQUENCY }
}

public class ImmediateAckFrame <: Frame {
    public func frameType(): UInt8 { FRAME_TYPE_IMMEDIATE_ACK }
}
