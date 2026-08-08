package http_lib.message
/**
 * HTTP 内容协商（RFC 7231 §5.3）。
 * 处理 Accept、Accept-Encoding、Accept-Language 头部。
 */

import std.collection.{ArrayList, HashMap}
import std.regex.Regex
import http_lib.core.HttpHeaders
import std.sort.sort

/**
 * HTTP 内容协商辅助函数（RFC 7231 Section 5.3）。
 *
 * 支持 Accept、Accept-Encoding、Accept-Charset、Accept-Language 解析
 * 以及质量值（q）加权协商。
 * 包括 Accept-Encoding/Accept-Language/Accept-Charset/Accept 头部解析，
 * 以及基于权重（q 值）的内容选择。支持通配符匹配。
 */

/**
 * A single 内容协商 entry with quality value.
 */
public class NegotiationEntry {
    public let value: String
    public let quality: Float64     // 0.0 - 1.0
    public let params: HashMap<String, String>

    public init(value: String, quality!: Float64 = 1.0, params!: HashMap<String, String> = HashMap<String, String>()) {
        this.value = value
        this.quality = quality
        this.params = params
    }
}

/**
 * 将 Accept-Encoding 头值解析为加权条目。
 *
 * 示例："gzip;q=1.0, deflate;q=0.5, br;q=0.3"
 * 返回按质量降序、然后按特殊性排序的条目。
 */
public func parseAcceptEncoding(header: String): ArrayList<NegotiationEntry> {
    let entries = parseWeightedHeader(header)
    sortNegotiationEntries(entries)
    entries
}

/**
 * 将 Accept 头值解析为加权条目。
 * 示例："text/html, application/xml;q=0.9"
 */
public func parseAccept(header: String): ArrayList<NegotiationEntry> {
    let entries = parseWeightedHeader(header)
    sortNegotiationEntries(entries)
    entries
}

/**
 * 将 Accept-Language 头值解析为加权条目。
 * 示例："en-US, en;q=0.9, fr;q=0.7"
 */
public func parseAcceptLanguage(header: String): ArrayList<NegotiationEntry> {
    let entries = parseWeightedHeader(header)
    sortNegotiationEntries(entries)
    entries
}

/**
 * 将 Accept-Charset 头值解析为加权条目。
 */
public func parseAcceptCharset(header: String): ArrayList<NegotiationEntry> {
    let entries = parseWeightedHeader(header)
    sortNegotiationEntries(entries)
    entries
}

/**
 * Select the best 内容编码 from a list of available encodings
 * 基于 Accept-Encoding 头。
 *
 * 返回选择的编码字符串，无匹配时返回 "identity"。
 */
public func selectContentEncoding(acceptEncoding: ?String, available: Array<String>): String {
    match (acceptEncoding) {
        case Some(ae) =>
            let entries = parseAcceptEncoding(ae)
            for (entry in entries) {
                if (entry.value == "*") { return available[0] } // 通配符：使用第一个可选项
                for (avail in available) {
                    if (entry.value == avail && entry.quality > 0.0) {
                        return avail
                    }
                }
            }
            "identity"
        case None => "identity"
    }
}

/**
 * 基于 Accept 头从可用类型中选择最佳内容类型。
 */
public func selectContentType(acceptHeader: ?String, available: Array<String>): String {
    match (acceptHeader) {
        case Some(ah) =>
            let entries = parseAccept(ah)
            for (entry in entries) {
                if (entry.value == "*/*") { return available[0] }
                // 精确匹配
                for (avail in available) {
                    if (entry.value == avail && entry.quality > 0.0) {
                        return avail
                    }
                }
                // Type/* 匹配（如 text/*）
                if (entry.value.endsWith("/*")) {
                    let prefix = entry.value[..entry.value.size - 2]
                    for (avail in available) {
                        if (avail.startsWith(prefix) && entry.quality > 0.0) {
                            return avail
                        }
                    }
                }
            }
            available[0]  // 默认使用第一个可选项
        case None => available[0]
    }
}

// ---- 内部 ----

private func parseWeightedHeader(header: String): ArrayList<NegotiationEntry> {
    let entries = ArrayList<NegotiationEntry>()
    let parts = splitByComma(header)
    for (part in parts) {
        let trimmed = part.trimAscii()
        if (trimmed.size == 0) { continue }
        let subParts = trimmed.split(";")
        if (subParts.size == 0) { continue }

        var quality: Float64 = 1.0
        var params = HashMap<String, String>()
        var i: Int64 = 1
        while (i < subParts.size) {
            let paramParts = subParts[i].split("=", 2)
            let key = if (paramParts.size > 0) { paramParts[0].trimAscii() } else { "" }
            let val = if (paramParts.size > 1) { paramParts[1].trimAscii() } else { "" }
            if (key == "q" && paramParts.size > 1) {
                try {
                    quality = parseFloat(paramParts[1])
                } catch (_: Exception) { quality = 1.0 }
            } else if (key.size > 0) {
                params[key] = val
            }
            i += 1
        }

        let value = subParts[0].trimAscii()
        if (value.size > 0) {
            entries.add(NegotiationEntry(value, quality: quality, params: params))
        }
    }
    entries
}

private func sortNegotiationEntries(entries: ArrayList<NegotiationEntry>): Unit {
    let arr = entries.toArray()
    sort(arr, by: {a: NegotiationEntry, b: NegotiationEntry =>
        if (a.quality > b.quality) { Ordering.LT }
        else if (a.quality < b.quality) { Ordering.GT }
        else { Ordering.EQ }
    })
    entries.clear()
    for (e in arr) { entries.add(e) }
}

/// 按逗号分割字符串（使用 std.regex）
private let COMMA_RE = Regex(",")

private func splitByComma(s: String): Array<String> {
    COMMA_RE.split(s)
}

private func parseFloat(s: String): Float64 {
    var result: Float64 = 0.0
    var decimalPart: Float64 = 0.0
    var decimalDiv: Float64 = 1.0
    var inDecimal = false
    let bytes = s.toArray()
    for (b in bytes) {
        if (b == b'.') {
            inDecimal = true
        } else if (b >= b'0' && b <= b'9') {
            let digit = Float64(b - b'0')
            if (inDecimal) {
                decimalDiv *= 10.0
                decimalPart = decimalPart * 10.0 + digit
            } else {
                result = result * 10.0 + digit
            }
        }
    }
    result + decimalPart / decimalDiv
}
