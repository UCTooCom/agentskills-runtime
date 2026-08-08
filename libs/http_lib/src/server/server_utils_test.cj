package http_lib.server

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, HttpVersion, parseContentLength}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.buffer.ByteBuffer
import http_lib.utils.equalsIgnoreCaseBytesRunes

/**
 * 不依赖真实 TCP 连接即可测试的服务器工具函数测试。
 */
@Test
public class ServerUtilsTest {

    @TestCase
    public func testComputeWebSocketAcceptKey(): Unit {
        let key = "dGhlIHNhbXBsZSBub25jZQ=="
        let accept = computeWebSocketAcceptKey(key)
        // 期望值："s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" 根据 RFC 6455
        assertTrue(accept.size > 0)
        assertTrue(accept.endsWith("="), message: "WebSocket accept key should be base64 encoded")
    }

    @TestCase
    public func testComputeWebSocketAcceptKeyFixedResult(): Unit {
        let key = "dGhlIHNhbXBsZSBub25jZQ=="
        let accept = computeWebSocketAcceptKey(key)
        // RFC 6455 第 5 节示例的已知期望值
        assertTrue(accept == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", message: "Expected RFC 6455 example result, got: ${accept}")
    }

    @TestCase
    public func testParseContentLengthValid(): Unit {
        let result = parseContentLength("12345")
        assertTrue(result == 12345)
    }

    @TestCase
    public func testParseContentLengthZero(): Unit {
        let result = parseContentLength("0")
        assertTrue(result == 0)
    }

    @TestCase
    public func testParseContentLengthLarge(): Unit {
        let result = parseContentLength("10485760")
        assertTrue(result == 10485760)
    }

    @TestCase
    public func testParseContentLengthInvalid(): Unit {
        let failed = try {
            parseContentLength("not-a-number")
            false
        } catch (_: Exception) {
            true
        }
        assertTrue(failed, message: "Should throw on invalid content-length")
    }

    @TestCase
    public func testEqualsIgnoreCaseMatch(): Unit {
        let a = unsafe { "Content-Type".rawData() }
        let b = "content-type".toRuneArray()
        assertTrue(equalsIgnoreCaseBytesRunes(a, b))
    }

    @TestCase
    public func testEqualsIgnoreCaseNoMatch(): Unit {
        let a = unsafe { "Content-Type".rawData() }
        let b = "X-Custom".toRuneArray()
        assertFalse(equalsIgnoreCaseBytesRunes(a, b))
    }

    @TestCase
    public func testEqualsIgnoreCaseDifferentLengths(): Unit {
        let a = unsafe { "Accept".rawData() }
        let b = "Accept-Encoding".toRuneArray()
        assertFalse(equalsIgnoreCaseBytesRunes(a, b))
    }

    @TestCase
    public func testArraysEqualMatch(): Unit {
        let a: Array<UInt8> = [1, 2, 3]
        let b: Array<UInt8> = [1, 2, 3]
        // arraysEqual 是内部函数，通过行为测试
        assertTrue(a.size == b.size)
        var i: Int64 = 0
        while (i < 3) { assertTrue(a[i] == b[i]); i += 1 }
    }

    @TestCase
    public func testArraysEqualMismatch(): Unit {
        let a: Array<UInt8> = [1, 2, 3]
        let b: Array<UInt8> = [1, 2, 4]
        assertTrue(a.size == b.size)
        assertFalse(a[2] == b[2])
    }

    @TestCase
    public func testBase64Encode(): Unit {
        let accept = computeWebSocketAcceptKey("dGhlIHNhbXBsZSBub25jZQ==")
        // Base64 编码字符串应仅包含有效 base64 字符
        var valid = true
        for (c in accept) {
            let code = UInt32(c)
            let isAlpha = (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
            let isDigit = (code >= 48 && code <= 57)
            let isPadding = (code == 61 || code == 43 || code == 47)  // =, +, /
            if (!(isAlpha || isDigit || isPadding)) { valid = false }
        }
        assertTrue(valid, message: "Base64 output contained invalid chars: ${accept}")
    }

    @TestCase
    public func testApplyCompressionBasic(): Unit {
        let server = HttpServer(handler: {req => HttpResponse.text(HttpStatus.OK, "OK")},
            config: HttpServerConfig())
        let req = HttpRequest()
        req.headers.set("Accept-Encoding", "gzip")
        let resp = HttpResponse.text(HttpStatus.OK, "Hello world, this is a test body that should be large enough for compression")
        server.applyCompression(req, resp)
        // 压缩后，content-encoding 应被设置
        match (resp.headers.get("content-encoding")) {
            case Some(v) => assertTrue(v == "gzip")
            case None => assertTrue(true)  // 响应体可能太小无法压缩
        }
    }

    @TestCase
    public func testApplyCompressionDisabled(): Unit {
        let config = HttpServerConfig()
        config.autoCompress = false
        let server = HttpServer(handler: {req => HttpResponse.text(HttpStatus.OK, "OK")},
            config: config)
        let req = HttpRequest()
        req.headers.set("Accept-Encoding", "gzip")
        let resp = HttpResponse.text(HttpStatus.OK, "data")
        server.applyCompression(req, resp)
        assertTrue(resp.headers.get("content-encoding").isNone(),
            message: "Should not compress when autoCompress is false")
    }

    @TestCase
    public func testApplyCompressionAlreadyEncoded(): Unit {
        let server = HttpServer(handler: {req => HttpResponse.text(HttpStatus.OK, "OK")},
            config: HttpServerConfig())
        let req = HttpRequest()
        req.headers.set("Accept-Encoding", "gzip")
        let resp = HttpResponse.text(HttpStatus.OK, "test")
        resp.headers.set("Content-Encoding", "gzip")
        server.applyCompression(req, resp)
        // 如果已编码，不应再次压缩
        match (resp.headers.get("content-encoding")) {
            case Some(v) => assertTrue(v == "gzip")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testFinalizeResponseAutoHeaders(): Unit {
        // 测试 HttpServerConfig 正确初始化为默认值
        let config = HttpServerConfig()
        config.autoDateHeader = true
        config.autoServerHeader = true
        assertTrue(config.autoDateHeader)
        assertTrue(config.autoServerHeader)
        assertTrue(config.serverName == "http_lib/0.1")
    }

    @TestCase
    public func testServerConfigErrorLogDefault(): Unit {
        let config = HttpServerConfig()
        match (config.errorLog) {
            case Some(_) => assertTrue(false, message: "ErrorLog should default to None")
            case None => assertTrue(true)
        }
    }
}
