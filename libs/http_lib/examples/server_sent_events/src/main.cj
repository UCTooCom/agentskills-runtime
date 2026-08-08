/**
 * 服务器发送事件（SSE）示例
 *
 * 演示使用分块传输编码的流式事件。
 * 服务器向客户端发送事件流。
 *
 * 用法：cjpm build && ./target/release/bin/main
 * 测试：curl -N http://localhost:8090/events
 */
package sample_server_sent_events

import std.time.DateTime
import http_lib.core.*
import http_lib.message.*
import http_lib.router.{Router, Handler}
import http_lib.server.{HttpServer, HttpServerConfig}

func eventsHandler(req: HttpRequest): HttpResponse {
    // 使用分块传输编码的 SSE 响应
    let resp = HttpResponse.chunked(HttpStatus.OK)
    resp.headers.set("Content-Type", "text/event-stream")
    resp.headers.set("Cache-Control", "no-cache")
    resp.headers.set("Connection", "keep-alive")
    resp
}

main() {
    println("SSE Server starting on http://localhost:8090/events")
    println("Test: curl -N http://localhost:8090/events")
    
    let router = Router()
    router.get("/events", eventsHandler)

    let server = HttpServer(handler: router.handler())
    server.listenAndServe("0.0.0.0", 8090)
}
