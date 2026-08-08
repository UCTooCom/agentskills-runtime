package http_lib.message
/**
 * HTTP/1.x 响应解析器。按 RFC 7230 解析状态行、头部和主体。
 * 支持分块传输编码、Content-Length 和连接关闭检测三种帧格式。
 */

import http_lib.buffer.ByteBuffer
import http_lib.core.*
import http_lib.utils.{findHeaderEnd, findCrlf, findByte, skipSpaces, trimEnd, normalizeLineEndings}

/**
 * HTTP/1.x 响应解析器。
 */
public class HttpResponseParser {

    public static func parse(data: Array<UInt8>): HttpResponse {
        let normalized = normalizeLineEndings(data)
        let len = normalized.size
        if (len == 0) {
            throw ProtocolException("empty HTTP 响应")
        }

        let headerEnd = findHeaderEnd(normalized, len)
        if (headerEnd < 0) {
            throw ProtocolException("HTTP 响应头不完整")
        }
        if (headerEnd > MAX_HEADER_SIZE) {
            throw ProtocolException("HTTP 响应头过大")
        }

        // 解析状态行：HTTP/1.1 200 OK

        let statusLineEnd = findCrlf(normalized, len)
        if (statusLineEnd < 0) {
            throw ProtocolException("invalid HTTP 响应 status line")
        }

        let (version, status) = parseStatusLine(normalized, 0, statusLineEnd)

        // 解析响应头
        let headers = parseResponseHeaders(normalized, statusLineEnd + 2, headerEnd)

        // 1xx 信息响应（101 除外）根据 RFC 7230 §3.3 没有主体
        if (status.isInformational() && status.code != 101) {
            return HttpResponse(
                version: version,
                status: status,
                headers: headers,
                body: ByteBuffer(capacity: 0)
            )
        }

        // 按 RFC 7230 以正确的帧格式解析主体
        let bodyBytes = extractBody(normalized, headerEnd, len, headers, status, version)

        HttpResponse(
            version: version,
            status: status,
            headers: headers,
            body: bodyBytes
        )
    }

    /**
     * 按 RFC 7230 Section 3.3 以正确的帧格式提取响应体。
     *
     * 帧格式规则（按优先级顺序）：
     * 1. HEAD 响应和 204/304 不得有主体
     * 2. Transfer-Encoding: chunked → 使用 ChunkedDecoder
     * 3. Content-Length → 精确读取指定字节数
     * 4. 其他情况（HTTP/1.0 或 Connection: close）→ 读取剩余字节
     */
    private static func extractBody(
        data: Array<UInt8>,
        headerEnd: Int64,
        totalLen: Int64,
        headers: HttpHeaders,
        status: HttpStatus,
        version: HttpVersion
    ): ByteBuffer {
        // 规则 1：HEAD、204 No Content、304 Not Modified 没有主体
        if (status.code == 204 || status.code == 304) {
            return ByteBuffer(capacity: 0)
        }

        // RFC 7230 §3.3.3 合规：检查 TE/CL 冲突（响应走私防御）
        let hasTe = match (headers.get("transfer-encoding")) {
            case Some(_) => true
            case None => false
        }
        let hasCl = match (headers.get("content-length")) {
            case Some(_) => true
            case None => false
        }
        if (hasTe && hasCl) {
            throw ProtocolException("response contains both Transfer-Encoding and Content-Length (RFC 7230 §3.3.3)")
        }

        // 检查 Transfer-Encoding: chunked
        let transferEncoding = headers.get("transfer-encoding")
        match (transferEncoding) {
            case Some(te) =>
                if (containsIgnoreCaseChunked(te)) {
                    // 规则 2：分块传输编码
                    if (headerEnd >= totalLen) {
                        return ByteBuffer(capacity: 0)
                    }
                    let bodyLen = totalLen - headerEnd
                    let bodyData = Array<UInt8>(bodyLen, repeat: 0)
                    data.copyTo(bodyData, headerEnd, 0, bodyLen)
                    let decoded = ChunkedDecoder.decode(bodyData)
                    return ByteBuffer.fromOwned(decoded)
                }
            case None => ()
        }

        // 规则 3：Content-Length
        let contentLength = headers.get("content-length")
        match (contentLength) {
            case Some(cl) =>
                let bodyLen = parseContentLength(cl)
                if (bodyLen <= 0) {
                    return ByteBuffer(capacity: 0)
                }
                let remaining = totalLen - headerEnd
                let actualLen = if (bodyLen < remaining) { bodyLen } else { remaining }
                let buf = Array<UInt8>(actualLen, repeat: 0)
                data.copyTo(buf, headerEnd, 0, actualLen)
                return ByteBuffer.fromOwned(buf)
            case None => ()
        }

        // 规则 4：无 content-length、无 chunked —— 读取直到连接关闭
        // 对于 HTTP/1.0（无 Keep-Alive）或 Connection: close
        let connectionHeader = headers.get("connection")
        let isClose = match (connectionHeader) {
            case Some(conn) => containsIgnoreCaseClose(conn)
            case None => version == HttpVersion.HTTP_1_0
        }

        if (isClose && headerEnd < totalLen) {
            let bodyLen = totalLen - headerEnd
            let buf = Array<UInt8>(bodyLen, repeat: 0)
            data.copyTo(buf, headerEnd, 0, bodyLen)
            return ByteBuffer.fromOwned(buf)
        }

        ByteBuffer(capacity: 0)
    }

    private static func parseStatusLine(data: Array<UInt8>, start: Int64, end: Int64): (HttpVersion, HttpStatus) {
        // 格式：HTTP/1.1 200 OK
        let space1 = findByte(data, start, end, SPACE_BYTE)
        if (space1 < 0) {
            throw ProtocolException("invalid HTTP status line")
        }

        let versionStr = String.fromUtf8(data[start..space1])
        let version = match (HttpVersion.parse(versionStr)) {
            case Some(v) => v
            case None => throw ProtocolException("unknown HTTP version: ${versionStr}")
        }

        let codeStart = skipSpaces(data, space1 + 1, end)
        let codeEndOrSpace = findByte(data, codeStart, end, SPACE_BYTE)
        let codeEnd = if (codeEndOrSpace >= 0) { codeEndOrSpace } else { end }

        let codeStr = String.fromUtf8(data[codeStart..codeEnd])
        let code = parseUInt16(codeStr)

        let reasonStart = if (codeEndOrSpace >= 0) {
            skipSpaces(data, codeEndOrSpace + 1, end)
        } else { end }
        let reasonPhrase = if (reasonStart < end) {
            String.fromUtf8(data[reasonStart..end])
        } else { "" }

        (version, HttpStatus(code, reasonPhrase: reasonPhrase))
    }

    private static func parseResponseHeaders(data: Array<UInt8>, start: Int64, end: Int64): HttpHeaders {
        let headers = HttpHeaders()
        var lineStart = start
        while (lineStart + 1 < end) {
            if (data[lineStart] == b'\r' && data[lineStart + 1] == b'\n') {
                break
            }
            let lineEnd = findCrlf(data, end, start: lineStart)
            if (lineEnd < 0) { break }

            let colonIndex = findByte(data, lineStart, lineEnd, COLON_BYTE)
            if (colonIndex < 0) { lineStart = lineEnd + 2; continue }

            let nameStart = skipSpaces(data, lineStart, colonIndex)
            let nameEnd = trimEnd(data, nameStart, colonIndex)
            let valueStart = skipSpaces(data, colonIndex + 1, lineEnd)
            let valueEnd = trimEnd(data, valueStart, lineEnd)

            let name = String.fromUtf8(data[nameStart..nameEnd])
            let value = if (valueStart < valueEnd) {
                String.fromUtf8(data[valueStart..valueEnd])
            } else { "" }

            headers.add(name, value)
            lineStart = lineEnd + 2
        }
        headers
    }

    private static func parseUInt16(s: String): UInt16 {
        let bytes = s.toArray()
        var result: UInt16 = 0
        for (b in bytes) {
            if (b >= b'0' && b <= b'9') {
                let digit = Int64(b - b'0')
                // 溢出检测：UInt16 最大值为 65535
                if (result > 6553 || (result == 6553 && digit > 5)) {
                    throw ProtocolException("状态码超出范围: ${s}")
                }
                result = UInt16(Int64(result) * 10 + digit)
            } else {
                throw ProtocolException("invalid status code: ${s}")
            }
        }
        result
    }

    /**
     * 大小写不敏感检查 Transfer-Encoding 头值是否包含 "chunked"。
     */
    private static func containsIgnoreCaseChunked(value: String): Bool {
        containsIgnoreCaseBytes(value, "chunked")
    }

    /**
     * 大小写不敏感检查 Connection 头值是否包含 "close"。
     */
    private static func containsIgnoreCaseClose(value: String): Bool {
        containsIgnoreCaseBytes(value, "close")
    }

    /**
     * 头值中简单的大小写不敏感子串搜索。
     * 直接操作字节，避免 toRuneArray() 的 UTF-32 转换开销。
     */
    private static func containsIgnoreCaseBytes(value: String, needle: String): Bool {
        let valBytes = unsafe { value.rawData() }
        let ndlBytes = unsafe { needle.rawData() }
        if (ndlBytes.size == 0) { return true }
        if (ndlBytes.size > valBytes.size) { return false }
        let n = ndlBytes.size
        var i: Int64 = 0
        while (i <= valBytes.size - n) {
            var isMatch = true
            var j: Int64 = 0
            while (j < n) {
                let vb = if (valBytes[i + j] >= b'A' && valBytes[i + j] <= b'Z') {
                    valBytes[i + j] + 32
                } else { valBytes[i + j] }
                let nb = if (ndlBytes[j] >= b'A' && ndlBytes[j] <= b'Z') {
                    ndlBytes[j] + 32
                } else { ndlBytes[j] }
                if (vb != nb) { isMatch = false; break }
                j++
            }
            if (isMatch) { return true }
            i++
        }
        false
    }
}
