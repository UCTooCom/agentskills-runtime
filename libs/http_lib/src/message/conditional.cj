package http_lib.message
/**
 * HTTP 条件请求支持（RFC 7232）。
 * 处理 If-Modified-Since、If-None-Match、If-Match、If-Unmodified-Since。
 */

import std.collection.ArrayList
import jinguissl_core.crypto.digest.{sha256, bytesToHexLower}
import http_lib.core.{HttpHeaders, HttpStatus, parseHttpDate}

/**
 * 条件请求辅助函数（RFC 7232 和 RFC 7233）。
 *
 * 支持 ETag 生成和完整的条件头评估：
 * - If-Match / If-None-Match / If-Modified-Since / If-Unmodified-Since
 *   - If-Range（用于范围请求，RFC 7233 Section 3.2）
 * 支持 If-Match、If-None-Match、If-Modified-Since、If-Unmodified-Since、
 * If-Range 五种条件请求头部的判断逻辑（RFC 7232 和 RFC 7233）。
 */

/**
 * 使用 SHA-256 从字节生成强 ETag 值。
 * 生成十六进制编码的内容哈希，提供强抗碰撞性
 * suitable for production 条件请求 validation.
 */
public func generateETag(data: Array<UInt8>): String {
    let digest = sha256(data)
    "\"${bytesToHexLower(digest)}\""
}

/**
 * 生成弱 ETag（W/"..."）。
 */
public func generateWeakETag(data: Array<UInt8>): String {
    "W/${generateETag(data)}"
}

/**
 * Evaluate 条件请求 headers and return the appropriate status.
 *
 * 返回值：
 *   - Some(PRECONDITION_FAILED) 若 If-Match 或 If-Unmodified-Since 失败
 *   - Some(NOT_MODIFIED) 若 If-None-Match 或 If-Modified-Since 匹配
 *   - None 若无条件头适用（正常继续）
 */
public func evaluateConditional(
    headers: HttpHeaders,
    etag: String,
    lastModified!: ?String = None
): Option<HttpStatus> {
    // If-Match：必须匹配
    match (headers.get("if-match")) {
        case Some(im) =>
            if (im != "*" && im != etag) {
                return Some(HttpStatus.PRECONDITION_FAILED)
            }
        case None => ()
    }

    // If-None-Match：不得匹配（GET/HEAD 返回 304）
    match (headers.get("if-none-match")) {
        case Some(inm) =>
            if (inm == "*" || inm == etag) {
                return Some(HttpStatus.NOT_MODIFIED)
            }
        case None => ()
    }

    // If-Modified-Since：按数值比较 HTTP 日期
    match (lastModified) {
        case Some(lm) =>
            match (headers.get("if-modified-since")) {
                case Some(ims) =>
                    if (httpDateLessOrEqual(lm, ims)) {
                        return Some(HttpStatus.NOT_MODIFIED)
                    }
                case None => ()
            }
        case None => ()
    }

    // If-Unmodified-Since：资源在给定日期后不得被修改
    // 根据 RFC 7232 第 3.4 节：如果 lastModified > ifUnmodifiedSince 则为 false (412)
    match (headers.get("if-unmodified-since")) {
        case Some(ius) =>
            match (lastModified) {
                case Some(lm) =>
                    if (httpDateGreater(lm, ius)) {
                        return Some(HttpStatus.PRECONDITION_FAILED)
                    }
                case None => ()
            }
        case None => ()
    }

    // If-Range：评估应发送部分还是完整响应
    match (headers.get("if-range")) {
        case Some(ir) =>
            if (ir.startsWith("\"") || ir.startsWith("W/\"")) {
                // ETag 比较
                if (ir != etag) {
                    return Some(HttpStatus.OK)  // 标记：发送完整响应
                }
            } else {
                // HTTP-date 比较
                match (lastModified) {
                    case Some(lm) =>
                        if (!httpDatesEqual(ir, lm)) {
                            return Some(HttpStatus.OK)  // 标记：发送完整响应
                        }
                    case None => ()
                }
            }
        case None => ()
    }

    None  // 无条件匹配——正常处理
}

/**
 * 评估 If-Range 头（RFC 7233 Section 3.2）。
 *
 * If-Range allows a client to make a 范围请求 conditional:
 * 未变更时，服务器发送部分内容；
 * 若已变化，服务器发送完整内容。
 *
 * 返回值：
 * - true：范围应被处理（资源未变更）
 * - false：发送完整响应（资源已变更）
 */
public func evaluateIfRange(
    headers: HttpHeaders,
    etag: String,
    lastModified!: ?String = None
): Bool {
    match (headers.get("if-range")) {
        case Some(ir) =>
            // If-Range 可以是 ETag 或 HTTP 日期
            if (ir.startsWith("\"") || ir.startsWith("W/\"")) {
                // ETag 比较
                ir == etag
            } else {
                // HTTP-date 比较
                match (lastModified) {
                    case Some(lm) => httpDatesEqual(ir, lm)
                    case None => false
                }
            }
        case None => true  // 没有 If-Range——始终处理范围请求
    }
}

/**
 * 在响应上设置标准 ETag 和 Last-Modified 头。
 */
public func setConditionalHeaders(headers: HttpHeaders, data: Array<UInt8>, lastModified!: ?String = None): Unit {
    headers.set("ETag", generateETag(data))
    match (lastModified) {
        case Some(lm) => headers.set("Last-Modified", lm)
        case None => ()
    }
}

/**
 * 使用数值时间戳比较两个 HTTP 日期字符串是否相等。
 * 若任一日期无法解析则回退到字符串比较。
 */
public func httpDatesEqual(a: String, b: String): Bool {
    if (a == b) { return true }
    let secsA = parseHttpDate(a)
    let secsB = parseHttpDate(b)
    match (secsA) {
        case Some(sa) =>
            match (secsB) {
                case Some(sb) => sa == sb
                case None => normalizeHttpDateForComparison(a) == normalizeHttpDateForComparison(b)
            }
        case None => normalizeHttpDateForComparison(a) == normalizeHttpDateForComparison(b)
    }
}

/**
 * 若日期字符串 a 表示的时间早于或等于 b 则返回 true。
 * 使用 Unix 时间戳数值比较。
 */
public func httpDateLessOrEqual(a: String, b: String): Bool {
    let secsA = parseHttpDate(a)
    let secsB = parseHttpDate(b)
    match (secsA) {
        case Some(sa) =>
            match (secsB) {
                case Some(sb) => sa <= sb
                case None => false
            }
        case None => false
    }
}

/**
 * 若日期字符串 a 表示的时间晚于 b 则返回 true。
 * 使用 Unix 时间戳数值比较。
 */
public func httpDateGreater(a: String, b: String): Bool {
    let secsA = parseHttpDate(a)
    let secsB = parseHttpDate(b)
    match (secsA) {
        case Some(sa) =>
            match (secsB) {
                case Some(sb) => sa > sb
                case None => false
            }
        case None => false
    }
}

private func normalizeHttpDateForComparison(s: String): String {
    let runes = s.toRuneArray()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r',') { start = i + 1; break }
        if (runes[i] == r' ' && i >= 3) { start = i; break }
        i += 1
    }
    while (start < runes.size && (runes[start] == r' ' || runes[start] == r'\t')) { start += 1 }
    var end = runes.size
    var j = runes.size - 1
    while (j > start) {
        if (runes[j] == r'G' && j + 2 < runes.size && runes[j + 1] == r'M' && runes[j + 2] == r'T') {
            end = j
            while (end > start && runes[end - 1] == r' ') { end -= 1 }
            break
        }
        j -= 1
    }
    if (end <= start) { return s }
    String(runes[start..end])
}
