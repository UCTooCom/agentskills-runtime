package http_lib.message
/**
 * Retry-After 头部解析（RFC 7231 §7.1.3）。
 * 支持 HTTP 日期和延迟秒数两种格式。
 */

import std.time.DateTime
import std.unicode.*
import std.convert.Parsable
import http_lib.core.{HttpHeaders, parseHttpDate, formatHttpDate}

/**
 * 解析 Retry-After 头值。
 *
 * 支持两种格式（RFC 7231 §7.1.3）：
 *   Retry-After: <HTTP-date>
 *   Retry-After: <delta-seconds>
 *
 * @param headers HTTP 头部
 * @return 如果存在且可解析，返回建议的等待时长（秒）；否则返回 None
 * 支持两种格式：HTTP-Date 格式（如 "Wed, 21 Oct 2015 07:28:00 GMT"）
 * 和延迟秒数格式（如 "120"）。返回重试时间点。
 */
public func parseRetryAfter(headers: HttpHeaders): ?Int64 {
    match (headers.get("retry-after")) {
        case Some(value) =>
            let trimmed = value.trimAscii()
            // 尝试解析为 delta-seconds（纯数字开头）
            let runes = trimmed.toRuneArray()
            if (runes.size > 0 && ((runes[0] >= r'0' && runes[0] <= r'9') || runes[0] == r'-')) {
                try {
                    let seconds = Int64.parse(trimmed)
                    if (seconds < 0) { return Some(0) }
                    return Some(seconds)
                } catch (_: Exception) {
                    return None
                }
            }
            // 尝试解析为 HTTP-date
            try {
                let ts = parseHttpDate(trimmed)
                match (ts) {
                    case Some(retryTs) =>
                        let nowStr = formatHttpDate(DateTime.now())
                        match (parseHttpDate(nowStr)) {
                            case Some(nowTs) =>
                                let delta = retryTs - nowTs
                                if (delta < 0) { return Some(0) }
                                return Some(delta)
                            case None => return None
                        }
                    case None => return None
                }
            } catch (_: Exception) {
                return None
            }
        case None => None
    }
}
