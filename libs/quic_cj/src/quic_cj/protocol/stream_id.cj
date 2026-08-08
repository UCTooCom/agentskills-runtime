package quic_cj.protocol

public type StreamId = Int64
public type StreamNum = Int64

public let INVALID_STREAM_ID: StreamId = -1
public let INVALID_STREAM_NUM: StreamNum = -1

public enum StreamType {
    | Uni
    | Bidi
}

private func streamTypeIsBidi(stype: StreamType): Bool {
    match (stype) {
        case StreamType.Bidi => true
        case _ => false
    }
}

private func persIsClient(pers: Perspective): Bool {
    match (pers) {
        case Perspective.Client => true
        case _ => false
    }
}

public let FIRST_OUTGOING_BIDI_STREAM_CLIENT: StreamId = 0
public let FIRST_OUTGOING_UNI_STREAM_CLIENT: StreamId = 2
public let FIRST_OUTGOING_BIDI_STREAM_SERVER: StreamId = 1
public let FIRST_OUTGOING_UNI_STREAM_SERVER: StreamId = 3

public func streamNumToStreamId(s: StreamNum, stype: StreamType, pers: Perspective): StreamId {
    if (s == 0) { return INVALID_STREAM_ID }
    let isClient = persIsClient(pers)
    let isBidi = streamTypeIsBidi(stype)
    let first = if (isBidi) {
        if (isClient) { FIRST_OUTGOING_BIDI_STREAM_CLIENT }
        else { FIRST_OUTGOING_BIDI_STREAM_SERVER }
    } else {
        if (isClient) { FIRST_OUTGOING_UNI_STREAM_CLIENT }
        else { FIRST_OUTGOING_UNI_STREAM_SERVER }
    }
    first + 4 * (s - 1)
}

public func streamInitiatedBy(s: StreamId): Perspective {
    if (s % 2 == 0) { Perspective.Client }
    else { Perspective.Server }
}

public func streamType(s: StreamId): StreamType {
    if (s % 4 >= 2) { StreamType.Uni }
    else { StreamType.Bidi }
}

public func streamNum(s: StreamId): StreamNum {
    s / 4 + 1
}
