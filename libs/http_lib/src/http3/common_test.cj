/**
 * HTTP/3 公共类型单元测试（RFC 9114）。
 *
 * 覆盖：
 * - Http3Exception 与错误码
 * - Http3SettingsId 枚举值与往返
 * - QuicErrorCode 枚举值与唯一性
 */
package http_lib.http3

import std.collection.ArrayList
import http_lib.core.{assertTrue, assertFalse}

// ======== HTTP/3 异常测试 ========

@Test
public class Http3ExceptionTest {

    @TestCase
    public func testHttp3Exception(): Unit {
        let ex = Http3Exception(Http3ErrorCode.H3_INTERNAL_ERROR, "test error")
        assertTrue(ex.errorCode == Http3ErrorCode.H3_INTERNAL_ERROR,
            message: "Error code should be preserved")
        assertTrue(ex.message.contains("test error"),
            message: "Message should be preserved")
    }

    @TestCase
    public func testHttp3ErrorCodes(): Unit {
        assertTrue(Http3ErrorCode.H3_NO_ERROR.toUInt16() == 0x0100u16)
        assertTrue(Http3ErrorCode.H3_INTERNAL_ERROR.toUInt16() == 0x0102u16)
        assertTrue(Http3ErrorCode.H3_QPACK_DECOMPRESSION_FAILED.toUInt16() == 0x0200u16)
    }

    @TestCase
    public func testHttp3ErrorCodeEquality(): Unit {
        assertTrue(Http3ErrorCode.H3_NO_ERROR == Http3ErrorCode.H3_NO_ERROR)
        assertTrue(Http3ErrorCode.H3_NO_ERROR != Http3ErrorCode.H3_INTERNAL_ERROR)
    }
}

// ======== HTTP/3 设置 ID 测试 ========

@Test
public class Http3SettingsIdTest {

    @TestCase
    public func testSettingsIdValues(): Unit {
        assertTrue(Http3SettingsId.QPACK_MAX_TABLE_CAPACITY.toUInt16() == 0x01)
        assertTrue(Http3SettingsId.MAX_FIELD_SECTION_SIZE.toUInt16() == 0x06)
        assertTrue(Http3SettingsId.SETTINGS_QPACK_BLOCKED_STREAMS.toUInt16() == 0x07)
        assertTrue(Http3SettingsId.ENABLE_CONNECT_PROTOCOL.toUInt16() == 0x08)
        assertTrue(Http3SettingsId.H3_DATAGRAM.toUInt16() == 0x33)
    }

    @TestCase
    public func testSettingsIdRoundtrip(): Unit {
        let ids = [Http3SettingsId.QPACK_MAX_TABLE_CAPACITY,
            Http3SettingsId.MAX_FIELD_SECTION_SIZE,
            Http3SettingsId.SETTINGS_QPACK_BLOCKED_STREAMS]
        for (id in ids) {
            let v = id.toUInt16()
            match (Http3SettingsId.fromUInt16(v)) {
                case Some(back) => assertTrue(back == id,
                    message: "${id} round-trip failed")
                case None => assertTrue(false,
                    message: "${id} should be valid")
            }
        }
    }

    @TestCase
    public func testUnknownSettingsIdReturnsNone(): Unit {
        match (Http3SettingsId.fromUInt16(0x10)) {
            case Some(_) => assertTrue(false, message: "Unknown ID 0x10 should return None")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testSettingsIdEquality(): Unit {
        assertTrue(Http3SettingsId.QPACK_MAX_TABLE_CAPACITY == Http3SettingsId.QPACK_MAX_TABLE_CAPACITY)
        assertTrue(Http3SettingsId.QPACK_MAX_TABLE_CAPACITY != Http3SettingsId.MAX_FIELD_SECTION_SIZE)
    }
    @TestCase
    public func testSettingsIdToString(): Unit {
        assertTrue(Http3SettingsId.QPACK_MAX_TABLE_CAPACITY.toString() == "QPACK_MAX_TABLE_CAPACITY")
        assertTrue(Http3SettingsId.MAX_FIELD_SECTION_SIZE.toString() == "MAX_FIELD_SECTION_SIZE")
        assertTrue(Http3SettingsId.SETTINGS_QPACK_BLOCKED_STREAMS.toString() == "SETTINGS_QPACK_BLOCKED_STREAMS")
        assertTrue(Http3SettingsId.ENABLE_CONNECT_PROTOCOL.toString() == "ENABLE_CONNECT_PROTOCOL")
        assertTrue(Http3SettingsId.H3_DATAGRAM.toString() == "H3_DATAGRAM")
    }
}

// ======== QUIC 传输错误码测试 ========

@Test
public class QuicTransportErrorCodeTest {

    @TestCase
    public func testQuicErrorCodeValues(): Unit {
        assertTrue(QuicErrorCode.QUIC_NO_ERROR.toUInt16() == 0x00)
        assertTrue(QuicErrorCode.QUIC_INTERNAL_ERROR.toUInt16() == 0x01)
        assertTrue(QuicErrorCode.QUIC_CONNECTION_REFUSED.toUInt16() == 0x02)
        assertTrue(QuicErrorCode.QUIC_FLOW_CONTROL_ERROR.toUInt16() == 0x03)
        assertTrue(QuicErrorCode.QUIC_PROTOCOL_VIOLATION.toUInt16() == 0x0A)
        assertTrue(QuicErrorCode.QUIC_NO_VIABLE_PATH.toUInt16() == 0x10)
    }

    @TestCase
    public func testQuicErrorCodeEquality(): Unit {
        assertTrue(QuicErrorCode.QUIC_NO_ERROR == QuicErrorCode.QUIC_NO_ERROR)
        assertTrue(QuicErrorCode.QUIC_NO_ERROR != QuicErrorCode.QUIC_INTERNAL_ERROR)
    }

    @TestCase
    public func testQuicErrorCodesAllUnique(): Unit {
        let codes = [
            QuicErrorCode.QUIC_NO_ERROR,
            QuicErrorCode.QUIC_INTERNAL_ERROR,
            QuicErrorCode.QUIC_CONNECTION_REFUSED,
            QuicErrorCode.QUIC_FLOW_CONTROL_ERROR,
            QuicErrorCode.QUIC_STREAM_LIMIT_ERROR,
            QuicErrorCode.QUIC_STREAM_STATE_ERROR,
            QuicErrorCode.QUIC_FINAL_SIZE_ERROR,
            QuicErrorCode.QUIC_FRAME_ENCODING_ERROR,
            QuicErrorCode.QUIC_TRANSPORT_PARAMETER_ERROR,
            QuicErrorCode.QUIC_CONNECTION_ID_LIMIT_ERROR,
            QuicErrorCode.QUIC_PROTOCOL_VIOLATION,
            QuicErrorCode.QUIC_INVALID_TOKEN,
            QuicErrorCode.QUIC_APPLICATION_ERROR,
            QuicErrorCode.QUIC_CRYPTO_BUFFER_EXCEEDED,
            QuicErrorCode.QUIC_KEY_UPDATE_ERROR,
            QuicErrorCode.QUIC_AEAD_LIMIT_REACHED,
            QuicErrorCode.QUIC_NO_VIABLE_PATH,
        ]
        var seen = ArrayList<UInt16>()
        for (code in codes) {
            let v = code.toUInt16()
            for (s in seen) {
                assertTrue(s != v, message: "Duplicate error code value: ${v}")
            }
            seen.add(v)
        }
    }
}
// ======== HTTP/3 帧类型测试 ========

@Test
public class Http3FrameTypeCommonTest {

    @TestCase
    public func testFrameTypeToString(): Unit {
        assertTrue(Http3FrameType.DATA.toString() == "DATA")
        assertTrue(Http3FrameType.HEADERS.toString() == "HEADERS")
        assertTrue(Http3FrameType.CANCEL_PUSH.toString() == "CANCEL_PUSH")
        assertTrue(Http3FrameType.SETTINGS.toString() == "SETTINGS")
        assertTrue(Http3FrameType.PUSH_PROMISE.toString() == "PUSH_PROMISE")
        assertTrue(Http3FrameType.GOAWAY.toString() == "GOAWAY")
        assertTrue(Http3FrameType.MAX_PUSH_ID.toString() == "MAX_PUSH_ID")
    }

    @TestCase
    public func testFrameTypeToUInt8(): Unit {
        assertTrue(Http3FrameType.DATA.toUInt8() == 0x00)
        assertTrue(Http3FrameType.HEADERS.toUInt8() == 0x01)
        assertTrue(Http3FrameType.CANCEL_PUSH.toUInt8() == 0x03)
        assertTrue(Http3FrameType.SETTINGS.toUInt8() == 0x04)
        assertTrue(Http3FrameType.PUSH_PROMISE.toUInt8() == 0x05)
        assertTrue(Http3FrameType.GOAWAY.toUInt8() == 0x07)
        assertTrue(Http3FrameType.MAX_PUSH_ID.toUInt8() == 0x0D)
    }

    @TestCase
    public func testFrameTypeFromUInt8(): Unit {
        assertTrue(Http3FrameType.fromUInt8(0x00) == Http3FrameType.DATA)
        assertTrue(Http3FrameType.fromUInt8(0x01) == Http3FrameType.HEADERS)
        assertTrue(Http3FrameType.fromUInt8(0x03) == Http3FrameType.CANCEL_PUSH)
        assertTrue(Http3FrameType.fromUInt8(0x04) == Http3FrameType.SETTINGS)
        assertTrue(Http3FrameType.fromUInt8(0x05) == Http3FrameType.PUSH_PROMISE)
        assertTrue(Http3FrameType.fromUInt8(0x07) == Http3FrameType.GOAWAY)
        assertTrue(Http3FrameType.fromUInt8(0x0D) == Http3FrameType.MAX_PUSH_ID)
    }

    @TestCase
    public func testFrameTypeEquality(): Unit {
        assertTrue(Http3FrameType.DATA == Http3FrameType.DATA)
        assertTrue(Http3FrameType.DATA != Http3FrameType.HEADERS)
    }

    @TestCase
    public func testFrameTypeUnknownThrows(): Unit {
        var threw = false
        try {
            let _ = Http3FrameType.fromUInt8(0x02)
        } catch (e: Http3Exception) {
            threw = true
            assertTrue(e.message.contains("unknown"), message: "Should mention unknown type")
        }
        assertTrue(threw, message: "Unknown frame type should throw")
    }
}
