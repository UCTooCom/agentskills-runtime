package http_lib.message
/**
 * HTTP 请求/响应调试转储。
 * 将请求和响应以人类可读格式输出为字符串，用于调试和日志记录。
 */

import http_lib.buffer.ByteBuffer
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion}

/**
 * 将 HTTP 请求转储为原始字节格式。
 * 适用于调试和日志记录。
 *
 * 输出格式（RFC 7230）：
 *   METHOD URI HTTP/VERSION\r\n
 *   Header: Value\r\n
 *   \r\n
 *   body
 *
 * 用法：
 *   let dump = dumpRequest(request)
 *   println(String.fromUtf8(dump))
 */
public func dumpRequest(req: HttpRequest): Array<UInt8> {
    let buf = ByteBuffer(capacity: 1024)

    // 请求行
    let methodStr = methodToString(req.method)
    let url = req.url
    let versionStr = versionToString(req.version)
    let requestLine = "${methodStr} ${url} ${versionStr}\r\n"
    let requestLineBytes = unsafe { requestLine.rawData() }
    buf.write(requestLineBytes)

    // 头部
    let headerBytes = req.headers.toBytes()
    if (headerBytes.size > 0) {
        buf.write(headerBytes)
    }

    // 空行
    buf.write(unsafe { "\r\n".rawData() })

    // 主体
    let bodyBytes = req.bodyAsBytes()
    if (bodyBytes.size > 0) {
        buf.write(bodyBytes)
    }

    buf.getArray()[..buf.getLimit()]
}

/**
 * 将 HTTP 响应转储为原始字节格式。
 * 适用于调试和日志记录。
 *
 * 输出格式（RFC 7230）：
 *   HTTP/VERSION STATUS_CODE REASON\r\n
 *   Header: Value\r\n
 *   \r\n
 *   body
 *
 * 参数：
 *   resp: HTTP 响应对象
 *   body: 若为 true，包含响应体（默认 true）
 *   maxBody: 最大响应体字节数（0 = 无限制）
 *
 * 用法：
 *   let dump = dumpResponse(response)
 *   println(String.fromUtf8(dump))
 */
public func dumpResponse(resp: HttpResponse, body!: Bool = true, maxBody!: Int64 = 0): Array<UInt8> {
    let buf = ByteBuffer(capacity: 1024)

    // 状态行
    let versionStr = versionToString(resp.version)
    let statusLine = "${versionStr} ${resp.status.code} ${resp.status.reasonPhrase}\r\n"
    let statusLineBytes = unsafe { statusLine.rawData() }
    buf.write(statusLineBytes)

    // 头部
    let headerBytes = resp.headers.toBytes()
    if (headerBytes.size > 0) {
        buf.write(headerBytes)
    }

    // 空行
    buf.write(unsafe { "\r\n".rawData() })

    // 主体（可选）
    if (body) {
        let bodyBytes = resp.bodyAsBytes()
        if (bodyBytes.size > 0) {
            if (maxBody > 0 && bodyBytes.size > maxBody) {
                buf.write(bodyBytes[0..maxBody])
                let truncatedMsg = unsafe { "\n... [截断 ${bodyBytes.size - maxBody} 字节]".rawData() }
                buf.write(truncatedMsg)
            } else {
                buf.write(bodyBytes)
            }
        }
    }

    buf.getArray()[..buf.getLimit()]
}

/**
 * 将 HTTP 响应转储为字符串格式。
 * 适用于日志记录。
 */
public func dumpResponseToString(resp: HttpResponse, body!: Bool = true, maxBody!: Int64 = 0): String {
    let bytes = dumpResponse(resp, body: body, maxBody: maxBody)
    String.fromUtf8(bytes)
}

/**
 * 将 HTTP 请求转储为字符串格式。
 * 适用于日志记录。
 */
public func dumpRequestToString(req: HttpRequest): String {
    let bytes = dumpRequest(req)
    String.fromUtf8(bytes)
}

/**
 * 截断请求体以保护敏感数据。
 */
public func dumpRequestSafe(req: HttpRequest, maxBodyLen!: Int64 = 256): Array<UInt8> {
    let buf = ByteBuffer(capacity: 1024)

    let methodStr = methodToString(req.method)
    let versionStr = versionToString(req.version)
    let requestLine = "${methodStr} ${req.url} ${versionStr}\r\n"
    buf.write(unsafe { requestLine.rawData() })

    let headerBytes = req.headers.toBytes()
    if (headerBytes.size > 0) {
        buf.write(headerBytes)
    }
    buf.write(unsafe { "\r\n".rawData() })

    let bodyBytes = req.bodyAsBytes()
    if (bodyBytes.size > 0) {
        if (maxBodyLen > 0 && bodyBytes.size > maxBodyLen) {
            buf.write(bodyBytes[0..maxBodyLen])
            let msg = unsafe { "\n... [主体 ${bodyBytes.size} 字节，截断]".rawData() }
            buf.write(msg)
        } else {
            buf.write(bodyBytes)
        }
    }

    buf.getArray()[..buf.getLimit()]
}

// ---- 内部辅助函数 ----

private func methodToString(method: HttpMethod): String {
    match (method) {
        case HttpMethod.GET => "GET"
        case HttpMethod.HEAD => "HEAD"
        case HttpMethod.POST => "POST"
        case HttpMethod.PUT => "PUT"
        case HttpMethod.DELETE => "DELETE"
        case HttpMethod.CONNECT => "CONNECT"
        case HttpMethod.OPTIONS => "OPTIONS"
        case HttpMethod.TRACE => "TRACE"
        case HttpMethod.PATCH => "PATCH"
    }
}

private func versionToString(version: HttpVersion): String {
    match (version) {
        case HttpVersion.HTTP_1_0 => "HTTP/1.0"
        case HttpVersion.HTTP_1_1 => "HTTP/1.1"
        case HttpVersion.HTTP_2_0 => "HTTP/2"
        case HttpVersion.HTTP_3_0 => "HTTP/3"
    }
}
