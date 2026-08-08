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
public class HexTest {

    @TestCase
    public func testHexCharsLength(): Unit {
        assertTrue(HEX_CHARS.size == 16)
        assertTrue(HEX_CHARS_UPPER.size == 16)
    }

    @TestCase
    public func testByteToHexChar(): Unit {
        assertTrue(byteToHexChar(0) == r'0')
        assertTrue(byteToHexChar(5) == r'5')
        assertTrue(byteToHexChar(10) == r'a')
        assertTrue(byteToHexChar(15) == r'f')
    }

    @TestCase
    public func testByteToHexCharUpper(): Unit {
        assertTrue(byteToHexCharUpper(0) == b'0')
        assertTrue(byteToHexCharUpper(10) == b'A')
        assertTrue(byteToHexCharUpper(15) == b'F')
    }

    @TestCase
    public func testHexEncodeEmpty(): Unit {
        let result = hexEncode([])
        assertTrue(result == "")
    }

    @TestCase
    public func testHexEncode(): Unit {
        let data: Array<UInt8> = [0x00, 0x0f, 0xff]
        let result = hexEncode(data)
        assertTrue(result == "000fff")
    }

    @TestCase
    public func testHexEncodeHello(): Unit {
        let data = unsafe { "Hello".rawData() }
        let result = hexEncode(data)
        assertTrue(result == "48656c6c6f")
    }

    @TestCase
    public func testHexDecodeEmpty(): Unit {
        let result = hexDecode("")
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testHexDecode(): Unit {
        let result = hexDecode("000fff")
        assertTrue(result.size == 3)
        assertTrue(result[0] == UInt8(0x00))
        assertTrue(result[1] == UInt8(0x0f))
        assertTrue(result[2] == UInt8(0xff))
    }

    @TestCase
    public func testHexRoundtrip(): Unit {
        let original: Array<UInt8> = [0x12, 0x34, 0xab, 0xcd, 0xef]
        let encoded = hexEncode(original)
        let decoded = hexDecode(encoded)
        var isMatch = true
        var i: Int64 = 0
        while (i < original.size) {
            if (original[i] != decoded[i]) { isMatch = false }
            i++
        }
        assertTrue(isMatch)
        assertTrue(decoded.size == original.size)
    }

    @TestCase
    public func testToHex32(): Unit {
        assertTrue(toHex32(0) == "00000000")
        assertTrue(toHex32(255) == "000000ff")
        assertTrue(toHex32(0x1234abcd) == "1234abcd")
    }

    @TestCase
    public func testToHex64(): Unit {
        assertTrue(toHex64(0) == "0")
        assertTrue(toHex64(1) == "1")
    }
}
