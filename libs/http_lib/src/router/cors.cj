package http_lib.router
/**
 * CORS（跨域资源共享）中间件（RFC 6454）。
 * 处理 OPTIONS 预检请求和跨域响应头设置。
 */

import std.collection.ArrayList
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.utils.{asciiToLower}

/**
 * CORS 跨域资源共享中间件。
 *
 * 处理预检（OPTIONS）请求并添加 Access-Control-*
 * 响应头。
 *
 * 用法：
 *   let cors = CorsConfig()
 *   router.use(corsMiddleware(cors))
 */

public class CorsConfig {
    public var allowOrigins: Array<String> = ["*"]
    public var allowMethods: Array<String> = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
    public var allowHeaders: Array<String> = ["Content-Type", "Authorization", "Accept"]
    public var exposeHeaders: Array<String> = []
    public var allowCredentials: Bool = false
    public var maxAge: Int64 = 86400  // 24 小时

    public init() {}
}

/**
 * 创建 CORS 中间件函数。
 */
public func corsMiddleware(config: CorsConfig): Middleware {
    {handler =>
        {req =>
            // 处理预检
            if (req.method == HttpMethod.OPTIONS) {
                let origin = match (req.headers.get("origin")) {
                    case Some(o) => o
                    case None => ""
                }
                if (origin.size > 0 && isOriginAllowed(config, origin)) {
                    // 验证 Access-Control-Request-Method
                    let requestMethod = match (req.headers.get("access-control-request-method")) {
                        case Some(m) => m
                        case None => return HttpResponse.text(HttpStatus.BAD_REQUEST, "CORS preflight: missing Access-Control-Request-Method")
                    }
                    var methodOk = false
                    let requestMethodLower = asciiToLower(requestMethod)
                    for (m in config.allowMethods) {
                        if (asciiToLower(m) == requestMethodLower) {
                            methodOk = true
                            break
                        }
                    }
                    if (!methodOk) {
                        return HttpResponse.text(HttpStatus.FORBIDDEN, "CORS preflight: method '${requestMethod}' not allowed")
                    }

                    // 验证 Access-Control-Request-Headers（如果存在）
                    match (req.headers.get("access-control-request-headers")) {
                        case Some(requestedHeaders) =>
                            if (requestedHeaders.size > 0) {
                                let parts = requestedHeaders.split(",")
                                for (part in parts) {
                                    let trimmed = part.trimAscii()
                                    if (trimmed.size == 0) { continue }
                                    var headerOk = false
                                    let trimmedLower = asciiToLower(trimmed)
                                    for (allow in config.allowHeaders) {
                                        if (asciiToLower(allow) == trimmedLower) {
                                            headerOk = true
                                            break
                                        }
                                    }
                                    if (!headerOk) {
                                        return HttpResponse.text(HttpStatus.FORBIDDEN, "CORS preflight: header '${trimmed}' not allowed")
                                    }
                                }
                            }
                        case None => ()
                    }

                    var resp = HttpResponse.empty(HttpStatus.NO_CONTENT)
                    addCorsHeaders(resp.headers, config, origin)
                    resp.headers.set("Access-Control-Allow-Methods", joinArray(config.allowMethods))
                    resp.headers.set("Access-Control-Allow-Headers", joinArray(config.allowHeaders))
                    resp.headers.set("Access-Control-Max-Age", "${config.maxAge}")
                    if (config.allowCredentials) {
                        resp.headers.set("Access-Control-Allow-Credentials", "true")
                    }
                    return resp
                }
            }

            // 处理实际请求
            let resp = handler(req)
            let origin = match (req.headers.get("origin")) {
                case Some(o) => o
                case None => ""
            }
            if (origin.size > 0 && isOriginAllowed(config, origin)) {
                addCorsHeaders(resp.headers, config, origin)
            }
            resp
        }
    }
}

private func isOriginAllowed(config: CorsConfig, origin: String): Bool {
    let normalizedOrigin = asciiToLower(origin)
    for (allowed in config.allowOrigins) {
        if (allowed == "*" || asciiToLower(allowed) == normalizedOrigin) {
            return true
        }
    }
    false
}

private func addCorsHeaders(headers: HttpHeaders, config: CorsConfig, origin: String): Unit {
    var echoOrigin = false
    if (config.allowOrigins.size == 1 && config.allowOrigins[0] == "*") {
        if (config.allowCredentials) {
            // 带凭据的请求必须根据 Fetch 规范回显特定来源
            headers.set("Access-Control-Allow-Origin", origin)
            echoOrigin = true
        } else {
            headers.set("Access-Control-Allow-Origin", "*")
        }
    } else {
        headers.set("Access-Control-Allow-Origin", origin)
        echoOrigin = true
    }
    if (echoOrigin) {
        headers.add("Vary", "Origin")
    }
    if (config.exposeHeaders.size > 0) {
        headers.set("Access-Control-Expose-Headers", joinArray(config.exposeHeaders))
    }
    if (config.allowCredentials) {
        headers.set("Access-Control-Allow-Credentials", "true")
    }
}

private func joinArray(arr: Array<String>): String {
    var result = ""
    var first = true
    for (s in arr) {
        if (first) { first = false } else { result += "," }
        result += s
    }
    result
}

