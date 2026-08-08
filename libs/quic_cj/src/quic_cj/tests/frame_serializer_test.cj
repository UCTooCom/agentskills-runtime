package quic_cj.tests

import quic_cj.wire.{appendFrame, parseFrame, appendByte, appendBytes,
    FRAME_TYPE_PING, FRAME_TYPE_HANDSHAKE_DONE, FRAME_TYPE_CRYPTO, FRAME_TYPE_MAX_DATA,
    CryptoFrame, MaxDataFrame, HandshakeDoneFrame}

@Test
public class FrameSerializerTestSuite {
    @TestCase
    public func testSerializePingRoundTrip(): Unit {
        var buf: Array<Byte> = []
        buf = appendByte(buf, 0x00u8) // 前缀
        buf = appendByte(buf, FRAME_TYPE_PING)
        let (frame, consumed) = parseFrame(buf[1..])
        @Assert(consumed, 1)
        @Assert(frame.frameType(), FRAME_TYPE_PING)
    }

    @TestCase
    public func testSerializeHandshakeDone(): Unit {
        let buf = appendByte([], FRAME_TYPE_HANDSHAKE_DONE)
        let (frame, consumed) = parseFrame(buf)
        @Assert(consumed, 1)
        @Assert(frame.frameType(), FRAME_TYPE_HANDSHAKE_DONE)
    }

    @TestCase
    public func testSerializeCrypto(): Unit {
        let frame = CryptoFrame()
        frame.offset = 0
        frame.data = [0x61u8, 0x62u8, 0x63u8]
        let buf = appendFrame([], frame)
        let (parsed, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(parsed.frameType(), FRAME_TYPE_CRYPTO)
        @Assert(parsed.getOffset(), 0)
        @Assert(parsed.getData(), [0x61u8, 0x62u8, 0x63u8])
    }
}
