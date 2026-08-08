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
public class UrlParserTest {

    @TestCase
    public func testParseHttpUrl(): Unit {
        let url = ParsedUrl.parse("http://example.com")
        assertTrue(url.scheme == "http")
        assertTrue(url.host == "example.com")
        assertTrue(url.port == 80u16)
        assertTrue(url.path == "/")
        assertFalse(url.isSecure)
    }

    @TestCase
    public func testParseHttpsUrl(): Unit {
        let url = ParsedUrl.parse("https://example.com")
        assertTrue(url.scheme == "https")
        assertTrue(url.port == 443u16)
        assertTrue(url.isSecure)
    }

    @TestCase
    public func testParseUrlWithPort(): Unit {
        let url = ParsedUrl.parse("http://example.com:8080/path")
        assertTrue(url.host == "example.com")
        assertTrue(url.port == 8080u16)
        assertTrue(url.path == "/path")
    }

    @TestCase
    public func testParseUrlWithPath(): Unit {
        let url = ParsedUrl.parse("https://example.com/api/v1/users")
        assertTrue(url.path == "/api/v1/users")
    }

    @TestCase
    public func testParseUrlWithUserInfo(): Unit {
        let url = ParsedUrl.parse("http://user:pass@example.com/")
        assertTrue(url.host == "example.com")
    }

    @TestCase
    public func testParseUrlRootPath(): Unit {
        let url = ParsedUrl.parse("http://example.com")
        assertTrue(url.path == "/")
    }

    @TestCase
    public func testParseHttpNotSecure(): Unit {
        let url = ParsedUrl.parse("http://example.com")
        assertFalse(url.isSecure)
    }

    @TestCase
    public func testParseHttpsIsSecure(): Unit {
        let url = ParsedUrl.parse("https://secure.example.com")
        assertTrue(url.isSecure)
    }
}
