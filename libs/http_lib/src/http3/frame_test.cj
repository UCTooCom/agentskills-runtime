/**
 * HTTP/3 帧编码/解码单元测试（RFC 9114 §7）。
 *
 * 覆盖：
 * - 帧类型枚举值
 * - 帧编码（DATA、SETTINGS、GOAWAY、MAX_PUSH_ID）
 * - 帧解码与帧头解析
 * - 全类型帧编解码往返
 * - CANCEL_PUSH、PUSH_PROMISE 扩展帧
 * - 多参数 SETTINGS 帧构建
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse, ProtocolException}
import http_lib.http2.{encodeQuicVarint, decodeQuicVarint}

// ======== HTTP/3 帧类型测试 ========

@Test
public class Http3FrameTypeTest {

    @TestCase
    public func testFrameTypeValues(): Unit {
        assertTrue(Http3FrameType.DATA.toUInt8() == 0x00)
        assertTrue(Http3FrameType.HEADERS.toUInt8() == 0x01)
        assertTrue(Http3FrameType.CANCEL_PUSH.toUInt8() == 0x03)
        assertTrue(Http3FrameType.SETTINGS.toUInt8() == 0x04)
        assertTrue(Http3FrameType.PUSH_PROMISE.toUInt8() == 0x05)
        assertTrue(Http3FrameType.GOAWAY.toUInt8() == 0x07)
        assertTrue(Http3FrameType.MAX_PUSH_ID.toUInt8() == 0x0D)
    }

    @TestCase
    public func testFrameTypeRoundTrip(): Unit {
        let allTypes = [Http3FrameType.DATA, Http3FrameType.HEADERS,
            Http3FrameType.CANCEL_PUSH, Http3FrameType.SETTINGS,
            Http3FrameType.PUSH_PROMISE, Http3FrameType.GOAWAY,
            Http3FrameType.MAX_PUSH_ID]
        for (t in allTypes) {
            let v = t.toUInt8()
            let back = Http3FrameType.fromUInt8(v)
            assertTrue(back == t, message: "${t} round-trip failed")
        }
    }

    @TestCase
    public func testFrameTypeEquality(): Unit {
        assertTrue(Http3FrameType.DATA == Http3FrameType.DATA)
        assertTrue(Http3FrameType.DATA != Http3FrameType.HEADERS)
    }

    @TestCase
    public func testUnknownFrameTypeThrows(): Unit {
        var threw = false
        try {
            let _ = Http3FrameType.fromUInt8(0x02)
        } catch (e: Http3Exception) {
            threw = true
        }
        assertTrue(threw, message: "Unknown frame type 0x02 should throw H3_FRAME_ERROR")
    }
}

// ======== HTTP/3 帧编码测试 ========

@Test
public class Http3FrameEncodeTest {

    @TestCase
    public func testEncodeH3Frame(): Unit {
        let payload: Array<UInt8> = [0x01, 0x02, 0x03]
        let frame = encodeH3Frame(Http3FrameType.DATA, payload)
        assertTrue(frame.size > payload.size, message: "Frame header adds bytes")
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.DATA,
            message: "Frame type should be DATA")
        assertTrue(header.payloadLength == 3,
            message: "Payload length should be 3")
    }

    @TestCase
    public func testEncodeH3SettingsFrame(): Unit {
        let settings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096u64),
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536u64),
        ]
        let frame = buildH3SettingsFrame(settings)
        assertTrue(frame.size > 0, message: "Settings frame should not be empty")
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.SETTINGS,
            message: "Frame type should be SETTINGS")
    }

    @TestCase
    public func testEncodeH3GoawayFrame(): Unit {
        let frame = buildH3GoawayFrame(42)
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.GOAWAY,
            message: "Frame type should be GOAWAY")
        let payload = frame[headerLen..]
        let (lastId, _) = decodeQuicVarint(payload, 0)
        assertTrue(lastId == 42u64, message: "GOAWAY should encode last stream ID 42")
    }

    @TestCase
    public func testBuildH3MaxPushIdFrame(): Unit {
        let frame = buildH3MaxPushIdFrame(100)
        let (header, _) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.MAX_PUSH_ID,
            message: "Frame type should be MAX_PUSH_ID")
    }
}

// ======== HTTP/3 帧解码测试 ========

@Test
public class Http3FrameDecodeTest {

    @TestCase
    public func testDecodeEmptyFrameHeaderThrows(): Unit {
        var threw = false
        try {
            let _ = decodeH3FrameHeader([0x00])
        } catch (e: ProtocolException) {
            threw = true
        }
        assertTrue(threw, message: "Decoding truncated frame header should throw")
    }

    @TestCase
    public func testDecodeSettingsFrame(): Unit {
        let settings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096u64),
        ]
        let frame = buildH3SettingsFrame(settings)
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.SETTINGS)
        assertTrue(header.payloadLength > 0, message: "Settings frame should have payload")
    }

    @TestCase
    public func testFrameHeaderConsumesCorrectOffset(): Unit {
        let payload: Array<UInt8> = [0x01, 0x02, 0x03]
        let frame = encodeH3Frame(Http3FrameType.DATA, payload)
        let (_, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(headerLen > 0, message: "Header length should be > 0")
        assertTrue(headerLen < frame.size, message: "Header should be smaller than the whole frame")
        let remaining = frame.size - headerLen
        assertTrue(remaining == Int64(3), message: "Should have 3 payload bytes after header")
    }
}

// ======== HTTP/3 帧构建器单元测试 ========

@Test
public class Http3FrameBuilderTest {

    @TestCase
    public func testBuildH3SettingsFrameWithMultipleSettings(): Unit {
        let settings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096u64),
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536u64),
            (Http3SettingsId.SETTINGS_QPACK_BLOCKED_STREAMS, 100u64),
        ]
        let frame = buildH3SettingsFrame(settings)
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.SETTINGS)
        assertTrue(header.payloadLength > 0,
            message: "Settings frame with 3 entries should have payload")

        let payload = frame[headerLen..headerLen + header.payloadLength]
        var parsedCount: Int64 = 0
        var offset: Int64 = 0
        while (offset < header.payloadLength) {
            let (_, idLen) = decodeQuicVarint(payload, offset)
            offset += idLen
            if (offset >= header.payloadLength) { break }
            let (_, valLen) = decodeQuicVarint(payload, offset)
            offset += valLen
            parsedCount += 1
        }
        assertTrue(parsedCount == 3, message: "Should parse 3 settings entries")
    }

    @TestCase
    public func testBuildH3GoawayFrameLargeStreamId(): Unit {
        let frame = buildH3GoawayFrame(1048576u64)
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.GOAWAY)
        let payload = frame[headerLen..]
        let (lastId, _) = decodeQuicVarint(payload, 0)
        assertTrue(lastId == 1048576u64,
            message: "Large stream ID should round-trip")
    }

    @TestCase
    public func testBuildH3MaxPushIdFrameZero(): Unit {
        let frame = buildH3MaxPushIdFrame(0)
        let (header, _) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.MAX_PUSH_ID)
    }
}

// ======== 扩展 HTTP/3 帧编码完整测试 ========

@Test
public class Http3ExtendedFrameTest {

    @TestCase
    public func testBuildH3CancelPushFrame(): Unit {
        let pushId: UInt64 = 42
        let frame = buildH3CancelPushFrame(pushId)
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.CANCEL_PUSH,
            message: "Frame type should be CANCEL_PUSH")
        let payload = frame[headerLen..]
        let decodedId = decodeH3CancelPushPayload(payload)
        assertTrue(decodedId == pushId,
            message: "CANCEL_PUSH pushId should round-trip")
    }

    @TestCase
    public func testBuildH3CancelPushFrameZeroId(): Unit {
        let frame = buildH3CancelPushFrame(0)
        let (header, _) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.CANCEL_PUSH,
            message: "Frame type should be CANCEL_PUSH")
    }

    @TestCase
    public func testBuildH3CancelPushFrameLargeId(): Unit {
        let pushId: UInt64 = 4294967295
        let frame = buildH3CancelPushFrame(pushId)
        let (header, headerLen) = decodeH3FrameHeader(frame)
        let payload = frame[headerLen..]
        let decodedId = decodeH3CancelPushPayload(payload)
        assertTrue(decodedId == pushId,
            message: "Large pushId should round-trip in CANCEL_PUSH")
    }

    @TestCase
    public func testDecodeH3CancelPushEmptyThrows(): Unit {
        try {
            let _ = decodeH3CancelPushPayload([])
            assertTrue(false, message: "Should throw on empty payload")
        } catch (e: ProtocolException) {
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "Should throw ProtocolException")
        }
    }

    @TestCase
    public func testBuildH3PushPromiseFrame(): Unit {
        let pushId: UInt64 = 1
        let headersData: Array<UInt8> = [0x00, 0x01, 0x02, 0x03]
        let frame = buildH3PushPromiseFrame(pushId, headersData)
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.PUSH_PROMISE,
            message: "Frame type should be PUSH_PROMISE")
        let payload = frame[headerLen..]
        let (decodedId, decodedHeaders) = decodeH3PushPromisePayload(payload)
        assertTrue(decodedId == pushId,
            message: "PUSH_PROMISE pushId should round-trip")
        assertTrue(decodedHeaders.size == headersData.size,
            message: "QPACK data size should match")
        for (i in 0..headersData.size) {
            assertTrue(decodedHeaders[i] == headersData[i],
                message: "QPACK data at index ${i} should match")
        }
    }

    @TestCase
    public func testBuildH3PushPromiseFrameEmptyHeaders(): Unit {
        let frame = buildH3PushPromiseFrame(0u64, [])
        let (header, headerLen) = decodeH3FrameHeader(frame)
        assertTrue(header.frameType == Http3FrameType.PUSH_PROMISE)
        let payload = frame[headerLen..]
        let (decodedId, decodedHeaders) = decodeH3PushPromisePayload(payload)
        assertTrue(decodedId == 0u64)
        assertTrue(decodedHeaders.size == 0)
    }

    @TestCase
    public func testDecodeH3PushPromiseEmptyThrows(): Unit {
        try {
            let _ = decodeH3PushPromisePayload([])
            assertTrue(false, message: "Should throw on empty payload")
        } catch (e: ProtocolException) {
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "Should throw ProtocolException")
        }
    }
}

// ======== HTTP/3 帧全类型编解码测试 ========

@Test
public class Http3FrameFullRoundTripTest {

    @TestCase
    public func testDataFrameRoundTrip(): Unit {
        let payload: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"
        let encoded = encodeH3Frame(Http3FrameType.DATA, payload)
        let (header, headerLen) = decodeH3FrameHeader(encoded)
        assertTrue(header.frameType == Http3FrameType.DATA, message: "Frame type should be DATA")
        assertTrue(header.payloadLength == 5, message: "Payload length should be 5")
        let consumed = headerLen + Int64(header.payloadLength)
        assertTrue(consumed <= encoded.size, message: "Frame should be fully consumed")
    }

    @TestCase
    public func testHeadersFrameRoundTripNoPayload(): Unit {
        let payload: Array<UInt8> = []
        let encoded = encodeH3Frame(Http3FrameType.HEADERS, payload)
        let (header, headerLen) = decodeH3FrameHeader(encoded)
        assertTrue(header.frameType == Http3FrameType.HEADERS, message: "Frame type should be HEADERS")
        assertTrue(header.payloadLength == 0, message: "Empty payload should have length 0")
    }

    @TestCase
    public func testSettingsFrameRoundTrip(): Unit {
        let settings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096),
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536),
        ]
        let encoded = buildH3SettingsFrame(settings)
        let (header, headerLen) = decodeH3FrameHeader(encoded)
        assertTrue(header.frameType == Http3FrameType.SETTINGS, message: "Frame type should be SETTINGS")
        assertTrue(header.payloadLength > 0, message: "Settings frame should have payload")
    }

    @TestCase
    public func testGoawayFrameRoundTrip(): Unit {
        let payload = encodeQuicVarint(100u64)
        let encoded = encodeH3Frame(Http3FrameType.GOAWAY, payload)
        let (header, _) = decodeH3FrameHeader(encoded)
        assertTrue(header.frameType == Http3FrameType.GOAWAY, message: "Frame type should be GOAWAY")
    }

    @TestCase
    public func testMaxPushIdFrameRoundTrip(): Unit {
        let payload = encodeQuicVarint(50u64)
        let encoded = encodeH3Frame(Http3FrameType.MAX_PUSH_ID, payload)
        let (header, _) = decodeH3FrameHeader(encoded)
        assertTrue(header.frameType == Http3FrameType.MAX_PUSH_ID, message: "Frame type should be MAX_PUSH_ID")
    }

    @TestCase
    public func testCancelPushFrameRoundTrip(): Unit {
        let payload = encodeQuicVarint(42u64)
        let encoded = encodeH3Frame(Http3FrameType.CANCEL_PUSH, payload)
        let (header, _) = decodeH3FrameHeader(encoded)
        assertTrue(header.frameType == Http3FrameType.CANCEL_PUSH, message: "Frame type should be CANCEL_PUSH")
    }

    @TestCase
    public func testPushPromiseFrameRoundTrip(): Unit {
        let payload: Array<UInt8> = [0x00, 0x01, 0x02]
        let encoded = encodeH3Frame(Http3FrameType.PUSH_PROMISE, payload)
        let (header, _) = decodeH3FrameHeader(encoded)
        assertTrue(header.frameType == Http3FrameType.PUSH_PROMISE, message: "Frame type should be PUSH_PROMISE")
    }
}
