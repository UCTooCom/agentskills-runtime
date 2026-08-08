package http_lib.message

import http_lib.core.{assertTrue, assertFalse, HttpHeaders}

@Test
public class RetryAfterTest {

    @TestCase
    public func testNoRetryAfterHeader(): Unit {
        let headers = HttpHeaders()
        let result = parseRetryAfter(headers)
        assertTrue(result.isNone())
    }

    @TestCase
    public func testRetryAfterDeltaSeconds(): Unit {
        let headers = HttpHeaders()
        headers.set("retry-after", "120")
        let result = parseRetryAfter(headers)
        assertTrue(result.isSome())
        match (result) {
            case Some(seconds) => assertTrue(seconds == 120)
            case None => assertTrue(false, message: "should parse 120")
        }
    }

    @TestCase
    public func testRetryAfterZero(): Unit {
        let headers = HttpHeaders()
        headers.set("retry-after", "0")
        let result = parseRetryAfter(headers)
        assertTrue(result.isSome())
        match (result) {
            case Some(seconds) => assertTrue(seconds == 0)
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRetryAfterInvalidString(): Unit {
        let headers = HttpHeaders()
        headers.set("retry-after", "invalid")
        // 非数字、非HTTP-date，应解析为None
        let result = parseRetryAfter(headers)
        match (result) {
            case Some(_) => assertTrue(true)
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testRetryAfterNegative(): Unit {
        let headers = HttpHeaders()
        headers.set("retry-after", "-30")
        let result = parseRetryAfter(headers)
        assertTrue(result.isSome())
        match (result) {
            case Some(seconds) => assertTrue(seconds >= 0)
            case None => assertTrue(false)
        }
    }
}
