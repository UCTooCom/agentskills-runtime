/**
 * QUIC 变长整数（Varint）编解码单元测试。
 *
 * 覆盖 RFC 9000 §16 中定义的 1/2/4/8 字节变长整数格式：
 * - 各个长度范围的编码正确性
 * - 边界值测试（0, 63, 64, 16383, 16384, ...）
 * - 编解码双向一致性（round-trip）
 * - 异常情况（值过大、数据不足、偏移越界）
 */
package http_lib.http2

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.ProtocolException

@Test
public class QuicVarintTest {

    // ======== 1 字节编码（prefix 00）========

    @TestCase
    public func testEncode1ByteZero(): Unit {
        let result = encodeQuicVarint(0u64)
        assertTrue(result.size == 1, message: "0 should encode to 1 byte")
        assertTrue(result[0] == 0u8, message: "encode 0 should be [0x00]")
    }

    @TestCase
    public func testEncode1ByteMax(): Unit {
        let result = encodeQuicVarint(63u64)
        assertTrue(result.size == 1, message: "63 should encode to 1 byte")
        assertTrue(result[0] == 63u8, message: "encode 63 should be [0x3F]")
    }

    @TestCase
    public func testEncode1ByteValue(): Unit {
        let result = encodeQuicVarint(42u64)
        assertTrue(result.size == 1, message: "42 should encode to 1 byte")
        assertTrue(result[0] == 42u8, message: "encode 42 should be [0x2A]")
    }

    // ======== 2 字节编码（prefix 01）========

    @TestCase
    public func testEncode2ByteMin(): Unit {
        let result = encodeQuicVarint(64u64)
        assertTrue(result.size == 2, message: "64 should encode to 2 bytes")
        assertTrue(result[0] == 0x40u8, message: "encode 64 first byte")
        assertTrue(result[1] == 0x40u8, message: "encode 64 second byte")
    }

    @TestCase
    public func testEncode2ByteMax(): Unit {
        let result = encodeQuicVarint(16383u64)
        assertTrue(result.size == 2, message: "16383 should encode to 2 bytes")
        assertTrue(result[0] == 0x7Fu8, message: "encode 16383 first byte")
        assertTrue(result[1] == 0xFFu8, message: "encode 16383 second byte")
    }

    // ======== 4 字节编码（prefix 10）========

    @TestCase
    public func testEncode4ByteMin(): Unit {
        let result = encodeQuicVarint(16384u64)
        assertTrue(result.size == 4, message: "16384 should encode to 4 bytes")
        assertTrue(result[0] == 0x80u8)
        assertTrue(result[1] == 0x00u8)
        assertTrue(result[2] == 0x40u8)
        assertTrue(result[3] == 0x00u8)
    }

    @TestCase
    public func testEncode4ByteValue(): Unit {
        let result = encodeQuicVarint(1073741823u64)
        assertTrue(result.size == 4, message: "1073741823 should encode to 4 bytes")
    }

    // ======== 8 字节编码（prefix 11）========

    @TestCase
    public func testEncode8ByteMin(): Unit {
        let result = encodeQuicVarint(1073741824u64)
        assertTrue(result.size == 8, message: "1073741824 should encode to 8 bytes")
        assertTrue(result[0] == 0xC0u8)
        assertTrue(result[4] == 0x40u8)
    }

    @TestCase
    public func testEncode8ByteMax(): Unit {
        let result = encodeQuicVarint(4611686018427387903u64)
        assertTrue(result.size == 8, message: "max value should encode to 8 bytes")
    }

    // ======== 编码异常 ========

    @TestCase
    public func testEncodeValueTooLarge(): Unit {
        var caught = false
        try {
            let _ = encodeQuicVarint(4611686018427387904u64)
        } catch (_: ProtocolException) {
            caught = true
        }
        assertTrue(caught, message: "should throw ProtocolException for out-of-range value")
    }

    // ======== 解码：1 字节 ========

    @TestCase
    public func testDecode1ByteZero(): Unit {
        let data: Array<UInt8> = [0x00]
        let (value, length) = decodeQuicVarint(data, 0)
        assertTrue(value == 0u64, message: "decode [0x00] should be 0")
        assertTrue(length == 1, message: "decoded length should be 1")
    }

    @TestCase
    public func testDecode1ByteValue(): Unit {
        let data: Array<UInt8> = [0x2A]
        let (value, length) = decodeQuicVarint(data, 0)
        assertTrue(value == 42u64, message: "decode [0x2A] should be 42")
        assertTrue(length == 1, message: "decoded length should be 1")
    }

    @TestCase
    public func testDecode1ByteMax(): Unit {
        let data: Array<UInt8> = [0x3F]
        let (value, length) = decodeQuicVarint(data, 0)
        assertTrue(value == 63u64, message: "decode [0x3F] should be 63")
        assertTrue(length == 1, message: "decoded length should be 1")
    }

    // ======== 解码：2 字节 ========

    @TestCase
    public func testDecode2ByteMin(): Unit {
        let data: Array<UInt8> = [0x40, 0x40]
        let (value, length) = decodeQuicVarint(data, 0)
        assertTrue(value == 64u64, message: "decode 2-byte min should be 64")
        assertTrue(length == 2, message: "decoded length should be 2")
    }

    @TestCase
    public func testDecode2ByteMax(): Unit {
        let data: Array<UInt8> = [0x7F, 0xFF]
        let (value, length) = decodeQuicVarint(data, 0)
        assertTrue(value == 16383u64, message: "decode 2-byte max should be 16383")
        assertTrue(length == 2, message: "decoded length should be 2")
    }

    // ======== 解码：4 字节 ========

    @TestCase
    public func testDecode4ByteMin(): Unit {
        let data: Array<UInt8> = [0x80, 0x00, 0x40, 0x00]
        let (value, length) = decodeQuicVarint(data, 0)
        assertTrue(value == 16384u64, message: "decode 4-byte min should be 16384")
        assertTrue(length == 4, message: "decoded length should be 4")
    }

    // ======== 解码：8 字节 ========

    @TestCase
    public func testDecode8ByteValue(): Unit {
        let data: Array<UInt8> = [0xC0, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00]
        let (value, length) = decodeQuicVarint(data, 0)
        assertTrue(value == 1073741824u64, message: "decode 8-byte should be 1073741824")
        assertTrue(length == 8, message: "decoded length should be 8")
    }

    // ======== 解码异常 ========

    @TestCase
    public func testDecodeEmptyData(): Unit {
        var caught = false
        try {
            let (_, _) = decodeQuicVarint([], 0)
        } catch (_: ProtocolException) {
            caught = true
        }
        assertTrue(caught, message: "should throw for empty data")
    }

    @TestCase
    public func testDecodeTruncated2Byte(): Unit {
        var caught = false
        try {
            let (_, _) = decodeQuicVarint([0x40], 0)
        } catch (_: ProtocolException) {
            caught = true
        }
        assertTrue(caught, message: "should throw for truncated 2-byte varint")
    }

    @TestCase
    public func testDecodeOffsetOutOfBounds(): Unit {
        var caught = false
        try {
            let (_, _) = decodeQuicVarint([0x2A], 5)
        } catch (_: ProtocolException) {
            caught = true
        }
        assertTrue(caught, message: "should throw for offset out of bounds")
    }

    // ======== 编解码往返一致性 ========

    @TestCase
    public func testRoundTripSmallValue(): Unit {
        let value: UInt64 = 42
        let encoded = encodeQuicVarint(value)
        let (decoded, _) = decodeQuicVarint(encoded, 0)
        assertTrue(decoded == value, message: "round-trip 42 should equal original")
    }

    @TestCase
    public func testRoundTrip1ByteMax(): Unit {
        let value: UInt64 = 63
        let encoded = encodeQuicVarint(value)
        let (decoded, _) = decodeQuicVarint(encoded, 0)
        assertTrue(decoded == value, message: "round-trip 63 should equal original")
    }

    @TestCase
    public func testRoundTrip2ByteMin(): Unit {
        let value: UInt64 = 64
        let encoded = encodeQuicVarint(value)
        let (decoded, _) = decodeQuicVarint(encoded, 0)
        assertTrue(decoded == value, message: "round-trip 64 should equal original")
    }

    @TestCase
    public func testRoundTrip2ByteMax(): Unit {
        let value: UInt64 = 16383
        let encoded = encodeQuicVarint(value)
        let (decoded, _) = decodeQuicVarint(encoded, 0)
        assertTrue(decoded == value, message: "round-trip 16383 should equal original")
    }

    @TestCase
    public func testRoundTrip4ByteMin(): Unit {
        let value: UInt64 = 16384
        let encoded = encodeQuicVarint(value)
        let (decoded, _) = decodeQuicVarint(encoded, 0)
        assertTrue(decoded == value, message: "round-trip 16384 should equal original")
    }

    @TestCase
    public func testRoundTrip4ByteMax(): Unit {
        let value: UInt64 = 1073741823
        let encoded = encodeQuicVarint(value)
        let (decoded, _) = decodeQuicVarint(encoded, 0)
        assertTrue(decoded == value, message: "round-trip 1073741823 should equal original")
    }

    @TestCase
    public func testRoundTrip8ByteMin(): Unit {
        let value: UInt64 = 1073741824
        let encoded = encodeQuicVarint(value)
        let (decoded, _) = decodeQuicVarint(encoded, 0)
        assertTrue(decoded == value, message: "round-trip 1073741824 should equal original")
    }

    @TestCase
    public func testRoundTrip8ByteMax(): Unit {
        let value: UInt64 = 4611686018427387903
        let encoded = encodeQuicVarint(value)
        let (decoded, _) = decodeQuicVarint(encoded, 0)
        assertTrue(decoded == value, message: "round-trip max should equal original")
    }

    // ======== 偏移量和连续解码 ========

    @TestCase
    public func testDecodeWithOffset(): Unit {
        let data: Array<UInt8> = [0x00, 0x00, 0x2A]
        let (value, length) = decodeQuicVarint(data, 2)
        assertTrue(value == 42u64, message: "decoded with offset 2 should be 42")
        assertTrue(length == 1, message: "decoded length with offset should be 1")
    }

    @TestCase
    public func testDecodeConsecutiveVarints(): Unit {
        let data: Array<UInt8> = [0x05, 0x43, 0xE8]
        let (v1, l1) = decodeQuicVarint(data, 0)
        assertTrue(v1 == 5u64, message: "first consecutive varint should be 5")
        assertTrue(l1 == 1, message: "first varint length should be 1")
        let (v2, l2) = decodeQuicVarint(data, l1)
        assertTrue(v2 == 1000u64, message: "second consecutive varint should be 1000")
        assertTrue(l2 == 2, message: "second varint length should be 2")
    }
}
