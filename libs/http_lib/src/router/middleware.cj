package http_lib.router
/**
 * HTTP 中间件链（洋葱模型）。
 * 中间件从外向内包裹目标处理器，每个中间件可以预处理请求、
 * 调用下一个处理器、后处理响应。适用于日志、认证、限流等横切关注点。
 */

import std.collection.ArrayList
import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.buffer.ByteBuffer
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * 中间件链。
 *
 * 每个中间件包裹下一个处理器，形成洋葱结构：
 * 请求 → m1 → m2 → ... → 处理器 → ... → m2 → m1 → 响应
 *
 * 用法：
 *   let chain = MiddlewareChain()
 *   chain.use(loggingMiddleware)
 *   chain.use(corsMiddleware)
 *   let finalHandler = chain.apply(routerHandler)
 */
public class MiddlewareChain {
    private var middlewares: ArrayList<Middleware>

    public init() {
        middlewares = ArrayList<Middleware>()
    }

    /**
     * 注册一个中间件函数。
     * 中间件按注册顺序应用（最先注册的 = 最外层）。
     */
    public func use(m: Middleware): MiddlewareChain {
        middlewares.add(m)
        this
    }

    /**
     * Apply the 中间件链 to a final handler.
     * 返回一个按顺序调用所有中间件的包装处理器。
     */
    public func apply(final: Handler): Handler {
        var result = final
        var i = middlewares.size - 1
        while (i >= 0) {
            result = middlewares[i](result)
            i--
        }
        result
    }

    /**
     * 获取已注册的中间件数量。
     */
    public prop size: Int64 {
        get() { middlewares.size }
    }
}

/**
 * RecoveryMiddleware 返回一个捕获异常抛出的中间件
 * 由下游处理器处理并返回 500 内部服务器错误响应。
 *
Handler 异常恢复 pattern. Prevents a single
 * 防止行为异常的处理器使整个连接崩溃。
 *
 * 用法：
 *   router.use(recoveryMiddleware())
 */
public func recoveryMiddleware(): Middleware {
    {next: Handler =>
        {req: HttpRequest =>
            try {
                next(req)
            } catch (e: Exception) {
                let headers = HttpHeaders()
                headers.set("Content-Type", "text/plain; charset=utf-8")
                let bodyStr = "Internal Server Error\n"
                let bodyData = unsafe { bodyStr.rawData() }
                headers.set("Content-Length", "${bodyData.size}")
                let body = ByteBuffer(capacity: bodyData.size)
                body.write(bodyData)
                HttpResponse(status: HttpStatus.INTERNAL_SERVER_ERROR, headers: headers, body: body)
            }
        }
    }
}
