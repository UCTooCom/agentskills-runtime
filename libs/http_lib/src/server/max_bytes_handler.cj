package http_lib.server
/**
 * 请求体大小限制中间件。
 * 限制请求体最大字节数，超标时返回 413 Payload Too Large。
 */

import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.buffer.ByteBuffer
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Handler

/**
 * 最大请求体大小限制处理器。
 *
 * 包装一个 Handler，限制进入的请求体大小。
 * 若 Content-Length 超过限制，返回 413 Request Entity Too Large。
 * 若实际读取的主体超过限制，返回 413 Request Entity Too Large。
 *
 * 用法：
 *   let handler = maxBytesHandler(myHandler, 1024 * 1024)  // 限制 1MB
 *   router.post("/upload", handler)
 *
 * 与服务器配置中的 maxBodySize 的不同：
 * - maxBodySize 是服务器级别的限制，在解析请求体时强制执行。
 * - MaxBytesHandler 是中间件，可以按路由粒度控制。
 * - 两者可以同时使用，MaxBytesHandler 在中间件链中更早生效。
 *
 * @param handler 被包装的原始处理器
 * @param maxBytes 最大允许的请求体大小（字节）
 * @return 返回 413 Request Entity Too Large 的处理器
 */
public func maxBytesHandler(handler: Handler, maxBytes: Int64): Handler {
    {req: HttpRequest =>
        // 检查 Content-Length 头部
        match (req.headers.get("content-length")) {
            case Some(cl) =>
                let contentLength = parseContentLength(cl)
                if (contentLength > maxBytes) {
                    return build413Response(req, maxBytes)
                }
            case None => ()
        }

        // 检查主体大小
        let bodySize = req.body.getLimit()
        if (bodySize > maxBytes) {
            return build413Response(req, maxBytes)
        }

        // 传递给原始处理器
        handler(req)
    }
}

/**
 * 构建 413 Request Entity Too Large 响应。
 */
private func build413Response(req: HttpRequest, maxBytes: Int64): HttpResponse {
    let headers = HttpHeaders()
    headers.set("Content-Type", "text/plain; charset=utf-8")
    headers.set("X-Content-Type-Options", "nosniff")
    let msg = "413 Request Entity Too Large: 请求体大小超过限制 ${maxBytes} 字节\n"
    let bodyBytes = unsafe { msg.rawData() }
    let body = ByteBuffer(capacity: bodyBytes.size)
    body.write(bodyBytes)
    HttpResponse(status: HttpStatus.PAYLOAD_TOO_LARGE, headers: headers, body: body)
}

/**
 * 解析 Content-Length 头部值为 Int64。
 */
private func parseContentLength(s: String): Int64 {
    let bytes = s.toArray()
    var result: Int64 = 0
    for (b in bytes) {
        if (b >= b'0' && b <= b'9') {
            result = result * 10 + Int64(b - b'0')
        } else {
            break
        }
    }
    result
}
