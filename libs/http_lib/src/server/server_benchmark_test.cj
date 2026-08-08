package http_lib.server

import http_lib.core.{HttpHeaders, HttpMethod, HttpStatus, parseContentLength}
import http_lib.message.{HttpRequest, HttpResponse}
import http_lib.utils.equalsIgnoreCaseBytesRunes

/**
 * 服务器工具和 WebSocket 性能基准测试。
 * HttpServer 在构造函数中初始化一次。
 */
@Test public class ServerBench {
    private var server: HttpServer

    public init() {
        this.server = HttpServer(handler: {req => HttpResponse.text(HttpStatus.OK, "OK")},
            config: HttpServerConfig())
    }

    @Bench
    public func computeWebSocketAcceptKey(): Unit {
        let _ = computeWebSocketAcceptKey("dGhlIHNhbXBsZSBub25jZQ==")
    }

    @Bench
    public func parseContentLength(): Unit {
        let _ = parseContentLength("1048576")
    }

    @Bench
    public func equalsIgnoreCase(): Unit {
        let a = unsafe { "Content-Type".rawData() }
        let b = "content-type".toRuneArray()
        let _ = equalsIgnoreCaseBytesRunes(a, b)
    }
}

/**
 * WebSocket 帧编码/解码性能基准测试。
 */
@Test public class WebSocketBench {
    @Bench
    public func opcodeToUInt8(): Unit {
        let _ = WebSocketOpcode.Text.toUInt8()
    }

    @Bench
    public func frameEncodeSmallText(): Unit {
        let _ = encodeWebSocketFrame(WebSocketOpcode.Text,
            [0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8, 0x2Cu8, 0x20u8,
             0x57u8, 0x6Fu8, 0x72u8, 0x6Cu8, 0x64u8, 0x21u8], false)
    }

    @Bench
    public func frameEncode4KbBinaryMasked(): Unit {
        let payload = Array<UInt8>(4096, repeat: 0x42)
        let _ = encodeWebSocketFrame(WebSocketOpcode.Binary, payload, true)
    }

    @Bench
    public func frameParseSmallText(): Unit {
        let frame = encodeWebSocketFrame(WebSocketOpcode.Text,
            [0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8, 0x21u8], false)
        let _ = parseWebSocketFrame(frame)
    }

    @Bench
    public func frameParse4KbBinary(): Unit {
        let payload = Array<UInt8>(4096, repeat: 0x42)
        let frame = encodeWebSocketFrame(WebSocketOpcode.Binary, payload, false)
        let _ = parseWebSocketFrame(frame)
    }

    @Bench
    public func frameValidate(): Unit {
        let frame = encodeWebSocketFrame(WebSocketOpcode.Text,
            [0x48u8, 0x65u8, 0x6Cu8, 0x6Cu8, 0x6Fu8, 0x21u8], true)
        let parsed = parseWebSocketFrame(frame)
        let _ = validateWireFrame(parsed)
    }
}
