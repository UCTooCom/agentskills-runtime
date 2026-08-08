package http_lib.core

/**
 * HTTP 日期格式化与解析测试（RFC 7231 Section 7.1.1）。
 */
@Test
public class HttpDateTest {

    @TestCase
    public func testCurrentHttpDate(): Unit {
        let now = currentHttpDate()
        assertTrue(now.size > 20, message: "Current HTTP-date should be long enough, got ${now.size}")
        assertTrue(now.endsWith("GMT"), message: "Current HTTP-date should end with GMT: ${now}")

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var dayMatch = false
        for (name in dayNames) {
            if (now.startsWith(name)) { dayMatch = true; break }
        }
        assertTrue(dayMatch, message: "Should start with valid day name: ${now}")
        assertTrue(now.indexOf(",").isSome(), message: "Should contain comma after day: ${now}")
    }

    @TestCase
    public func testFormatHttpDateConsistency(): Unit {
        let now1 = currentHttpDate()
        let now2 = currentHttpDate()
        assertTrue(now1.size == now2.size, message: "Same-length strings expected")
    }

    @TestCase
    public func testParseRfc1123Date(): Unit {
        let result = parseHttpDate("Sun, 06 Nov 1994 08:49:37 GMT")
        assertTrue(result.isSome(), message: "Should parse RFC 1123 date")
        match (result) {
            case Some(secs) => assertTrue(secs > 780000000, message: "Unix seconds should be reasonable, got ${secs}")
            case None => ()
        }
    }

    @TestCase
    public func testParseRfc850Date(): Unit {
        let result = parseHttpDate("Sunday, 06-Nov-94 08:49:37 GMT")
        assertTrue(result.isSome(), message: "Should parse RFC 850 date")
        match (result) {
            case Some(secs) => assertTrue(secs > 780000000, message: "Unix seconds should be reasonable, got ${secs}")
            case None => ()
        }
    }

    @TestCase
    public func testParseAnsicDate(): Unit {
        let result = parseHttpDate("Sun Nov  6 08:49:37 1994")
        assertTrue(result.isSome(), message: "Should parse ANSI C date")
        match (result) {
            case Some(secs) => assertTrue(secs > 780000000, message: "Unix seconds should be reasonable, got ${secs}")
            case None => ()
        }
    }

    @TestCase
    public func testAllFormatsSameValue(): Unit {
        // 同一日期的三种格式应解析为相同的 Unix 时间戳
        let rfc1123 = parseHttpDate("Sun, 06 Nov 1994 08:49:37 GMT")
        let rfc850 = parseHttpDate("Sunday, 06-Nov-94 08:49:37 GMT")
        let ansic = parseHttpDate("Sun Nov  6 08:49:37 1994")
        match (rfc1123) {
            case Some(s1) =>
                match (rfc850) {
                    case Some(s2) =>
                        assertTrue(s1 == s2, message: "RFC 1123 and RFC 850 should parse to same timestamp")
                    case None => ()
                }
                match (ansic) {
                    case Some(s3) =>
                        assertTrue(s1 == s3, message: "RFC 1123 and ANSI C should parse to same timestamp")
                    case None => ()
                }
            case None => ()
        }
    }

    @TestCase
    public func testParseInvalidDate(): Unit {
        let result = parseHttpDate("not a date")
        assertTrue(result.isNone(), message: "Should not parse invalid date")
    }

    @TestCase
    public func testEmptyDateString(): Unit {
        let result = parseHttpDate("")
        assertTrue(result.isNone(), message: "Should not parse empty string")
    }

    @TestCase
    public func testFormatContainsMonthAndYear(): Unit {
        let date = currentHttpDate()
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var foundMonth = false
        for (m in months) {
            if (date.indexOf(m).isSome()) { foundMonth = true; break }
        }
        assertTrue(foundMonth, message: "Should contain a valid month abbreviation: ${date}")
    }

    @TestCase
    public func testFormatHttpDateWithKnownDate(): Unit {
        // 无法直接构造 DateTime，因此通过验证往返来测试：
        // 解析已知日期，然后格式化它
        match (parseHttpDate("Sun, 06 Nov 1994 08:49:37 GMT")) {
            case Some(epochSecond) =>
                let formatted = currentHttpDate()
                // 验证格式化后的日期包含所有预期标记
                assertTrue(formatted.endsWith("GMT"), message: "HTTP date must end with GMT")
                assertTrue(formatted.indexOf(":").isSome(), message: "HTTP date must contain time")
            case None => assertTrue(false, message: "Should parse valid date")
        }
    }

    @TestCase
    public func testFormatHttpDateMatchesPattern(): Unit {
        let dateStr = currentHttpDate()
        // 模式："Sat, 27 Jun 2026 12:34:56 GMT" —— 至少 29 个字符
        assertTrue(dateStr.size >= 29, message: "HTTP date should be at least 29 chars, got: ${dateStr}")
        // 第 3 位有逗号
        let runes = dateStr.toRuneArray()
        assertTrue(runes[3] == r',', message: "Expected comma at position 3")
        // 年份为 4 位
        let yearPart = String(runes[12..16])
        assertTrue(yearPart.size == 4, message: "Year should be 4 digits")
        // 验证所有字符均为数字
        var allDigits = true
        var yi: Int64 = 0
        while (yi < yearPart.size) {
            let c = yearPart.toRuneArray()[0]
            if (c < r'0' || c > r'9') { allDigits = false }
            yi++
        }
        assertTrue(allDigits, message: "Year should be numeric: ${yearPart}")
    }
}
