package http_lib.server
/**
 * 请求超时中间件。限制单个请求的最大处理时间。
 */

/**
 * 请求超时控制中间件。
 * 包装 HTTP Handler，若处理时间超过设定的超时阈值，
 * 自动返回 408 Request Timeout 响应。
 */

import std.collection.ArrayList
import std.sync.{Mutex, AtomicBool}
import std.time.DateTime
import http_lib.core.{HttpHeaders, HttpStatus, HttpMethod}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Handler

/**
 * 超时处理器（为 HTTP 处理器添加真实超时）。
 *
 * TimedHandler 模式。
 * 处理器在单独的生成线程中运行。若未能在指定持续时间内
 * 完成，则返回 503 Service Unavailable 响应。处理器线程继续
 * 运行但其响应被丢弃。
 *
 * 用法：
 *   let handler = TimedHandler(myHandler, Duration.second * 5, "请求超时")
 *   router.get("/slow", handler)
 */
public func TimedHandler(
    handler: Handler,
    timeout: Duration,
    message!: String = "Service Unavailable"
): Handler {
    {req: HttpRequest =>
        let completed = AtomicBool(false)
        let mutex = Mutex()
        let sharedResponse = ArrayList<HttpResponse>()
        let h = handler

        // 创建子上下文，超时时通过取消机制通知处理协程停止
        let childCtx = req.ctx.createChild()
        childCtx.onCancel({ =>
            completed.store(true)
        })

        // 在单独的线程中运行处理器
        spawn {
            // 将子上下文设置到请求中，使处理器能检查 isCancelled()
            req.ctx = childCtx
            let result = try {
                h(req)
            } catch (e: Exception) {
                HttpResponse.text(HttpStatus.INTERNAL_SERVER_ERROR, e.message)
            }
            mutex.lock()
            sharedResponse.add(result)
            mutex.unlock()
            completed.store(true)
        }

        // 自适应轮询：通过根据剩余时间调整休眠来减少唤醒。
        // 短处理器获得快速响应；长处理器避免浪费 CPU。
        let startTime = DateTime.now()
        var iter = 0
        while (!completed.load()) {
            let elapsed = DateTime.now() - startTime
            if (elapsed > timeout) {
                // 超时已过期 — 通过子上下文取消通知处理协程停止
                childCtx.cancel(reason: "timeout")
                return HttpResponse.text(HttpStatus.SERVICE_UNAVAILABLE, message)
            }
            // 自适应休眠：初始 5ms，长轮询时增至 100ms。
            // 这为快速处理器提供约 5ms 的最坏延迟，同时避免
            // 固定 10ms 间隔的 100Hz 繁忙唤醒。
            var sleepMs: Int64 = 5 + iter * 5  // 5 毫秒、10 毫秒、15 毫秒……
            if (sleepMs > 100) { sleepMs = 100 }  // 上限 100ms
            sleep(sleepMs * Duration.millisecond)
            iter += 1
        }

        // 处理器在超时内完成 — 返回其响应
        mutex.lock()
        let resp = if (sharedResponse.size > 0) {
            sharedResponse[0]
        } else {
            HttpResponse.text(HttpStatus.SERVICE_UNAVAILABLE, message)
        }
        mutex.unlock()
        resp
    }
}

/**
 * 请求体大小限制处理器。
 *
 * SizeLimitHandler 模式。
 * 如果请求体超过 maxBytes，返回 413 Payload Too Large
 * 返回响应。
 *
 * 用法：
 *   let handler = SizeLimitHandler(myHandler, 1024 * 1024)  // 限制 1MB
 *   router.get("/upload", handler)
 */
public func SizeLimitHandler(
    handler: Handler,
    maxBytes: Int64
): Handler {
    {req: HttpRequest =>
        let bodySize = req.body.getLimit()
        if (bodySize > maxBytes) {
            return HttpResponse.text(HttpStatus.PAYLOAD_TOO_LARGE,
                "Request body exceeds maximum size of ${maxBytes} bytes")
        }
        handler(req)
    }
}
