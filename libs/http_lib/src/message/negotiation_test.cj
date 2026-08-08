package http_lib.message

import http_lib.core.{assertTrue, assertFalse}

/**
 * 测试 HTTP 内容协商（RFC 7231 第 5.3 节）。
 */
@Test
public class NegotiationTest {

    @TestCase
    public func testParseAcceptEncodingSimple(): Unit {
        let entries = parseAcceptEncoding("gzip, deflate, br")
        assertTrue(entries.size == 3, message: "should have 3 entries, got ${entries.size}")
    }

    @TestCase
    public func testParseAcceptEncodingWithQuality(): Unit {
        let entries = parseAcceptEncoding("gzip;q=1.0, deflate;q=0.5, br;q=0.3")
        assertTrue(entries.size == 3, message: "should have 3 entries")
    }

    @TestCase
    public func testSelectContentEncodingPreferGzip(): Unit {
        let available = ["gzip", "deflate"]
        let selected = selectContentEncoding(Some("gzip, deflate;q=0.5"), available)
        assertTrue(selected == "gzip", message: "should prefer gzip, got ${selected}")
    }

    @TestCase
    public func testSelectContentEncodingIdentity(): Unit {
        let available = ["gzip"]
        let selected = selectContentEncoding(Some("br;q=1.0"), available)
        assertTrue(selected == "identity", message: "should return identity, got ${selected}")
    }

    @TestCase
    public func testSelectContentEncodingNone(): Unit {
        let available = ["gzip"]
        let selected = selectContentEncoding(None, available)
        assertTrue(selected == "identity", message: "should return identity when no Accept-Encoding, got ${selected}")
    }

    @TestCase
    public func testSelectContentEncodingWildcard(): Unit {
        let available = ["gzip", "deflate"]
        let selected = selectContentEncoding(Some("*"), available)
        assertTrue(selected == "gzip", message: "wildcard should match first available, got ${selected}")
    }

    @TestCase
    public func testParseAcceptWithQuality(): Unit {
        let entries = parseAccept("text/html;q=1.0, application/json;q=0.9")
        assertTrue(entries.size >= 2, message: "should have at least 2 entries, got ${entries.size}")
    }

    @TestCase
    public func testSelectContentTypeExact(): Unit {
        let available = ["text/html", "application/json"]
        let selected = selectContentType(Some("application/json"), available)
        assertTrue(selected == "application/json", message: "should select exact match, got ${selected}")
    }

    @TestCase
    public func testSelectContentTypeWildcard(): Unit {
        let available = ["text/html", "application/json"]
        let selected = selectContentType(Some("*/*"), available)
        assertTrue(selected == "text/html", message: "wildcard should return first available, got ${selected}")
    }

    @TestCase
    public func testSelectContentTypeTypeWildcard(): Unit {
        let available = ["text/html", "application/json"]
        let selected = selectContentType(Some("text/*"), available)
        assertTrue(selected == "text/html", message: "text/* should match text/html, got ${selected}")
    }

    @TestCase
    public func testParseAcceptLanguage(): Unit {
        let entries = parseAcceptLanguage("en-US;q=1.0, en;q=0.9, fr;q=0.7, *;q=0.3")
        assertTrue(entries.size >= 2, message: "should parse language entries, got ${entries.size}")
    }

    @TestCase
    public func testParseAcceptCharset(): Unit {
        let entries = parseAcceptCharset("utf-8;q=1.0, iso-8859-1;q=0.5")
        assertTrue(entries.size == 2, message: "should parse charset entries, got ${entries.size}")
    }
}
