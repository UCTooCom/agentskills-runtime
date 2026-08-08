package http_lib.http2

import http_lib.core.{assertTrue, assertFalse}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.buffer.ByteBuffer

/**
 * HTTP/2 帧编码/解码测试（RFC 9113 Section 4 & 6）。
 */
@Test
public class Http2FrameTest {

    @TestCase
    public func testFrameHeaderEncode(): Unit {
        let header = Http2FrameHeader(100, Http2FrameType.DATA, flags: FLAG_END_STREAM, streamId: 1)
        let bytes = header.toBytes()
        assertTrue(bytes.size == 9, message: "Frame header should be 9 bytes")

        // 长度应编码为 24 位大端序
        assertTrue(bytes[0] == 0, message: "Length byte 0 should be 0")
        assertTrue(bytes[1] == 0, message: "Length byte 1 should be 0")
        assertTrue(bytes[2] == 100, message: "Length byte 2 should be 100")

        // 类型应为 DATA (0x0)
        assertTrue(bytes[3] == 0, message: "Type should be DATA (0)")

        // 标志应有 END_STREAM (0x1)
        assertTrue(bytes[4] == 0x1, message: "Flags should be END_STREAM")

        // 流 ID 应为 1
        assertTrue(bytes[8] == 1, message: "Stream ID LSB should be 1")
    }

    @TestCase
    public func testFrameHeaderParse(): Unit {
        let original = Http2FrameHeader(50, Http2FrameType.HEADERS, flags: FLAG_END_HEADERS, streamId: 3)
        let bytes = original.toBytes()
        let parsed = Http2FrameHeader.parse(bytes)

        assertTrue(parsed.payloadLength == 50, message: "Parsed length should be 50")
        assertTrue(parsed.frameType == Http2FrameType.HEADERS, message: "Parsed type should be HEADERS")
        assertTrue(parsed.flags == FLAG_END_HEADERS, message: "Parsed flags should be END_HEADERS")
        assertTrue(parsed.streamId == 3, message: "Parsed stream ID should be 3")
    }

    @TestCase
    public func testFrameHeaderLargeStreamId(): Unit {
        // 流 ID 使用 31 位（MSB 保留）
        let header = Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 2147483647)  // 最大 31 位
        let bytes = header.toBytes()
        let parsed = Http2FrameHeader.parse(bytes)
        assertTrue(parsed.streamId == 2147483647, message: "Should preserve max 31-bit stream ID")
    }

    @TestCase
    public func testFrameEncodeData(): Unit {
        let header = Http2FrameHeader(5, Http2FrameType.DATA, flags: FLAG_END_STREAM, streamId: 1)
        let payload: Array<UInt8> = [b'h', b'e', b'l', b'l', b'o']
        let frame = encodeFrame(header, payload)

        assertTrue(frame.size == 14, message: "Frame should be 9 (header) + 5 (payload) = 14 bytes")
        assertTrue(frame[9] == b'h', message: "First payload byte should be 'h'")
        assertTrue(frame[13] == b'o', message: "Last payload byte should be 'o'")
    }

    @TestCase
    public func testSettingsEncodeDecode(): Unit {
        let settings: Array<(Http2SettingsId, UInt32)> = [
            (Http2SettingsId.HEADER_TABLE_SIZE, 4096),
            (Http2SettingsId.ENABLE_PUSH, 1),
            (Http2SettingsId.MAX_CONCURRENT_STREAMS, 128),
        ]
        let payload = encodeSettings(settings)
        assertTrue(payload.size == 18, message: "3 settings × 6 bytes = 18 bytes")

        let decoded = decodeSettings(payload)
        assertTrue(decoded.size == 3, message: "Should decode 3 settings")
    }

    @TestCase
    public func testGoawayEncodeDecode(): Unit {
        let payload = encodeGoaway(5, Http2ErrorCode.NO_ERROR)
        assertTrue(payload.size >= 8, message: "GOAWAY payload should be at least 8 bytes")
    }

    @TestCase
    public func testRstStreamEncodeDecode(): Unit {
        let payload = encodeRstStream(Http2ErrorCode.CANCEL)
        assertTrue(payload.size == 4, message: "RST_STREAM payload should be 4 bytes")

        let decoded = decodeRstStream(payload)
        assertTrue(decoded == Http2ErrorCode.CANCEL, message: "Should decode CANCEL error code")
    }

    @TestCase
    public func testWindowUpdateEncodeDecode(): Unit {
        let payload = encodeWindowUpdate(65535)
        assertTrue(payload.size == 4, message: "WINDOW_UPDATE payload should be 4 bytes")

        let decoded = decodeWindowUpdate(payload)
        assertTrue(decoded == 65535, message: "Should decode 65535")
    }

    @TestCase
    public func testPingEncode(): Unit {
        let opaque: Array<UInt8> = [1, 2, 3, 4, 5, 6, 7, 8]
        let payload = encodePing(opaque)
        assertTrue(payload.size == 8, message: "PING payload should be 8 bytes")
        assertTrue(payload[0] == 1 && payload[7] == 8, message: "Should preserve opaque data")
    }

    @TestCase
    public func testBuildSettingsAckFrame(): Unit {
        let frame = buildSettingsAckFrame()
        assertTrue(frame.size == 9, message: "SETTINGS ACK should be 9 bytes (header only, no payload)")
        // 类型应为 SETTINGS (4)，标志应为 ACK (1)
        assertTrue(frame[3] == 4, message: "Type should be SETTINGS")
        assertTrue(frame[4] == FLAG_ACK, message: "Flags should be ACK")
    }

    @TestCase
    public func testBuildPingFrame(): Unit {
        let data: Array<UInt8> = [0, 1, 2, 3, 4, 5, 6, 7]
        let frame = buildPingFrame(data)
        assertTrue(frame.size == 17, message: "PING frame should be 9 (header) + 8 (data)")

        let ackFrame = buildPingFrame(data, ack: true)
        assertTrue(ackFrame[4] == FLAG_ACK, message: "ACK frame should have ACK flag")
    }

    @TestCase
    public func testBuildGoawayFrame(): Unit {
        let frame = buildGoawayFrame(7, Http2ErrorCode.NO_ERROR)
        assertTrue(frame.size >= 17, message: "GOAWAY frame should be at least 17 bytes")
        assertTrue(frame[3] == 7, message: "Type should be GOAWAY (7)")
    }

    @TestCase
    public func testBuildRstStreamFrame(): Unit {
        let frame = buildRstStreamFrame(5, Http2ErrorCode.REFUSED_STREAM)
        assertTrue(frame.size == 13, message: "RST_STREAM should be 9 + 4 = 13 bytes")
        assertTrue(frame[3] == 3, message: "Type should be RST_STREAM (3)")
    }

    @TestCase
    public func testAllFrameTypesHaveValidEncoding(): Unit {
        // 验证所有帧类型枚举值有效
        let types = [
            Http2FrameType.DATA, Http2FrameType.HEADERS, Http2FrameType.PRIORITY,
            Http2FrameType.RST_STREAM, Http2FrameType.SETTINGS, Http2FrameType.PUSH_PROMISE,
            Http2FrameType.PING, Http2FrameType.GOAWAY, Http2FrameType.WINDOW_UPDATE,
            Http2FrameType.CONTINUATION
        ]
        for (ft in types) {
            let header = Http2FrameHeader(0, ft, streamId: 0)
            let _ = header.toBytes()
            // 不应抛出异常
        }
        assertTrue(true, message: "All frame types encode without error")
    }

    @TestCase
    public func testAllSettingsIds(): Unit {
        let ids = [
            Http2SettingsId.HEADER_TABLE_SIZE, Http2SettingsId.ENABLE_PUSH,
            Http2SettingsId.MAX_CONCURRENT_STREAMS, Http2SettingsId.INITIAL_WINDOW_SIZE,
            Http2SettingsId.MAX_FRAME_SIZE, Http2SettingsId.MAX_HEADER_LIST_SIZE
        ]
        for (id in ids) {
            let val = id.toUInt16()
            assertTrue(val >= 1 && val <= 6, message: "Settings ID should be in range 1-6")
        }
    }

    @TestCase
    public func testAllErrorCodes(): Unit {
        let codes = [
            Http2ErrorCode.NO_ERROR, Http2ErrorCode.PROTOCOL_ERROR, Http2ErrorCode.INTERNAL_ERROR,
            Http2ErrorCode.FLOW_CONTROL_ERROR, Http2ErrorCode.SETTINGS_TIMEOUT, Http2ErrorCode.STREAM_CLOSED,
            Http2ErrorCode.FRAME_SIZE_ERROR, Http2ErrorCode.REFUSED_STREAM, Http2ErrorCode.CANCEL,
            Http2ErrorCode.COMPRESSION_ERROR, Http2ErrorCode.CONNECT_ERROR, Http2ErrorCode.ENHANCE_YOUR_CALM,
            Http2ErrorCode.INADEQUATE_SECURITY, Http2ErrorCode.HTTP_1_1_REQUIRED
        ]
        for (ec in codes) {
            // 通过 UInt32 往返
            let val = ec.toUInt32()
            let back = Http2ErrorCode.fromUInt32(val)
            assertTrue(ec == back, message: "Error code round-trip should preserve value")
        }
    }

    @TestCase
    public func testBuildConnectionWindowUpdate(): Unit {
        let frame = buildConnectionWindowUpdate(65535)
        assertTrue(frame.size == 13, message: "WINDOW_UPDATE for connection should be 9 + 4 = 13 bytes")
        assertTrue(frame[3] == 8, message: "Type should be WINDOW_UPDATE (8)")
        let header = Http2FrameHeader.parse(frame)
        assertTrue(header.streamId == 0, message: "Connection-level WINDOW_UPDATE should have streamId=0")
    }

    @TestCase
    public func testBuildStreamWindowUpdate(): Unit {
        let frame = buildStreamWindowUpdate(5, 16384)
        assertTrue(frame.size == 13, message: "WINDOW_UPDATE for stream should be 9 + 4 = 13 bytes")
        let header = Http2FrameHeader.parse(frame)
        assertTrue(header.streamId == 5, message: "Stream WINDOW_UPDATE should preserve streamId")
    }

    @TestCase
    public func testStripPaddingNoFlag(): Unit {
        let payload: Array<UInt8> = [b'h', b'e', b'l', b'l', b'o']
        let stripped = stripPadding(Http2FrameType.DATA, 0, payload)
        assertTrue(stripped.size == 5, message: "Without PADDED flag, payload should be unchanged")
    }

    @TestCase
    public func testStripPaddingDataFrame(): Unit {
        // PADDED DATA 帧：[pad_length=2][data: hello][padding:xx]
        let payload: Array<UInt8> = [2, b'h', b'e', b'l', b'l', b'o', 0, 0]
        let stripped = stripPadding(Http2FrameType.DATA, FLAG_PADDED, payload)
        assertTrue(stripped.size == 5, message: "Should strip 2 bytes of padding from DATA frame")
        assertTrue(stripped[0] == b'h', message: "First stripped byte should be 'h'")
    }

    @TestCase
    public func testStripPaddingHeadersFrame(): Unit {
        // PADDED HEADERS 帧：[pad_length=1][data:abc][padding:x]
        let payload: Array<UInt8> = [1, b'a', b'b', b'c', 0]
        let stripped = stripPadding(Http2FrameType.HEADERS, FLAG_PADDED, payload)
        assertTrue(stripped.size == 3, message: "Should strip padding from HEADERS frame")
    }

    @TestCase
    public func testStripPaddingInvalid(): Unit {
        // pad_length >= 有效载荷大小应抛出 Http2Exception
        let payload: Array<UInt8> = [10, b'h', b'i']
        let threw = try {
            let stripped = stripPadding(Http2FrameType.DATA, FLAG_PADDED, payload)
            false
        } catch (_: Http2Exception) {
            true
        }
        assertTrue(threw, message: "Invalid padding should throw Http2Exception")
    }

    @TestCase
    public func testStripPaddingEmptyPayload(): Unit {
        let stripped = stripPadding(Http2FrameType.DATA, FLAG_PADDED, [])
        assertTrue(stripped.size == 0, message: "Empty payload should return empty")
    }

    @TestCase
    public func testStripPaddingHeadersWithPriority(): Unit {
        // PADDED + PRIORITY HEADERS 帧：// [pad_len=1][E][stream_dep(4)][weight][data:ab][padding:x]
        let payload = Array<UInt8>(9, {i =>
            match (i) {
                case 0 => 1  // 填充长度 = 1
                case 1 => 0  // E + 流依赖（最高位）
                case 2 => 0
                case 3 => 0
                case 4 => 5  // 流依赖（低位字节）
                case 5 => 16 // 权重
                case 6 => b'a'
                case 7 => b'b'
                case _ => 0  // 填充字节
            }
        })
        let stripped = stripPadding(Http2FrameType.HEADERS, FLAG_PADDED | FLAG_PRIORITY, payload)
        assertTrue(stripped.size == 2, message: "Should strip padding + priority from HEADERS")
    }
}


@Test
public class PriorityFieldTest {
    @TestCase
    public func testParsePriorityFieldValue(): Unit {
        let (urgency, incremental) = parsePriorityFieldValue(unsafe { "u=4".rawData() })
        if (urgency != 4u8 || incremental) {
            throw Exception("Expected urgency=4, incremental=false")
        }
    }

    @TestCase
    public func testParsePriorityFieldValueDefault(): Unit {
        let (urgency, incremental) = parsePriorityFieldValue([])
        if (urgency != 3u8 || incremental) {
            throw Exception("Expected default urgency=3, incremental=false")
        }
    }

    @TestCase
    public func testUrgencyToWeight(): Unit {
        let w = urgencyToWeight(3u8)
        if (w != 16u8) {
            throw Exception("Expected weight 16 for urgency 3, got ${w}")
        }
        let w0 = urgencyToWeight(0u8)
        if (w0 != 128u8) {
            throw Exception("Expected weight 128 for urgency 0, got ${w0}")
        }
    }
}


// ======== 优先级帧编解码测试 ========

@Test
public class PriorityFrameEncodeTest {

    @TestCase
    public func testEncodePriority(): Unit {
        let payload = encodePriority(5, false, 16)
        assertTrue(payload.size == 5, message: "Priority payload should be 5 bytes")
        let (dep, excl, weight) = decodePriority(payload)
        assertTrue(dep == 5, message: "Stream dependency should be 5")
        assertFalse(excl, message: "Should not be exclusive")
        assertTrue(weight == 16, message: "Weight should be 16")
    }

    @TestCase
    public func testEncodePriorityExclusive(): Unit {
        let payload = encodePriority(10, true, 200)
        let (dep, excl, weight) = decodePriority(payload)
        assertTrue(dep == 10, message: "Stream dependency should be 10")
        assertTrue(excl, message: "Should be exclusive")
        assertTrue(weight == 200, message: "Weight should be 200")
    }

    @TestCase
    public func testBuildPriorityFrame(): Unit {
        let frame = buildPriorityFrame(1, 3, exclusive: false, weight: 32)
        assertTrue(frame.size > 0, message: "Priority frame should not be empty")
        // Verify roundtrip: the payload should start at offset 9 (frame header)
        if (frame.size >= 14) {
            let payload = frame[9..14]
            let (dep, excl, weight) = decodePriority(payload)
            assertTrue(dep == 3, message: "Stream dependency should be 3")
            assertFalse(excl, message: "Should not be exclusive")
            assertTrue(weight == 32, message: "Weight should be 32")
        }
    }

    @TestCase
    public func testDecodePriorityThrowsOnShortPayload(): Unit {
        var threw = false
        try {
            let _ = decodePriority([0x00, 0x00, 0x00])
        } catch (e: Http2Exception) {
            threw = true
        }
        assertTrue(threw, message: "Short payload should throw Http2Exception")
    }

    @TestCase
    public func testEncodePriorityRoundtrip(): Unit {
        // Test that encode + decode is lossless for various values
        let testCases = [(0u32, false, 1u8), (0u32, true, 1u8), 
                         (100u32, false, 30u8), (0x7fffffffu32, false, 255u8)]
        for ((dep, excl, w) in testCases) {
            let payload = encodePriority(dep, excl, w)
            let (dep2, excl2, w2) = decodePriority(payload)
            assertTrue(dep2 == dep, message: "Stream dependency should roundtrip for ${dep}")
            assertTrue(excl2 == excl, message: "Exclusive flag should roundtrip")
            assertTrue(w2 == w, message: "Weight should roundtrip for ${w}")
        }
    }
}

// ======== Priority Update 帧编解码测试 ========

@Test
public class PriorityUpdateFrameEncodeTest {

    @TestCase
    public func testEncodePriorityUpdatePayload(): Unit {
        let priorityField = unsafe { "u=4".rawData() }
        let payload = encodePriorityUpdatePayload(1, priorityField)
        assertTrue(payload.size > 4, message: "Payload should be > 4 bytes")
        let (sid, pf) = decodePriorityUpdatePayload(payload)
        assertTrue(sid == 1, message: "Prioritized stream ID should be 1")
        assertTrue(pf.size == priorityField.size, message: "Priority field should match")
    }

    @TestCase
    public func testDecodePriorityUpdatePayloadThrowsOnShort(): Unit {
        var threw = false
        try {
            let _ = decodePriorityUpdatePayload([0x00, 0x00])
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw, message: "Short payload should throw")
    }

    @TestCase
    public func testBuildPriorityUpdateFrame(): Unit {
        let priorityField = unsafe { "u=2, i=?1".rawData() }
        let frame = buildPriorityUpdateFrame(3, 1, priorityField)
        assertTrue(frame.size > 0, message: "Priority update frame should not be empty")
    }
}

// ======== ORIGIN 帧编解码测试 ========

@Test
public class OriginFrameEncodeTest {

    @TestCase
    public func testEncodeOriginPayload(): Unit {
        let payload = encodeOriginPayload(["https://example.com"])
        assertTrue(payload.size > 2, message: "Origin payload should not be empty")
        let origins = decodeOriginPayload(payload)
        assertTrue(origins.size == 1, message: "Should decode 1 origin")
        assertTrue(origins[0] == "https://example.com", message: "Origin should match")
    }

    @TestCase
    public func testEncodeOriginPayloadMultiple(): Unit {
        let payload = encodeOriginPayload(["https://a.com", "https://b.com"])
        let origins = decodeOriginPayload(payload)
        assertTrue(origins.size == 2, message: "Should decode 2 origins")
        assertTrue(origins[0] == "https://a.com", message: "First origin should match")
        assertTrue(origins[1] == "https://b.com", message: "Second origin should match")
    }

    @TestCase
    public func testBuildOriginFrame(): Unit {
        let frame = buildOriginFrame(["https://example.com"])
        assertTrue(frame.size > 0, message: "Origin frame should not be empty")
    }
}

// ======== ALTSVC 帧编解码测试 ========

@Test
public class AltSvcFrameEncodeTest {

    @TestCase
    public func testEncodeAltSvcPayload(): Unit {
        let altSvcValue: Array<UInt8> = [0x68, 0x32, 0x3D, 0x22, 0x3A, 0x34, 0x34, 0x33, 0x22] // h2=":443"
        let payload = encodeAltSvcPayload("example.com", altSvcValue)
        assertTrue(payload.size > 2, message: "ALTSVC payload should not be empty")
        let (origin, value) = decodeAltSvcPayload(payload)
        assertTrue(origin == "example.com", message: "Origin should match")
        assertTrue(value.size == altSvcValue.size, message: "Alt-Svc value should match")
    }

    @TestCase
    public func testBuildAltSvcFrame(): Unit {
        let altSvcValue: Array<UInt8> = [0x68, 0x32, 0x3D, 0x22, 0x3A, 0x34, 0x34, 0x33, 0x22] // h2=":443"
        let frame = buildAltSvcFrame("example.com", altSvcValue)
        assertTrue(frame.size > 0, message: "ALTSVC frame should not be empty")
    }

    @TestCase
    public func testDecodeAltSvcPayloadThrowsOnShort(): Unit {
        var threw = false
        try {
            let _ = decodeAltSvcPayload([0x00])
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw, message: "Short payload should throw")
    }
}

