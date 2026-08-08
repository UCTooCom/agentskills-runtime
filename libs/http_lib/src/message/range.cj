package http_lib.message

import std.collection.ArrayList
import std.unicode.*
import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.buffer.ByteBuffer
import http_lib.connection.{secureRandom}

/**
 * HTTP 范围请求支持（RFC 7233）。
 *
 * 提供 Range 头的解析以及 Content-Range
 * 响应头和 multipart/byteranges 响应体的构建。
 * 提供 Range 头的解析（suffix/start-end/open-end）以及
 * Content-Range 响应头的构建和 multipart/byteranges 响应体的组装。
 * 包含范围轰炸保护（每个请求最多 2 倍内容大小）。
 */

/**
 * 单个字节范围规格。
 */
public class ByteRange {
    public let start: Int64
    public let end: Int64    // -1 表示"到末尾"
    public let suffix: Bool  // 是否为后缀范围（例如 -500）

    public init(start: Int64, end!: Int64 = -1, suffix!: Bool = false) {
        this.start = start
        this.end = end
        this.suffix = suffix
    }
}

/**
 * 解析 Range 头值（如 "bytes=0-499"、"bytes=-500"、"bytes=0-499,1000-1499"）。
 * 返回解析后的范围集合，如果头部无效则返回空。
 */
public func parseRange(rangeHeader: String, totalSize: Int64): ArrayList<ByteRange> {
    let result = ArrayList<ByteRange>()
    let lowered = toLowerRunes(rangeHeader)
    if (!lowered.startsWith("bytes=")) { return result }

    // 提取 "bytes=" 之后的部分
    let runes = rangeHeader.toRuneArray()
    var i: Int64 = 6  // 跳过 "bytes="
    while (i < runes.size) {
        // 跳过空格
        while (i < runes.size && (runes[i] == r' ' || runes[i] == r'\t')) { i += 1 }
        if (i >= runes.size) { break }

        // 解析范围规格
        if (runes[i] == r'-') {
            // 后缀范围：-N
            i += 1
            var suffixLen: Int64 = 0
            while (i < runes.size && runes[i] >= r'0' && runes[i] <= r'9') {
                suffixLen = suffixLen * 10 + Int64(UInt32(runes[i]) - 48)
                i += 1
            }
            if (suffixLen > totalSize) { suffixLen = totalSize }
            result.add(ByteRange(totalSize - suffixLen, end: totalSize - 1, suffix: true))
        } else {
            // Start-End 或 Start-
            var start: Int64 = 0
            while (i < runes.size && runes[i] >= r'0' && runes[i] <= r'9') {
                start = start * 10 + Int64(UInt32(runes[i]) - 48)
                i += 1
            }
            if (i < runes.size && runes[i] == r'-') {
                i += 1
                if (i < runes.size && runes[i] >= r'0' && runes[i] <= r'9') {
                    var end: Int64 = 0
                    while (i < runes.size && runes[i] >= r'0' && runes[i] <= r'9') {
                        end = end * 10 + Int64(UInt32(runes[i]) - 48)
                        i += 1
                    }
                    if (end >= totalSize) { end = totalSize - 1 }
                    if (start <= end) {
                        result.add(ByteRange(start, end: end))
                    }
                } else {
                    // 开放式：start-
                    result.add(ByteRange(start, end: totalSize - 1))
                }
            }
        }
        // 跳过逗号
        while (i < runes.size && (runes[i] == r',' || runes[i] == r' ')) { i += 1 }
    }

    // 范围轰炸保护： reject requests where the sum of all
    // 请求的范围超出总大小的合理倍数。
    // 根据 RFC 7233，服务器可以合并/拒绝过多的范围
    if (result.size > 1) {
        var totalRequested: Int64 = 0
        for (r in result) {
            totalRequested += r.end - r.start + 1
        }
        // 允许多范围请求最多 2 倍内容大小
        var maxAllowed = totalSize * 2
        if (maxAllowed < totalSize) { maxAllowed = totalSize }  // 溢出保护
        if (totalRequested > maxAllowed) {
            // 返回空以在调用方触发 416
            return ArrayList<ByteRange>()
        }
    }

    result
}

/**
 * 从完整数据中提取范围指定的字节。
 */
public func extractRange(data: Array<UInt8>, range: ByteRange): Array<UInt8> {
    let end = if (range.end < 0) { data.size - 1 } else { range.end }
    if (range.start < 0 || range.start >= data.size) { return [] }
    if (end < range.start || end >= data.size) { return [] }
    let length = end - range.start + 1
    let result = Array<UInt8>(length, repeat: 0)
    var i: Int64 = 0
    while (i < length) { result[i] = data[range.start + i]; i += 1 }
    result
}

/**
 * 构建 Content-Range 头值（如 "bytes 0-499/1000"）。
 */
public func buildContentRange(range: ByteRange, totalSize: Int64): String {
    if (range.suffix) {
        "bytes ${range.start}-${totalSize - 1}/${totalSize}"
    } else {
        let e = if (range.end < 0) { totalSize - 1 } else { range.end }
        "bytes ${range.start}-${e}/${totalSize}"
    }
}

/**
 * 为多个范围构建 multipart/byteranges 响应体。
 */
public func buildMultipartRanges(data: Array<UInt8>, ranges: ArrayList<ByteRange>, contentType: String, totalSize: Int64): Array<UInt8> {
    if (ranges.size == 0) { return [] }
    let randBytes = secureRandom(16)
    // 将随机字节编码为小写十六进制作为安全的边界字符串
    let hexChars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
    var boundary = ""
    for (b in randBytes) {
        boundary = boundary + hexChars[Int64(b) / 16] + hexChars[Int64(b) % 16]
    }
    boundary = "httpLibBoundary_${boundary}"
    let crlf = "\r\n"

    // 计算总大小
    var totalLen: Int64 = 0
    for (range in ranges) {
        let partBody = extractRange(data, range)
        let partHeader = "--${boundary}${crlf}Content-Type: ${contentType}${crlf}Content-Range: ${buildContentRange(range, totalSize)}${crlf}${crlf}"
        let partHeaderBytes = unsafe { partHeader.rawData() }
        totalLen += partHeaderBytes.size + partBody.size + crlf.size
    }
    let endMarker = "--${boundary}--${crlf}"
    let endBytes = unsafe { endMarker.rawData() }
    totalLen += endBytes.size

    let result = Array<UInt8>(totalLen, repeat: 0)
    var offset: Int64 = 0
    for (range in ranges) {
        let partBody = extractRange(data, range)
        let partHeader = "--${boundary}${crlf}Content-Type: ${contentType}${crlf}Content-Range: ${buildContentRange(range, totalSize)}${crlf}${crlf}"
        let hBytes = unsafe { partHeader.rawData() }
        var j: Int64 = 0
        while (j < hBytes.size) { result[offset + j] = hBytes[j]; j += 1 }
        offset += hBytes.size
        j = 0
        while (j < partBody.size) { result[offset + j] = partBody[j]; j += 1 }
        offset += partBody.size
        // CRLF（回车换行 \r\n）
        result[offset] = b'\r'; offset += 1
        result[offset] = b'\n'; offset += 1
    }
    var j: Int64 = 0
    while (j < endBytes.size) { result[offset + j] = endBytes[j]; j += 1 }
    result
}

/**
 * 为支持范围的响应构建 Accept-Ranges 头值。
 */
public func acceptRangesHeader(): String {
    "bytes"
}

private func toLowerRunes(s: String): String {
    s.toLower()
}
