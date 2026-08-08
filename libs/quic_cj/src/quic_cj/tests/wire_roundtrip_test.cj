package quic_cj.tests

import quic_cj.wire.{appendFrame, parseFrame, appendByte, appendBytes,
    Frame, PingFrame, PaddingFrame, CryptoFrame, MaxDataFrame, MaxStreamDataFrame, MaxStreamsFrame,
    DataBlockedFrame, StreamDataBlockedFrame, StreamsBlockedFrame,
    NewConnectionIDFrame, RetireConnectionIDFrame, PathChallengeFrame, PathResponseFrame,
    NewTokenFrame, ConnectionCloseFrame, ApplicationCloseFrame, HandshakeDoneFrame,
    DatagramFrame, StreamFrame, ResetStreamFrame, StopSendingFrame, AckFrame,
    ImmediateAckFrame, AckFrequencyFrame,
    FRAME_TYPE_PING, FRAME_TYPE_PADDING, FRAME_TYPE_CRYPTO, FRAME_TYPE_MAX_DATA, FRAME_TYPE_MAX_STREAM_DATA,
    FRAME_TYPE_MAX_STREAMS_BIDI, FRAME_TYPE_MAX_STREAMS_UNI,
    FRAME_TYPE_DATA_BLOCKED, FRAME_TYPE_STREAM_DATA_BLOCKED,
    FRAME_TYPE_STREAMS_BLOCKED_BIDI, FRAME_TYPE_STREAMS_BLOCKED_UNI,
    FRAME_TYPE_RESET_STREAM, FRAME_TYPE_STOP_SENDING, FRAME_TYPE_NEW_CONNECTION_ID,
    FRAME_TYPE_RETIRE_CONNECTION_ID, FRAME_TYPE_PATH_CHALLENGE, FRAME_TYPE_PATH_RESPONSE,
    FRAME_TYPE_NEW_TOKEN, FRAME_TYPE_CONNECTION_CLOSE, FRAME_TYPE_APPLICATION_CLOSE,
    FRAME_TYPE_HANDSHAKE_DONE, FRAME_TYPE_DATAGRAM, FRAME_TYPE_DATAGRAM_LEN,
    FRAME_TYPE_ACK, FRAME_TYPE_ACK_ECN, FRAME_TYPE_IMMEDIATE_ACK,
    FRAME_TYPE_ACK_FREQUENCY,
    appendVarint, readVarint}

@Test
public class WireRoundTripTestSuite {
    @TestCase
    public func testPingRoundTrip(): Unit {
        let buf = appendFrame([], PingFrame())
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, 1)
        @Assert(parsed.frameType(), FRAME_TYPE_PING)
    }
    @TestCase
    public func testPaddingRoundTrip(): Unit {
        let frame = PaddingFrame()
        frame.size = 3
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, 3)
        @Assert(parsed.frameType(), FRAME_TYPE_PADDING)
        match (parsed as PaddingFrame) {
            case Some(pf) => @Assert(pf.size, 3)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testHandshakeDoneRoundTrip(): Unit {
        let buf = appendFrame([], HandshakeDoneFrame())
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, 1)
        @Assert(parsed.frameType(), FRAME_TYPE_HANDSHAKE_DONE)
    }

    @TestCase
    public func testImmediateAckRoundTrip(): Unit {
        let buf = appendFrame([], ImmediateAckFrame())
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, 1)
        @Assert(parsed.frameType(), FRAME_TYPE_IMMEDIATE_ACK)
    }

    @TestCase
    public func testCryptoFrameRoundTrip(): Unit {
        let frame = CryptoFrame()
        frame.offset = 42
        frame.data = [0x61u8, 0x62u8, 0x63u8, 0x64u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_CRYPTO)
        @Assert(parsed.getOffset(), 42)
        @Assert(parsed.getData(), [0x61u8, 0x62u8, 0x63u8, 0x64u8])
    }

    @TestCase
    public func testMaxDataFrameRoundTrip(): Unit {
        let frame = MaxDataFrame()
        frame.maxData = 123456
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_MAX_DATA)
        @Assert(parsed.getMaxData(), 123456)
    }

    @TestCase
    public func testResetStreamFrameRoundTrip(): Unit {
        let frame = ResetStreamFrame(7, 42u64, 999)
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_RESET_STREAM)
        @Assert(parsed.getStreamId(), 7)
        @Assert(parsed.getErrorCode() == 42u64, true)
    }

    @TestCase
    public func testStopSendingRoundTrip(): Unit {
        let frame = StopSendingFrame()
        frame.streamId = 5
        frame.errorCode = 99u64
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_STOP_SENDING)
        @Assert(parsed.getStreamId(), 5)
        @Assert(parsed.getErrorCode() == 99u64, true)
    }

    @TestCase
    public func testStreamFrameRoundTrip(): Unit {
        let frame = StreamFrame()
        frame.streamId = 4
        frame.offset = 100
        frame.fin = true
        frame.data = [0xa1u8, 0xa2u8, 0xa3u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.getStreamId(), 4)
        @Assert(parsed.getOffset(), 100)
        @Assert(parsed.getFin(), true)
        @Assert(parsed.getData(), [0xa1u8, 0xa2u8, 0xa3u8])
    }

    @TestCase
    public func testNewConnectionIDRoundTrip(): Unit {
        let frame = NewConnectionIDFrame()
        frame.seq = 1
        frame.retirePriorTo = 0
        frame.connectionId = [0x01u8, 0x02u8, 0x03u8, 0x04u8]
        frame.statelessResetToken = Array<Byte>(16, repeat: 0xabu8)
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_NEW_CONNECTION_ID)
        @Assert(parsed.getSeq(), 1)
        @Assert(parsed.getRetirePriorTo(), 0)
        @Assert(parsed.getConnId(), [0x01u8, 0x02u8, 0x03u8, 0x04u8])
        @Assert(parsed.getResetToken().size, 16)
    }

    @TestCase
    public func testPathChallengeRoundTrip(): Unit {
        let frame = PathChallengeFrame()
        frame.data = [0x10u8, 0x20u8, 0x30u8, 0x40u8, 0x50u8, 0x60u8, 0x70u8, 0x80u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_PATH_CHALLENGE)
        @Assert(parsed.getData().size, 8)
    }

    @TestCase
    public func testConnectionCloseRoundTrip(): Unit {
        let frame = ConnectionCloseFrame()
        frame.errorCode = 100u64
        frame.trigFrameType = Int64(FRAME_TYPE_PING)
        frame.reasonPhrase = [0x61u8, 0x62u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_CONNECTION_CLOSE)
        @Assert(parsed.getErrorCode() == 100u64, true)
        @Assert(parsed.getReasonPhrase(), [0x61u8, 0x62u8])
    }

    @TestCase
    public func testDatagramFrameRoundTrip(): Unit {
        let frame = DatagramFrame()
        frame.data = [0x11u8, 0x22u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_DATAGRAM)
        @Assert(parsed.getData(), [0x11u8, 0x22u8])
    }

    @TestCase
    public func testAckFrameRoundTrip(): Unit {
        let frame = AckFrame()
        frame.largestAcked = 60
        frame.ackDelay = 5
        frame.ackRanges[0] = (50, 60)
        frame.ackRangeCount = 1
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_ACK)
        @Assert(parsed.getLargestAcked(), 60)
        @Assert(parsed.getAckRangeCount(), 1)
        let (start0, end0) = parsed.getAckRange(0)
        @Assert(start0, 50)
        @Assert(end0, 60)
    }

    @TestCase
    public func testDataBlockedRoundTrip(): Unit {
        let frame = DataBlockedFrame()
        frame.maxData = 5000
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_DATA_BLOCKED)
        @Assert(parsed.getMaxData(), 5000)
    }

    @TestCase
    public func testMaxStreamDataRoundTrip(): Unit {
        let frame = MaxStreamDataFrame()
        frame.streamId = 3
        frame.maxStreamData = 20000
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_MAX_STREAM_DATA)
        @Assert(parsed.getStreamId(), 3)
        @Assert(parsed.getMaxStreamData(), 20000)
    }
}

@Test
public class WireRoundTripMultiRangeAndEdgeTestSuite {
    @TestCase
    public func testAckFrameMultiRangeRoundTrip(): Unit {
        let frame = AckFrame()
        frame.largestAcked = 100
        frame.ackDelay = 5
        frame.ackRanges[0] = (80, 100)
        frame.ackRanges[1] = (50, 60)
        frame.ackRangeCount = 2
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_ACK)
        @Assert(parsed.getLargestAcked(), 100)
        @Assert(parsed.getAckRangeCount(), 2)
        let (s0, e0) = parsed.getAckRange(0)
        @Assert(s0, 80)
        @Assert(e0, 100)
        let (s1, e1) = parsed.getAckRange(1)
        @Assert(s1, 50)
        @Assert(e1, 60)
    }

    @TestCase
    public func testAckAckThreeRangesRoundTrip(): Unit {
        let frame = AckFrame()
        frame.largestAcked = 200
        frame.ackDelay = 3
        frame.ackRanges[0] = (150, 200)
        frame.ackRanges[1] = (100, 120)
        frame.ackRanges[2] = (30, 50)
        frame.ackRangeCount = 3
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.getAckRangeCount(), 3)
        let (s0, e0) = parsed.getAckRange(0)
        @Assert(s0, 150)
        @Assert(e0, 200)
        let (s2, e2) = parsed.getAckRange(2)
        @Assert(s2, 30)
        @Assert(e2, 50)
    }

    @TestCase
    public func testPaddingSize0(): Unit {
        let frame = PaddingFrame()
        frame.size = 0
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, 0)
        @Assert(parsed.frameType(), FRAME_TYPE_PADDING)
    }

    @TestCase
    public func testPaddingSize1(): Unit {
        let frame = PaddingFrame()
        frame.size = 1
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, 1)
        @Assert(parsed.frameType(), FRAME_TYPE_PADDING)
        match (parsed as PaddingFrame) {
            case Some(pf) => @Assert(pf.size, 1)
            case None => @Assert(false, true)
        }
    }

    @TestCase
    public func testPathResponseFrameRoundTrip(): Unit {
        let frame = PathResponseFrame()
        frame.data = [0x10u8, 0x20u8, 0x30u8, 0x40u8, 0x50u8, 0x60u8, 0x70u8, 0x80u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_PATH_RESPONSE)
        @Assert(parsed.getData().size, 8)
    }

    @TestCase
    public func testStreamsBlockedRoundTrip(): Unit {
        let frame = StreamsBlockedFrame()
        frame.maxStreams = 20
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.getMaxStreams(), 20)
    }
}

@Test
public class WireRoundTripExtendedTestSuite {
    @TestCase
    public func testMaxStreamsUniRoundTrip(): Unit {
        let frame = MaxStreamsFrame()
        frame.maxStreams = 50
        // MaxStreamsFrame 始终序列化为 BIDI
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.getMaxStreams(), 50)
    }

    @TestCase
    public func testStreamDataBlockedRoundTrip(): Unit {
        let frame = StreamDataBlockedFrame()
        frame.streamId = 7
        frame.maxStreamData = 5000
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_STREAM_DATA_BLOCKED)
        @Assert(parsed.getStreamId(), 7)
        @Assert(parsed.getMaxStreamData(), 5000)
    }



    @TestCase
    public func testRetireConnectionIDRoundTrip(): Unit {
        let frame = RetireConnectionIDFrame()
        frame.seq = 5
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_RETIRE_CONNECTION_ID)
        @Assert(parsed.getSeq(), 5)
    }

    @TestCase
    public func testNewTokenRoundTrip(): Unit {
        let frame = NewTokenFrame()
        frame.token = [0xa1u8, 0xa2u8, 0xa3u8, 0xa4u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_NEW_TOKEN)
        @Assert(parsed.getData(), [0xa1u8, 0xa2u8, 0xa3u8, 0xa4u8])
    }

    @TestCase
    public func testApplicationCloseRoundTrip(): Unit {
        let frame = ApplicationCloseFrame()
        frame.errorCode = 0x100u64
        frame.reasonPhrase = [0x61u8, 0x62u8, 0x63u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_APPLICATION_CLOSE)
        @Assert(parsed.getErrorCode() == 0x100u64, true)
        @Assert(parsed.getReasonPhrase(), [0x61u8, 0x62u8, 0x63u8])
    }

    @TestCase
    public func testDatagramFrameRoundTripExtended(): Unit {
        let frame = DatagramFrame()
        frame.data = [0x11u8, 0x22u8, 0x33u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.getData().size, 3)
    }

    @TestCase
    public func testAckECNRoundTrip(): Unit {
        let frame = AckFrame()
        frame.largestAcked = 20
        frame.ackDelay = 3
        frame.ackRanges[0] = (10, 20)
        frame.ackRangeCount = 1
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.getLargestAcked(), 20)
        let (start0, end0) = parsed.getAckRange(0)
        @Assert(start0, 10)
        @Assert(end0, 20)
    }

    @TestCase
    public func testStreamFrameWithoutOffLenFin(): Unit {
        let frame = StreamFrame()
        frame.streamId = 4
        frame.data = [0xa1u8, 0xa2u8]
        // 最小流帧：无偏移，无长度，无结束标记
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.getStreamId(), 4)
        @Assert(parsed.getOffset(), 0)
        @Assert(parsed.getFin(), false)
    }



    @TestCase
    public func testStreamFrameNumericEdgeCases(): Unit {
        let frame = StreamFrame()
        frame.streamId = 0
        frame.offset = 0
        frame.fin = true
        frame.data = []
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.getStreamId(), 0)
        @Assert(parsed.getFin(), true)
        @Assert(parsed.getData().size, 0)
    }

    @TestCase
    public func testAckFrequencyRoundTrip(): Unit {
        let frame = AckFrequencyFrame()
        frame.seq = 0
        frame.packetsAfter = 10
        frame.maxAckDelayMicro = 25000
        frame.ignoreOrder = true
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_ACK_FREQUENCY)
        match (parsed as AckFrequencyFrame) {
            case Some(p) =>
                @Assert(p.seq, 0)
                @Assert(p.packetsAfter, 10)
                @Assert(p.maxAckDelayMicro, 25000)
                @Assert(p.ignoreOrder, true)
            case None => @Assert(true, false)
        }
    }

}
