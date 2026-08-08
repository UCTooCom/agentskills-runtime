package http_lib.message
/**
 * HTTP 请求体解析工具：URL 编码表单、JSON、Multipart 表单。
 * 包含 DoS 防护限制（最大部分数、部分大小、总大小）。
 */

import kaca_json.{JSON, JsonValue}
import std.collection.{ArrayList, HashMap}
import http_lib.core.{HttpHeaders, ProtocolException}
import http_lib.buffer.ByteBuffer
import http_lib.connection.secureRandom32
import http_lib.utils.{findHeaderEnd, findCrlf, findByte}

/**
 * URL 编码或 multipart 请求体中的表单字段。
 */
public class FormField {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

/**
 * 多部分表单中的文件或字段。
 */
public class MultipartField {
    public let name: String
    public let fileName: String
    public let headers: HttpHeaders
    public let data: Array<UInt8>

    public init(name: String, fileName!: String = "", headers!: HttpHeaders = HttpHeaders(), data!: Array<UInt8> = []) {
        this.name = name
        this.fileName = fileName
        this.headers = headers
        this.data = data
    }

    public func asString(): String {
        unsafe { String.withRawData(data) }
    }
}

/**
 * 不同内容类型的主解析器。
 */
/**
 * 默认多部分解析限制，防止 DoS 攻击。
 * 这些限制约束多部分请求主体中部分的数量和大小。
请求体读取限制。
 */
public let DEFAULT_MAX_MULTIPART_PARTS: Int64 = 64        // 最大部分数量
public let DEFAULT_MAX_MULTIPART_PART_SIZE: Int64 = 10485760  // 每部分最大 10 MB
public let DEFAULT_MAX_MULTIPART_TOTAL_SIZE: Int64 = 33554432 // 总计最大 32 MB

public class BodyParser {

    /**
     * 解析 URL 编码的表单主体（application/x-www-form-urlencoded）。
     * 按 & 分割键值对，按 = 分割键和值，对键值进行 URL 解码。
     */
    public static func parseUrlEncoded(body: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        if (body.isEmpty()) { return result }
        // 直接操作裸字节，避免 split() 产生的中间字符串分配
        let bytes = unsafe { body.rawData() }
        let len = bytes.size
        var pairStart: Int64 = 0

        while (pairStart < len) {
            // 查找下一个 &
            var ampPos = pairStart
            while (ampPos < len && bytes[ampPos] != b'&') { ampPos++ }

            if (ampPos > pairStart) {
                // 在键值对内查找 =
                var eqPos = pairStart
                while (eqPos < ampPos && bytes[eqPos] != b'=') { eqPos++ }

                let key = if (eqPos > pairStart) { urlDecodeRaw(bytes, pairStart, eqPos) } else { "" }
                let value = if (ampPos > eqPos + 1) { urlDecodeRaw(bytes, eqPos + 1, ampPos) } else { "" }
                result[key] = value
            }

            pairStart = ampPos + 1
        }
        result
    }

    public static func parseJson(body: String): JsonValue {
        JSON.parse(body.toArray())
    }

    /**
      * 使用可配置限制解析 multipart/form-data 主体。
     * 限制可防止过多或过大部分导致的 DoS 攻击。
     *
     * @param body 原始 multipart 主体字节
     * @param boundary multipart 边界字符串
     * @param maxParts 最大部分数（默认：64）
    /**
     * 解析 JSON 格式的主体（application/json）。
     * 使用 kaca_json 库进行解析。
     */
     * @param maxPartSize 单个部分的最大字节数（默认：10 MB）
     * @param maxTotalSize 处理的最大总主体大小（默认：32 MB）
     */
    public static func parseMultipart(
        body: Array<UInt8>,
        boundary: String,
        maxParts!: Int64 = DEFAULT_MAX_MULTIPART_PARTS,
        maxPartSize!: Int64 = DEFAULT_MAX_MULTIPART_PART_SIZE,
        maxTotalSize!: Int64 = DEFAULT_MAX_MULTIPART_TOTAL_SIZE
    ): HashMap<String, MultipartField> {
        let result = HashMap<String, MultipartField>()
        if (body.size == 0 || boundary.isEmpty()) { return result }
        if (body.size > maxTotalSize) {
            throw ProtocolException("multipart body exceeds maximum total size (${maxTotalSize} bytes)")
        }
        let boundaryMarker = "--${boundary}"
        let boundaryBytes = unsafe { boundaryMarker.rawData() }
        var pos: Int64 = 0
        let len = body.size
        var partCount: Int64 = 0

        while (pos < len) {
            let boundaryStart = findBytesAt(body, pos, len, boundaryBytes)
            if (boundaryStart < 0) { break }

            pos = boundaryStart + boundaryBytes.size
            if (pos + 1 < len && body[pos] == b'\r' && body[pos + 1] == b'\n') {
                pos += 2
            }

            if (boundaryStart + boundaryBytes.size < len &&
                body[boundaryStart + boundaryBytes.size] == b'-') {
                break
            }

            // 强制执行最大部分数限制
            partCount += 1
            if (partCount > maxParts) {
                throw ProtocolException("multipart body exceeds maximum number of parts (${maxParts})")
            }

            let nextBoundary = findBytesAt(body, pos, len, boundaryBytes)
            let partEnd = if (nextBoundary >= 0) { nextBoundary } else { len }

            let headerEnd = findHeaderEnd(body, partEnd, start: pos)
            if (headerEnd < 0) { break }

            let partHeaders = parseHeadersAt(body, pos, headerEnd - 2)

            let contentStart = headerEnd
            let contentEnd = if (partEnd >= 2 && body[partEnd - 2] == b'\r' && body[partEnd - 1] == b'\n') {
                partEnd - 2
            } else { partEnd }

            let fieldName = extractFieldName(partHeaders)
            let fileName = extractFileName(partHeaders)

            if (fieldName.size > 0) {
                let contentLen = contentEnd - contentStart
                // 强制执行最大部分大小限制
                if (contentLen > maxPartSize) {
                    throw ProtocolException("multipart part '${fieldName}' exceeds maximum part size (${maxPartSize} bytes)")
                }
                let contentData = if (contentLen > 0) {
                    let out = Array<UInt8>(contentLen, repeat: 0)
                    var ci: Int64 = 0
                    while (ci < contentLen) {
                        out[ci] = body[contentStart + ci]
                        ci++
                    }
                    out
                } else { Array<UInt8>(0, repeat: 0) }

                let field = MultipartField(fieldName, fileName: fileName, headers: partHeaders, data: contentData)
                result[fieldName] = field
            }
            pos = if (nextBoundary >= 0) { nextBoundary } else { len }
        }
        result
    }


    public static func extractBoundary(contentType: String): Option<String> {
        let parts = contentType.split(";")
        for (part in parts) {
            let trimmed = part.trimAscii()
            if (trimmed.startsWith("boundary=")) {
                let value = trimmed["boundary=".size..]
                if (value.size >= 2 && value[0] == b'"' && value[value.size - 1] == b'"') {
                    return Some(value[1..value.size - 1])
                }
                return Some(value)
            }
        }
        None
    }

    /**
     * URL 解码字节数组范围 [start, end) 并返回 String。
     * 允许在不分配中间 String 或 Array 副本的情况下进行索引扫描。
     */
    private static func urlDecodeRaw(data: Array<UInt8>, start: Int64, end: Int64): String {
        // 快速路径：扫描是否真的需要解码
        var needsDecode = false
        var scanIdx = start
        while (scanIdx < end) {
            let ch = data[scanIdx]
            if (ch == b'+' || ch == b'%') {
                needsDecode = true
                break
            }
            scanIdx++
        }
        if (!needsDecode) {
            return String.fromUtf8(data[start..end])
        }

        // 慢速路径：需要 URL 解码
        let len = end - start
        let buf = Array<UInt8>(len, repeat: 0)
        var wi: Int64 = 0
        var i: Int64 = start
        while (i < end) {
            if (data[i] == b'+') {
                buf[wi] = b' '
                wi += 1
                i += 1
            } else if (data[i] == b'%' && i + 2 < end) {
                let high = hexVal(data[i + 1])
                let low = hexVal(data[i + 2])
                if (high >= 0 && low >= 0) {
                    buf[wi] = UInt8((high << 4) | low)
                    wi += 1
                    i += 3
                } else {
                    buf[wi] = data[i]
                    wi += 1
                    i += 1
                }
            } else {
                buf[wi] = data[i]
                wi += 1
                i += 1
            }
        }
        let trimmed = Array<UInt8>(wi, repeat: 0)
        buf.copyTo(trimmed, 0, 0, wi)
        unsafe { String.withRawData(trimmed) }
    }

    private static func urlDecode(s: String): String {
        let bytes = unsafe { s.rawData() }
        let result = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < bytes.size) {
            if (bytes[i] == b'+') {
                result.add(b' ')
                i++
            } else if (bytes[i] == b'%' && i + 2 < bytes.size) {
                let high = hexVal(bytes[i + 1])
                let low = hexVal(bytes[i + 2])
                if (high >= 0 && low >= 0) {
                    result.add(UInt8((high << 4) | low))
                    i += 3
                } else {
                    result.add(bytes[i])
                    i++
                }
            } else {
                result.add(bytes[i])
                i++
            }
        }
        unsafe { String.withRawData(result.toArray()) }
    }

    /**
     * URL 解码字节数组范围 [start, end) 并返回 String。
     * 允许在不分配中间 String 或 Array 副本的情况下进行索引扫描。
     */
    private static func hexVal(b: UInt8): Int64 {
        if (b >= b'0' && b <= b'9') { Int64(b - b'0') }
        else if (b >= b'A' && b <= b'F') { Int64(b - b'A') + 10 }
        else if (b >= b'a' && b <= b'f') { Int64(b - b'a') + 10 }
        else { -1 }
    }

    private static func extractFieldName(headers: HttpHeaders): String {
        match (headers.get("content-disposition")) {
            case Some(v) =>
                let parts = v.split(";")
                for (part in parts) {
                    let trimmed = part.trimAscii()
                    if (trimmed.startsWith("name=")) {
                        let raw = trimmed["name=".size..]
                        if (raw.size >= 2 && raw[0] == b'"' && raw[raw.size - 1] == b'"') {
                            return raw[1..raw.size - 1]
                        }
                        return raw
                    }
                }
                ""
            case None => ""
        }
    }

    private static func extractFileName(headers: HttpHeaders): String {
        match (headers.get("content-disposition")) {
            case Some(v) =>
                let parts = v.split(";")
                for (part in parts) {
                    let trimmed = part.trimAscii()
                    if (trimmed.startsWith("filename=")) {
                        let raw = trimmed["filename=".size..]
                        if (raw.size >= 2 && raw[0] == b'"' && raw[raw.size - 1] == b'"') {
                            return raw[1..raw.size - 1]
                        }
                        return raw
                    }
                }
                ""
            case None => ""
        }
    }

    private static func parseHeadersAt(data: Array<UInt8>, start: Int64, end: Int64): HttpHeaders {
        let headers = HttpHeaders()
        var lineStart = start
        while (lineStart < end) {
            let lineEnd = findCrlf(data, end, start: lineStart)
            if (lineEnd < 0 || lineEnd >= end) { break }
            let colonIndex = findByte(data, lineStart, lineEnd, b':')
            if (colonIndex >= 0) {
                var nameStart = lineStart
                while (nameStart < colonIndex && (data[nameStart] == b' ' || data[nameStart] == b'\t')) { nameStart++ }
                var nameEnd = colonIndex
                while (nameEnd > nameStart && (data[nameEnd - 1] == b' ' || data[nameEnd - 1] == b'\t')) { nameEnd-- }
                var valueStart = colonIndex + 1
                while (valueStart < lineEnd && (data[valueStart] == b' ' || data[valueStart] == b'\t')) { valueStart++ }
                var valueEnd = lineEnd
                while (valueEnd > valueStart && (data[valueEnd - 1] == b' ' || data[valueEnd - 1] == b'\t')) { valueEnd-- }
                let name = String.fromUtf8(data[nameStart..nameEnd])
                let value = String.fromUtf8(data[valueStart..valueEnd])
                headers.add(name, value)
            }
            lineStart = lineEnd + 2
        }
        headers
    }

    private static func findBytesAt(data: Array<UInt8>, start: Int64, end: Int64, needle: Array<UInt8>): Int64 {
        if (needle.size == 0 || needle.size > end - start) { return -1 }
        var i = start
        while (i <= end - needle.size) {
            var isMatch = true
            var j: Int64 = 0
            while (j < needle.size) {
                if (data[i + j] != needle[j]) { isMatch = false; break }
                j++
            }
            if (isMatch) { return i }
            i++
        }
        -1
    }
}

/**
 * Convenience: parse an HTTP 请求 body as URL-encoded form data.
 */
public func parseFormBody(request: HttpRequest): HashMap<String, String> {
    BodyParser.parseUrlEncoded(request.bodyAsString())
}

/**
 * Convenience: parse an HTTP 请求 body as a JSON string.
 */
public func parseJsonBody(request: HttpRequest): JsonValue {
    BodyParser.parseJson(request.bodyAsString())
}

/**
 * Convenience: parse an HTTP 请求 body as multipart form data.
 */
public func parseMultipartBody(request: HttpRequest): HashMap<String, MultipartField> {
    let ctype = match (request.headers.get("content-type")) {
        case Some(v) => v
        case None => return HashMap<String, MultipartField>()
    }
    match (BodyParser.extractBoundary(ctype)) {
        case Some(boundary) => BodyParser.parseMultipart(request.bodyAsBytes(), boundary)
        case None => HashMap<String, MultipartField>()
    }
}

/**
 * * 生成随机 multipart 边界字符串。
 */
public func generateMultipartBoundary(): String {
    let random = secureRandom32()
    let hexChars = "0123456789abcdef"
    var boundary = "----stdHttpLib"
    var i: Int64 = 0
    while (i < 16) {
        let idx = Int64(UInt8(random[i]) % 16)
        boundary += hexChars[idx..idx + 1]
        i++
    }
    boundary
}

/**
 * * 从字段映射构建 multipart/form-data 主体。
 *
 * 每个 MultipartField 按如下格式序列化：
 *   --boundary\r\n
 * Content-Disposition: form-data; name="fieldName"[; filename="..."]\r\n
 *   [Content-Type: ...]\r\n
 *   \r\n
 *   <data>\r\n
 *
 * 主体以如下格式结束：
 *   --boundary--\r\n
 */
public func buildMultipartBody(fields: HashMap<String, MultipartField>, boundary: String): Array<UInt8> {
    if (fields.isEmpty()) {
        return []
    }

    let newline = unsafe { "\r\n".rawData() }
    let boundaryBytes = unsafe { "--${boundary}".rawData() }
    let endBoundaryBytes = unsafe { "--${boundary}--".rawData() }

    // 先计算总大小
    var totalSize: Int64 = 0
    for ((name, field) in fields) {
        totalSize += boundaryBytes.size + newline.size  // --分隔符\r\n
        totalSize += contentDispositionBytes(name, field.fileName).size + newline.size  // Content-Disposition 头部\r\n
        // 可选的 Content-Type
        match (field.headers.get("content-type")) {
            case Some(ct) =>
                let ctLine = "Content-Type: ${ct}"
                let ctBytes = unsafe { ctLine.rawData() }
                totalSize += ctBytes.size + newline.size
            case None => ()
        }
        totalSize += newline.size  // 头部后的空行
        totalSize += field.data.size + newline.size  // 数据 + \r\n
    }
    totalSize += endBoundaryBytes.size + newline.size  // --分隔符--\r\n

    let result = Array<UInt8>(totalSize, repeat: 0)
    var offset: Int64 = 0

    for ((name, field) in fields) {
        // --分隔符\r\n
        writeBytesTo(boundaryBytes, result, offset)
        offset += boundaryBytes.size
        writeNewlineTo(result, offset)
        offset += 2

        // Content-Disposition 响应头
        let cd = contentDispositionBytes(name, field.fileName)
        writeBytesTo(cd, result, offset)
        offset += cd.size
        writeNewlineTo(result, offset)
        offset += 2

        // Content-Type（如存在）
        match (field.headers.get("content-type")) {
            case Some(ct) =>
                let ctLine = "Content-Type: ${ct}"
                let ctBytes = unsafe { ctLine.rawData() }
                writeBytesTo(ctBytes, result, offset)
                offset += ctBytes.size
                writeNewlineTo(result, offset)
                offset += 2
            case None => ()
        }

        // 空行
        writeNewlineTo(result, offset)
        offset += 2

        // 字段数据
        writeBytesTo(field.data, result, offset)
        offset += field.data.size
        writeNewlineTo(result, offset)
        offset += 2
    }

    // --分隔符--\r\n
    writeBytesTo(endBoundaryBytes, result, offset)
    offset += endBoundaryBytes.size
    writeNewlineTo(result, offset)

    result
}

/**
 * * 为 multipart 字段构建 Content-Disposition 响应头行。
 */
private func contentDispositionBytes(name: String, fileName: String): Array<UInt8> {
    if (fileName.size > 0) {
        let line = "Content-Disposition: form-data; name=\"${name}\"; filename=\"${fileName}\""
        unsafe { line.rawData() }
    } else {
        let line = "Content-Disposition: form-data; name=\"${name}\""
        unsafe { line.rawData() }
    }
}

private func writeBytesTo(source: Array<UInt8>, dest: Array<UInt8>, destOffset: Int64): Unit {
    if (source.size > 0) {
        source.copyTo(dest, 0, destOffset, source.size)
    }
}

private func writeNewlineTo(dest: Array<UInt8>, offset: Int64): Unit {
    dest[offset] = b'\r'
    dest[offset + 1] = b'\n'
}
