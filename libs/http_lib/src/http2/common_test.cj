package http_lib.http2

import http_lib.core.{assertTrue, assertFalse}

/**
 * === 测试大纲：HTTP/2 边界测试 ===
 * 以下测试场景应添加以获得完整的边界覆盖：
 *   - 帧大小边界：载荷正好为 MAX_FRAME_SIZE (16384) 和 MAX_FRAME_SIZE_LIMIT (2^24-1)
 *   - 带 END_STREAM 标志的零长度 DATA 帧（RFC 9113 Section 6.1）
 *   - 带 PRIORITY 标志但载荷 < 5 字节的 HEADERS 帧（FRAME_SIZE_ERROR）
 *   - PADDED 标志带 PadLength == 0 与 PadLength >= 载荷长度
 *   - ACK 标志 + 非零载荷的 SETTINGS 帧（必须为空，PROTOCOL_ERROR）
 *   - 非 8 字节载荷的 PING 帧（FRAME_SIZE_ERROR）
 *   - 载荷 < 4 字节的 RST_STREAM 帧（FRAME_SIZE_ERROR）
 * - 验证递增的 last-stream-id 的 GOAWAY
 * - increment=0 的 WINDOW_UPDATE（根据 RFC 9113 第 6.9 节为 PROTOCOL_ERROR）
 * - 在不同流上发送 CONTINUATION，但当前流未设置 END_HEADERS
 * - 将流 ID 0 用于非连接级帧（PROTOCOL_ERROR）
 * - 多个 SETTINGS 帧之间无 ACK
 * - 保留帧类型（0x0a-0xef）的帧——根据 RFC 9113 第 4.1 节必须忽略
 * - 自依赖的 PRIORITY 帧（流依赖于自身）——PROTOCOL_ERROR
 * - IDLE 流上的 PRIORITY 帧——根据 RFC 9113 第 5.1 节必须是 RST_STREAM
 * - SETTINGS_ENABLE_PUSH 值不是 0 或 1（必须是 PROTOCOL_ERROR）
 * - SETTINGS_INITIAL_WINDOW_SIZE > 2^31-1（FLOW_CONTROL_ERROR）
 * - SETTINGS_MAX_FRAME_SIZE 超出 [16384, 2^24-1]（PROTOCOL_ERROR）
 */

@Test
public class Http2CommonUnitTest {
    @TestCase
    public func testErrorCodeToU32(): Unit {
        assertTrue(Http2ErrorCode.NO_ERROR.toUInt32() == 0)
        assertTrue(Http2ErrorCode.CANCEL.toUInt32() == 8)
    }
    @TestCase
    public func testErrorCodeFromU32(): Unit {
        assertTrue(Http2ErrorCode.fromUInt32(0) == Http2ErrorCode.NO_ERROR)
        assertTrue(Http2ErrorCode.fromUInt32(8) == Http2ErrorCode.CANCEL)
    }
    @TestCase
    public func testErrorCodeHash(): Unit {
        assertTrue(Http2ErrorCode.NO_ERROR.hashCode() == 0)
    }
    @TestCase
    public func testFrameTypeToU8(): Unit {
        assertTrue(Http2FrameType.DATA.toUInt8() == 0)
        assertTrue(Http2FrameType.GOAWAY.toUInt8() == 7)
    }
    @TestCase
    public func testFrameTypeFromU8(): Unit {
        match (Http2FrameType.fromUInt8(4)) {
            case Some(f) => assertTrue(f == Http2FrameType.SETTINGS)
            case None => assertTrue(false)
        }
    }
    @TestCase
    public func testSettingsIdToU16(): Unit {
        assertTrue(Http2SettingsId.HEADER_TABLE_SIZE.toUInt16() == 1)
        assertTrue(Http2SettingsId.MAX_FRAME_SIZE.toUInt16() == 5)
    }
    @TestCase
    public func testSettingsIdFromU16(): Unit {
        match (Http2SettingsId.fromUInt16(3)) {
            case Some(s) => assertTrue(s == Http2SettingsId.MAX_CONCURRENT_STREAMS)
            case None => assertTrue(false)
        }
    }
    @TestCase
    public func testHttp2Exception(): Unit {
        let e = Http2Exception(Http2ErrorCode.PROTOCOL_ERROR, "test message")
        assertTrue(e.errorCode == Http2ErrorCode.PROTOCOL_ERROR)
        assertTrue(e.message.contains("test"))
    }

    @TestCase
    public func testErrorCodeToString(): Unit {
        assertTrue(Http2ErrorCode.NO_ERROR.toString() == "NO_ERROR")
        assertTrue(Http2ErrorCode.PROTOCOL_ERROR.toString() == "PROTOCOL_ERROR")
        assertTrue(Http2ErrorCode.CANCEL.toString() == "CANCEL")
        assertTrue(Http2ErrorCode.REFUSED_STREAM.toString() == "REFUSED_STREAM")
    }

    @TestCase
    public func testErrorCodeFromInvalid(): Unit {
        // 未知代码默认为 PROTOCOL_ERROR
        assertTrue(Http2ErrorCode.fromUInt32(999) == Http2ErrorCode.PROTOCOL_ERROR)
    }

    @TestCase
    public func testFrameTypeToString(): Unit {
        assertTrue(Http2FrameType.DATA.toString() == "DATA")
        assertTrue(Http2FrameType.HEADERS.toString() == "HEADERS")
        assertTrue(Http2FrameType.SETTINGS.toString() == "SETTINGS")
        assertTrue(Http2FrameType.GOAWAY.toString() == "GOAWAY")
    }

    @TestCase
    public func testFrameTypeHashCode(): Unit {
        assertTrue(Http2FrameType.DATA.hashCode() == 0)
        assertTrue(Http2FrameType.HEADERS.hashCode() == 1)
        assertTrue(Http2FrameType.SETTINGS.hashCode() == 4)
    }

    @TestCase
    public func testSettingsIdToString(): Unit {
        assertTrue(Http2SettingsId.HEADER_TABLE_SIZE.toString() == "HEADER_TABLE_SIZE")
        assertTrue(Http2SettingsId.MAX_CONCURRENT_STREAMS.toString() == "MAX_CONCURRENT_STREAMS")
        assertTrue(Http2SettingsId.INITIAL_WINDOW_SIZE.toString() == "INITIAL_WINDOW_SIZE")
    }

    @TestCase
    public func testSettingsIdHashCode(): Unit {
        assertTrue(Http2SettingsId.HEADER_TABLE_SIZE.hashCode() == 1)
        assertTrue(Http2SettingsId.MAX_FRAME_SIZE.hashCode() == 5)
    }

    @TestCase
    public func testSettingsIdFromInvalid(): Unit {
        assertTrue(Http2SettingsId.fromUInt16(999).isNone())
    }

    @TestCase
    public func testErrorCodeEquality(): Unit {
        assertTrue(Http2ErrorCode.NO_ERROR == Http2ErrorCode.NO_ERROR)
        assertFalse(Http2ErrorCode.NO_ERROR == Http2ErrorCode.CANCEL)
        assertTrue(Http2ErrorCode.fromUInt32(0) == Http2ErrorCode.NO_ERROR)
    }
}
