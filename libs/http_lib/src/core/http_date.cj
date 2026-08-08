package http_lib.core

import std.time.DateTime

/**
 * HTTP 日期格式化与解析（RFC 1123）。
 *
 * 按 RFC 1123 格式格式化日期：
 * Sun, 06 Nov 1994 08:49:37 GMT
 *
 * 解析支持所有三种 HTTP 日期格式（RFC 1123、RFC 850、ANSI C）。
 */



private let DAY_NAMES: Array<String> = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
private let MONTH_NAMES: Array<String> = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]

/**
 * 按 RFC 1123 将 DateTime 格式化为 HTTP 日期字符串。
 *
 * 使用 UTC 时间生成标准化日期字符串，适用于 Date、Last-Modified、
 * Expires 等时间相关响应头。
 *
 * @return 格式化字符串，例如 "Sun, 06 Nov 1994 08:49:37 GMT"
 */
public func formatHttpDate(dt: DateTime): String {
    let ns = dt.nanosecond
    let secs = ns / 1000000000

    let (year, month, day, hour, minute, second, dayOfWeek) = decomposeUtcSeconds(secs)

    let dayName = DAY_NAMES[dayOfWeek]
    let monthName = MONTH_NAMES[month - 1]
    let dayStr = pad2(day)
    let hourStr = pad2(hour)
    let minStr = pad2(minute)
    let secStr = pad2(second)
    "${dayName}, ${dayStr} ${monthName} ${year} ${hourStr}:${minStr}:${secStr} GMT"
}

/**
 * 将当前时间格式化为 HTTP 日期字符串。
 * 等价于 formatHttpDate(DateTime.now())，用于 Date 头部。
 */
public func currentHttpDate(): String {
    formatHttpDate(DateTime.now())
}

/**
 * 解析 HTTP 日期字符串为自纪元起的 Unix 秒数。
 * 若无法解析则返回 None，不抛出异常。
 * 支持所有三种 HTTP 日期格式：RFC 1123、RFC 850、ANSI C。
 */
public func parseHttpDate(s: String): ?Int64 {
    let runes = s.toRuneArray()
    // 最小长度：ANSI C "Sun N 1 0:00:00 2000" 约 21 个字符
    if (runes.size < 20) { return None }

    // 先尝试 RFC 1123："Sun, 06 Nov 1994 08:49:37 GMT"
    if (runes.size >= 29 && runes[3] == r',') {
        return parseRfc1123(s)
    }

    // 再尝试 RFC 850："Sunday, 06-Nov-94 08:49:37 GMT"
    if (runes.size > 6 && runes[6] == r',') {
        return parseRfc850(s)
    }

    // 最后尝试 ANSI C："Sun Nov  6 08:49:37 1994"
    return parseAnsic(s)
}



private func parseRfc1123(s: String): ?Int64 {
    let runes = s.toRuneArray()
    if (runes.size < 29) { return None }
    try {
        let day = parseDigitPair(runes, 5)
        let month = match (monthIndex(String(runes[8..11]))) {
            case Some(m) => m
            case None => return None
        }
        let year = parseDigits(runes, 12, 16)
        let hour = parseDigits(runes, 17, 19)
        let minute = parseDigits(runes, 20, 22)
        let second = parseDigits(runes, 23, 25)
        Some(dateTimeToUnixSeconds(year, month, day, hour, minute, second))
    } catch (_: Exception) {
        None
    }
}

/**
 * 解析 RFC 850 格式："Sunday, 06-Nov-94 08:49:37 GMT"
 * 注意两位年份的世纪推断规则：00-69 → 2000-2069，70-99 → 1970-1999
 */
private func parseRfc850(s: String): ?Int64 {
    let runes = s.toRuneArray()
    if (runes.size < 30) { return None }
    try {
        var commaPos: Int64 = 0
        while (commaPos < runes.size && runes[commaPos] != r',') { commaPos += 1 }
        if (commaPos + 3 >= runes.size) { return None }
        let dayStart = commaPos + 2
        let day = parseDigitPair(runes, dayStart)
        if (runes[dayStart + 2] != r'-') { return None }
        let month = match (monthIndex(String(runes[dayStart + 3..dayStart + 6]))) {
            case Some(m) => m
            case None => return None
        }
        if (runes[dayStart + 6] != r'-') { return None }
        let year2 = parseDigitPair(runes, dayStart + 7)
        let year = if (year2 < 70) { year2 + 2000 } else { year2 + 1900 }
        let hour = parseDigits(runes, dayStart + 10, dayStart + 12)
        let minute = parseDigits(runes, dayStart + 13, dayStart + 15)
        let second = parseDigits(runes, dayStart + 16, dayStart + 18)
        Some(dateTimeToUnixSeconds(year, month, day, hour, minute, second))
    } catch (_: Exception) {
        None
    }
}

/**
 * 解析 ANSI C 格式："Sun Nov  6 08:49:37 1994"
 */
private func parseAnsic(s: String): ?Int64 {
    let runes = s.toRuneArray()
    if (runes.size < 24) { return None }
    try {
        let month = match (monthIndex(String(runes[4..7]))) {
            case Some(m) => m
            case None => return None
        }
        var pos: Int64 = 8
        while (pos < runes.size && runes[pos] == r' ') { pos += 1 }
        let day = if (pos + 2 <= runes.size && runes[pos + 1] != r' ') {
            parseDigitPair(runes, pos)
        } else {
            digitVal(runes[pos])
        }
        if (runes[pos] != r' ' && runes[pos + 1] == r' ') {
            pos += 2
        } else if (runes[pos + 1] != r' ') {
            pos += 3
        } else {
            pos += 2
        }
        let hour = parseDigitPair(runes, pos)
        let minute = parseDigitPair(runes, pos + 3)
        let second = parseDigitPair(runes, pos + 6)
        let yearEnd = if (pos + 13 <= runes.size) { pos + 13 } else { runes.size }
        let year = parseDigits(runes, pos + 9, yearEnd)
        Some(dateTimeToUnixSeconds(year, month, day, hour, minute, second))
    } catch (_: Exception) {
        None
    }
}



/**
 * 将 Unix 秒数（UTC）分解为日期组件。
 *
 * 手动实现因仓颉 DateTime 缺少从 Unix 秒数的构造 API。
 * 返回 (年, 月, 日, 时, 分, 秒, 星期几)，其中月份范围为 1-12。
 */
private func decomposeUtcSeconds(secs: Int64): (Int64, Int64, Int64, Int64, Int64, Int64, Int64) {
    let secsPerDay: Int64 = 86400
    let secsPerHour: Int64 = 3600
    let secsPerMin: Int64 = 60

    var daysSinceEpoch = secs / secsPerDay
    var timeOfDay = secs % secsPerDay
    if (timeOfDay < 0) {
        timeOfDay += secsPerDay
        daysSinceEpoch -= 1
    }

    // 星期几（1970 年 1 月 1 日是星期四 = 4）
    let dayOfWeek = ((daysSinceEpoch + 4) % 7 + 7) % 7

    var year: Int64 = 1970
    while (true) {
        let daysInYear = if (isLeapYear(year)) { Int64(366) } else { Int64(365) }
        if (daysSinceEpoch < daysInYear) { break }
        daysSinceEpoch -= daysInYear
        year += 1
    }

    let monthDays = if (isLeapYear(year)) {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    }

    var month: Int64 = 0
    while (month < 12) {
        if (daysSinceEpoch < monthDays[month]) { break }
        daysSinceEpoch -= monthDays[month]
        month += 1
    }

    let day = daysSinceEpoch + 1
    let hour = timeOfDay / secsPerHour
    let minute = (timeOfDay % secsPerHour) / secsPerMin
    let second = timeOfDay % secsPerMin

    (year, month + 1, day, hour, minute, second, dayOfWeek)
}

/**
 * 将日期组件转换为 Unix 秒数。
 */
private func dateTimeToUnixSeconds(year: Int64, month: Int64, day: Int64, hour: Int64, minute: Int64, second: Int64): Int64 {
    var days: Int64 = 0

    var y: Int64 = 1970
    while (y < year) {
        days += if (isLeapYear(y)) { 366 } else { 365 }
        y += 1
    }

    let monthDays = if (isLeapYear(year)) {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    }
    var m: Int64 = 0
    while (m < month - 1) {
        days += monthDays[m]
        m += 1
    }

    days += day - 1
    days * 86400 + hour * 3600 + minute * 60 + second
}

private func isLeapYear(year: Int64): Bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}



private func monthIndex(name: String): ?Int64 {
    var i: Int64 = 0
    while (i < MONTH_NAMES.size) {
        if (name == MONTH_NAMES[i]) { return Some(i + 1) }
        i += 1
    }
    None
}

private func pad2(value: Int64): String {
    if (value < 10) { "0${value}" } else { "${value}" }
}

private func parseDigitPair(runes: Array<Rune>, start: Int64): Int64 {
    (digitVal(runes[start]) * 10 + digitVal(runes[start + 1]))
}

private func parseDigits(runes: Array<Rune>, start: Int64, end: Int64): Int64 {
    var result: Int64 = 0
    var i = start
    while (i < end) {
        result = result * 10 + digitVal(runes[i])
        i += 1
    }
    result
}

private func digitVal(r: Rune): Int64 {
    if (r >= r'0' && r <= r'9') {
        Int64(UInt32(r) - 48)
    } else {
        throw Exception("invalid digit")
    }
}
