package sample_https_server

import std.collection.{HashMap, ArrayList}
import http_lib.core.*
import http_lib.message.*
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.connection.{TlsConfig}

/**
 * HTTPS 服务器示例，演示 TLS 加密。
 *
 * 需要 TLS 证书。用于测试时，生成自签名证书：
 * openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=localhost"
 *
 * 演示的功能：
 * - TLS 1.2 加密
 * - 通过 TLS 支持 HTTP/2
 * - 自动压缩
 * - 安全头部
 */

func helloHandler(req: HttpRequest): HttpResponse {
    let body = "Hello, Secure World! You requested: ${req.method} ${req.url}"
    HttpResponse.html(HttpStatus.OK, "<html><body><h1>${body}</h1><p>Served over TLS</p></body></html>")
}

func jsonEchoHandler(req: HttpRequest): HttpResponse {
    let body = req.bodyAsString()
    HttpResponse.json(HttpStatus.OK, "{\"echo\":\"${body}\",\"secure\":true}")
}

main(): Int64 {
    // 配置 TLS
    let tlsConfig = TlsConfig()
    tlsConfig.serverCertPath = "cert.pem"
    tlsConfig.serverKeyPath = "key.pem"
    tlsConfig.enableDiagnostics = true

    // 构建路由器
    let router = Router()
        .get("/", helloHandler)
        .post("/echo", jsonEchoHandler)

    let handler = router.handler()

    // 带 TLS 和 HTTP/2 的服务器配置
    let serverConfig = HttpServerConfig()
    serverConfig.tlsConfig = Some(tlsConfig)
    serverConfig.enableHttp2 = true
    serverConfig.autoCompress = true
    serverConfig.serverName = "http_lib-https/0.1"
    serverConfig.keepAlive = true

    let server = HttpServer(handler: handler, config: serverConfig)

    println("========================================")
    println("  HTTPS Server Sample")
    println("  Listening on: https://127.0.0.1:8443")
    println("")
    println("  Test with:")
    println("    curl -k https://127.0.0.1:8443/")
    println("    curl -k -X POST -d 'hello' https://127.0.0.1:8443/echo")
    println("")
    println("  Note: Requires cert.pem and key.pem in working directory")
    println("========================================")

    server.listenAndServeTls("127.0.0.1", 8443)
    0
}
