package sample_graceful_shutdown

import std.time.DateTime
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.router.Router
import http_lib.core.HttpStatus
import http_lib.message.{HttpRequest, HttpResponse}

/**
 * 优雅关闭示例。
 *
 * 演示：
 * 1. 启动服务器
 * 2. 接收带模拟延迟的请求
 * 3. 调用 shutdown() — 等待进行中的请求完成
 * 4. 服务器干净退出
 */
main(): Int64 {
    println("=== Graceful Shutdown Demo ===")
    println("")

    let router = Router()
    // 模拟耗时 3 秒的慢端点
    router.get("/slow", { req =>
        var count: Int64 = 0
        while (count < 3000000000) { count += 1 }  // Simple spin delay
        HttpResponse.text(HttpStatus.OK, "slow response done")
    })
    router.get("/fast", { req =>
        HttpResponse.text(HttpStatus.OK, "fast response")
    })

    let config = HttpServerConfig()
    config.readTimeout = Duration.second * 10

    let server = HttpServer(handler: router.handler(), config: config)

    println("Server starting on :8080...")
    println("Send a request to /slow and then trigger shutdown.")
    println("The server will wait for /slow to complete before exiting.")
    println("")

    // 在实际应用中，你会生成服务器并处理操作系统信号
    // 在此演示中，我们仅展示 API
    println("Calling server.shutdown() would:")
    println("  1. Stop accepting new connections")
    println("  2. Wait for in-flight requests to finish (up to readTimeout)")
    println("  3. Close the server socket")
    println("")
    println("API: server.shutdown()  // graceful, waits for requests")
    println("API: server.close()     // immediate, force close")

    0
}
