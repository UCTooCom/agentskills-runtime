package http_lib.utils

import std.collection.ArrayList

/**
 * HTTP 协议解析的共享字节搜索工具函数。
 * 从 request_parser、response_parser、chunked_decoder 和 body 模块集中而来。
 */

/**
 * 查找 HTTP 响应头结束标记（\r\n\r\n）。
 */
public func findHeaderEnd(data: Array<UInt8>, length: Int64, start!: Int64 = 0): Int64 {
    var i = max(start, 0)
    while (i + 3 < length) {
        if (data[i + 3] == b'\n' &&
            data[i] == b'\r' && data[i + 1] == b'\n' && data[i + 2] == b'\r') {
            return i + 4
        }
        i++
    }
    -1
}

/**
 * 从 `start` 开始查找数据中的 \r\n。
 */
public func findCrlf(data: Array<UInt8>, length: Int64, start!: Int64 = 0): Int64 {
    var i = max(start, 0)
    while (i + 1 < length) {
        if (data[i] == b'\r' && data[i + 1] == b'\n') {
            return i
        }
        i++
    }
    -1
}

/**
 * 在某个位置或之后查找行结束符。
 * 优先查找 \r\n，若未找到则回退到纯 \n（兼容 HTTP/1.0 老旧客户端）。
 * 返回 (pos, hasCr)，其中 hasCr 表示是否找到 CRLF。
 */
public func findLineEnd(data: Array<UInt8>, length: Int64, start!: Int64 = 0): (Int64, Bool) {
    var i = max(start, 0)
    while (i + 1 < length) {
        if (data[i] == b'\r' && data[i + 1] == b'\n') {
            return (i, true)
        }
        i++
    }
    // 回退到纯 LF
    i = max(start, 0)
    while (i < length) {
        if (data[i] == b'\n') {
            return (i, false)
        }
        i++
    }
    (-1, false)
}

/**
 * 查找头部结束标记（\r\n\r\n 或 \n\n）。
 */
public func findHeaderEndOrLf(data: Array<UInt8>, length: Int64, start!: Int64 = 0): Int64 {
    // 先尝试标准 CRLF 结束
    let crlfEnd = findHeaderEnd(data, length, start: start)
    if (crlfEnd >= 0) { return crlfEnd }
    // 尝试纯 LF 结束
    var i = max(start, 0)
    while (i + 2 < length) {
        if (data[i] == b'\n' && data[i + 1] == b'\n') {
            // 跳过可能的 \r 之前的 \n
            if (i > 0 && data[i - 1] == b'\r') { i -= 1 }
            return i + 2
        }
        if (data[i] == b'\n' && data[i + 1] == b'\r' && data[i + 2] == b'\n') {
            return i + 3
        }
        i++
    }
    -1
}

/**
 * 在某个位置或之后查找 \r\n（为清晰起见，findCrlf 的别名）。
 */
public func findCrlfAt(data: Array<UInt8>, start: Int64, end: Int64): Int64 {
    var i = max(start, 0)
    while (i + 1 < end) {
        if (data[i] == b'\r' && data[i + 1] == b'\n') {
            return i
        }
        i++
    }
    -1
}

/**
 * 在范围 [start, end) 中查找特定字节。
 */
public func findByte(data: Array<UInt8>, start: Int64, end: Int64, target: UInt8): Int64 {
    var i = max(start, 0)
    while (i < end) {
        if (data[i] == target) { return i }
        i++
    }
    -1
}

/**
 * 在某个位置或之后查找特定字节。
 */
public func findByteAt(data: Array<UInt8>, start: Int64, end: Int64, target: UInt8): Int64 {
    findByte(data, start, end, target)
}

/**
 * 跳过空格 (0x20) 和水平制表符。
 */
public func skipSpaces(data: Array<UInt8>, start: Int64, end: Int64): Int64 {
    var i = max(start, 0)
    while (i < end && (data[i] == b' ' || data[i] == b'\t')) { i++ }
    i
}

/**
 * 去除尾部空白。
 */
public func trimEnd(data: Array<UInt8>, start: Int64, end: Int64): Int64 {
    var i = end
    while (i > start && (data[i - 1] == b' ' || data[i - 1] == b'\t')) { i-- }
    i
}

/**
 * 在范围内查找字节模式。
 */
public func findBytesAt(data: Array<UInt8>, start: Int64, end: Int64, pattern: Array<UInt8>): Int64 {
    var i = max(start, 0)
    while (i + pattern.size <= end) {
        var matched = true
        var j: Int64 = 0
        while (j < pattern.size) {
            if (data[i + j] != pattern[j]) {
                matched = false
                break
            }
            j++
        }
        if (matched) { return i }
        i++
    }
    -1
}

/**
 * 规范化行结束符：将纯 \n（无前置 \r）替换为 \r\n。
 * 兼容 HTTP/1.0 老旧客户端使用裸 LF 的行为（RFC 7230 §3.5 废弃说明）。
 * 返回新的字节数组，不修改原始输入。
 */
public func normalizeLineEndings(data: Array<UInt8>): Array<UInt8> {
    // 统计需要插入的 \r 数量
    var extraCount: Int64 = 0
    var i: Int64 = 0
    while (i < data.size) {
        if (data[i] == b'\n' && (i == 0 || data[i - 1] != b'\r')) {
            extraCount += 1
        }
        i++
    }
    if (extraCount == 0) { return data }
    var result = Array<UInt8>(data.size + extraCount, repeat: 0u8)
    var ri: Int64 = 0
    i = 0
    while (i < data.size) {
        if (data[i] == b'\n' && (i == 0 || data[i - 1] != b'\r')) {
            result[ri] = b'\r'; ri += 1
        }
        result[ri] = data[i]; ri += 1
        i++
    }
    result
}

/**
 * 检查字节数组是否包含不区分大小写的子字符串。
 * 用于头部值检查（例如：chunked、close）。
 */
public func containsIgnoreCase(data: Array<UInt8>, start: Int64, end: Int64, needle: Array<UInt8>): Bool {
    var i = max(start, 0)
    while (i + needle.size <= end) {
        var matched = true
        var j: Int64 = 0
        while (j < needle.size) {
            let a = data[i + j]
            let b = needle[j]
            // 大小写不敏感 ASCII 比较
            let an = if (a >= b'A' && a <= b'Z') { a + 32 } else { a }
            let bn = if (b >= b'A' && b <= b'Z') { b + 32 } else { b }
            if (an != bn) {
                matched = false
                break
            }
            j++
        }
        if (matched) { return true }
        i++
    }
    false
}
