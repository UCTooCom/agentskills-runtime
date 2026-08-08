/**
 * WebSocket 客户端单元测试。
 */
package http_lib.client

import http_lib.core.{assertTrue, assertFalse}
import std.collection.ArrayList

@Test
internal class WebSocketClientTest {
    /**
     * 测试 generateWebSocketKey 生成正确格式的 Base64 key。
     */
    @TestCase
    public func testGenerateWebSocketKey(): Unit {
        let client = WebSocketClient()
        let key1 = client.generateWebSocketKey()
        let key2 = client.generateWebSocketKey()
        assertTrue(key1.size > 0, message: "key should not be empty")
        assertTrue(key1 != key2, message: "consecutive keys should differ")
    }

    /**
     * 测试 ws:// URL 解析。
     */
    @TestCase
    public func testParseWsUrl(): Unit {
        let client = WebSocketClient()
        let (host, port, path) = client.parseWebSocketUrl("echo.example.com/chat", 80u16)
        assertTrue(host == "echo.example.com", message: "host mismatch: ${host}")
        assertTrue(port == 80u16, message: "port should be 80")
        assertTrue(path == "/chat", message: "path mismatch: ${path}")
    }

    /**
     * 测试 URL 解析带端口号的。
     */
    @TestCase
    public func testParseUrlWithPort(): Unit {
        let client = WebSocketClient()
        let (host, port, path) = client.parseWebSocketUrl("secure.example.com:4433/ws", 443u16)
        assertTrue(host == "secure.example.com", message: "host mismatch: ${host}")
        assertTrue(port == 4433u16, message: "port should be 4433")
        assertTrue(path == "/ws", message: "path mismatch: ${path}")
    }

    /**
     * 测试 URL 解析不带路径时默认 /。
     */
    @TestCase
    public func testParseUrlDefaultPath(): Unit {
        let client = WebSocketClient()
        let (host, port, path) = client.parseWebSocketUrl("example.com", 443u16)
        assertTrue(path == "/", message: "default path should be /")
    }

    /**
     * 测试构建 Upgrade 请求。
     */
    @TestCase
    public func testBuildUpgradeRequest(): Unit {
        let client = WebSocketClient()
        let key = "dGhlIHNhbXBsZSBub25jZQ=="
        let protocols = ArrayList<String>()
        protocols.add("chat")
        let request = client.buildUpgradeRequest("echo.example.com", "/chat", key, "", protocols)
        let requestStr = String.fromUtf8(request)

        assertTrue(requestStr.contains("GET /chat HTTP/1.1"), message: "should start with GET")
        assertTrue(requestStr.contains("Host: echo.example.com"), message: "should have Host")
        assertTrue(requestStr.contains("Upgrade: websocket"), message: "should have Upgrade")
        assertTrue(requestStr.contains("Connection: Upgrade"), message: "should have Connection")
        assertTrue(requestStr.contains("Sec-WebSocket-Key: ${key}"), message: "should have Sec-WebSocket-Key")
        assertTrue(requestStr.contains("Sec-WebSocket-Version: 13"), message: "should have version 13")
        assertTrue(!requestStr.contains("Origin:"), message: "should not have Origin when empty")
        assertTrue(requestStr.contains("Sec-WebSocket-Protocol: chat"), message: "should have protocol")
    }

    /**
     * 测试构建带 Origin 的 Upgrade 请求。
     */
    @TestCase
    public func testBuildUpgradeWithOrigin(): Unit {
        let client = WebSocketClient()
        let key = "dGhlIHNhbXBsZSBub25jZQ=="
        let request = client.buildUpgradeRequest("example.com", "/", key, "https://example.com", ArrayList<String>())
        let requestStr = String.fromUtf8(request)
        assertTrue(requestStr.contains("Origin: https://example.com"), message: "should have Origin")
    }

    /**
     * 测试验证正确的 Upgrade 响应。
     */
    @TestCase
    public func testVerifyUpgradeResponseSuccess(): Unit {
        let client = WebSocketClient()
        let key = "dGhlIHNhbXBsZSBub25jZQ=="
        let response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n"
        // 验证应通过（不抛异常）
        client.verifyUpgradeResponse(response, key)
        assertTrue(true, message: "valid response should pass verification")
    }

    /**
     * 测试验证失败的 Upgrade 响应（非 101）。
     */
    @TestCase
    public func testVerifyUpgradeResponseWrongStatus(): Unit {
        let client = WebSocketClient()
        let key = "dGhlIHNhbXBsZSBub25jZQ=="
        let response = "HTTP/1.1 404 Not Found\r\n\r\n"
        try {
            client.verifyUpgradeResponse(response, key)
            assertTrue(false, message: "should have thrown")
        } catch (_: Exception) {
            assertTrue(true, message: "expected exception thrown")
        }
    }

    /**
     * 测试验证缺失 Upgrade 头的响应。
     */
    @TestCase
    public func testVerifyWithoutUpgradeHeader(): Unit {
        let client = WebSocketClient()
        let key = "dGhlIHNhbXBsZSBub25jZQ=="
        let response = "HTTP/1.1 101 Switching Protocols\r\nContent-Type: text/plain\r\n\r\n"
        try {
            client.verifyUpgradeResponse(response, key)
            assertTrue(false, message: "should have thrown")
        } catch (_: Exception) {
            assertTrue(true, message: "expected exception for missing Upgrade header")
        }
    }
}
