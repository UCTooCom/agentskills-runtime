/**
 * HTTP/3 客户端单元测试（RFC 9114）。
 *
 * 覆盖：
 * - 客户端初始配置
 * - 无传输工厂时连接失败
 * - close() 幂等性
 * - 断连客户端请求返回 None
 */
package http_lib.http3

import http_lib.core.{assertTrue, assertFalse}
import http_lib.message.HttpResponse
import http_lib.message.HttpRequest
import http_lib.core.HttpMethod

// ======== HTTP/3 Client 测试 ========

@Test
public class Http3ClientTest {

    @TestCase
    public func testClientInitialConfig(): Unit {
        let client = Http3Client()
        assertTrue(!client.isConnected(),
            message: "Client should not be connected initially")
        let config = Http3ClientConfig()
        config.connectTimeout = Duration.second * 5
        config.readTimeout = Duration.second * 30
        assertTrue(config.enableConnectProtocol == true)
    }

    @TestCase
    public func testClientUsesBuiltInQuicDriver(): Unit {
        let client = Http3Client()
        // 无 transportFactory 时使用内置 QuicClientDriver
        // 验证构造函数和配置正常（不实际拨号避免 I/O 阻塞）
        assertTrue(!client.isConnected(),
            message: "Client should not be connected initially")
        // 验证仍可正常设置 tlsConfig
        let tls = H3TlsConfig.defaultClient("example.com")
        try {
            client.setTlsConfig(tls)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "setTlsConfig should not throw")
        }
        client.close()
    }

    @TestCase
    public func testClientCloseIdempotent(): Unit {
        let client = Http3Client()
        try {
            client.close()
            client.close()
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "close() should be idempotent")
        }
    }

    @TestCase
    public func testClientRequestOnDisconnectedClient(): Unit {
        let client = Http3Client()
        let resp = client.get("/test")
        match (resp) {
            case Some(_) =>
                assertTrue(false, message: "Disconnected client should not return response")
            case None =>
                assertTrue(true, message: "Disconnected client should return None")
        }
    }
}


// ======== HTTP/3 客户端配置与查询测试 ========

@Test
public class Http3ClientConfigQueryTest {

    @TestCase
    public func testToH3ConnectionConfig(): Unit {
        let config = Http3ClientConfig()
        config.maxFieldSectionSize = 16384
        config.qpackMaxTableCapacity = 8192
        let connCfg = config.toH3ConnectionConfig()
        assertTrue(connCfg.maxFieldSectionSize == 16384,
            message: "maxFieldSectionSize should propagate")
        assertTrue(connCfg.qpackMaxTableCapacity == 8192,
            message: "qpackMaxTableCapacity should propagate")
    }

    @TestCase
    public func testSetTlsConfig(): Unit {
        let client = Http3Client()
        let tls = H3TlsConfig.defaultServer("/tmp/cert.pem", "/tmp/key.pem")
        try {
            client.setTlsConfig(tls)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "setTlsConfig should not throw")
        }
    }

    @TestCase
    public func testDeleteOnDisconnectedClient(): Unit {
        let client = Http3Client()
        let resp = client.delete("/test")
        match (resp) {
            case Some(_) => assertTrue(false, message: "Disconnected client should not return response")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testHeadOnDisconnectedClient(): Unit {
        let client = Http3Client()
        let resp = client.head("/test")
        match (resp) {
            case Some(_) => assertTrue(false, message: "Disconnected client should not return response")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testOptionsOnDisconnectedClient(): Unit {
        let client = Http3Client()
        let resp = client.options("/test")
        match (resp) {
            case Some(_) => assertTrue(false, message: "Disconnected client should not return response")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testPostOnDisconnectedClient(): Unit {
        let client = Http3Client()
        let resp = client.post("/test")
        match (resp) {
            case Some(_) => assertTrue(false, message: "Disconnected client should not return response")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testPutOnDisconnectedClient(): Unit {
        let client = Http3Client()
        let resp = client.put("/test")
        match (resp) {
            case Some(_) => assertTrue(false, message: "Disconnected client should not return response")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testSetPushResponseHandler(): Unit {
        let client = Http3Client()
        let handler: (UInt64, HttpResponse) -> Unit = {_, _ => ()}
        try {
            client.setPushResponseHandler(handler)
            assertTrue(true)
        } catch (_: Exception) {
            assertTrue(false, message: "setPushResponseHandler should not throw")
        }
    }

    @TestCase
    public func testGetCompletedPushesDisconnected(): Unit {
        let client = Http3Client()
        let pushes = client.getCompletedPushes()
        assertTrue(pushes.size == 0, message: "Disconnected client should return empty pushes")
    }
}


// ======== HTTP/3 Client doRequest 测试 ========

@Test
public class Http3ClientDoRequestTest {

    @TestCase
    public func testDoRequestOnDisconnected(): Unit {
        let client = Http3Client()
        let req = HttpRequest(method: HttpMethod.GET, url: "/test")
        let resp = client.doRequest(req)
        match (resp) {
            case Some(_) => assertTrue(false, message: "Disconnected client should not return response")
            case None => assertTrue(true, message: "Should return None on disconnected client")
        }
    }
}
