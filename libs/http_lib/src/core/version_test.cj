package http_lib.core

@Test
public class VersionTest {
    @TestCase
    public func testToString(): Unit {
        assertTrue(HttpVersion.HTTP_1_0.toString() == "HTTP/1.0")
        assertTrue(HttpVersion.HTTP_1_1.toString() == "HTTP/1.1")
        assertTrue(HttpVersion.HTTP_2_0.toString() == "HTTP/2.0")
    }

    @TestCase
    public func testParse(): Unit {
        match (HttpVersion.parse("HTTP/1.0")) {
            case Some(v) => assertTrue(v == HttpVersion.HTTP_1_0)
            case None => assertTrue(false)
        }
        match (HttpVersion.parse("HTTP/1.1")) {
            case Some(v) => assertTrue(v == HttpVersion.HTTP_1_1)
            case None => assertTrue(false)
        }
        match (HttpVersion.parse("HTTP/2.0")) {
            case Some(v) => assertTrue(v == HttpVersion.HTTP_2_0)
            case None => assertTrue(false)
        }
        match (HttpVersion.parse("HTTP/3.0")) {
            case Some(v) => assertTrue(v == HttpVersion.HTTP_3_0, message: "HTTP/3.0 should be supported")
            case None => assertTrue(false, message: "HTTP/3.0 should parse to Some")
        }
        match (HttpVersion.parse("HTTP/3")) {
            case Some(v) => assertTrue(v == HttpVersion.HTTP_3_0, message: "HTTP/3 should be supported")
            case None => assertTrue(false, message: "HTTP/3 should parse to Some")
        }
    }

    @TestCase
    public func testParseInvalid(): Unit {
        // 未知版本应返回 None
        assertTrue(HttpVersion.parse("HTTP/4.0").isNone())
        assertTrue(HttpVersion.parse("SPDY/3.1").isNone())
    }

    @TestCase
    public func testHttp3ToString(): Unit {
        assertTrue(HttpVersion.HTTP_3_0.toString() == "HTTP/3.0")
    }

    @TestCase
    public func testHttp3PersistentConnection(): Unit {
        assertTrue(HttpVersion.HTTP_3_0.supportsPersistentConnection())
    }

    @TestCase
    public func testSupportsPersistentConnection(): Unit {
        assertFalse(HttpVersion.HTTP_1_0.supportsPersistentConnection())
        assertTrue(HttpVersion.HTTP_1_1.supportsPersistentConnection())
        assertTrue(HttpVersion.HTTP_2_0.supportsPersistentConnection())
    }

    @TestCase
    public func testHashCode(): Unit {
        let v1 = HttpVersion.HTTP_1_1
        let v2 = HttpVersion.HTTP_1_1
        let v3 = HttpVersion.HTTP_2_0
        assertTrue(v1.hashCode() == v2.hashCode())
        assertTrue(v1.hashCode() != v3.hashCode())
    }

    @TestCase
    public func testInequality(): Unit {
        assertTrue(HttpVersion.HTTP_1_0 != HttpVersion.HTTP_1_1)
        assertTrue(HttpVersion.HTTP_1_1 != HttpVersion.HTTP_2_0)
        assertFalse(HttpVersion.HTTP_1_0 != HttpVersion.HTTP_1_0)
    }
}
