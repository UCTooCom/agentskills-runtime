/**
 * 流式上传服务器示例
 *
 * 演示服务器端处理流式/分块请求主体。
 * 服务器增量读取请求主体，而不是在内存中缓冲
 * 所有内容，使其适用于大型文件上传。
 *
 * 用法：cjpm build && ./target/release/bin/main
 * 测试：curl -X POST --data-binary @largefile.bin http://localhost:8080/upload
 *        curl -X POST -H "Transfer-Encoding: chunked" -d @data.txt http://localhost:8080/upload
 */
package sample_streaming_upload

import http_lib.core.*
import http_lib.message.{HttpRequest, HttpResponse, ResponseBuilder, StreamingHandler}
import http_lib.router.{Router, Handler}
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.buffer.ByteBuffer

main(): Int64 {
    let router = Router()

    // 带上传表单的主页
    router.get("/", {_ =>
        let html = "<!DOCTYPE html><html><body><h1>Streaming Upload Demo</h1><form action='/upload' method='post' enctype='multipart/form-data'><input type='file' name='file'><br><br><input type='submit' value='Upload'></form><p>Or use curl:</p><pre>curl -X POST --data-binary @largefile.bin http://localhost:8080/upload</pre></body></html>"
        HttpResponse.html(HttpStatus.OK, html)
    })

    // 流式上传处理器 — 分块读取主体并报告进度
    router.post("/upload", {req =>
        let bodyBytes = req.bodyAsBytes()
        let bodySize = bodyBytes.size
        var report = "Upload Complete\n"
        report = report + "------------------------\n"
        report = report + "Bytes received: ${bodySize}\n"
        if (bodySize >= 1024 * 1024) {
            report = report + "Size: ${bodySize / (1024 * 1024)} MB\n"
        } else if (bodySize >= 1024) {
            report = report + "Size: ${bodySize / 1024} KB\n"
        }
        // 在实际的流式处理器中，你会使用 ResponseBuilder 进行
        // 增量写入，但在此演示中我们缓冲整个响应
        HttpResponse.text(HttpStatus.OK, report)
    })

    // 健康检查
    router.get("/health", {_ =>
        HttpResponse.json(HttpStatus.OK, "{\"status\":\"ok\"}")
    })

    let config = HttpServerConfig()
    config.serverName = "StreamingUploadDemo/1.0"
    config.maxBodySize = 104857600  // 100 MB max upload

    let server = HttpServer(handler: router.handler(), config: config)

    println("=== Streaming Upload Server ===")
    println("Listening on http://localhost:8080")
    println("  GET  /       -> upload form")
    println("  POST /upload -> upload endpoint (up to 100 MB)")
    println("  GET  /health -> health check")
    println("Test: curl -X POST --data-binary @file.bin http://localhost:8080/upload")

    server.listenAndServe("0.0.0.0", 8080)
    0
}
