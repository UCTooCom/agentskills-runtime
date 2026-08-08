package http_lib.core

@Test
public class StatusTest {
    @TestCase
    public func testStandardStatusCodes(): Unit {
        // 1xx（信息响应）
        assertTrue(HttpStatus.CONTINUE.code == 100)
        assertTrue(HttpStatus.CONTINUE.reasonPhrase == "Continue")
        assertTrue(HttpStatus.PROCESSING.code == 102)
        assertTrue(HttpStatus.EARLY_HINTS.code == 103)
        // 2xx（成功）
        assertTrue(HttpStatus.OK.code == 200)
        assertTrue(HttpStatus.OK.reasonPhrase == "OK")
        assertTrue(HttpStatus.MULTI_STATUS.code == 207)
        assertTrue(HttpStatus.IM_USED.code == 226)
        // 3xx（重定向）
        assertTrue(HttpStatus.MULTIPLE_CHOICES.code == 300)
        // 4xx（客户端错误）
        assertTrue(HttpStatus.NOT_FOUND.code == 404)
        assertTrue(HttpStatus.NOT_FOUND.reasonPhrase == "Not Found")
        assertTrue(HttpStatus.PAYMENT_REQUIRED.code == 402)
        assertTrue(HttpStatus.IM_A_TEAPOT.code == 418)
        assertTrue(HttpStatus.TOO_EARLY.code == 425)
        assertTrue(HttpStatus.UNAVAILABLE_FOR_LEGAL_REASONS.code == 451)
        // 5xx（服务器错误）
        assertTrue(HttpStatus.INTERNAL_SERVER_ERROR.code == 500)
        assertTrue(HttpStatus.LOOP_DETECTED.code == 508)
        assertTrue(HttpStatus.NETWORK_AUTHENTICATION_REQUIRED.code == 511)
    }

    @TestCase
    public func testAllNewStatusCodesPresent(): Unit {
        // 验证全部 51+ 状态码
        let codes = [
            HttpStatus.CONTINUE, HttpStatus.SWITCHING_PROTOCOLS,
            HttpStatus.PROCESSING, HttpStatus.EARLY_HINTS,
            HttpStatus.OK, HttpStatus.CREATED, HttpStatus.ACCEPTED,
            HttpStatus.NON_AUTHORITATIVE_INFORMATION, HttpStatus.NO_CONTENT,
            HttpStatus.RESET_CONTENT, HttpStatus.PARTIAL_CONTENT,
            HttpStatus.MULTI_STATUS, HttpStatus.ALREADY_REPORTED, HttpStatus.IM_USED,
            HttpStatus.MULTIPLE_CHOICES, HttpStatus.MOVED_PERMANENTLY,
            HttpStatus.FOUND, HttpStatus.SEE_OTHER, HttpStatus.NOT_MODIFIED,
            HttpStatus.TEMPORARY_REDIRECT, HttpStatus.PERMANENT_REDIRECT,
            HttpStatus.BAD_REQUEST, HttpStatus.UNAUTHORIZED, HttpStatus.PAYMENT_REQUIRED,
            HttpStatus.FORBIDDEN, HttpStatus.NOT_FOUND, HttpStatus.METHOD_NOT_ALLOWED,
            HttpStatus.NOT_ACCEPTABLE, HttpStatus.PROXY_AUTHENTICATION_REQUIRED,
            HttpStatus.REQUEST_TIMEOUT, HttpStatus.CONFLICT, HttpStatus.GONE,
            HttpStatus.LENGTH_REQUIRED, HttpStatus.PRECONDITION_FAILED,
            HttpStatus.PAYLOAD_TOO_LARGE, HttpStatus.URI_TOO_LONG,
            HttpStatus.UNSUPPORTED_MEDIA_TYPE, HttpStatus.RANGE_NOT_SATISFIABLE,
            HttpStatus.EXPECTATION_FAILED, HttpStatus.IM_A_TEAPOT,
            HttpStatus.MISDIRECTED_REQUEST, HttpStatus.UNPROCESSABLE_ENTITY,
            HttpStatus.LOCKED, HttpStatus.FAILED_DEPENDENCY, HttpStatus.TOO_EARLY,
            HttpStatus.UPGRADE_REQUIRED, HttpStatus.PRECONDITION_REQUIRED,
            HttpStatus.TOO_MANY_REQUESTS, HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE,
            HttpStatus.UNAVAILABLE_FOR_LEGAL_REASONS,
            HttpStatus.INTERNAL_SERVER_ERROR, HttpStatus.NOT_IMPLEMENTED,
            HttpStatus.BAD_GATEWAY, HttpStatus.SERVICE_UNAVAILABLE,
            HttpStatus.GATEWAY_TIMEOUT, HttpStatus.HTTP_VERSION_NOT_SUPPORTED,
            HttpStatus.VARIANT_ALSO_NEGOTIATES, HttpStatus.INSUFFICIENT_STORAGE,
            HttpStatus.LOOP_DETECTED, HttpStatus.NOT_EXTENDED,
            HttpStatus.NETWORK_AUTHENTICATION_REQUIRED
        ]
        // 所有状态码应有非空原因短语
        for (status in codes) {
            assertTrue(status.reasonPhrase.size > 0)
        }
    }

    @TestCase
    public func testCustomStatus(): Unit {
        let status = HttpStatus(299, reasonPhrase: "Custom")
        assertTrue(status.code == 299)
        assertTrue(status.reasonPhrase == "Custom")
    }

    @TestCase
    public func testCategoryChecks(): Unit {
        assertTrue(HttpStatus(100).isInformational())
        assertTrue(HttpStatus(200).isSuccess())
        assertTrue(HttpStatus(301).isRedirection())
        assertTrue(HttpStatus(404).isClientError())
        assertTrue(HttpStatus(500).isServerError())
        assertFalse(HttpStatus(200).isClientError())
        assertFalse(HttpStatus(404).isSuccess())
    }

    @TestCase
    public func testToString(): Unit {
        assertTrue(HttpStatus.OK.toString() == "200 OK")
        assertTrue(HttpStatus.NOT_FOUND.toString() == "404 Not Found")
    }

    @TestCase
    public func testEquality(): Unit {
        let status1 = HttpStatus(200)
        let status2 = HttpStatus(200)
        assertTrue(status1 == status2)
    }

    @TestCase
    public func testInequality(): Unit {
        assertTrue(HttpStatus(200) != HttpStatus(404))
        assertTrue(HttpStatus.OK != HttpStatus.NOT_FOUND)
    }

    @TestCase
    public func testEqualityWithReasonPhrase(): Unit {
        let s1 = HttpStatus(299, reasonPhrase: "Custom")
        let s2 = HttpStatus(299, reasonPhrase: "Custom")
        let s3 = HttpStatus(299, reasonPhrase: "Other")
        assertTrue(s1 == s2)
        // 相等性仅基于状态码，而非原因短语
        assertTrue(s1 == s3)
    }
}
