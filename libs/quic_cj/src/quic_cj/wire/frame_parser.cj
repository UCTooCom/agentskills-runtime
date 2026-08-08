package quic_cj.wire

import quic_cj.protocol.MAX_CONN_ID_LEN

/// 从数据中读取一个 QUIC 帧并返回 (Frame, 已消费字节数)。
/// 如果数据不足或帧类型未知，返回 (Frame(), 0)。
public func parseFrame(data: Array<Byte>): (Frame, Int64) {
    parseFrameAt(data, 0)
}

/// 在 data 的 start 位置解析 QUIC 帧（offset-based，避免切片拷贝）。
public func parseFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    if (data.size < start + 1) { return (Frame(), 0) }
    let typeByte = UInt8(data[start])
    if (typeByte == FRAME_TYPE_PING) {
        (PingFrame(), 1)
    } else if (typeByte == FRAME_TYPE_PADDING) {
        parsePaddingFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_ACK || typeByte == FRAME_TYPE_ACK_ECN) {
        parseAckFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_RESET_STREAM) {
        parseResetStreamFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_STOP_SENDING) {
        parseStopSendingFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_CRYPTO) {
        parseCryptoFrameAt(data, start)
    } else if (typeByte >= FRAME_TYPE_STREAM_BASE && typeByte < (FRAME_TYPE_STREAM_BASE + 8u8)) {
        parseStreamFrameAt(data, start, typeByte)
    } else if (typeByte == FRAME_TYPE_MAX_DATA) {
        parseMaxDataFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_MAX_STREAM_DATA) {
        parseMaxStreamDataFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_MAX_STREAMS_BIDI || typeByte == FRAME_TYPE_MAX_STREAMS_UNI) {
        parseMaxStreamsFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_DATA_BLOCKED) {
        parseDataBlockedFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_STREAM_DATA_BLOCKED) {
        parseStreamDataBlockedFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_STREAMS_BLOCKED_BIDI || typeByte == FRAME_TYPE_STREAMS_BLOCKED_UNI) {
        parseStreamsBlockedFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_CONNECTION_CLOSE) {
        parseConnectionCloseFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_APPLICATION_CLOSE) {
        parseApplicationCloseFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_HANDSHAKE_DONE) {
        (HandshakeDoneFrame(), 1)
    } else if (typeByte == FRAME_TYPE_NEW_CONNECTION_ID) {
        parseNewConnectionIDFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_RETIRE_CONNECTION_ID) {
        parseRetireConnectionIDFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_PATH_CHALLENGE) {
        parsePathChallengeFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_PATH_RESPONSE) {
        parsePathResponseFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_NEW_TOKEN) {
        parseNewTokenFrameAt(data, start)
   } else if (typeByte == FRAME_TYPE_IMMEDIATE_ACK) {
        (ImmediateAckFrame(), 1)
    } else if (typeByte == FRAME_TYPE_ACK_FREQUENCY) {
        parseAckFrequencyFrameAt(data, start)
    } else if (typeByte == FRAME_TYPE_DATAGRAM || typeByte == FRAME_TYPE_DATAGRAM_LEN) {
        parseDatagramFrameAt(data, start, typeByte)
    } else {
        (Frame(), 1) // 未知，消费 1 字节并跳过
    }
}

// ── 旧兼容包装（调用 offset-based 版本） ──

private func parseAckFrame(data: Array<Byte>): (Frame, Int64) { parseAckFrameAt(data, 0) }
private func parseResetStreamFrame(data: Array<Byte>): (Frame, Int64) { parseResetStreamFrameAt(data, 0) }
private func parseStopSendingFrame(data: Array<Byte>): (Frame, Int64) { parseStopSendingFrameAt(data, 0) }
private func parseCryptoFrame(data: Array<Byte>): (Frame, Int64) { parseCryptoFrameAt(data, 0) }
private func parseStreamFrame(data: Array<Byte>, typeByte: UInt8): (Frame, Int64) { parseStreamFrameAt(data, 0, typeByte) }
private func parseMaxDataFrame(data: Array<Byte>): (Frame, Int64) { parseMaxDataFrameAt(data, 0) }
private func parseMaxStreamDataFrame(data: Array<Byte>): (Frame, Int64) { parseMaxStreamDataFrameAt(data, 0) }
private func parseMaxStreamsFrame(data: Array<Byte>): (Frame, Int64) { parseMaxStreamsFrameAt(data, 0) }
private func parseDataBlockedFrame(data: Array<Byte>): (Frame, Int64) { parseDataBlockedFrameAt(data, 0) }
private func parseStreamDataBlockedFrame(data: Array<Byte>): (Frame, Int64) { parseStreamDataBlockedFrameAt(data, 0) }
private func parseStreamsBlockedFrame(data: Array<Byte>): (Frame, Int64) { parseStreamsBlockedFrameAt(data, 0) }
private func parseConnectionCloseFrame(data: Array<Byte>): (Frame, Int64) { parseConnectionCloseFrameAt(data, 0) }
private func parseApplicationCloseFrame(data: Array<Byte>): (Frame, Int64) { parseApplicationCloseFrameAt(data, 0) }
private func parseNewConnectionIDFrame(data: Array<Byte>): (Frame, Int64) { parseNewConnectionIDFrameAt(data, 0) }
private func parseRetireConnectionIDFrame(data: Array<Byte>): (Frame, Int64) { parseRetireConnectionIDFrameAt(data, 0) }
private func parsePathChallengeFrame(data: Array<Byte>): (Frame, Int64) { parsePathChallengeFrameAt(data, 0) }
private func parsePathResponseFrame(data: Array<Byte>): (Frame, Int64) { parsePathResponseFrameAt(data, 0) }
private func parseNewTokenFrame(data: Array<Byte>): (Frame, Int64) { parseNewTokenFrameAt(data, 0) }
private func parseDatagramFrame(data: Array<Byte>, typeByte: UInt8): (Frame, Int64) { parseDatagramFrameAt(data, 0, typeByte) }

// ── offset-based 帧解析器（避免切片拷贝） ──

private func parseAckFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    if (data.size < start + 2) { return (Frame(), 0) }
    let (largestAcked, n1) = readVarintAt(data, start + 1)
    if (n1 == 0) { return (Frame(), 0) }
    var offset: Int64 = 1 + n1
    let (ackDelay, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    let (ackRangeCount, n3) = readVarintAt(data, start + offset)
    if (n3 == 0) { return (Frame(), 0) }
    offset += n3
    let (firstBlockLen, n4) = readVarintAt(data, start + offset)
    if (n4 == 0) { return (Frame(), 0) }
    offset += n4
    let frame = AckFrame()
    frame.largestAcked = largestAcked
    frame.ackDelay = ackDelay
    // First range: [largestAcked - firstBlockLen + 1, largestAcked]
    frame.ackRanges[0] = (largestAcked - firstBlockLen + 1, largestAcked)
    frame.ackRangeCount = 1
    // Additional ranges with proper gap computation
    var prevStart = largestAcked - firstBlockLen + 1
    var i: Int64 = 0
    while (i < ackRangeCount && start + offset < data.size) {
        let (gap, ng) = readVarintAt(data, start + offset)
        if (ng == 0) { break }
        offset += ng
        if (start + offset >= data.size) { break }
        let (blockLen, nb) = readVarintAt(data, start + offset)
        if (nb == 0) { break }
        offset += nb
        let end_ = prevStart - gap - 1
        let start_ = end_ - blockLen + 1
        frame.ackRanges[frame.ackRangeCount] = (start_, end_)
        frame.ackRangeCount += 1
        prevStart = start_
        i += 1
    }
    // If ACK_ECN, parse ECN counts
    if ((start < data.size) && data[start] == FRAME_TYPE_ACK_ECN) {
        if (start + offset >= data.size) { return (Frame(), 0) }
        let (ect0, ne0) = readVarintAt(data, start + offset)

        if (ne0 == 0) { return (Frame(), 0) }
        offset += ne0
        if (start + offset >= data.size) { return (Frame(), 0) }
        let (ect1, ne1) = readVarintAt(data, start + offset)
        if (ne1 == 0) { return (Frame(), 0) }
        offset += ne1
        if (start + offset >= data.size) { return (Frame(), 0) }
        let (ce, nce) = readVarintAt(data, start + offset)
        if (nce == 0) { return (Frame(), 0) }
        offset += nce
        frame.ecnECT0 = ect0
        frame.ecnECT1 = ect1
        frame.ecnCE = ce
    }
    (frame, offset)
}

private func parseStreamsBlockedFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    let (ms, n) = readVarintAt(data, start + 1)
    if (n == 0) { return (Frame(), 0) }
    let frame = StreamsBlockedFrame()
    frame.maxStreams = ms
    (frame, 1 + n)
}

private func parseResetStreamFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var offset: Int64 = 1
    let (sid, n1) = readVarintAt(data, start + offset)
    if (n1 == 0) { return (Frame(), 0) }
    offset += n1
    let (err, ne) = readVarintAt(data, start + offset)
    if (ne == 0) { return (Frame(), 0) }
    offset += ne
    let (fs, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    (ResetStreamFrame(sid, UInt64(err), fs), offset)
}

private func parseStopSendingFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var offset: Int64 = 1
    let (sid, n1) = readVarintAt(data, start + offset)
    if (n1 == 0) { return (Frame(), 0) }
    offset += n1
    let (err, ne) = readVarintAt(data, start + offset)
    if (ne == 0) { return (Frame(), 0) }
    offset += ne
    let frame = StopSendingFrame()
    frame.streamId = sid
    frame.errorCode = UInt64(err)
    (frame, offset)
}

private func parseCryptoFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var offset: Int64 = 1
    let (off, n1) = readVarintAt(data, start + offset)
    if (n1 == 0) { return (Frame(), 0) }
    offset += n1
    let (len, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    if (start + offset + len > data.size) { return (Frame(), 0) }
    let frame = CryptoFrame()
    frame.offset = off
    frame.data = data[(start + offset)..(start + offset + len)]
    (frame, offset + len)
}

private func parseStreamFrameAt(data: Array<Byte>, start: Int64, typeByte: UInt8): (Frame, Int64) {
    let hasOff = (typeByte & STREAM_OFF_BIT) != 0u8
    let hasLen = (typeByte & STREAM_LEN_BIT) != 0u8
    let fin = (typeByte & STREAM_FIN_BIT) != 0u8
    var offset: Int64 = 1
    let (sid, n1) = readVarintAt(data, start + offset)
    if (n1 == 0) { return (Frame(), 0) }
    offset += n1
    var streamOff: Int64 = 0
    if (hasOff) {
        let (o, n2) = readVarintAt(data, start + offset)
        if (n2 == 0) { return (Frame(), 0) }
        streamOff = o
        offset += n2
    }
    var dataLen = data.size - (start + offset)
    if (hasLen) {
        let (l, n3) = readVarintAt(data, start + offset)
        if (n3 == 0) { return (Frame(), 0) }
        dataLen = l
        offset += n3
    }
    if (start + offset + dataLen > data.size) { return (Frame(), 0) }
    let frame = StreamFrame()
    frame.streamId = sid
    frame.offset = streamOff
    frame.fin = fin
    frame.data = data[(start + offset)..(start + offset + dataLen)]
    (frame, offset + dataLen)
}

private func parseMaxDataFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    let (md, n) = readVarintAt(data, start + 1)
    if (n == 0) { return (Frame(), 0) }
    let frame = MaxDataFrame()
    frame.maxData = md
    (frame, 1 + n)
}

private func parseMaxStreamDataFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var offset: Int64 = 1
    let (sid, n1) = readVarintAt(data, start + offset)
    if (n1 == 0) { return (Frame(), 0) }
    offset += n1
    let (msd, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    let frame = MaxStreamDataFrame()
    frame.streamId = sid
    frame.maxStreamData = msd
    (frame, offset)
}

private func parseMaxStreamsFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    let (ms, n) = readVarintAt(data, start + 1)
    if (n == 0) { return (Frame(), 0) }
    let frame = MaxStreamsFrame()
    frame.maxStreams = ms
    (frame, 1 + n)
}

private func parseDataBlockedFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    let (md, n) = readVarintAt(data, start + 1)
    if (n == 0) { return (Frame(), 0) }
    let frame = DataBlockedFrame()
    frame.maxData = md
    (frame, 1 + n)
}

private func parseStreamDataBlockedFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var offset: Int64 = 1
    let (sid, n1) = readVarintAt(data, start + offset)
    if (n1 == 0) { return (Frame(), 0) }
    offset += n1
    let (msd, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    let frame = StreamDataBlockedFrame()
    frame.streamId = sid
    frame.maxStreamData = msd
    (frame, offset)
}

private func parseConnectionCloseFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var offset: Int64 = 1
    let (err, ne) = readVarintAt(data, start + offset)
    if (ne == 0) { return (Frame(), 0) }
    offset += ne
    let (ft, n1) = readVarintAt(data, start + offset)
    if (n1 == 0) { return (Frame(), 0) }
    offset += n1
    let (phraseLen, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    let frame = ConnectionCloseFrame()
    frame.errorCode = UInt64(err)
    frame.trigFrameType = ft
    if (start + offset + phraseLen <= data.size) {
        frame.reasonPhrase = data[(start + offset)..(start + offset + phraseLen)]
    }
    (frame, offset + phraseLen)
}

private func parseApplicationCloseFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var offset: Int64 = 1
    let (err, ne) = readVarintAt(data, start + offset)
    if (ne == 0) { return (Frame(), 0) }
    offset += ne
    let (phraseLen, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    let frame = ApplicationCloseFrame()
    frame.errorCode = UInt64(err)
    if (start + offset + phraseLen <= data.size) {
        frame.reasonPhrase = data[(start + offset)..(start + offset + phraseLen)]
    }
    (frame, offset + phraseLen)
}

private func parseNewConnectionIDFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var offset: Int64 = 1
    let (seq, n1) = readVarintAt(data, start + offset)
    if (n1 == 0) { return (Frame(), 0) }
    offset += n1
    let (rpt, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    if (start + offset >= data.size) { return (Frame(), 0) }
    let connIdLen = Int64(UInt8(data[start + offset]))
    if (connIdLen > MAX_CONN_ID_LEN) { return (Frame(), 0) }
    offset += 1
    if (start + offset + connIdLen + 16 > data.size) { return (Frame(), 0) }
    let frame = NewConnectionIDFrame()
    frame.seq = seq
    frame.retirePriorTo = rpt
    frame.connectionId = data[(start + offset)..(start + offset + connIdLen)]
    frame.statelessResetToken = data[(start + offset + connIdLen)..(start + offset + connIdLen + 16)]
    (frame, offset + connIdLen + 16)
}

private func parseRetireConnectionIDFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    let (seq, n) = readVarintAt(data, start + 1)
    if (n == 0) { return (Frame(), 0) }
    let frame = RetireConnectionIDFrame()
    frame.seq = seq
    (frame, 1 + n)
}

private func parsePathChallengeFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    if (data.size < start + 9) { return (Frame(), 0) }
    let frame = PathChallengeFrame()
    frame.data = data[(start + 1)..(start + 9)]
    (frame, 9)
}

private func parsePathResponseFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    if (data.size < start + 9) { return (Frame(), 0) }
    let frame = PathResponseFrame()
    frame.data = data[(start + 1)..(start + 9)]
    (frame, 9)
}

private func parseNewTokenFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    let (tokenLen, n) = readVarintAt(data, start + 1)
    if (n == 0) { return (Frame(), 0) }
    let total = 1 + n
    if (start + total + tokenLen > data.size) { return (Frame(), 0) }
    let frame = NewTokenFrame()
    frame.token = data[(start + total)..(start + total + tokenLen)]
    (frame, total + tokenLen)
}

// PADDING frame: return consecutive 0x00 bytes as a single PaddingFrame

private func parsePaddingFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    var count: Int64 = 0
    var pos = start
    while (pos < data.size && UInt8(data[pos]) == FRAME_TYPE_PADDING) {
        count += 1
        pos += 1
    }
    let frame = PaddingFrame()
    frame.size = count
    (frame, count)
}


private func parseAckFrequencyFrameAt(data: Array<Byte>, start: Int64): (Frame, Int64) {
    if (data.size < start + 2) { return (Frame(), 0) }
    let (seq, n1) = readVarintAt(data, start + 1)
    if (n1 == 0) { return (Frame(), 0) }
    var offset: Int64 = 1 + n1
    let (packetsAfter, n2) = readVarintAt(data, start + offset)
    if (n2 == 0) { return (Frame(), 0) }
    offset += n2
    let (maxAckDelayMicro, n3) = readVarintAt(data, start + offset)
    if (n3 == 0) { return (Frame(), 0) }
    offset += n3
    let (ignoreOrderVar, n4) = readVarintAt(data, start + offset)
    if (n4 == 0) { return (Frame(), 0) }
    offset += n4
    let frame = AckFrequencyFrame()
    frame.seq = seq
    frame.packetsAfter = packetsAfter
    frame.maxAckDelayMicro = maxAckDelayMicro
    frame.ignoreOrder = (ignoreOrderVar != 0)
    (frame, offset)
}
private func parseDatagramFrameAt(data: Array<Byte>, start: Int64, typeByte: UInt8): (Frame, Int64) {
    // ── 原始内容 ──
    let hasLen = (typeByte == FRAME_TYPE_DATAGRAM_LEN)
    if (hasLen) {
        let (dlen, n) = readVarintAt(data, start + 1)
        if (n == 0) { return (Frame(), 0) }
        let total = 1 + n
        if (start + total + dlen > data.size) { return (Frame(), 0) }
        let frame = DatagramFrame()
        frame.data = data[(start + total)..(start + total + dlen)]
        (frame, total + dlen)
    } else {
        let frame = DatagramFrame()
        frame.data = data[(start + 1)..]
        (frame, Int64(data.size - start))
    }
}
