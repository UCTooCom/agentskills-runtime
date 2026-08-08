package sample_http2_client

import std.collection.HashMap
import http_lib.client.{HttpClient, HttpClientConfig, HttpRequestBuilder}
import http_lib.connection.TlsConfig

/**
 * HTTP/2 客户端示例 — 演示单个连接上的多路复用请求。
 */
main(): Int64 {
    println("=== HTTP/2 Client Demo ===")
    println("")

    let tlsConfig = TlsConfig.default()
    tlsConfig.nextProtos = ["h2"]  // Request HTTP/2

    let config = HttpClientConfig()
    config.enableHttp2 = true
    config.tlsConfig = tlsConfig
    config.connectionPoolEnabled = true
    config.maxConnectionsPerHost = 1  // Force single connection for multiplexing demo

    let client = HttpClient(config: config)

    // 多个请求在单个 HTTP/2 连接上多路复用
    println("Sending 5 concurrent requests over HTTP/2...")
    var i: Int64 = 0
    while (i < 5) {
        let resp = client.get("https://http2.example.com/api/resource/${i}")
        println("  Request ${i}: ${resp.status}")
        i += 1
    }

    client.close()
    println("")
    println("Done.")
    0
}
