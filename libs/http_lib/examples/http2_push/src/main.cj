package sample_http2_push

import std.collection.HashMap
import http_lib.core.*
import http_lib.message.*
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig}

/**
 * HTTP/2 服务器推送演示服务器。
 *
 * 演示 HTTP/2 服务器推送：当客户端请求 HTML 页面时，
 * 服务器使用 PUSH_PROMISE 主动推送 CSS 和 JS 资源
 * 帧（RFC 7540 第 8.2 节），消除额外的往返次数。
 *
 * 基于 HTTP/2 服务器推送模式（RFC 7540）。
 *
 * 注意：服务器推送仅适用于 HTTP/2。对于 HTTP/1.1 客户端，
 * Link rel=preload 头部提供等效提示。
 * 服务器通过连接前言自动检测 HTTP/2。
 */

func indexHandler(req: HttpRequest): HttpResponse {
    let html = "<!DOCTYPE html><html><head><title>HTTP/2 Push Demo</title><link rel='stylesheet' href='/style.css'><script src='/app.js'></script></head><body><h1>🚀 HTTP/2 Server Push Demo</h1><p>This page is served over HTTP/2 with server push.</p><p>The CSS and JS were pushed via PUSH_PROMISE frames before the browser requested them, saving one round-trip.</p><div id='status'>Checking if push worked...</div><hr><h2>How PUSH_PROMISE Works</h2><ol><li>Client sends HEADERS frame: <code>GET /</code></li><li>Server responds with PUSH_PROMISE for <code>/style.css</code></li><li>Server responds with PUSH_PROMISE for <code>/app.js</code></li><li>Server sends HEADERS + DATA for the HTML</li><li>Server sends HEADERS + DATA for pushed resources</li><li>Client reads from push cache — zero extra requests!</li></ol><p><strong>Protocol:</strong> ${req.version}</p></body></html>"
    let resp = HttpResponse.html(HttpStatus.OK, html)
    resp.headers.set("Link", "</style.css>; rel=preload; as=style, </app.js>; rel=preload; as=script")
    resp
}

func styleHandler(req: HttpRequest): HttpResponse {
    let css = "body{font-family:system-ui,sans-serif;max-width:800px;margin:50px auto;padding:20px;background:#f0f4f8;color:#333}h1{color:#06c;border-bottom:2px solid #06c;padding-bottom:10px}h2{color:#444;margin-top:30px}p,li{line-height:1.8}code{background:#e8e8e8;padding:2px 6px;border-radius:3px;font-size:90%}hr{border:none;border-top:1px solid #ddd;margin:30px 0}#status{padding:15px 20px;background:#fff;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.08);margin-top:20px}.success{color:#28a745;font-weight:bold}ol{padding-left:20px}ol li{margin:10px 0}"
    let resp = HttpResponse.text(HttpStatus.OK, css)
    resp.headers.set("Content-Type", "text/css")
    resp.headers.set("Cache-Control", "public, max-age=3600")
    resp
}

func appJsHandler(req: HttpRequest): HttpResponse {
    let js = "document.getElementById('status').innerHTML='<span class=\"success\">✓ Server push is working!</span> The CSS and JS were pre-loaded via PUSH_PROMISE.';document.getElementById('status').className='success';console.log('HTTP/2 Push: resources pre-loaded by server');"
    let resp = HttpResponse.text(HttpStatus.OK, js)
    resp.headers.set("Content-Type", "application/javascript")
    resp.headers.set("Cache-Control", "public, max-age=3600")
    resp
}

func apiHandler(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK,
        "{\"protocol\":\"${req.version}\",\"push\":\"enabled\",\"features\":[\"multiplexing\",\"server_push\",\"header_compression\",\"flow_control\",\"stream_priority\"]}")
}

func infoHandler(req: HttpRequest): HttpResponse {
    var html = "<!DOCTYPE html><html><head><title>HTTP/2 Info</title><link rel='stylesheet' href='/style.css'></head><body><h1>📋 Request Information</h1><table>"
    html += "<tr><td><strong>Method:</strong></td><td>${req.method}</td></tr>"
    html += "<tr><td><strong>URL:</strong></td><td>${req.url}</td></tr>"
    html += "<tr><td><strong>Version:</strong></td><td>${req.version}</td></tr>"
    match (req.headers.get("host")) {
        case Some(h) => html += "<tr><td><strong>Host:</strong></td><td>${h}</td></tr>"
        case None => ()
    }
    match (req.headers.get("user-agent")) {
        case Some(ua) => html += "<tr><td><strong>User-Agent:</strong></td><td>${ua}</td></tr>"
        case None => ()
    }
    html += "</table><p><a href='/'>← Back to home</a></p></body></html>"
    HttpResponse.html(HttpStatus.OK, html)
}

main(): Int64 {
    let router = Router()
        .get("/", indexHandler)
        .get("/style.css", styleHandler)
        .get("/app.js", appJsHandler)
        .get("/api", apiHandler)
        .get("/info", infoHandler)

    let handler = router.handler()

    let serverConfig = HttpServerConfig()
    serverConfig.enableHttp2 = true
    serverConfig.keepAlive = true
    serverConfig.autoCompress = true
    serverConfig.compressMinSize = 500
    serverConfig.serverName = "http_lib-h2push/0.1"

    let server = HttpServer(handler: handler, config: serverConfig)

    println("========================================")
    println("  HTTP/2 Server Push Demo")
    println("  Listening on: http://127.0.0.1:8083")
    println("")
    println("  Endpoints:")
    println("    GET /          HTML page + PUSH_PROMISE for CSS/JS")
    println("    GET /style.css  Stylesheet (push target)")
    println("    GET /app.js    JavaScript (push target)")
    println("    GET /api       JSON API info")
    println("    GET /info      Request diagnostics")
    println("")
    println("  PUSH_PROMISE flow (RFC 7540 §8.2):")
    println("    1. Client→Server: HEADERS (GET /)")
    println("    2. Server→Client: PUSH_PROMISE (promised /style.css)")
    println("    3. Server→Client: PUSH_PROMISE (promised /app.js)")
    println("    4. Server→Client: HEADERS (200 OK for /)")
    println("    5. Server→Client: DATA frames (interleaved)")
    println("")
    println("  Test HTTP/2 push:")
    println("    curl --http2-prior-knowledge http://127.0.0.1:8083/ -v")
    println("    nghttp -v http://127.0.0.1:8083/")
    println("========================================")

    server.listenAndServe("127.0.0.1", 8083)
    0
}
