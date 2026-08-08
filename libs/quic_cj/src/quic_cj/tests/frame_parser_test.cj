package quic_cj.tests

import quic_cj.wire.{parseFrame, appendVarint, FRAME_TYPE_PING, FRAME_TYPE_CRYPTO, FRAME_TYPE_MAX_DATA, FRAME_TYPE_MAX_STREAMS_BIDI}

@Test
public class FrameParserTestSuite {
    @TestCase
    public func testParsePing(): Unit {
        let data: Array<Byte> = [FRAME_TYPE_PING]
        let (frame, consumed) = parseFrame(data)
        @Assert(consumed, 1)
        @Assert(frame.frameType(), FRAME_TYPE_PING)
    }

    @TestCase
    public func testParseCryptoFrame(): Unit {
        var buf: Array<Byte> = [FRAME_TYPE_CRYPTO]
        buf = appendVarint(buf, 0)     // 偏移=0
        let result = appendVarint(buf, 3) // 长度=3
        // 构建最终缓冲区：类型 + 偏移(1) + 长度(1) + 负载(3)
        var fullBuf = Array<Byte>(result.size + 3, repeat: 0)
        var i: Int64 = 0
        while (i < result.size) {
            fullBuf[i] = result[i]
            i += 1
        }
        fullBuf[i] = 0x61u8
        fullBuf[i + 1] = 0x62u8
        fullBuf[i + 2] = 0x63u8
        let (frame, consumed) = parseFrame(fullBuf)
        @Assert(consumed > 0, true)
        @Assert(frame.frameType(), FRAME_TYPE_CRYPTO)
    }

    @TestCase
    public func testParseMaxData(): Unit {
        var buf: Array<Byte> = [FRAME_TYPE_MAX_DATA]
        buf = appendVarint(buf, 1000)
        let (frame, consumed) = parseFrame(buf)
        @Assert(consumed, buf.size)
        @Assert(frame.frameType(), FRAME_TYPE_MAX_DATA)
    }

    @TestCase
    public func testParseTooShort(): Unit {
        let (frame, consumed) = parseFrame([])
        @Assert(consumed, 0)
        @Assert(frame.frameType(), 0u8)
    }
}
