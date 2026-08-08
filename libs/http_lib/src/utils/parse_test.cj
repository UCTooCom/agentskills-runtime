package http_lib.utils

// 简单断言辅助函数（避免与 http_lib.core 循环依赖）
private func assertTrue(condition: Bool, msg!: String = ""): Unit {
    if (!condition) {
        throw Exception("assertion failed: ${msg}")
    }
}

@Test
public class ParseTest {

    @TestCase
    public func testParsePort80(): Unit {
        let result = parsePortString("80")
        assertTrue(result == 80u16)
    }

    @TestCase
    public func testParsePort443(): Unit {
        let result = parsePortString("443")
        assertTrue(result == 443u16)
    }

    @TestCase
    public func testParsePort0(): Unit {
        let result = parsePortString("0")
        assertTrue(result == 0u16)
    }

    @TestCase
    public func testParsePort65535(): Unit {
        let result = parsePortString("65535")
        assertTrue(result == 65535u16)
    }

    @TestCase
    public func testParsePortInvalidThrows(): Unit {
        var threw = false
        try {
            let _ = parsePortString("abc")
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw, msg: "invalid port should throw")
    }

    @TestCase
    public func testParsePortOverflowThrows(): Unit {
        var threw = false
        try {
            let _ = parsePortString("70000")
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw, msg: "overflow port should throw")
    }
}
