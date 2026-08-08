package http_lib.utils

// 简单断言辅助函数（避免与 http_lib.core 循环依赖）
private func assertTrue(condition: Bool, msg!: String = ""): Unit {
    if (!condition) {
        throw Exception("assertion failed: ${msg}")
    }
}

private func assertFalse(condition: Bool, msg!: String = ""): Unit {
    assertTrue(!condition, msg: msg)
}

@Test
public class UtilsTest {

    @TestCase
    public func testCopyBytes(): Unit {
        let src = Array<UInt8>(5, { i => UInt8(i + 1) })
        let dest = Array<UInt8>(5, repeat: 0)
        copyBytes(src, 0, dest, 0, 5)
        assertTrue(dest[0] == 1)
        assertTrue(dest[4] == 5)
    }

    @TestCase
    public func testCopyBytesPartial(): Unit {
        let src = Array<UInt8>(5, { i => UInt8(i + 1) })
        let dest = Array<UInt8>(3, repeat: 0)
        copyBytes(src, 1, dest, 0, 3)
        assertTrue(dest[0] == 2)
        assertTrue(dest[1] == 3)
        assertTrue(dest[2] == 4)
    }

    @TestCase
    public func testCopyBytesZeroLength(): Unit {
        let src = Array<UInt8>(3, repeat: 0x01)
        let dest = Array<UInt8>(3, repeat: 0xFF)
        copyBytes(src, 0, dest, 0, 0)
        assertTrue(dest[0] == 0xFF)
    }

    @TestCase
    public func testMaxInt64(): Unit {
        assertTrue(maxInt64(5, 3) == 5)
        assertTrue(maxInt64(-1, 0) == 0)
        assertTrue(maxInt64(100, 100) == 100)
    }

    @TestCase
    public func testMinInt64(): Unit {
        assertTrue(minInt64(5, 3) == 3)
        assertTrue(minInt64(-1, 0) == -1)
        assertTrue(minInt64(100, 100) == 100)
    }

    @TestCase
    public func testParseHttpUrl(): Unit {
        let parsed = ParsedUrl.parse("https://example.com:8443/api/v1")
        assertTrue(parsed.host == "example.com")
        assertTrue(parsed.port == 8443)
        assertTrue(parsed.isSecure == true)
        assertTrue(parsed.path == "/api/v1")
    }

    @TestCase
    public func testParseHttpUrlDefaultPorts(): Unit {
        let parsed1 = ParsedUrl.parse("https://example.com/")
        assertTrue(parsed1.host == "example.com")
        assertTrue(parsed1.port == 443)
        assertTrue(parsed1.isSecure == true)

        let parsed2 = ParsedUrl.parse("http://example.com/")
        assertTrue(parsed2.host == "example.com")
        assertTrue(parsed2.port == 80)
        assertTrue(parsed2.isSecure == false)
    }

    @TestCase
    public func testParseHttpUrlPathOnly(): Unit {
        let parsed = ParsedUrl.parse("http://example.com")
        assertTrue(parsed.host == "example.com")
        assertTrue(parsed.path == "/")
    }

    @TestCase
    public func testBase64EncodeBytes(): Unit {
        let data: Array<UInt8> = [b'h', b'e', b'l', b'l', b'o']
        let encoded = base64EncodeBytes(data)
        assertTrue(encoded.size > 0)
    }

    @TestCase
    public func testBase64EncodeString(): Unit {
        let encoded = base64EncodeString("hello")
        assertTrue(encoded.size > 0)
    }

    @TestCase
    public func testContainsIgnoreCaseBytes(): Unit {
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o', b'W', b'o', b'r', b'l', b'd']
        assertTrue(containsIgnoreCaseBytes(data, [b'w', b'o', b'r', b'l', b'd']))
        assertTrue(containsIgnoreCaseBytes(data, [b'h', b'e', b'l', b'l', b'o']))
        assertFalse(containsIgnoreCaseBytes(data, [b'x', b'y', b'z']))
    }

    @TestCase
    public func testContainsIgnoreCase(): Unit {
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        assertTrue(containsIgnoreCase(data, "hello".toRuneArray()))
        assertTrue(containsIgnoreCase(data, "HELLO".toRuneArray()))
        assertFalse(containsIgnoreCase(data, "world".toRuneArray()))
    }

    @TestCase
    public func testEqualsIgnoreCaseBytes(): Unit {
        assertTrue(equalsIgnoreCaseBytes([b'h', b'e', b'l', b'l', b'o'], [b'H', b'E', b'l', b'l', b'o']))
        assertFalse(equalsIgnoreCaseBytes([b'h', b'e', b'l', b'l', b'o'], [b'w', b'o', b'r', b'l', b'd']))
    }

    @TestCase
    public func testArraysEqual(): Unit {
        assertTrue(arraysEqual([b'a', b'b', b'c'], [b'a', b'b', b'c']))
        assertFalse(arraysEqual([b'a', b'b'], [b'a', b'b', b'c']))
        assertFalse(arraysEqual([b'a', b'b', b'c'], [b'a', b'b', b'd']))
    }

    @TestCase
    public func testFormUrlEncode(): Unit {
        let encoded = formUrlEncode("hello world")
        assertTrue(encoded.contains("+"))
    }

    @TestCase
    public func testHexEncode(): Unit {
        let data: Array<UInt8> = [0xde, 0xad]
        let hex = hexEncode(data)
        assertTrue(hex == "dead")
    }

    @TestCase
    public func testStringToBytes(): Unit {
        let bytes = stringToBytes("hello")
        assertTrue(bytes.size == 5)
        let restored = String.fromUtf8(bytes)
        assertTrue(restored == "hello")
    }

    @TestCase
    public func testStartsWithIgnoreCase(): Unit {
        let data: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        assertTrue(startsWithIgnoreCase(data, [b'h', b'e']))
        assertTrue(startsWithIgnoreCase(data, [b'H', b'E']))
        assertFalse(startsWithIgnoreCase(data, [b'x']))
    }

    @TestCase
    public func testMaxMinInt64(): Unit {
        assertTrue(maxInt64(5, 3) == 5)
        assertTrue(minInt64(5, 3) == 3)
    }
}


@Test
public class Base64Test {
    @TestCase
    public func testBase64Decode(): Unit {
        let original = "Hello World"
        let encoded = base64EncodeString(original)
        let decoded = base64DecodeString(encoded)
        if (decoded != original) {
            throw Exception("Base64 roundtrip failed: ${decoded}")
        }
    }

    @TestCase
    public func testBase64DecodeBytes(): Unit {
        let data: Array<UInt8> = [b'H', b'i']
        let encoded = base64EncodeBytes(data)
        let decoded = base64DecodeBytes(encoded)
        if (decoded.size != data.size || decoded[0] != data[0]) {
            throw Exception("Base64 bytes roundtrip failed")
        }
    }
}
