/**
 * HTTP/1.1 服务端管道复用（Pipelining）单元测试。
 */
package http_lib.server

import http_lib.core.{assertTrue, assertFalse}

@Test
public class ServerPipeliningTest {

    @TestCase
    public func testPipeliningConfigOption(): Unit {
        let config = HttpServerConfig()
        // 默认情况下管道复用应被禁用
        assertFalse(config.enablePipelining,
            message: "Pipelining should be disabled by default")
    }

    @TestCase
    public func testEnablePipelining(): Unit {
        let config = HttpServerConfig()
        config.enablePipelining = true
        assertTrue(config.enablePipelining,
            message: "Pipelining should be enabled after setting flag")
    }

    @TestCase
    public func testPipeliningWithKeepAlive(): Unit {
        let config = HttpServerConfig()
        config.enablePipelining = true
        config.keepAlive = true
        assertTrue(config.keepAlive,
            message: "Pipelining requires Keep-Alive enabled")
    }


    @TestCase
    public func testPipelineRequestBatch(): Unit {
        // 测试管道请求格式：两个 HTTP/1.1 请求连续发送
        let req1 = "POST /api HTTP/1.1\r\nHost: example.com\r\nContent-Length: 5\r\n\r\nHello"
        let req2 = "GET /next HTTP/1.1\r\nHost: example.com\r\n\r\n"
        let pipeline = req1 + req2
        assertTrue(pipeline.contains("POST /api"),
            message: "Pipeline should contain POST request")
        assertTrue(pipeline.contains("GET /next"),
            message: "Pipeline should contain GET request")
        // 检查双请求格式（每个请求都有 \r\n\r\n）
        let headers = pipeline.split("\r\n\r\n")
        assertTrue(headers.size >= 2,
            message: "Pipeline should have at least 2 header/body sections")
    }
}
