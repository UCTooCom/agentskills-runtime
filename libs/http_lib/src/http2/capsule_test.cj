package http_lib.http2

import http_lib.core.{assertTrue, assertFalse, ProtocolException}

@Test
public class CapsuleTest {
    @TestCase
    public func testCapsuleTypeEncodeDecode(): Unit {
        let types = [CapsuleType.DATA, CapsuleType.DATAGRAM, CapsuleType.DATAGRAM_WITH_CONTEXT, CapsuleType.CLOSE]
        for (t in types) {
            let v = t.toUInt64()
            let back = CapsuleType.fromUInt64(v)
            if (back.isNone() || back.getOrThrow() != t) {
                throw Exception("CapsuleType roundtrip failed for ${t}")
            }
        }
    }

    @TestCase
    public func testInvalidCapsuleType(): Unit {
        let result = CapsuleType.fromUInt64(99u64)
        if (result.isSome()) {
            throw Exception("Expected None for invalid capsule type")
        }
    }

    @TestCase
    public func testBuildAndDecodeDatagramCapsule(): Unit {
        let payload: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        let capsule = buildDatagramCapsule(payload)
        if (capsule.capsuleType != CapsuleType.DATAGRAM) {
            throw Exception("Expected DATAGRAM type")
        }
        if (capsule.payload.size != 5) {
            throw Exception("Expected payload size 5, got ${capsule.payload.size}")
        }
    }

    @TestCase
    public func testBuildCloseCapsule(): Unit {
        let capsule = buildCloseCapsule()
        if (capsule.capsuleType != CapsuleType.CLOSE) {
            throw Exception("Expected CLOSE type")
        }
    }

    @TestCase
    public func testEncodeDecodeCapsule(): Unit {
        let payload: Array<UInt8> = [b't', b'e', b's', b't']
        let original = Capsule(CapsuleType.DATAGRAM, payload)
        let encoded = encodeCapsule(original)
        let decoded = decodeCapsule(encoded)
        if (decoded.capsuleType != original.capsuleType) {
            throw Exception("Type mismatch after encode/decode")
        }
        if (decoded.payload.size != original.payload.size) {
            throw Exception("Payload size mismatch")
        }
    }

    @TestCase
    public func testDecodeTruncatedCapsule(): Unit {
        let short: Array<UInt8> = [0x00, 0x01]
        try {
            let _ = decodeCapsule(short)
            throw Exception("Expected ProtocolException for truncated capsule")
        } catch (_: ProtocolException) {
            // Expected
        }
    }

    @TestCase
    public func testDatagramWithContext(): Unit {
        let data: Array<UInt8> = [b'a', b'b']
        let capsule = buildDatagramWithContextCapsule(1u64, data)
        if (capsule.capsuleType != CapsuleType.DATAGRAM_WITH_CONTEXT) {
            throw Exception("Expected DATAGRAM_WITH_CONTEXT type")
        }
    }
}


@Test
public class CapsuleVarintTest {

    @TestCase
    public func testEncodeQuicVarint1Byte(): Unit {
        // 1 字节：值 ≤ 63
        let result = encodeQuicVarint(0)
        assertTrue(result.size == 1, message: "0 should encode as 1 byte")
        assertTrue(result[0] == 0)
        
        let result63 = encodeQuicVarint(63)
        assertTrue(result63.size == 1, message: "63 should encode as 1 byte")
        assertTrue(result63[0] == 63)
    }

    @TestCase
    public func testEncodeQuicVarint2Byte(): Unit {
        // 2 字节：64 ≤ 值 ≤ 16383
        let result = encodeQuicVarint(64)
        assertTrue(result.size == 2, message: "64 should encode as 2 bytes")
        
        let result16383 = encodeQuicVarint(16383)
        assertTrue(result16383.size == 2, message: "16383 should encode as 2 bytes")
    }

    @TestCase
    public func testEncodeQuicVarint4Byte(): Unit {
        // 4 字节：16384 ≤ 值 ≤ 1073741823
        let result = encodeQuicVarint(16384)
        assertTrue(result.size == 4, message: "16384 should encode as 4 bytes")
        
        let resultMax = encodeQuicVarint(1073741823)
        assertTrue(resultMax.size == 4, message: "1073741823 should encode as 4 bytes")
    }

    @TestCase
    public func testEncodeQuicVarint8Byte(): Unit {
        // 8 字节：1073741824 ≤ 值
        let result = encodeQuicVarint(1073741824)
        assertTrue(result.size == 8, message: "1073741824 should encode as 8 bytes")
        
        let resultLarge = encodeQuicVarint(4611686018427387903)
        assertTrue(resultLarge.size == 8, message: "large value should encode as 8 bytes")
    }

    @TestCase
    public func testDecodeQuicVarint1Byte(): Unit {
        let data: Array<UInt8> = [0x2A]  // 42
        let (value, len) = decodeQuicVarint(data, 0)
        assertTrue(value == 42u64, message: "Should decode 42")
        assertTrue(len == 1, message: "Should consume 1 byte")
    }

    @TestCase
    public func testDecodeQuicVarint2Byte(): Unit {
        let data: Array<UInt8> = [0x40, 0x40]  // 64 (0x40 | 0 | 0x00)
        let (value, len) = decodeQuicVarint(data, 0)
        assertTrue(value == 64u64, message: "Should decode 64 from 2-byte varint, got ${value}")
        assertTrue(len == 2, message: "Should consume 2 bytes")
    }

    @TestCase
    public func testDecodeQuicVarint4Byte(): Unit {
        let data: Array<UInt8> = [0x80, 0x00, 0x00, 0x04]  // 4 with 2-bit=10 prefix
        let (value, len) = decodeQuicVarint(data, 0)
        assertTrue(value == 4u64, message: "Should decode 4 from 4-byte varint")
        assertTrue(len == 4, message: "Should consume 4 bytes")
    }

    @TestCase
    public func testEncodeDecodeRoundTrip(): Unit {
        let testValues: Array<UInt64> = [0, 1, 42, 63, 64, 16383, 16384, 1073741823, 1073741824, 4611686018427387903]
        for (v in testValues) {
            let encoded = encodeQuicVarint(v)
            let (decoded, consumed) = decodeQuicVarint(encoded, 0)
            assertTrue(decoded == v, message: "Round-trip failed for ${v}, got ${decoded}")
            assertTrue(consumed == encoded.size, message: "Consumed ${consumed} != encoded ${encoded.size}")
        }
    }
    
    @TestCase
    public func testDecodeInvalidTruncated(): Unit {
        let data: Array<UInt8> = [0xC0]  // 8-byte prefix but only 1 byte
        try {
            let (_, _) = decodeQuicVarint(data, 0)
            assertTrue(false, message: "Should throw on truncated varint")
        } catch (e: ProtocolException) {
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "Should throw ProtocolException")
        }
    }
}

@Test
public class CapsuleProtocolTest {

    @TestCase
    public func testBuildDatagramCapsule(): Unit {
        let data: Array<UInt8> = [0x01, 0x02, 0x03]
        let capsule = buildDatagramCapsule(data)
        let encoded = encodeCapsule(capsule)
        let decoded = decodeCapsule(encoded)
        assertTrue(decoded.capsuleType == CapsuleType.DATAGRAM,
            message: "Type should be DATAGRAM")
        assertTrue(decoded.payload.size == 3, 
            message: "Payload should be 3 bytes")
        assertTrue(decoded.payload[0] == 0x01 &&
                   decoded.payload[1] == 0x02 &&
                   decoded.payload[2] == 0x03,
            message: "Payload content should match")
    }

    @TestCase
    public func testBuildCloseCapsule(): Unit {
        let capsule = buildCloseCapsule()
        let encoded = encodeCapsule(capsule)
        let decoded = decodeCapsule(encoded)
        assertTrue(decoded.capsuleType == CapsuleType.CLOSE,
            message: "Type should be CLOSE")
        assertTrue(decoded.payload.size == 0,
            message: "CLOSE capsule should have empty payload")
    }

    @TestCase
    public func testDatagramWithContext(): Unit {
        let data: Array<UInt8> = [0xAA, 0xBB]
        // 编码时使用 small context ID（1 字节 varint）
        let capsule = buildDatagramWithContextCapsule(0, data)
        let encoded = encodeCapsule(capsule)
        let decoded = decodeCapsule(encoded)
        assertTrue(decoded.capsuleType == CapsuleType.DATAGRAM_WITH_CONTEXT,
            message: "Type should be DATAGRAM_WITH_CONTEXT")
    }
}
