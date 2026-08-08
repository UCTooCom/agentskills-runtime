package http_lib.router
/**
 * 处理器工具函数：JSON 响应、错误响应、重定向辅助。
 */

/**
 * 路由器处理器工具函数集合。
 * 提供便捷方法将函数快速包装为标准 HTTP Handler，
 * 包括 JSON 响应、字符串响应、静态文件响应等常见场景。
 */

import http_lib.core.{HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * PrefixStripper 返回一个处理器，移除请求路径中的指定前缀后调用内部处理器。
 *
 * 行为：
 *   - 如果路径不以 prefix 开头，返回 404 Not Found。
 *
 * 用法：
 *   // 将 /static/ 下的文件映射为根路径
 *   router.get("/static/{path}", PrefixStripper("/static/", serveStatic("./public")))
 */
public func PrefixStripper(prefix: String, handler: Handler): Handler {
    if (prefix.size == 0) {
        return handler
    }

    {req: HttpRequest =>
        let path = req.path
        if (path.startsWith(prefix)) {
            // 处理边界情况：路径等于前缀（例如 "/api" 和前缀 "/api"）
            let newPath = if (path.size <= prefix.size) {
                "/"
            } else {
                // 如果 prefix 以 '/' 结尾，保留一个前导 '/'；否则自然保留
                let startIdx = if (prefix[prefix.size - 1] == b'/') { prefix.size - 1 } else { prefix.size }
                path[startIdx..]
            }
            let newReq = HttpRequest(
                method: req.method,
                url: newPath,
                version: req.version,
                headers: req.headers,
                body: req.body
            )
            // 保留查询字符串
            let origUrl = req.url
            match (origUrl.indexOf("?")) {
                case Some(qIdx) =>
                    newReq.url = newPath + origUrl[qIdx..]
                case None => ()
            }
            handler(newReq)
        } else {
            HttpResponse.text(HttpStatus.NOT_FOUND,
                "Not Found: path '${path}' does not start with '${prefix}'")
        }
    }
}

/**
 * NotFoundHandler 返回 404 Not Found 响应。
 * 用法：
 *   NotFoundHandler returns 404 for unmatched routes
 */
public func NotFoundHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.NOT_FOUND, "404 page not found")
}

/**
 * RedirectHandler 返回一个重定向响应处理器。
 * 默认使用 301 Moved Permanently，可通过 status 参数自定义。
 */
public func RedirectHandler(url: String, status!: HttpStatus = HttpStatus.MOVED_PERMANENTLY): Handler {
    {req: HttpRequest =>
        HttpResponse.redirect(url, status: status)
    }
}
