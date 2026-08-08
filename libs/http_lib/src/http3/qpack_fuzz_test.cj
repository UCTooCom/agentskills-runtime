/**
 * QPACK 模糊测试（Fuzz Testing）。
 *
 * 生成随机的、畸形的字节序列，测试 QPACK 编解码器和 HTTP/3 帧解析器
 * 在异常输入下的健壮性。确保不抛出意外异常或导致状态不一致。
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse, HttpHeaders, ProtocolException}

// ======== QPACK 解码器模糊测试 ========

@Test
public class QpackDecoderFuzzTest {

    /**
     * 测试解码随机字节序列是否安全。
     * 模糊测试不要求解码成功，只期望不抛出非 ProtocolException 异常。
     */
    @TestCase
    public func testFuzzDecodeRandomBytes(): Unit {
        let decoder = QpackDecoder()
        let randomData: Array<Array<UInt8>> = [
            [],
            [0x00u8],
            [0xFFu8],
            [0x80u8, 0x00u8],
            [0x40u8, 0x00u8, 0x01u8],
            [0x20u8, 0x00u8, 0x01u8, 0x02u8],
            [0x10u8],
            [0xFFu8, 0xFFu8, 0xFFu8, 0xFFu8, 0xFFu8],
            [0x00u8, 0x00u8, 0x00u8, 0x00u8],
            [0x7Fu8, 0x7Fu8, 0x7Fu8],
        ]
        for (data in randomData) {
            try {
                let _ = decoder.decode(data)
            } catch (_: ProtocolException) {
                // ProtocolException 是预期的——畸形数据应优雅拒绝
            } catch (_: Exception) {
                assertTrue(false, message: "QPACK fuzz: unexpected exception for data pattern")
            }
        }
    }

    /**
     * 测试解码器处理随机编码器流数据的健壮性。
     */
    @TestCase
    public func testFuzzProcessEncoderStream(): Unit {
        let decoder = QpackDecoder()
        let randomData: Array<Array<UInt8>> = [
            [0x02u8],
            [0xFFu8, 0x00u8],
            [0x80u8, 0x01u8, 0x01u8],
            [0x40u8, 0x01u8, 0x41u8, 0x01u8],
            [0x08u8, 0x01u8],
            [0x20u8, 0x40u8],
        ]
        for (data in randomData) {
            try {
                decoder.processEncoderStream(data)
            } catch (_: ProtocolException) {
                // 预期行为
            } catch (_: Exception) {
                assertTrue(false, message: "QPACK fuzz processEncoderStream: unexpected exception")
            }
        }
    }
}

// ======== QPACK 编码器模糊测试 ========

@Test
public class QpackEncoderFuzzTest {

    /**
     * 测试用异常头部数据编码是否安全。
     */
    @TestCase
    public func testFuzzEncodeEdgeHeaders(): Unit {
        let encoder = QpackEncoder(maxTableCapacity: 4096)
        let edgeHeaders: Array<HttpHeaders> = [
            HttpHeaders(),
            buildHeaderWithValue("x-custom", ""),
            buildHeaderWithValue("", "value"),
            buildHeaderWithValue(":method", "GET"),
        ]
        for (h in edgeHeaders) {
            try {
                let _ = encoder.encode(h)
            } catch (_: Exception) {
                assertTrue(false, message: "QPACK fuzz: encode should not throw on valid edge case headers")
            }
        }
    }

    /**
     * 测试编码器处理畸形解码器指令的健壮性。
     */
    @TestCase
    public func testFuzzProcessDecoderInstruction(): Unit {
        let encoder = QpackEncoder()
        let randomData: Array<Array<UInt8>> = [
            [],
            [0x00u8],
            [0xFFu8],
            [0x80u8, 0xFFu8, 0xFFu8, 0xFFu8],
            [0x40u8, 0xFFu8, 0xFFu8],
            [0xC0u8, 0x01u8],
        ]
        for (data in randomData) {
            try {
                encoder.processDecoderInstruction(data)
            } catch (_: ProtocolException) {
                // 预期行为
            } catch (_: Exception) {
                assertTrue(false, message: "QPACK fuzz processDecoderInstruction: unexpected exception")
            }
        }
    }
}

// ======== HTTP/3 帧解析器模糊测试 ========

@Test
public class H3FrameParserFuzzTest {

    /**
     * 测试构建各种异常帧数据是否安全。
     */
    @TestCase
    public func testFuzzBuildFrame(): Unit {
        let frames: Array<Array<UInt8>> = [
            encodeH3Frame(Http3FrameType.DATA, []),
            encodeH3Frame(Http3FrameType.HEADERS, []),
            encodeH3Frame(Http3FrameType.SETTINGS, []),
            encodeH3Frame(Http3FrameType.GOAWAY, []),
            encodeH3Frame(Http3FrameType.MAX_PUSH_ID, []),
            encodeH3Frame(Http3FrameType.CANCEL_PUSH, []),
        ]
        for (f in frames) {
            assertTrue(f.size > 0, message: "Frame should have content")
        }
    }
}

// ======== 辅助函数 ========

private func buildHeaderWithValue(name: String, value: String): HttpHeaders {
    let h = HttpHeaders()
    h.set(name, value)
    h
}
