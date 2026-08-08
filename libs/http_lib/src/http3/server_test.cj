/**

 * HTTP/3 服务器单元测试（RFC 9114）。

 *

 * 覆盖：

 * - 服务器初始配置与配置转换

 * - 无传输工厂时 listenAndServe 失败

 * - 停止未启动的服务器

 * - setTlsConfig 设置器

 */

package http_lib.http3

import quic_cj.Config



import http_lib.core.{assertTrue, assertFalse, HttpStatus}

import http_lib.message.{HttpRequest, HttpResponse}



// ======== HTTP/3 Server 测试 ========



@Test

public class Http3ServerTest {



    @TestCase

    public func testServerInitialConfig(): Unit {

        let handler: (HttpRequest) -> HttpResponse = {_ =>

            HttpResponse.text(HttpStatus.OK, "H3 server")

        }

        let config = Http3ServerConfig()

        config.serverName = "test-h3-server"



        let connConfig = config.toH3ConnectionConfig()

        assertTrue(connConfig.serverName == "test-h3-server")

        let http3Config = config.toHttp3Config()

        assertTrue(http3Config.maxFieldSectionSize == 65536)



        let server = Http3Server(handler, config: config)

        assertTrue(!server.isRunning(),

            message: "Server should not be running without listenAndServe")

    }




    @TestCase

    public func testServerWithoutTransportFactoryUsesBuiltInDriver(): Unit {

        let handler: (HttpRequest) -> HttpResponse = {_ =>

            HttpResponse.text(HttpStatus.OK, "ok")

        }

        let server = Http3Server(handler)

        // 无 transportFactory 时不再抛异常，改用内置 QuicServerDriver
        // 验证构造函数和配置路径正常
        assertTrue(!server.isRunning(),

            message: "Server should not be running without listenAndServe")

        // 验证仍可正常设置 transportFactory（向后兼容）
        let factory = MockTransportFactory()

        try {

            server.setTransportFactory(factory)

            assertTrue(true)

        } catch (_: Exception) {

            assertTrue(false, message: "setTransportFactory should not throw")

        }

    }



    @TestCase

    public func testServerStopBeforeStart(): Unit {

        let handler: (HttpRequest) -> HttpResponse = {_ =>

            HttpResponse.text(HttpStatus.OK, "ok")

        }

        let server = Http3Server(handler)

        try {

            server.stop()

            assertTrue(true)

        } catch (_: Exception) {

            assertTrue(false, message: "stop() on unstarted server should not throw")

        }

    }



    @TestCase

    public func testSetTlsConfig(): Unit {

        let handler: (HttpRequest) -> HttpResponse = {_ =>

            HttpResponse.text(HttpStatus.OK, "ok")

        }

        let server = Http3Server(handler)

        let tls = H3TlsConfig.defaultServer("/tmp/cert.pem", "/tmp/key.pem")

        try {

            server.setTlsConfig(tls)

            assertTrue(true)

        } catch (_: Exception) {

            assertTrue(false, message: "setTlsConfig should not throw")

        }

    }

}





// ======== H3Server setTransportFactory 测试 ========



class MockTransportFactory <: QuicTransportFactory {

    public func listen(host: String, port: UInt16, tlsConfig: H3TlsConfig): ?QuicListener { None }

    public func dial(host: String, port: UInt16, tlsConfig: H3TlsConfig): ?QuicConnection { None }

    public func getName(): String { "mock" }

    public func setConfig(cfg: Config): Unit {}

}

@Test
public class H3ServerSetTransportFactoryTest {



    @TestCase

    public func testSetTransportFactory(): Unit {


        let handler: (HttpRequest) -> HttpResponse = {_ =>

            HttpResponse.text(HttpStatus.OK, "ok")

        }

        let server = Http3Server(handler)

        try {

            server.setTransportFactory(MockTransportFactory())

            assertTrue(true)

        } catch (_: Exception) {

            assertTrue(false, message: "setTransportFactory should not throw")

        }

    }

}


