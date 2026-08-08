package http_lib.message

import http_lib.buffer.ByteBuffer
import http_lib.core.*
import http_lib.utils.{findHeaderEnd, findCrlf, findByte, skipSpaces, trimEnd, containsIgnoreCase, normalizeLineEndings}

/**
 * HTTP/1.x 请求解析器。
 */
public class HttpRequestParser {

    /**
     * Parse a complete HTTP 请求 from raw bytes.
     * @param data 从连接接收的原始字节
     * @return 解析后的 HttpRequest
     * @throws ProtocolException 请求格式错误时抛出
     */
    public static func parse(data: Array<UInt8>): HttpRequest {
        let normalized = normalizeLineEndings(data)
        let len = normalized.size
        if (len == 0) {
            throw ProtocolException("empty HTTP 请求")
        }

        // 查找头部结束：\r\n\r\n
        let headerEnd = findHeaderEnd(normalized, len)
        if (headerEnd < 0) {
            throw ProtocolException("incomplete HTTP 请求 headers")
        }
        if (headerEnd > MAX_HEADER_SIZE) {
            throw ProtocolException("HTTP 请求 headers too large")
        }

        // 解析请求行：METHOD URI HTTP/VERSION
        let statusLineEnd = findCrlf(normalized, len)
        if (statusLineEnd < 0) {
            throw ProtocolException("invalid HTTP 请求 line")
        }

        let (method, uri, version) = parseRequestLine(normalized, 0, statusLineEnd)

        // 解析响应头
        let headers = parseHeaders(normalized, statusLineEnd + 2, headerEnd)

        // 解析主体
        let body = parseBody(normalized, headerEnd, len, headers, method)

        let request = HttpRequest(method: method, url: uri, version: version, headers: headers, body: body)
        // 从 URI 提取路径（去除查询字符串）
        request.path = extractPathFromUri(uri)
        request
    }

    /**
     * 通过去除查询字符串从 URI 中提取路径组件。
     */
    private static func extractPathFromUri(uri: String): String {
        match (uri.indexOf("?")) {
            case Some(idx) => uri[..idx]
            case None => uri
        }
    }

    /**
     * 解析请求行："GET /path HTTP/1.1\r\n"
     */
    private static func parseRequestLine(data: Array<UInt8>, start: Int64, end: Int64): (HttpMethod, String, HttpVersion) {
        // 查找方法结束位置（第一个空格）
        let methodEnd = findByte(data, start, end, SPACE_BYTE)
        if (methodEnd < 0) {
            throw ProtocolException("invalid HTTP 请求 line: no method")
        }

        let methodStr = String.fromUtf8(data[start..methodEnd])
        let method = match (HttpMethod.parse(methodStr)) {
            case Some(m) => m
            case None => throw ProtocolException("unknown HTTP method: ${methodStr}")
        }

        // 查找 URI（空格之间）
        let uriStart = skipSpaces(data, methodEnd + 1, end)
        if (uriStart >= end) {
            throw ProtocolException("invalid HTTP 请求 line: no URI")
        }
        let uriEndOrMissing = findByte(data, uriStart, end, SPACE_BYTE)
        let uriEnd = if (uriEndOrMissing >= 0) { uriEndOrMissing } else { end }
        let rawUri = String.fromUtf8(data[uriStart..uriEnd])

        // RFC 7230 §5.3.4：OPTIONS * 是合法的请求目标
        let isOptionsStar = method == HttpMethod.OPTIONS && rawUri == "*"
        let uri = if (isOptionsStar) { "*" } else { rawUri }

        // 查找版本
        let versionStart = if (uriEndOrMissing >= 0 && !isOptionsStar) {
            skipSpaces(data, uriEndOrMissing + 1, end)
        } else if (isOptionsStar) {
            end  // OPTIONS * 不需要版本
        } else {
            end
        }
        let version = if (versionStart < end) {
            let versionStr = String.fromUtf8(data[versionStart..end])
            match (HttpVersion.parse(versionStr)) {
                case Some(v) => v
                case None => throw ProtocolException("unknown HTTP version: ${versionStr}")
            }
        } else {
            HttpVersion.HTTP_1_1
        }

        (method, uri, version)
    }
}

/**
 * 从头块解析 HTTP 头。
 */
public func parseHeaders(data: Array<UInt8>, start: Int64, end: Int64): HttpHeaders {
    let headers = HttpHeaders()
    var lineStart = start
    while (lineStart + 1 < end) {
        // 检查空行（响应头结束）
        if (data[lineStart] == b'\r' && data[lineStart + 1] == b'\n') {
            break
        }

        let lineEnd = findCrlf(data, end, start: lineStart)
        if (lineEnd < 0) {
            throw ProtocolException("invalid HTTP header")
        }

        // 检查 obs-fold（以空格/制表符开头的续行）
        if (lineStart > start && (data[lineStart] == b' ' || data[lineStart] == b'\t')) {
            throw ProtocolException("obs-fold headers not supported")
        }

        let colonIndex = findByte(data, lineStart, lineEnd, COLON_BYTE)
        if (colonIndex < 0) {
            throw ProtocolException("invalid HTTP header line (no colon)")
        }

        let nameStart = skipSpaces(data, lineStart, colonIndex)
        let nameEnd = trimEnd(data, nameStart, colonIndex)
        if (nameEnd <= nameStart) {
            throw ProtocolException("invalid HTTP header line (empty name)")
        }

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

/**
 * 基于 Content-Length 或 Transfer-Encoding 解析 HTTP 主体。
 */
public func parseBody(
    data: Array<UInt8>,
    bodyStart: Int64,
    bodyEnd: Int64,
    headers: HttpHeaders,
    method: HttpMethod
): ByteBuffer {
    // HEAD、GET、DELETE 等方法无主体，除非 Content-Length 另有说明
    let hasContentLength = match (headers.get("content-length")) {
        case Some(_) => true
        case None => false
    }
    let hasTransferEncoding = match (headers.get("transfer-encoding")) {
        case Some(ve) =>
            let bytes = unsafe { ve.rawData() }
            containsIgnoreCase(bytes, "chunked".toRuneArray())
        case None => false
    }

    // RFC 7230 §3.3.2：检查多个 Content-Length 头是否值不一致（请求走私攻击）
    // RFC 7230 §3.3.2 / §3.3.3：仅在存在相关响应头时运行走私检测，
    // 避免对无主体请求（如 GET）进行多余的 HashMap 查询和空数组分配。
    if (hasContentLength || hasTransferEncoding) {
        if (hasContentLength) {
            let allContentLengths = headers.getAll("content-length")
            if (allContentLengths.size > 1) {
                let firstCL = allContentLengths[0]
                for (cl in allContentLengths) {
                    if (cl != firstCL) {
                        throw ProtocolException("multiple Content-Length headers with different values (possible smuggling)")
                    }
                }
            }
        }

        // RFC 7230 §3.3.3：如果 Transfer-Encoding 和 Content-Length 同时存在，
        // reject the request to prevent HTTP 请求 smuggling (CVE-2019-15642 et al).
        // 根据规范 Transfer-Encoding 优先，但拒绝更安全。
        if (hasTransferEncoding && hasContentLength) {
            throw ProtocolException("request contains both Transfer-Encoding and Content-Length")
        }

        // Transfer-Encoding smuggling 深度防护（RFC 7230 §3.3.3 / CVE-2022-2294）
        // 多个 Transfer-Encoding 头或逗号分隔的多值编码是走私攻击向量。
        if (hasTransferEncoding) {
            let allTes = headers.getAll("transfer-encoding")
            if (allTes.size > 1) {
                throw ProtocolException("multiple Transfer-Encoding headers detected (possible smuggling)")
            }
            if (allTes.size == 1 && allTes[0].size > 0) {
                let teValue = allTes[0]
                // 逗号分隔多个编码值也是走私向量
                if (teValue.contains(",")) {
                    throw ProtocolException("Transfer-Encoding header contains multiple comma-separated values (possible smuggling)")
                }
            }
        }
    }

    if (!hasContentLength && !hasTransferEncoding) {
        return ByteBuffer(capacity: 0)
    }
    if (bodyStart >= bodyEnd) {
        return ByteBuffer(capacity: 0)
    }

    let bodyLen = bodyEnd - bodyStart

    if (hasTransferEncoding) {
        // 解码分块主体
        let rawChunked = data[bodyStart..bodyEnd]
        let decoded = ChunkedDecoder.decode(rawChunked)
        let buf = ByteBuffer(capacity: decoded.size)
        buf.write(decoded)
        return buf
    }

    let buf = ByteBuffer(capacity: bodyLen)
    buf.write(data, bodyStart, bodyLen)
    buf
}
