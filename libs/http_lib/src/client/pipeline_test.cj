package http_lib.client

import std.collection.ArrayList

import http_lib.core.{assertTrue, assertFalse, HttpMethod}
import http_lib.message.HttpRequest
import http_lib.connection.MockConnection

/**
 * HTTP/1.1 Pipeline 单元测试。
 *
 * Pipeline 提供在单个持久连接上发送多个请求
 * 然后按 FIFO 顺序读取响应的能力。
 */
@Test
public class PipelineUnitTest {

    @TestCase
    public func testCreateAndClose(): Unit {
        let conn = MockConnection([])
        let transport = HttpTransport()
        let pipeline = Pipeline(conn, transport, "example.com")
        assertFalse(pipeline.isClosed(), message: "新建 Pipeline 应处于未关闭状态")
        pipeline.close()
        assertTrue(pipeline.isClosed(), message: "close() 后 Pipeline 应标记为已关闭")
    }

    @TestCase
    public func testCloseIdempotent(): Unit {
        let conn = MockConnection([])
        let transport = HttpTransport()
        let pipeline = Pipeline(conn, transport, "example.com")
        pipeline.close()
        pipeline.close()
        pipeline.close()
        assertTrue(pipeline.isClosed(), message: "多次 close() 应幂等")
    }

    @TestCase
    public func testSendAfterCloseThrows(): Unit {
        let conn = MockConnection([])
        let transport = HttpTransport()
        let pipeline = Pipeline(conn, transport, "example.com")
        pipeline.close()
        var threw = false
        try {
            pipeline.send(HttpRequest(method: HttpMethod.GET, url: "/test"))
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw, message: "已关闭的 Pipeline 上 send() 应抛出异常")
    }

    @TestCase
    public func testRecvAfterCloseThrows(): Unit {
        let conn = MockConnection([])
        let transport = HttpTransport()
        let pipeline = Pipeline(conn, transport, "example.com")
        pipeline.close()
        var threw = false
        try {
            pipeline.recv()
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw, message: "已关闭的 Pipeline 上 recv() 应抛出异常")
    }

    @TestCase
    public func testSendWritesData(): Unit {
        let conn = MockConnection([])
        let transport = HttpTransport()
        let pipeline = Pipeline(conn, transport, "example.com")
        pipeline.send(HttpRequest(method: HttpMethod.GET, url: "/test"))
        let written = conn.getWrittenBytes()
        assertTrue(written.size > 0, message: "send() 后应写入数据到连接")
        assertTrue(written.size > 12, message: "写入数据应包含 HTTP 方法")
        // 验证写入了正确的请求行
        let reqStr = unsafe { String.withRawData(written) }
        assertTrue(reqStr.startsWith("GET /test HTTP/1.1"), message: "请求行应以 GET /test HTTP/1.1 开头")
        pipeline.close()
    }

    @TestCase
    public func testSendMultipleWritesAll(): Unit {
        let conn = MockConnection([])
        let transport = HttpTransport()
        let pipeline = Pipeline(conn, transport, "example.com")
        pipeline.send(HttpRequest(method: HttpMethod.GET, url: "/a"))
        pipeline.send(HttpRequest(method: HttpMethod.POST, url: "/b"))
        let written = conn.getWrittenBytes()
        let reqStr = unsafe { String.withRawData(written) }
        // 检查两个请求都在一次 flush 中发送
        assertTrue(reqStr.contains("GET /a HTTP/1.1"), message: "第一个请求行应存在")
        assertTrue(reqStr.contains("POST /b HTTP/1.1"), message: "第二个请求行应存在")
        pipeline.close()
    }

    @TestCase
    public func testRecvWithNoDataThrows(): Unit {
        let conn = MockConnection([])
        let transport = HttpTransport()
        let pipeline = Pipeline(conn, transport, "example.com")
        pipeline.send(HttpRequest(method: HttpMethod.GET, url: "/test"))
        var threw = false
        try {
            pipeline.recv()
        } catch (_: Exception) {
            threw = true
        }
        assertTrue(threw, message: "MockConnection 无数据时 recv() 应抛出异常")
        pipeline.close()
    }

    @TestCase
    public func testRecvWithResponseData(): Unit {
        let responseBytes = unsafe { "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello".rawData() }
        let conn = MockConnection(responseBytes)
        let transport = HttpTransport()
        let pipeline = Pipeline(conn, transport, "example.com")
        pipeline.send(HttpRequest(method: HttpMethod.GET, url: "/test"))
        let resp = pipeline.recv()
        assertTrue(resp.status.code == 200, message: "应解析出 200 状态码")
        let body = resp.bodyAsString()
        assertTrue(body == "Hello", message: "响应体应为 'Hello'")
        pipeline.close()
    }

    @TestCase
    public func testPipelineBatchEmpty(): Unit {
        let transport = HttpTransport()
        let responses = transport.pipeline(ArrayList<HttpRequest>())
        assertTrue(responses.size == 0, message: "空请求列表应返回空响应列表")
    }
}
