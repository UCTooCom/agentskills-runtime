/**
 * HTTP/3（QUIC）服务器示例。
 *
 * 演示基于 HTTP/3（HTTP over QUIC）的服务器 API。
 * HTTP/3 使用 QUIC（RFC 9000）作为传输层，提供：
 *   - 0-RTT 连接建立
 *   - 内置 TLS 1.3 加密
 *   - 无队头阻塞的多路复用
 *   - 更快的连接迁移
 *
 * 运行本示例需要外部 QUIC 传输实现（如 quic-go 适配器）
 * 提供 QuicTransportFactory 接口的具体实现。
 *
 * 适用场景：
 *   1）需要极低延迟连接建立的实时应用
 *   2）网络切换频繁的移动端服务
 *   3）需要最大化并发性能的 API 服务
 */

package sample_http3_server

import http_lib.core.*
import http_lib.message.*
import http_lib.router.Router
import http_lib.http3.{Http3Server, Http3ServerConfig, H3TlsConfig, QuicTransportFactory}

/**
 * 首页处理器：返回服务器信息和文档链接。
 */
func indexHandler(req: HttpRequest): HttpResponse {
    let html = "<!DOCTYPE html>\n" +
        "<html lang=\"zh-CN\">\n" +
        "<head><meta charset=\"UTF-8\"><title>HTTP/3 Server Demo</title>" +
        "<style>body{font-family:-apple-system,sans-serif;max-width:800px;margin:50px auto;padding:20px}" +
        "h1{color:#1a73e8}.info{background:#f8f9fa;padding:15px;border-radius:8px;margin:10px 0}" +
        "code{background:#e8eaed;padding:2px 6px;border-radius:4px}</style></head>\n" +
        "<body>\n" +
        "<h1>HTTP/3 Server Demo</h1>\n" +
        "<div class=\"info\">\n" +
        "<p>Protocol: <strong>HTTP/3 (QUIC)</strong></p>\n" +
        "<p>Transport: <strong>QUIC (RFC 9000)</strong></p>\n" +
        "<p>Encryption: <strong>TLS 1.3</strong></p>\n" +
        "<p>Connection: <strong>0-RTT</strong></p>\n" +
        "</div>\n" +
        "<p>本服务运行在 HTTP/3 之上。</p>\n" +
        "</body>\n</html>"
    HttpResponse.html(HttpStatus.OK, html)
}

/**
 * API 信息处理器。
 */
func apiInfoHandler(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK, "{" +
        "\"service\":\"http_lib-http3\"," +
        "\"version\":\"0.1.0\"," +
        "\"protocol\":\"HTTP/3\"," +
        "\"transport\":\"QUIC (RFC 9000)\"," +
        "\"encryption\":\"TLS 1.3\"}")
}

/**
 * 数据回显处理器。
 */
func echoHandler(req: HttpRequest): HttpResponse {
    let body = req.bodyAsString()
    let method = req.method.toString()
    let url = req.url
    HttpResponse.json(HttpStatus.OK, "{" +
        "\"method\":\"${method}\"," +
        "\"url\":\"${url}\"," +
        "\"body\":\"${body}\"," +
        "\"protocol\":\"HTTP/3\"}")
}

/**
 * 健康检查处理器。
 */
func healthHandler(req: HttpRequest): HttpResponse {
    HttpResponse.json(HttpStatus.OK, "{" +
        "\"status\":\"healthy\"," +
        "\"protocol\":\"h3\"}")
}

/**
 * 主函数。
 */
main(): Int64 {
    println("========================================")
    println("  http_lib HTTP/3 Server 示例")
    println("========================================")
    println("")
    println("本示例展示 Http3Server API 的使用方式。")

    // 构建路由器
    let router = Router()
        .get("/", indexHandler)
        .get("/api", apiInfoHandler)
        .get("/health", healthHandler)
        .post("/echo", echoHandler)

    let handler = router.handler()

    // 配置 HTTP/3 服务器
    let serverConfig = Http3ServerConfig()
    serverConfig.serverName = "http_lib-h3/0.1"

    let server = Http3Server(handler, config: serverConfig)

    // 配置 TLS（HTTP/3 需要 TLS 1.3）
    let tlsConfig = H3TlsConfig()
    tlsConfig.serverCertPath = "cert.pem"
    tlsConfig.serverKeyPath = "key.pem"
    server.setTlsConfig(tlsConfig)

    println("")
    println("  ! 本示例需要外部 QUIC 传输实现")
    println("")
    println("  使用步骤：")
    println("    1. 准备 QUIC 传输适配器实现 QuicTransportFactory 接口")
    println("    2. 调用 server.setTransportFactory(myFactory) 注入")
    println("    3. 生成 TLS 证书：")
    println("       openssl req -x509 -newkey rsa:4096 \\")
    println("         -keyout key.pem -out cert.pem \\")
    println("         -days 365 -nodes -subj '/CN=localhost'")
    println("    4. 启动服务器")
    println("")
    println("  测试命令：")
    println("       curl --http3 https://127.0.0.1:4433/")
    println("       curl --http3 https://127.0.0.1:4433/api")
    println("")

    // 实际使用中请先设置 transportFactory 再启动：
    // server.setTransportFactory(myQuicTransportFactory)
    // server.listenAndServe("127.0.0.1", 4433)

    0
}
