package http_lib.message

import http_lib.core.{assertTrue, assertFalse}

/**
 * 测试 Cache-Control 头部解析（RFC 7234）。
 */
@Test
public class CacheControlTest {

    @TestCase
    public func testHasDirective(): Unit {
        let cc = CacheControl.parse("no-cache, no-store, must-revalidate")
        assertTrue(cc.has("no-cache"), message: "has() should find no-cache")
        assertTrue(cc.has("no-store"), message: "has() should find no-store")
        assertTrue(cc.has("must-revalidate"), message: "has() should find must-revalidate")
        assertFalse(cc.has("no-transform"), message: "has() should not find no-transform")
    }

    @TestCase
    public func testGetDirective(): Unit {
        let cc = CacheControl.parse("max-age=3600, s-maxage=86400")
        match (cc.get("max-age")) {
            case Some(v) => assertTrue(v == "3600", message: "get(max-age) should return 3600")
            case None => assertTrue(false)
        }
        match (cc.get("s-maxage")) {
            case Some(v) => assertTrue(v == "86400")
            case None => assertTrue(false)
        }
        match (cc.get("no-such-directive")) {
            case Some(_) => assertTrue(false)
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testParseSimpleDirectives(): Unit {
        let cc = CacheControl.parse("no-cache, no-store")
        assertTrue(cc.isNoCache(), message: "should detect no-cache")
        assertTrue(cc.isNoStore(), message: "should detect no-store")
    }

    @TestCase
    public func testParseMaxAge(): Unit {
        let cc = CacheControl.parse("max-age=3600")
        match (cc.maxAge()) {
            case Some(age) => assertTrue(age == 3600, message: "max-age should be 3600, got ${age}")
            case None => assertTrue(false, message: "should parse max-age")
        }
    }

    @TestCase
    public func testParseMultipleDirectives(): Unit {
        let cc = CacheControl.parse("public, max-age=86400, must-revalidate")
        assertTrue(cc.isPublic(), message: "should be public")
        assertTrue(cc.isMustRevalidate(), message: "should be must-revalidate")
        match (cc.maxAge()) {
            case Some(age) => assertTrue(age == 86400, message: "max-age should be 86400")
            case None => assertTrue(false, message: "should parse max-age")
        }
    }

    @TestCase
    public func testParsePrivate(): Unit {
        let cc = CacheControl.parse("private")
        assertTrue(cc.isPrivate(), message: "should be private")
        let isPublic = cc.isPublic()
        assertFalse(isPublic, message: "should not be public")
    }

    @TestCase
    public func testParseSMaxAge(): Unit {
        let cc = CacheControl.parse("s-maxage=7200, max-age=3600")
        match (cc.sMaxAge()) {
            case Some(age) => assertTrue(age == 7200, message: "s-maxage should be 7200")
            case None => assertTrue(false, message: "should parse s-maxage")
        }
        match (cc.maxAge()) {
            case Some(age) => assertTrue(age == 3600, message: "max-age should be 3600")
            case None => assertTrue(false, message: "should parse max-age")
        }
    }

    @TestCase
    public func testParseNoTransform(): Unit {
        let cc = CacheControl.parse("no-transform")
        assertTrue(cc.isNoTransform(), message: "should detect no-transform")
    }

    @TestCase
    public func testParseImmutable(): Unit {
        let cc = CacheControl.parse("public, max-age=31536000, immutable")
        assertTrue(cc.isImmutable(), message: "should detect immutable")
        assertTrue(cc.isPublic(), message: "should be public")
    }

    @TestCase
    public func testParseEmpty(): Unit {
        let cc = CacheControl.parse("")
        assertTrue(cc.directives.size == 0, message: "empty should have no directives")
    }

    @TestCase
    public func testParseStaleWhileRevalidate(): Unit {
        let cc = CacheControl.parse("max-age=3600, stale-while-revalidate=86400")
        match (cc.isStaleWhileRevalidate()) {
            case Some(v) => assertTrue(v == 86400, message: "stale-while-revalidate should be 86400")
            case None => assertTrue(false, message: "should parse stale-while-revalidate")
        }
    }

    @TestCase
    public func testParseStaleIfError(): Unit {
        let cc = CacheControl.parse("max-age=3600, stale-if-error=604800")
        match (cc.isStaleIfError()) {
            case Some(v) => assertTrue(v == 604800, message: "stale-if-error should be 604800")
            case None => assertTrue(false, message: "should parse stale-if-error")
        }
    }

    @TestCase
    public func testIsCacheable(): Unit {
        assertTrue(CacheControl.parse("public, max-age=3600").isCacheable(), message: "public should be cacheable")
        let ns = CacheControl.parse("no-store")
        assertFalse(ns.isCacheable(), message: "no-store should not be cacheable")
        let priv = CacheControl.parse("private")
        assertFalse(priv.isCacheable(), message: "private should not be cacheable by shared cache")
    }

    @TestCase
    public func testToString(): Unit {
        let cc = CacheControl()
        cc.directives["public"] = ""
        cc.directives["max-age"] = "3600"
        let str = cc.toString()
        assertTrue(str.indexOf("public").isSome(), message: "should contain public")
        assertTrue(str.indexOf("max-age=3600").isSome(), message: "should contain max-age=3600")
    }

    @TestCase
    public func testMaxStale(): Unit {
        let cc = CacheControl.parse("max-stale=3600")
        match (cc.maxStale()) {
            case Some(v) => assertTrue(v == 3600, message: "max-stale should be 3600, got ${v}")
            case None => assertTrue(false, message: "should parse max-stale")
        }
    }

    @TestCase
    public func testMaxStaleWithoutValue(): Unit {
        let cc = CacheControl.parse("max-stale")
        match (cc.maxStale()) {
            case Some(v) => assertTrue(v == -1, message: "max-stale without value should return -1")
            case None => assertTrue(false, message: "should parse max-stale without value")
        }
    }

    @TestCase
    public func testMinFresh(): Unit {
        let cc = CacheControl.parse("min-fresh=120")
        match (cc.minFresh()) {
            case Some(v) => assertTrue(v == 120, message: "min-fresh should be 120, got ${v}")
            case None => assertTrue(false, message: "should parse min-fresh")
        }
    }

    @TestCase
    public func testNoCacheField(): Unit {
        let cc = CacheControl.parse("no-cache=\"Set-Cookie\"")
        match (cc.noCacheField()) {
            case Some(f) => assertTrue(f == "Set-Cookie", message: "no-cache field should be Set-Cookie")
            case None => assertTrue(false, message: "should parse no-cache field")
        }
    }

    @TestCase
    public func testNoCacheFieldWithoutValue(): Unit {
        let cc = CacheControl.parse("no-cache")
        match (cc.noCacheField()) {
            case Some(f) => assertTrue(f.size == 0, message: "no-cache value should be empty")
            case None => assertTrue(false, message: "should parse no-cache")
        }
    }

    @TestCase
    public func testIsPublic(): Unit {
        let cc = CacheControl.parse("public")
        assertTrue(cc.isPublic(), message: "should detect public")
        assertFalse(CacheControl.parse("private").isPublic(), message: "private should not be public")
    }

    @TestCase
    public func testIsNoCache(): Unit {
        let cc = CacheControl.parse("no-cache")
        assertTrue(cc.isNoCache(), message: "should detect no-cache")
        assertFalse(CacheControl.parse("no-store").isNoCache(), message: "no-store should not be no-cache")
    }

    @TestCase
    public func testIsMustRevalidate(): Unit {
        let cc = CacheControl.parse("must-revalidate")
        assertTrue(cc.isMustRevalidate(), message: "should detect must-revalidate")
    }

    @TestCase
    public func testIsProxyRevalidate(): Unit {
        let cc = CacheControl.parse("proxy-revalidate")
        assertTrue(cc.isProxyRevalidate(), message: "should detect proxy-revalidate")
    }
}
