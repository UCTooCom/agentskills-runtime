package quic_cj.wire

/// 返回序列化 frame 所需的字节数（不包含已有 buf）。
public func frameWireSize(frame: Frame): Int64 {
    let ft = frame.frameType()
    if (ft == FRAME_TYPE_PING || ft == FRAME_TYPE_HANDSHAKE_DONE || ft == FRAME_TYPE_IMMEDIATE_ACK) {
        1
    } else if (ft == FRAME_TYPE_PADDING) {
        match (frame as PaddingFrame) {
            case Some(pf) => pf.size
            case None => 1
        }
    } else if (ft == FRAME_TYPE_CRYPTO) {
        1 + writeVarintLen(frame.getOffset()) + writeVarintLen(frame.getData().size) + frame.getData().size
    } else if (ft == FRAME_TYPE_MAX_DATA) {
        1 + writeVarintLen(frame.getMaxData())
    } else if (ft == FRAME_TYPE_MAX_STREAM_DATA) {
        1 + writeVarintLen(frame.getStreamId()) + writeVarintLen(frame.getMaxStreamData())
    } else if (ft == FRAME_TYPE_RESET_STREAM) {
        1 + writeVarintLen(frame.getStreamId()) + writeVarintLen(Int64(frame.getErrorCode())) + writeVarintLen(frame.getFinalSize())
    } else if (ft == FRAME_TYPE_STOP_SENDING) {
        1 + writeVarintLen(frame.getStreamId()) + writeVarintLen(Int64(frame.getErrorCode()))
    } else if (ft == FRAME_TYPE_DATA_BLOCKED) {
        1 + writeVarintLen(frame.getMaxData())
    } else if (ft == FRAME_TYPE_STREAM_DATA_BLOCKED) {
        1 + writeVarintLen(frame.getStreamId()) + writeVarintLen(frame.getMaxStreamData())
    } else if (ft == FRAME_TYPE_MAX_STREAMS_BIDI || ft == FRAME_TYPE_MAX_STREAMS_UNI) {
        1 + writeVarintLen(frame.getMaxStreams())
    } else if (ft == FRAME_TYPE_STREAMS_BLOCKED_BIDI || ft == FRAME_TYPE_STREAMS_BLOCKED_UNI) {
        1 + writeVarintLen(frame.getMaxStreams())
    } else if (ft == FRAME_TYPE_RETIRE_CONNECTION_ID) {
        1 + writeVarintLen(frame.getSeq())
    } else if (ft == FRAME_TYPE_PATH_CHALLENGE || ft == FRAME_TYPE_PATH_RESPONSE) {
        1 + frame.getData().size
    } else if (ft == FRAME_TYPE_NEW_TOKEN) {
        let tok = frame.getData()
        1 + writeVarintLen(tok.size) + tok.size
    } else if (ft == FRAME_TYPE_CONNECTION_CLOSE) {
        let reason = frame.getReasonPhrase()
        1 + writeVarintLen(Int64(frame.getErrorCode())) + writeVarintLen(frame.getTrigFrameType()) + writeVarintLen(reason.size) + reason.size
    } else if (ft == FRAME_TYPE_APPLICATION_CLOSE) {
        let reason = frame.getReasonPhrase()
        1 + writeVarintLen(Int64(frame.getErrorCode())) + writeVarintLen(reason.size) + reason.size
    } else if (ft == FRAME_TYPE_NEW_CONNECTION_ID) {
        let cid = frame.getConnId()
        let tok = frame.getResetToken()
        1 + writeVarintLen(frame.getSeq()) + writeVarintLen(frame.getRetirePriorTo()) + 1 + cid.size + tok.size
    } else if (ft == FRAME_TYPE_DATAGRAM || ft == FRAME_TYPE_DATAGRAM_LEN) {
        let d = frame.getData()
        if (ft == FRAME_TYPE_DATAGRAM_LEN) {
            1 + writeVarintLen(d.size) + d.size
        } else {
            1 + d.size
        }
    } else if (ft >= FRAME_TYPE_STREAM_BASE && ft < FRAME_TYPE_STREAM_BASE + 8u8) {
        let data = frame.getData()
        let hasOffset = if (frame.getOffset() != 0) { 1 } else { 0 }
        1 + writeVarintLen(frame.getStreamId()) + (if (hasOffset == 1) { writeVarintLen(frame.getOffset()) } else { 0 }) + writeVarintLen(data.size) + data.size
    } else if (ft == FRAME_TYPE_ACK_FREQUENCY) {
        match (frame as AckFrequencyFrame) {
            case Some(aff) => 1 + writeVarintLen(aff.seq) + writeVarintLen(aff.packetsAfter) + writeVarintLen(aff.maxAckDelayMicro) + 1
            case None => 1
        }
    } else if (ft == FRAME_TYPE_ACK || ft == FRAME_TYPE_ACK_ECN) {
        var sz: Int64 = 1 + writeVarintLen(frame.getLargestAcked()) + writeVarintLen(frame.getAckDelay())
        let rangeCount = frame.getAckRangeCount()
        if (rangeCount <= 0) {
            sz += writeVarintLen(0) + writeVarintLen(1)
        } else {
            let (start0, end0) = frame.getAckRange(0)
            sz += writeVarintLen(rangeCount - 1)
            sz += writeVarintLen(end0 - start0 + 1)
            var i: Int64 = 1
            while (i < rangeCount) {
                let (prevStart, _) = frame.getAckRange(i - 1)
                let (start, end_) = frame.getAckRange(i)
                let gap = prevStart - end_ - 1
                sz += writeVarintLen(gap) + writeVarintLen(end_ - start + 1)
                i += 1
            }
        }
        if (ft == FRAME_TYPE_ACK_ECN) {
            sz += writeVarintLen(frame.getEcnECT0()) + writeVarintLen(frame.getEcnECT1()) + writeVarintLen(frame.getEcnCE())
        }
        sz
    } else {
        0
    }
}

/// 将 frame 序列化写入到预分配的 buf 中 pos 位置，返回新位置。
public func writeFrameAt(buf: Array<Byte>, pos: Int64, frame: Frame): Int64 {
    let ft = frame.frameType()
    if (ft == FRAME_TYPE_PING) {
        writeByteAt(buf, pos, FRAME_TYPE_PING)
    } else if (ft == FRAME_TYPE_PADDING) {
        match (frame as PaddingFrame) {
            case Some(pf) =>
                var p = pos
                var i: Int64 = 0
                while (i < pf.size) {
                    p = writeByteAt(buf, p, FRAME_TYPE_PADDING)
                    i += 1
                }
                p
            case None => writeByteAt(buf, pos, FRAME_TYPE_PADDING)
        }
    } else if (ft == FRAME_TYPE_HANDSHAKE_DONE) {
        writeByteAt(buf, pos, FRAME_TYPE_HANDSHAKE_DONE)
    } else if (ft == FRAME_TYPE_IMMEDIATE_ACK) {
        writeByteAt(buf, pos, FRAME_TYPE_IMMEDIATE_ACK)
    } else if (ft == FRAME_TYPE_CRYPTO) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_CRYPTO)
        p = writeVarintAt(buf, p, frame.getOffset())
        p = writeVarintAt(buf, p, frame.getData().size)
        writeBytesAt(buf, p, frame.getData())
    } else if (ft == FRAME_TYPE_MAX_DATA) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_MAX_DATA)
        writeVarintAt(buf, p, frame.getMaxData())
    } else if (ft == FRAME_TYPE_MAX_STREAM_DATA) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_MAX_STREAM_DATA)
        p = writeVarintAt(buf, p, frame.getStreamId())
        writeVarintAt(buf, p, frame.getMaxStreamData())
    } else if (ft == FRAME_TYPE_RESET_STREAM) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_RESET_STREAM)
        p = writeVarintAt(buf, p, frame.getStreamId())
        p = writeVarintAt(buf, p, Int64(frame.getErrorCode()))
        writeVarintAt(buf, p, frame.getFinalSize())
    } else if (ft == FRAME_TYPE_STOP_SENDING) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_STOP_SENDING)
        p = writeVarintAt(buf, p, frame.getStreamId())
        writeVarintAt(buf, p, Int64(frame.getErrorCode()))
    } else if (ft == FRAME_TYPE_DATA_BLOCKED) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_DATA_BLOCKED)
        writeVarintAt(buf, p, frame.getMaxData())
    } else if (ft == FRAME_TYPE_STREAM_DATA_BLOCKED) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_STREAM_DATA_BLOCKED)
        p = writeVarintAt(buf, p, frame.getStreamId())
        writeVarintAt(buf, p, frame.getMaxStreamData())
    } else if (ft == FRAME_TYPE_MAX_STREAMS_BIDI || ft == FRAME_TYPE_MAX_STREAMS_UNI) {
        var p = writeByteAt(buf, pos, ft)
        writeVarintAt(buf, p, frame.getMaxStreams())
    } else if (ft == FRAME_TYPE_STREAMS_BLOCKED_BIDI || ft == FRAME_TYPE_STREAMS_BLOCKED_UNI) {
        var p = writeByteAt(buf, pos, ft)
        writeVarintAt(buf, p, frame.getMaxStreams())
    } else if (ft == FRAME_TYPE_RETIRE_CONNECTION_ID) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_RETIRE_CONNECTION_ID)
        writeVarintAt(buf, p, frame.getSeq())
    } else if (ft == FRAME_TYPE_PATH_CHALLENGE) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_PATH_CHALLENGE)
        writeBytesAt(buf, p, frame.getData())
    } else if (ft == FRAME_TYPE_PATH_RESPONSE) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_PATH_RESPONSE)
        writeBytesAt(buf, p, frame.getData())
    } else if (ft == FRAME_TYPE_NEW_TOKEN) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_NEW_TOKEN)
        let tok = frame.getData()
        p = writeVarintAt(buf, p, tok.size)
        writeBytesAt(buf, p, tok)
    } else if (ft == FRAME_TYPE_CONNECTION_CLOSE) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_CONNECTION_CLOSE)
        p = writeVarintAt(buf, p, Int64(frame.getErrorCode()))
        p = writeVarintAt(buf, p, frame.getTrigFrameType())
        let reason = frame.getReasonPhrase()
        p = writeVarintAt(buf, p, reason.size)
        writeBytesAt(buf, p, reason)
    } else if (ft == FRAME_TYPE_APPLICATION_CLOSE) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_APPLICATION_CLOSE)
        p = writeVarintAt(buf, p, Int64(frame.getErrorCode()))
        let reason = frame.getReasonPhrase()
        p = writeVarintAt(buf, p, reason.size)
        writeBytesAt(buf, p, reason)
    } else if (ft == FRAME_TYPE_NEW_CONNECTION_ID) {
        var p = writeByteAt(buf, pos, FRAME_TYPE_NEW_CONNECTION_ID)
        p = writeVarintAt(buf, p, frame.getSeq())
        p = writeVarintAt(buf, p, frame.getRetirePriorTo())
        let cid = frame.getConnId()
        p = writeByteAt(buf, p, UInt8(cid.size))
        p = writeBytesAt(buf, p, cid)
        writeBytesAt(buf, p, frame.getResetToken())
    } else if (ft == FRAME_TYPE_DATAGRAM || ft == FRAME_TYPE_DATAGRAM_LEN) {
        var p = writeByteAt(buf, pos, ft)
        let d = frame.getData()
        if (ft == FRAME_TYPE_DATAGRAM_LEN) {
            p = writeVarintAt(buf, p, d.size)
        }
        writeBytesAt(buf, p, d)
    } else if (ft >= FRAME_TYPE_STREAM_BASE && ft < FRAME_TYPE_STREAM_BASE + 8u8) {
        var typeByte = FRAME_TYPE_STREAM_BASE
        if (frame.getFin()) { typeByte = typeByte | STREAM_FIN_BIT }
        if (frame.getOffset() != 0) { typeByte = typeByte | STREAM_OFF_BIT }
        typeByte = typeByte | STREAM_LEN_BIT
        var p = writeByteAt(buf, pos, typeByte)
        p = writeVarintAt(buf, p, frame.getStreamId())
        if (frame.getOffset() != 0) { p = writeVarintAt(buf, p, frame.getOffset()) }
        p = writeVarintAt(buf, p, frame.getData().size)
        writeBytesAt(buf, p, frame.getData())
    } else if (ft == FRAME_TYPE_ACK_FREQUENCY) {
        match (frame as AckFrequencyFrame) {
            case Some(aff) =>
                var p = writeByteAt(buf, pos, ft)
                p = writeVarintAt(buf, p, aff.seq)
                p = writeVarintAt(buf, p, aff.packetsAfter)
                p = writeVarintAt(buf, p, aff.maxAckDelayMicro)
                p = writeVarintAt(buf, p, if (aff.ignoreOrder) { 1 } else { 0 })
                p
            case None => pos
        }
    } else if (ft == FRAME_TYPE_ACK || ft == FRAME_TYPE_ACK_ECN) {
        var p = writeByteAt(buf, pos, ft)
        p = writeVarintAt(buf, p, frame.getLargestAcked())
        p = writeVarintAt(buf, p, frame.getAckDelay())
        let rangeCount = frame.getAckRangeCount()
        if (rangeCount <= 0) {
            p = writeVarintAt(buf, p, 0)
            p = writeVarintAt(buf, p, 1)
        } else {
            let (start0, end0) = frame.getAckRange(0)
            p = writeVarintAt(buf, p, rangeCount - 1)
            p = writeVarintAt(buf, p, end0 - start0 + 1)
            var i: Int64 = 1
            while (i < rangeCount) {
                let (prevStart, _) = frame.getAckRange(i - 1)
                let (start, end_) = frame.getAckRange(i)
                let gap = prevStart - end_ - 1
                p = writeVarintAt(buf, p, gap)
                p = writeVarintAt(buf, p, end_ - start + 1)
                i += 1
            }
        }
        if (ft == FRAME_TYPE_ACK_ECN) {
            p = writeVarintAt(buf, p, frame.getEcnECT0())
            p = writeVarintAt(buf, p, frame.getEcnECT1())
            p = writeVarintAt(buf, p, frame.getEcnCE())
        }
        p
    } else {
        pos
    }
}

/// 序列化 Frame 并返回新缓冲区（预分配 + 一次写入）。
public func appendFrame(buf: Array<Byte>, frame: Frame): Array<Byte> {
    let ft = frame.frameType()
    if (ft == FRAME_TYPE_PING) {
        appendByte(buf, FRAME_TYPE_PING)
    } else if (ft == FRAME_TYPE_PADDING) {
        match (frame as PaddingFrame) {
            case Some(pf) =>
                let totalSize = buf.size + pf.size
                var out = Array<Byte>(totalSize, repeat: 0u8)
                var pos = writeBytesAt(out, 0, buf)
                var i: Int64 = 0
                while (i < pf.size) {
                    out[pos] = 0u8
                    pos += 1
                    i += 1
                }
                out
            case None => appendByte(buf, FRAME_TYPE_PADDING)
        }
    } else if (ft == FRAME_TYPE_HANDSHAKE_DONE) {
        appendByte(buf, FRAME_TYPE_HANDSHAKE_DONE)
    } else if (ft == FRAME_TYPE_IMMEDIATE_ACK) {
        appendByte(buf, FRAME_TYPE_IMMEDIATE_ACK)
    } else if (ft == FRAME_TYPE_CRYPTO) {
        let data = frame.getData()
        let frameSize = 1 + writeVarintLen(frame.getOffset()) + writeVarintLen(data.size) + data.size
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_CRYPTO)
        pos = writeVarintAt(out, pos, frame.getOffset())
        pos = writeVarintAt(out, pos, data.size)
        writeBytesAt(out, pos, data)
        out
    } else if (ft == FRAME_TYPE_MAX_DATA) {
        let frameSize = 1 + writeVarintLen(frame.getMaxData())
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_MAX_DATA)
        writeVarintAt(out, pos, frame.getMaxData())
        out
    } else if (ft == FRAME_TYPE_MAX_STREAM_DATA) {
        let frameSize = 1 + writeVarintLen(frame.getStreamId()) + writeVarintLen(frame.getMaxStreamData())
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_MAX_STREAM_DATA)
        pos = writeVarintAt(out, pos, frame.getStreamId())
        writeVarintAt(out, pos, frame.getMaxStreamData())
        out
    } else if (ft == FRAME_TYPE_RESET_STREAM) {
        let frameSize = 1 + writeVarintLen(frame.getStreamId()) + writeVarintLen(Int64(frame.getErrorCode())) + writeVarintLen(frame.getFinalSize())
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_RESET_STREAM)
        pos = writeVarintAt(out, pos, frame.getStreamId())
        pos = writeVarintAt(out, pos, Int64(frame.getErrorCode()))
        writeVarintAt(out, pos, frame.getFinalSize())
        out
    } else if (ft == FRAME_TYPE_STOP_SENDING) {
        let frameSize = 1 + writeVarintLen(frame.getStreamId()) + writeVarintLen(Int64(frame.getErrorCode()))
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_STOP_SENDING)
        pos = writeVarintAt(out, pos, frame.getStreamId())
        writeVarintAt(out, pos, Int64(frame.getErrorCode()))
        out
    } else if (ft == FRAME_TYPE_DATA_BLOCKED) {
        let frameSize = 1 + writeVarintLen(frame.getMaxData())
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_DATA_BLOCKED)
        writeVarintAt(out, pos, frame.getMaxData())
        out
    } else if (ft == FRAME_TYPE_STREAM_DATA_BLOCKED) {
        let frameSize = 1 + writeVarintLen(frame.getStreamId()) + writeVarintLen(frame.getMaxStreamData())
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_STREAM_DATA_BLOCKED)
        pos = writeVarintAt(out, pos, frame.getStreamId())
        writeVarintAt(out, pos, frame.getMaxStreamData())
        out
    } else if (ft == FRAME_TYPE_MAX_STREAMS_BIDI || ft == FRAME_TYPE_MAX_STREAMS_UNI) {
        let frameSize = 1 + writeVarintLen(frame.getMaxStreams())
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, ft)
        writeVarintAt(out, pos, frame.getMaxStreams())
        out
    } else if (ft == FRAME_TYPE_STREAMS_BLOCKED_BIDI || ft == FRAME_TYPE_STREAMS_BLOCKED_UNI) {
        let frameSize = 1 + writeVarintLen(frame.getMaxStreams())
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, ft)
        writeVarintAt(out, pos, frame.getMaxStreams())
        out
    } else if (ft == FRAME_TYPE_RETIRE_CONNECTION_ID) {
        let frameSize = 1 + writeVarintLen(frame.getSeq())
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_RETIRE_CONNECTION_ID)
        writeVarintAt(out, pos, frame.getSeq())
        out
    } else if (ft == FRAME_TYPE_PATH_CHALLENGE) {
        let d = frame.getData()
        let frameSize = 1 + d.size
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_PATH_CHALLENGE)
        writeBytesAt(out, pos, d)
        out
    } else if (ft == FRAME_TYPE_PATH_RESPONSE) {
        let d = frame.getData()
        let frameSize = 1 + d.size
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_PATH_RESPONSE)
        writeBytesAt(out, pos, d)
        out
    } else if (ft == FRAME_TYPE_NEW_TOKEN) {
        let tok = frame.getData()
        let frameSize = 1 + writeVarintLen(tok.size) + tok.size
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_NEW_TOKEN)
        pos = writeVarintAt(out, pos, tok.size)
        writeBytesAt(out, pos, tok)
        out
    } else if (ft == FRAME_TYPE_CONNECTION_CLOSE) {
        let reason = frame.getReasonPhrase()
        let frameSize = 1 + writeVarintLen(Int64(frame.getErrorCode())) + writeVarintLen(frame.getTrigFrameType()) + writeVarintLen(reason.size) + reason.size
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_CONNECTION_CLOSE)
        pos = writeVarintAt(out, pos, Int64(frame.getErrorCode()))
        pos = writeVarintAt(out, pos, frame.getTrigFrameType())
        pos = writeVarintAt(out, pos, reason.size)
        writeBytesAt(out, pos, reason)
        out
    } else if (ft == FRAME_TYPE_APPLICATION_CLOSE) {
        let reason = frame.getReasonPhrase()
        let frameSize = 1 + writeVarintLen(Int64(frame.getErrorCode())) + writeVarintLen(reason.size) + reason.size
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_APPLICATION_CLOSE)
        pos = writeVarintAt(out, pos, Int64(frame.getErrorCode()))
        pos = writeVarintAt(out, pos, reason.size)
        writeBytesAt(out, pos, reason)
        out
    } else if (ft == FRAME_TYPE_NEW_CONNECTION_ID) {
        let cid = frame.getConnId()
        let tok = frame.getResetToken()
        let frameSize = 1 + writeVarintLen(frame.getSeq()) + writeVarintLen(frame.getRetirePriorTo()) + 1 + cid.size + tok.size
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, FRAME_TYPE_NEW_CONNECTION_ID)
        pos = writeVarintAt(out, pos, frame.getSeq())
        pos = writeVarintAt(out, pos, frame.getRetirePriorTo())
        pos = writeByteAt(out, pos, UInt8(cid.size))
        pos = writeBytesAt(out, pos, cid)
        writeBytesAt(out, pos, tok)
        out
   } else if (ft == FRAME_TYPE_DATAGRAM || ft == FRAME_TYPE_DATAGRAM_LEN) {
       let d = frame.getData()
       let frameSize = if (ft == FRAME_TYPE_DATAGRAM_LEN) { 1 + writeVarintLen(d.size) + d.size } else { 1 + d.size }
       let totalSize = buf.size + frameSize
       var out = Array<Byte>(totalSize, repeat: 0u8)
       var pos = writeBytesAt(out, 0, buf)
       pos = writeByteAt(out, pos, ft)
       if (ft == FRAME_TYPE_DATAGRAM_LEN) {
           pos = writeVarintAt(out, pos, d.size)
       }
       writeBytesAt(out, pos, d)
       out
    } else if (ft == FRAME_TYPE_ACK_FREQUENCY) {
        match (frame as AckFrequencyFrame) {
            case Some(aff) =>
                let frameSize = 1 + writeVarintLen(aff.seq) + writeVarintLen(aff.packetsAfter) + writeVarintLen(aff.maxAckDelayMicro) + 1
                let totalSize = buf.size + frameSize
                var out = Array<Byte>(totalSize, repeat: 0u8)
                var pos = writeBytesAt(out, 0, buf)
                pos = writeByteAt(out, pos, FRAME_TYPE_ACK_FREQUENCY)
                pos = writeVarintAt(out, pos, aff.seq)
                pos = writeVarintAt(out, pos, aff.packetsAfter)
                pos = writeVarintAt(out, pos, aff.maxAckDelayMicro)
                pos = writeVarintAt(out, pos, if (aff.ignoreOrder) { 1 } else { 0 })
                out
            case None => buf
        }
    } else if (ft >= FRAME_TYPE_STREAM_BASE && ft < FRAME_TYPE_STREAM_BASE + 8u8) {
        let data = frame.getData()
        let hasOffset = if (frame.getOffset() != 0) { 1 } else { 0 }
        let frameSize = 1 + writeVarintLen(frame.getStreamId()) + (if (hasOffset == 1) { writeVarintLen(frame.getOffset()) } else { 0 }) + writeVarintLen(data.size) + data.size
        let totalSize = buf.size + frameSize
        var typeByte = FRAME_TYPE_STREAM_BASE
        if (frame.getFin()) { typeByte = typeByte | STREAM_FIN_BIT }
        if (frame.getOffset() != 0) { typeByte = typeByte | STREAM_OFF_BIT }
        typeByte = typeByte | STREAM_LEN_BIT
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, typeByte)
        pos = writeVarintAt(out, pos, frame.getStreamId())
        if (frame.getOffset() != 0) { pos = writeVarintAt(out, pos, frame.getOffset()) }
        pos = writeVarintAt(out, pos, data.size)
        writeBytesAt(out, pos, data)
        out
    } else if (ft == FRAME_TYPE_ACK || ft == FRAME_TYPE_ACK_ECN) {
        var frameSize: Int64 = 1 + writeVarintLen(frame.getLargestAcked()) + writeVarintLen(frame.getAckDelay())
        let rangeCount = frame.getAckRangeCount()
        if (rangeCount <= 0) {
            frameSize += writeVarintLen(0) + writeVarintLen(1)
        } else {
            let (start0, end0) = frame.getAckRange(0)
            frameSize += writeVarintLen(rangeCount - 1)
            frameSize += writeVarintLen(end0 - start0 + 1)
            var i: Int64 = 1
            while (i < rangeCount) {
                let (prevStart, _) = frame.getAckRange(i - 1)
                let (start, end_) = frame.getAckRange(i)
                let gap = prevStart - end_ - 1
                frameSize += writeVarintLen(gap) + writeVarintLen(end_ - start + 1)
                i += 1
            }
        }
        if (ft == FRAME_TYPE_ACK_ECN) {
            frameSize += writeVarintLen(frame.getEcnECT0()) + writeVarintLen(frame.getEcnECT1()) + writeVarintLen(frame.getEcnCE())
        }
        let totalSize = buf.size + frameSize
        var out = Array<Byte>(totalSize, repeat: 0u8)
        var pos = writeBytesAt(out, 0, buf)
        pos = writeByteAt(out, pos, ft)
        pos = writeVarintAt(out, pos, frame.getLargestAcked())
        pos = writeVarintAt(out, pos, frame.getAckDelay())
        if (rangeCount <= 0) {
            pos = writeVarintAt(out, pos, 0)
            pos = writeVarintAt(out, pos, 1)
        } else {
            let (start0, end0) = frame.getAckRange(0)
            pos = writeVarintAt(out, pos, rangeCount - 1)
            pos = writeVarintAt(out, pos, end0 - start0 + 1)
            var i: Int64 = 1
            while (i < rangeCount) {
                let (prevStart, _) = frame.getAckRange(i - 1)
                let (start, end_) = frame.getAckRange(i)
                let gap = prevStart - end_ - 1
                pos = writeVarintAt(out, pos, gap)
                pos = writeVarintAt(out, pos, end_ - start + 1)
                i += 1
            }
        }
        if (ft == FRAME_TYPE_ACK_ECN) {
            pos = writeVarintAt(out, pos, frame.getEcnECT0())
            pos = writeVarintAt(out, pos, frame.getEcnECT1())
            pos = writeVarintAt(out, pos, frame.getEcnCE())
        }
        out
    } else {
        buf
    }
}
