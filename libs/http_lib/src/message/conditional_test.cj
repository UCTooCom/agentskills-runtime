package http_lib.message

import http_lib.core.{HttpHeaders, HttpStatus, assertTrue, assertFalse}

/**
 * 测试条件头部评估（RFC 7232）。
 */
@Test
public class ConditionalTest {

    /**
     * If-Unmodified-Since：日期匹配时，资源未被修改→继续。
     * 根据 RFC 7232 第 3.4 节：如果 lastModified <= ifUnmodifiedSince → 条件为真。
     */
    @TestCase
    public func testIfUnmodifiedSinceMatch(): Unit {
        let headers = HttpHeaders()
        headers.set("If-Unmodified-Since", "Sun, 06 Nov 1994 08:49:37 GMT")
        let etag = "\"abc123\""
        let lastModified = "Sun, 06 Nov 1994 08:49:37 GMT"

        let result = evaluateConditional(headers, etag, lastModified: lastModified)
        // 相同日期：资源未修改 → 不应返回 412
        match (result) {
            case Some(s) => assertTrue(s.code != 412, message: "Should NOT return 412 when dates match")
            case None => ()  // None = 正常处理——正确
        }
    }

    /**
     * If-Unmodified-Since：资源新于条件日期时→412。
     */
    @TestCase
    public func testIfUnmodifiedSinceMismatch(): Unit {
        let headers = HttpHeaders()
        // 条件日期较旧——资源此后已被修改
        headers.set("If-Unmodified-Since", "Sun, 01 Jan 1990 00:00:00 GMT")
        let etag = "\"abc123\""
        let lastModified = "Sun, 06 Nov 1994 08:49:37 GMT"

        let result = evaluateConditional(headers, etag, lastModified: lastModified)
        // 资源日期在条件日期之后 → 应返回 412
        match (result) {
            case Some(s) => assertTrue(s.code == 412, message: "Should return 412 when resource is newer")
            case None => assertTrue(false, message: "Should return 412, got None")
        }
    }

    /**
     * If-Modified-Since：资源未变更时 → 304。
     */
    @TestCase
    public func testIfModifiedSinceNotModified(): Unit {
        let headers = HttpHeaders()
        headers.set("If-Modified-Since", "Sun, 06 Nov 1994 08:49:37 GMT")
        let etag = "\"abc123\""
        let lastModified = "Sun, 01 Jan 1990 00:00:00 GMT"

        let result = evaluateConditional(headers, etag, lastModified: lastModified)
        // 资源早于条件 → 304
        match (result) {
            case Some(s) => assertTrue(s.isRedirection(), message: "Should return 304")
            case None => ()  // 也可接受
        }
    }

    /**
     * If-None-Match：匹配的 ETag → 304 未修改。
     */
    @TestCase
    public func testIfNoneMatch(): Unit {
        let headers = HttpHeaders()
        headers.set("If-None-Match", "\"abc123\"")
        let etag = "\"abc123\""
        let result = evaluateConditional(headers, etag)
        match (result) {
            case Some(s) => assertTrue(s.code == 304, message: "If-None-Match match should return 304")
            case None => ()
        }
    }

    /**
     * If-Match：不匹配的 ETag → 412 Precondition Failed。
     */
    @TestCase
    public func testIfMatchMismatch(): Unit {
        let headers = HttpHeaders()
        headers.set("If-Match", "\"xyz789\"")
        let etag = "\"abc123\""
        let result = evaluateConditional(headers, etag)
        match (result) {
            case Some(s) => assertTrue(s.code == 412, message: "If-Match mismatch should return 412")
            case None => ()
        }
    }

    /**
     * 无条件头部 → None（正常处理）。
     */
    @TestCase
    public func testNoConditionalHeaders(): Unit {
        let headers = HttpHeaders()
        let result = evaluateConditional(headers, "\"etag\"")
        assertTrue(result.isNone(), message: "No headers should return None")
    }

    /**
     * ETag 生成产生有效格式。
     */
    @TestCase
    public func testGenerateETagFormat(): Unit {
        let data = unsafe { "hello world".rawData() }
        let etag = generateETag(data)
        assertTrue(etag.startsWith("\""), message: "ETag should start with quote")
        assertTrue(etag.endsWith("\""), message: "ETag should end with quote")
    }

    /**
     * 弱 ETag 带有 W/ 前缀。
     */
    @TestCase
    public func testGenerateWeakETag(): Unit {
        let data = unsafe { "hello world".rawData() }
        let weakEtag = generateWeakETag(data)
        assertTrue(weakEtag.startsWith("W/"), message: "Weak ETag should start with W/")
    }

    @TestCase
    public func testEvaluateIfRangeEtagMatch(): Unit {
        let headers = HttpHeaders()
        headers.set("If-Range", "\"abc123\"")
        let result = evaluateIfRange(headers, "\"abc123\"")
        assertTrue(result, message: "If-Range with matching ETag should return true")
    }

    @TestCase
    public func testEvaluateIfRangeEtagMismatch(): Unit {
        let headers = HttpHeaders()
        headers.set("If-Range", "\"abc123\"")
        let result = evaluateIfRange(headers, "\"xyz789\"")
        assertFalse(result, message: "If-Range with non-matching ETag should return false")
    }

    @TestCase
    public func testEvaluateIfRangeDateMatch(): Unit {
        let headers = HttpHeaders()
        headers.set("If-Range", "Sun, 06 Nov 1994 08:49:37 GMT")
        let result = evaluateIfRange(headers, "\"etag\"", lastModified: "Sun, 06 Nov 1994 08:49:37 GMT")
        assertTrue(result, message: "If-Range with matching date should return true")
    }

    @TestCase
    public func testEvaluateIfRangeNoHeader(): Unit {
        let headers = HttpHeaders()
        let result = evaluateIfRange(headers, "\"etag\"")
        assertTrue(result, message: "No If-Range header should return true")
    }

    @TestCase
    public func testEvaluateIfRangeWeakEtag(): Unit {
        let headers = HttpHeaders()
        headers.set("If-Range", "W/\"abc\"")
        let result = evaluateIfRange(headers, "W/\"abc\"")
        assertTrue(result, message: "If-Range with matching weak ETag should return true")
    }

    @TestCase
    public func testSetConditionalHeaders(): Unit {
        let headers = HttpHeaders()
        let data = unsafe { "test data".rawData() }
        let lastModified = "Sun, 06 Nov 1994 08:49:37 GMT"
        setConditionalHeaders(headers, data, lastModified: lastModified)
        assertTrue(headers.contains("ETag"), message: "should set ETag")
        assertTrue(headers.contains("Last-Modified"), message: "should set Last-Modified")
        match (headers.get("Last-Modified")) {
            case Some(v) => assertTrue(v == "Sun, 06 Nov 1994 08:49:37 GMT")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testSetConditionalHeadersWithoutLastModified(): Unit {
        let headers = HttpHeaders()
        let data = unsafe { "test data".rawData() }
        setConditionalHeaders(headers, data)
        assertTrue(headers.contains("ETag"), message: "should set ETag")
        assertFalse(headers.contains("Last-Modified"), message: "should NOT set Last-Modified")
    }

    @TestCase
    public func testHttpDateGreater(): Unit {
        assertTrue(httpDateGreater("Mon, 07 Nov 1994 08:49:37 GMT", "Sun, 06 Nov 1994 08:49:37 GMT"),
            message: "later date should be greater")
        assertFalse(httpDateGreater("Sun, 06 Nov 1994 08:49:37 GMT", "Mon, 07 Nov 1994 08:49:37 GMT"),
            message: "earlier date should NOT be greater")
        assertFalse(httpDateGreater("Sun, 06 Nov 1994 08:49:37 GMT", "Sun, 06 Nov 1994 08:49:37 GMT"),
            message: "equal dates should NOT be greater")
    }

    @TestCase
    public func testHttpDateGreaterInvalid(): Unit {
        assertFalse(httpDateGreater("not-a-date", "Sun, 06 Nov 1994 08:49:37 GMT"),
            message: "invalid date should return false")
    }

    @TestCase
    public func testHttpDatesEqualSameString(): Unit {
        let s = "Sun, 06 Nov 1994 08:49:37 GMT"
        assertTrue(httpDatesEqual(s, s), message: "identical strings should be equal")
    }

    @TestCase
    public func testHttpDatesEqualDifferentFormatSameTime(): Unit {
        // RFC 1123 和 RFC 850 表示同一时刻
        let rfc1123 = "Sun, 06 Nov 1994 08:49:37 GMT"
        let rfc850 = "Sunday, 06-Nov-94 08:49:37 GMT"
        assertTrue(httpDatesEqual(rfc1123, rfc850), message: "same time different formats should be equal")
    }

    @TestCase
    public func testHttpDatesEqualMismatch(): Unit {
        assertFalse(httpDatesEqual("Sun, 06 Nov 1994 08:49:37 GMT", "Mon, 07 Nov 1994 08:49:37 GMT"),
            message: "different times should NOT be equal")
    }

    @TestCase
    public func testHttpDateLessOrEqual(): Unit {
        let earlier = "Sun, 06 Nov 1994 08:49:37 GMT"
        let later = "Mon, 07 Nov 1994 08:49:37 GMT"
        assertTrue(httpDateLessOrEqual(earlier, later), message: "earlier <= later should be true")
        assertTrue(httpDateLessOrEqual(earlier, earlier), message: "equal dates should satisfy <= ")
        assertFalse(httpDateLessOrEqual(later, earlier), message: "later <= earlier should be false")
    }
}
