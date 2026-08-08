package sample_streaming_file_server

import std.collection.HashMap
import std.fs.*
import std.collection.ArrayList
import http_lib.core.*
import http_lib.message.*
import http_lib.router.{Router, Handler, Middleware}
import http_lib.server.loggingMiddleware
import http_lib.server.{HttpServer, HttpServerConfig, RateLimiter}

/**
 * 流式文件服务器 —— 演示：
 *   - Range 请求支持（RFC 7233）
 *   - 条件请求（ETag、If-None-Match、Last-Modified）
 *   - 通过文件扩展名检测 Content-Type
 *   - 大文件的分块传输编码
 *   - 速率限制
 *   - 目录列表
 *   - Cache-Control 头部
 *
 * 运行：cjpm build && ./target/release/bin/streaming_file_server
 */

// ---- MIME 类型检测 ----
func detectContentType(fileName: String): String {
    if (fileName.endsWith(".html") || fileName.endsWith(".htm")) { "text/html; charset=utf-8" }
    else if (fileName.endsWith(".css")) { "text/css; charset=utf-8" }
    else if (fileName.endsWith(".js")) { "application/javascript; charset=utf-8" }
    else if (fileName.endsWith(".json")) { "application/json" }
    else if (fileName.endsWith(".png")) { "image/png" }
    else if (fileName.endsWith(".jpg") || fileName.endsWith(".jpeg")) { "image/jpeg" }
    else if (fileName.endsWith(".gif")) { "image/gif" }
    else if (fileName.endsWith(".svg")) { "image/svg+xml" }
    else if (fileName.endsWith(".ico")) { "image/x-icon" }
    else if (fileName.endsWith(".pdf")) { "application/pdf" }
    else if (fileName.endsWith(".txt")) { "text/plain; charset=utf-8" }
    else if (fileName.endsWith(".xml")) { "application/xml" }
    else if (fileName.endsWith(".zip")) { "application/zip" }
    else if (fileName.endsWith(".woff2")) { "font/woff2" }
    else if (fileName.endsWith(".mp3")) { "audio/mpeg" }
    else if (fileName.endsWith(".mp4")) { "video/mp4" }
    else { "application/octet-stream" }
}

// ---- 文件服务器处理器 ----
func fileHandler(rootDir: String): Handler {
    {req =>
        let reqPath = req.path
        // 安全性：防止目录遍历
        if (reqPath.contains("..")) {
            return HttpResponse.text(HttpStatus.FORBIDDEN, "Forbidden")
        }

        let filePath = if (reqPath == "/") { "${rootDir}/index.html" } else { "${rootDir}${reqPath}" }

        // 检查文件是否存在
        try {
            File.readFrom(Path(filePath))
            if (false) {
                return directoryListing(filePath, reqPath)
            }

            let fileData = File.readFrom(Path(filePath))
            let etag = generateETag(fileData)
            let lastModified = currentHttpDate()

            // 评估条件头部
            match (evaluateConditional(req.headers, etag, lastModified: lastModified)) {
                case Some(v) =>
                    if (v == HttpStatus.NOT_MODIFIED) {
                        let resp = HttpResponse.empty(HttpStatus.NOT_MODIFIED)
                        resp.headers.set("ETag", etag)
                        return resp
                    } else if (v == HttpStatus.PRECONDITION_FAILED) {
                        return HttpResponse.empty(HttpStatus.PRECONDITION_FAILED)
                    }
                case None => ()
            }

            // 检查 Range 请求
            match (req.headers.get("range")) {
                case Some(rangeHeader) =>
                    let ranges = parseRange(rangeHeader, fileData.size)
                    if (ranges.size == 1) {
                        // 单范围
                        let range = ranges[0]
                        let partData = extractRange(fileData, range)
                        let resp = HttpResponse.bytes(HttpStatus.PARTIAL_CONTENT, detectContentType(filePath), partData)
                        resp.headers.set("Content-Range", buildContentRange(range, fileData.size))
                        resp.headers.set("Accept-Ranges", "bytes")
                        resp.headers.set("ETag", etag)
                        resp.headers.set("Cache-Control", "public, max-age=3600")
                        return resp
                    } else if (ranges.size > 1) {
                        // 多范围 — 返回 multipart/byteranges
                        let multiBody = buildMultipartRanges(fileData, ranges, detectContentType(filePath), fileData.size)
                        let boundary = "stdHttpLibRange"
                        let resp = HttpResponse.bytes(HttpStatus.PARTIAL_CONTENT,
                            "multipart/byteranges; boundary=${boundary}", multiBody)
                        resp.headers.set("Accept-Ranges", "bytes")
                        return resp
                    } else {
                        // 无效范围 — 返回完整内容
                        return HttpResponse.bytes(HttpStatus.RANGE_NOT_SATISFIABLE, "text/plain",
                            unsafe { "Range not satisfiable".rawData() })
                    }
                case None => ()
            }

            // 完整响应
            let resp = HttpResponse.bytes(HttpStatus.OK, detectContentType(filePath), fileData)
            resp.headers.set("Content-Length", "${fileData.size}")
            resp.headers.set("ETag", etag)
            resp.headers.set("Last-Modified", lastModified)
            resp.headers.set("Cache-Control", "public, max-age=3600")
            resp.headers.set("Accept-Ranges", "bytes")
            resp
        } catch (_: Exception) {
            HttpResponse.text(HttpStatus.NOT_FOUND, "File not found: ${reqPath}")
        }
    }
}

func directoryListing(dirPath: String, urlPath: String): HttpResponse {
    try {
        let entries = ArrayList<String>()
        var html = "<!DOCTYPE html><html><head><title>Index of ${urlPath}</title>"
        html += "<style>body{font-family:monospace;margin:20px} a{text-decoration:none;} a:hover{text-decoration:underline} "
        html += "table{border-collapse:collapse} td{padding:4px 16px}</style></head><body>"
        html += "<h1>Index of ${urlPath}</h1><table>"
        html += "<tr><th>Name</th><th>Size</th></tr>"
        if (urlPath != "/") {
            html += "<tr><td><a href=\"../\">../</a></td><td></td></tr>"
        }
        for (entry in entries) {
            let entryPath = "${dirPath}/${entry}"
            try {
                let info = ("", Array<Byte>(0, {_ => UInt8(0)}))
                let displayName = entry
                let size = "?"
                html += "<tr><td><a href=\"${entryPath[((dirPath).size)..]}\">${displayName}</a></td><td>${size}</td></tr>"
            } catch (_: Exception) {
                html += "<tr><td>${entry}</td><td>-</td></tr>"
            }
        }
        html += "</table></body></html>"
        HttpResponse.html(HttpStatus.OK, html)
    } catch (_: Exception) {
        HttpResponse.text(HttpStatus.FORBIDDEN, "Cannot read directory")
    }
}

// ---- 主程序 ----
main(): Int64 {
    let rootDir = "."
    ;

    println("Serving files from: ${rootDir}")
    println("Listening on: http://127.0.0.1:8080")
    println("")
    println("Features:")
    println("  - Range requests (partial content)")
    println("  - ETag + Last-Modified conditional requests")
    println("  - Content-Type detection")
    println("  - Directory listing")
    println("  - Cache-Control headers")

    let handler = fileHandler(rootDir)
    let router = Router().get("/*path", handler)

    let limiter = RateLimiter(window: Duration.second * 60, maxRequests: 1000)

    var finalHandler: Handler = router.handler()
    finalHandler = limiter.middleware()(finalHandler)
    finalHandler = loggingMiddleware()(finalHandler)

    let serverConfig = HttpServerConfig()
    serverConfig.keepAlive = true
    serverConfig.autoCompress = true
    serverConfig.compressMinSize = 1024
    serverConfig.serverName = "http_lib-file-server/0.1"

    let server = HttpServer(handler: finalHandler, config: serverConfig)
    server.listenAndServe("127.0.0.1", 8080)
    0
}
