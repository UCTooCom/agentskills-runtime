package http_lib.server

import std.collection.ArrayList
import http_lib.core.{assertTrue, assertFalse}

@Test
public class WebSocketFrameTest {

    @TestCase
    public func testParseTextFrame(): Unit {
        // 未掩码文本帧："Hello"
        // FIN=1, opcode=0x1, 负载长度=5
        let frameData: Array<UInt8> = [
            0x81,  // FIN + 文本操作码
            0x05,  // 负载长度 = 5
            b'H', b'e', b'l', b'l', b'o'
        ]
        let frame = parseWebSocketFrame(frameData)
        assertTrue(frame.fin)
        assertFalse(frame.masked)
        assertTrue(frame.opcode == WebSocketOpcode.Text)
        assertTrue(frame.payloadLength == 5)
        let text = String.fromUtf8(frame.payloadData)
        assertTrue(text == "Hello")
    }

    @TestCase
    public func testParseMaskedFrame(): Unit {
        // 掩码文本帧："Test"（客户端到服务器）
        // FIN=1, MASK=1, opcode=0x1, 负载长度=4
        // 掩码密钥：0x01 0x02 0x03 0x04
        let maskKey: Array<UInt8> = [0x01, 0x02, 0x03, 0x04]
        let payload: Array<UInt8> = [b'T', b'e', b's', b't']
        var maskedPayload = Array<UInt8>(4, repeat: 0)
        var i: Int64 = 0
        while (i < 4) {
            maskedPayload[i] = payload[i] ^ maskKey[i]
            i++
        }
        var frameData = ArrayList<UInt8>()
        frameData.add(0x81)      // FIN + 文本帧
        frameData.add(0x84)      // 掩码 + 长度=4
        for (b in maskKey) { frameData.add(b) }
        for (b in maskedPayload) { frameData.add(b) }

        let frame = parseWebSocketFrame(frameData.toArray())
        assertTrue(frame.fin)
        assertTrue(frame.masked)
        assertTrue(frame.opcode == WebSocketOpcode.Text)
        let text = String.fromUtf8(frame.payloadData)
        assertTrue(text == "Test")
    }

    @TestCase
    public func testParseBinaryFrame(): Unit {
        // 3 字节的二进制帧
        let frameData: Array<UInt8> = [
            0x82,  // FIN + 二进制操作码
            0x03,  // 长度 = 3
            0x01, 0x02, 0x03
        ]
        let frame = parseWebSocketFrame(frameData.toArray())
        assertTrue(frame.fin)
        assertTrue(frame.opcode == WebSocketOpcode.Binary)
        assertTrue(frame.payloadLength == 3)
        assertTrue(frame.payloadData.size == 3)
        assertTrue(frame.payloadData[0] == 0x01)
        assertTrue(frame.payloadData[1] == 0x02)
        assertTrue(frame.payloadData[2] == 0x03)
    }

    @TestCase
    public func testParseCloseFrame(): Unit {
        // 带状态码的 Close 帧
        let frameData: Array<UInt8> = [
            0x88,  // FIN + 关闭操作码
            0x02,  // 长度 = 2
            0x03, 0xe8  // 状态码 1000
        ]
        let frame = parseWebSocketFrame(frameData.toArray())
        assertTrue(frame.fin)
        assertTrue(frame.opcode == WebSocketOpcode.Close)
        assertTrue(frame.payloadLength == 2)
    }

    @TestCase
    public func testParsePingFrame(): Unit {
        let frameData: Array<UInt8> = [
            0x89,  // FIN + Ping 帧 帧
            0x00   // 无负载
        ]
        let frame = parseWebSocketFrame(frameData.toArray())
        assertTrue(frame.fin)
        assertTrue(frame.opcode == WebSocketOpcode.Ping)
        assertTrue(frame.payloadLength == 0)
    }

    @TestCase
    public func testParsePongFrame(): Unit {
        let frameData: Array<UInt8> = [
            0x8a,  // FIN + Pong 帧
            0x00   // 无负载
        ]
        let frame = parseWebSocketFrame(frameData.toArray())
        assertTrue(frame.fin)
        assertTrue(frame.opcode == WebSocketOpcode.Pong)
        assertTrue(frame.payloadLength == 0)
    }

    @TestCase
    public func testParseContinuationFrame(): Unit {
        let frameData: Array<UInt8> = [
            0x00,  // 无 FIN + 延续帧
            0x03,  // 长度 = 3
            0x01, 0x02, 0x03
        ]
        let frame = parseWebSocketFrame(frameData.toArray())
        assertFalse(frame.fin)
        assertTrue(frame.opcode == WebSocketOpcode.Continuation)
        assertTrue(frame.payloadLength == 3)
    }

    @TestCase
    public func testParseExtendedLength16(): Unit {
        // 126 字节负载（使用 16 位扩展长度）
        var payload = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < 126) { payload.add(UInt8(i & 0xff)); i++ }
        var frameData = ArrayList<UInt8>()
        frameData.add(0x82)  // FIN + 二进制帧
        frameData.add(126)   // 扩展长度标记
        frameData.add(0x00)  // 长度高位字节
        frameData.add(126)   // 长度低位字节
        for (b in payload) { frameData.add(b) }

        let frame = parseWebSocketFrame(frameData.toArray())
        assertTrue(frame.payloadLength == 126)
        assertTrue(frame.payloadData.size == 126)
    }

    @TestCase
    public func testEncodeTextFrame(): Unit {
        let payload = unsafe { "Hello".rawData() }
        let encoded = encodeWebSocketFrame(WebSocketOpcode.Text, payload, false)

        assertTrue(encoded.size == 7)  // 2 字节头部 + 5 字节负载
        assertTrue(encoded[0] == 0x81)  // FIN + 文本帧
        assertTrue(encoded[1] == 0x05)  // 长度 = 5

        let text = String.fromUtf8(encoded[2..])
        assertTrue(text == "Hello")
    }

    @TestCase
    public func testEncodeBinaryFrame(): Unit {
        let payload: Array<UInt8> = [0x01, 0x02, 0x03]
        let encoded = encodeWebSocketFrame(WebSocketOpcode.Binary, payload, false)

        assertTrue(encoded.size == 5)  // 2 字节头部 + 3 字节负载
        assertTrue(encoded[0] == 0x82)  // FIN + 二进制帧
        assertTrue(encoded[1] == 0x03)  // 长度 = 3
        assertTrue(encoded[2] == 0x01)
        assertTrue(encoded[3] == 0x02)
        assertTrue(encoded[4] == 0x03)
    }

    @TestCase
    public func testEncodeEmptyFrame(): Unit {
        let payload: Array<UInt8> = []
        let encoded = encodeWebSocketFrame(WebSocketOpcode.Ping, payload, false)

        assertTrue(encoded.size == 2)
        assertTrue(encoded[0] == 0x89)  // FIN + Ping 帧 帧
        assertTrue(encoded[1] == 0x00)  // 长度 = 0
    }

    @TestCase
    public func testEncodeCloseFrame(): Unit {
        let payload: Array<UInt8> = [0x03, 0xe8]  // 状态码 1000
        let encoded = encodeWebSocketFrame(WebSocketOpcode.Close, payload, false)

        assertTrue(encoded.size == 4)
        assertTrue(encoded[0] == 0x88)  // FIN + 关闭帧
        assertTrue(encoded[1] == 0x02)  // 长度 = 2
    }

    @TestCase
    public func testRoundTripTextFrame(): Unit {
        let originalPayload = unsafe { "Round Trip Test!".rawData() }
        let encoded = encodeWebSocketFrame(WebSocketOpcode.Text, originalPayload, false)
        let parsed = parseWebSocketFrame(encoded)

        assertTrue(parsed.opcode == WebSocketOpcode.Text)
        let parsedText = String.fromUtf8(parsed.payloadData)
        assertTrue(parsedText == "Round Trip Test!")
    }

    @TestCase
    public func testRoundTripMaskedFrame(): Unit {
        let originalPayload = unsafe { "Masked Data".rawData() }
        let encoded = encodeWebSocketFrame(WebSocketOpcode.Text, originalPayload, true)
        let parsed = parseWebSocketFrame(encoded)

        assertTrue(parsed.opcode == WebSocketOpcode.Text)
        assertTrue(parsed.masked)
        let parsedText = String.fromUtf8(parsed.payloadData)
        assertTrue(parsedText == "Masked Data")
    }

    @TestCase
    public func testEncodeLargePayload16Bit(): Unit {
        // 200 字节负载（触发 16 位扩展长度）
        var payload = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < 200) { payload.add(b'X'); i++ }
        let encoded = encodeWebSocketFrame(WebSocketOpcode.Binary, payload.toArray(), false)

        assertTrue(encoded.size == 204)  // 4 字节头部 + 200 字节负载
        assertTrue(encoded[0] == 0x82)   // FIN + 二进制帧
        assertTrue(encoded[1] == 126)    // 16 位扩展长度标记
        assertTrue(encoded[2] == 0x00)   // 长度高位
        assertTrue(encoded[3] == 200)    // 长度低位 = 200
    }

    @TestCase
    public func testParseInvalidShortFrame(): Unit {
        try {
            parseWebSocketFrame([0x81])  // 只有 1 字节
            assertTrue(false)
        } catch (_: Exception) {
            assertTrue(true)
        }
    }

    @TestCase
    public func testParseInvalidOpcode(): Unit {
        try {
            // 操作码 0x03 是保留的
            parseWebSocketFrame([0x83, 0x00])
            assertTrue(false)
        } catch (_: Exception) {
            assertTrue(true)
        }
    }
}
