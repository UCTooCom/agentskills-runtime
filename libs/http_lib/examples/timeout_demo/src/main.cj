package sample_timeout_demo
/**
 * 超时演示 —— 演示 TimedHandler 和 SizeLimitHandler。
 *
 * 展示：
 * 1. TimedHandler —— 用超时包装慢处理器
 * 2. SizeLimitHandler —— 限制请求主体大小
 *
 * 运行：cjpm run
 * 测试：curl http://localhost:8086/
 *       curl http://localhost:8086/slow
 *       curl -X POST -d "small body" http://localhost:8086/echo
 *       curl -X POST -d "$(python3 -c 'print("A"*5000)')" http://localhost:8086/upload
 */

import http_lib.core.{HttpMethod, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig, TimedHandler, SizeLimitHandler}
import http_lib.router.Handler

main() {
    let router = Router()

    // 快速处理器 — 立即响应
    let fastHandler: Handler = {req: HttpRequest =>
        HttpResponse.text(HttpStatus.OK,
            "Fast response! This handler returns instantly.")
    }

    // 慢速处理器 — 通过休眠模拟延迟
    let slowHandler: Handler = {req: HttpRequest =>
        // 模拟慢速处理
        var i: Int64 = 0
        while (i < 10000000) { i += 1 }
        HttpResponse.text(HttpStatus.OK,
            "Slow response! This handler took some time.")
    }

    // 回显处理器 — 返回请求主体
    let echoHandler: Handler = {req: HttpRequest =>
        let body = req.bodyAsString()
        let resp = HttpResponse.text(HttpStatus.OK,
            "Received ${body.size} bytes:\n${body}")
        resp
    }

    // 上传处理器 — 返回主体大小
    let uploadHandler: Handler = {req: HttpRequest =>
        let bodySize = req.body.getLimit()
        HttpResponse.text(HttpStatus.OK,
            "Upload received. Size: ${bodySize} bytes.")
    }

    // 使用处理器注册路由
    router.get("/", fastHandler)

    // 用 500ms 超时包装慢速处理器
    // 如果未及时完成，返回 503
    router.get("/slow", TimedHandler(slowHandler,
        Duration.millisecond * 500,
        message: "Handler timed out after 500ms"))

    // 带 SizeLimitHandler 的回显 — 限制主体为 1024 字节
    router.post("/echo", SizeLimitHandler(echoHandler, 1024))

    // 带更大限制的上传（10KB）
    router.post("/upload", SizeLimitHandler(uploadHandler, 10240))

    // 同时具有超时和主体限制的路由
    let guardedHandler = SizeLimitHandler(
        TimedHandler({req =>
            var i: Int64 = 0
            while (i < 5000000) { i += 1 }
            HttpResponse.text(HttpStatus.OK, "Guarded handler completed.")
        }, Duration.second * 2),
        2048
    )
    router.get("/guarded", guardedHandler)

    let server = HttpServer(handler: router.handler(), config: HttpServerConfig())
    println("Timeout Demo server listening on http://localhost:8086")
    println("  Try: curl http://localhost:8086/")
    println("  Try: curl http://localhost:8086/slow")
    println("  Try: curl -X POST -d 'hello' http://localhost:8086/echo")
    println("  Try: curl -X POST -d '$(python3 -c \"print('A'*5000)\")' http://localhost:8086/upload")
    server.listenAndServe("0.0.0.0", 8086)
}
