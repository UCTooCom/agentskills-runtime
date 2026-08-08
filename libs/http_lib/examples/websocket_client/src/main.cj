/**
 * WebSocket 客户端示例
 *
 * 演示使用 ConnectionController API 连接 WebSocket 服务器
 * 在 HTTP 升级握手后。发送消息并读取响应。
 *
 * 用法：cjpm build && ./target/release/bin/main
 * 连接至：ws://localhost:8080/chat（先运行 websocket_chat 示例服务器）
 */
package sample_websocket_client

import http_lib.client.{HttpClient, HttpClientConfig, HttpRequestBuilder}
import http_lib.core.*
import http_lib.message.{HttpRequest, HttpResponse}

main(): Int64 {
    println("WebSocket Client Sample")
    println("=======================")
    println("This sample demonstrates WebSocket upgrade handshake.")
    println("Run websocket_chat sample server in another terminal first:")
    println("  cd sample/websocket_chat && cjpm build && ./target/release/bin/main")
    println("")

    // 构建 WebSocket 升级请求
    let key = "dGhlIHNhbXBsZSBub25jZQ=="
    let req = HttpRequestBuilder()
        .get().withUrl("http://localhost:8080/chat")
        .withHeader("Upgrade", "websocket")
        .withHeader("Connection", "Upgrade")
        .withHeader("Sec-WebSocket-Key", key)
        .withHeader("Sec-WebSocket-Version", "13")
        .build()

    let config = HttpClientConfig()
    config.followRedirects = false
    let client = HttpClient(config: config)

    println("Sending WebSocket upgrade request...")
    try {
        let resp = client.send(req)
        if (resp.status.code == 101u16) {
            println("✅ Upgrade successful! Status: 101 Switching Protocols")
            match (resp.headers.get("Sec-WebSocket-Accept")) {
                case Some(accept) => println("   Sec-WebSocket-Accept: ${accept}")
                case None => println("   Warning: Missing Sec-WebSocket-Accept header")
            }
        } else {
            println("❌ Upgrade failed. Status: ${resp.status.code}")
            println("   Body: ${resp.bodyAsString()}")
        }
    } catch (e: Exception) {
        println("❌ Connection failed: ${e.message}")
        println("   Make sure the WebSocket server is running on port 8080")
    }

    client.close()
    0
}
