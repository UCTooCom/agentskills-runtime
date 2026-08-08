/**
 * 双向 TLS（mTLS）服务器示例
 *
 * 演示带客户端证书认证的 HTTPS 服务器。
 * 需要服务器证书/密钥 + CA 证书用于客户端验证。
 *
 * 用法：
 * 首先生成证书（使用 openssl）：
 *     openssl req -x509 -newkey rsa:2048 -keyout server.key -out server.crt -days 365 -nodes
 *     openssl req -x509 -newkey rsa:2048 -keyout client.key -out client.crt -days 365 -nodes
 * 然后：
 *     cjpm build && ./target/release/bin/main
 * 测试方式：
 *     curl --cacert server.crt --cert client.crt --key client.key https://localhost:8443/
 */
package sample_mtls_server

import http_lib.core.*
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.router.{Router, Handler}
import http_lib.connection.{TlsConfig, TlsConnection, TlsServerConnection}
import http_lib.server.{HttpServer, HttpServerConfig}

main(): Int64 {
    // 使用 mTLS 配置 TLS
    let tlsConfig = TlsConfig()
    tlsConfig.serverCertPath = "server.crt"   // Server certificate
    tlsConfig.serverKeyPath = "server.key"    // Server private key
    tlsConfig.caCertPath = "ca.crt"           // CA cert to verify client certificates
    tlsConfig.verifyPeer = true               // Require and verify client cert
    tlsConfig.verifyHost = true

    let router = Router()
    router.get("/", {req =>
        // 显示客户端证书信息（如果可用）
        var body = "<h1>mTLS Secured Server</h1>"
        body = body + "<p>Client authenticated successfully!</p>"
        match (req.headers.get("x-ssl-client-dn")) {
            case Some(dn) => body = body + "<p>Client DN: ${dn}</p>"
            case None => ()
        }
        HttpResponse.html(HttpStatus.OK, body)
    })
    router.get("/public", {_ =>
        HttpResponse.text(HttpStatus.OK, "Public endpoint (still requires client cert)")
    })
    router.get("/health", {_ =>
        HttpResponse.json(HttpStatus.OK, "{\"status\":\"healthy\",\"tls\":\"mutual\"}")
    })

    let config = HttpServerConfig()
    config.tlsConfig = Some(tlsConfig)
    config.serverName = "mTLSDemo/1.0"
    config.enableHttp2 = false  // HTTP/1.1 only for simplicity

    let server = HttpServer(handler: router.handler(), config: config)

    println("=== mTLS Server ===")
    println("Listening on https://localhost:8443")
    println("Requires client certificate for all endpoints.")
    println("Test: curl --cacert server.crt --cert client.crt --key client.key https://localhost:8443/")

    server.listenAndServeTls("0.0.0.0", 8443)
    0
}
