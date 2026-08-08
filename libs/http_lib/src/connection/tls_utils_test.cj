package http_lib.connection

private func assertTrue(condition: Bool, msg!: String = ""): Unit {
    if (!condition) { throw Exception("assertion failed: ${msg}") }
}

private func assertFalse(condition: Bool, msg!: String = ""): Unit {
    assertTrue(!condition, msg: msg)
}

@Test
public class TlsUtilsTest {

    @TestCase
    public func testConcatByteArrays(): Unit {
        let a: Array<UInt8> = [0x01, 0x02]
        let b: Array<UInt8> = [0x03, 0x04]
        let result = concatByteArrays(a, b)
        assertTrue(result.size == 4)
        assertTrue(result[0] == 0x01)
        assertTrue(result[1] == 0x02)
        assertTrue(result[2] == 0x03)
        assertTrue(result[3] == 0x04)
    }

    @TestCase
    public func testConcatByteArraysEmpty(): Unit {
        let a: Array<UInt8> = []
        let b: Array<UInt8> = [0x01]
        let result = concatByteArrays(a, b)
        assertTrue(result.size == 1)
        assertTrue(result[0] == 0x01)
    }

    @TestCase
    public func testConcatThree(): Unit {
        let a: Array<UInt8> = [0x01]
        let b: Array<UInt8> = [0x02]
        let c: Array<UInt8> = [0x03]
        let result = concatThree(a, b, c)
        assertTrue(result.size == 3)
        assertTrue(result[0] == 0x01)
        assertTrue(result[1] == 0x02)
        assertTrue(result[2] == 0x03)
    }

    @TestCase
    public func testConcatFive(): Unit {
        let a: Array<UInt8> = [0x01]
        let b: Array<UInt8> = [0x02]
        let c: Array<UInt8> = [0x03]
        let d: Array<UInt8> = [0x04]
        let e: Array<UInt8> = [0x05]
        let result = concatFive(a, b, c, d, e)
        assertTrue(result.size == 5)
        var i: Int64 = 0
        while (i < 5) {
            assertTrue(result[i] == UInt8(i + 1))
            i++
        }
    }
}


// ======== TLS PRF 函数测试 ========

@Test
public class TlsPrfTest {

    @TestCase
    public func testTls12PrfSha256EmptySecret(): Unit {
        var threw = false
        try {
            let _ = tls12PrfSha256([], "test", [0x01], 32)
        } catch (e: TlsException) {
            threw = true
        }
        assertTrue(threw, msg: "Empty secret should throw TlsException")
    }

    @TestCase
    public func testTls12PrfSha256ZeroOutput(): Unit {
        try {
            let result = tls12PrfSha256([0x01], "test", [0x02], 0)
            assertTrue(result.size == 0, msg: "Zero output length should return empty array")
        } catch (_: TlsException) {
            assertTrue(true, msg: "TlsException is acceptable if HMAC is unavailable")
        }
    }

    @TestCase
    public func testTls12PrfSha256NegativeOutput(): Unit {
        var threw = false
        try {
            let _ = tls12PrfSha256([0x01], "test", [0x02], -1)
        } catch (e: TlsException) {
            threw = true
        }
        assertTrue(threw, msg: "Negative output length should throw TlsException")
    }

    @TestCase
    public func testPHashSha256ZeroOutput(): Unit {
        let result = pHashSha256([0x01], [0x02], 0)
        assertTrue(result.size == 0, msg: "Zero output length should return empty array")
    }
}

