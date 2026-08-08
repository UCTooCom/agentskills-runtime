package http_lib.http2

import http_lib.core.HttpHeaders

/**
 * HTTP/2 HPACK 编码/解码、帧编码/解析、优先级树基准测试。
 */
@Test public class HpackBench {
    @Bench
    public func encodeSimpleHeaders(): Unit {
        let headers = HttpHeaders()
        headers.set(":method", "GET")
        headers.set(":path", "/")
        headers.set(":scheme", "https")
        headers.set(":authority", "example.com")
        headers.set("accept", "*/*")
        let hpack = HPACK()
        let _ = hpack.encode(headers)
    }

    @Bench
    public func decodeHeaders(): Unit {
        let headers = HttpHeaders()
        headers.set(":method", "GET")
        headers.set(":path", "/")
        headers.set(":scheme", "https")
        headers.set(":authority", "example.com")
        let hpack = HPACK()
        let encoded = hpack.encode(headers)
        let _ = hpack.decode(encoded)
    }

    @Bench
    public func huffmanEncode(): Unit {
        let data = unsafe { "https://www.example.com/this-is-a-long-url-path".rawData() }
        let _ = huffmanEncode(data)
    }
}

@Test public class Http2FrameBench {
    @Bench
    public func encodeFrame(): Unit {
        let header = Http2FrameHeader(128, Http2FrameType.HEADERS, flags: 0x4, streamId: 1)
        let payload = Array<UInt8>(128, repeat: 0x42)
        let _ = encodeFrame(header, payload)
    }

    @Bench
    public func parseFrameHeader(): Unit {
        let header = Http2FrameHeader(128, Http2FrameType.DATA, flags: 0, streamId: 3)
        let payload = Array<UInt8>(128, repeat: 0x41)
        let frame = encodeFrame(header, payload)
        let _ = Http2FrameHeader.parse(frame)
    }

    @Bench
    public func encodeSettings(): Unit {
        let settings = [
            (Http2SettingsId.ENABLE_PUSH, UInt32(0)),
            (Http2SettingsId.MAX_CONCURRENT_STREAMS, UInt32(100)),
            (Http2SettingsId.INITIAL_WINDOW_SIZE, UInt32(65535)),
            (Http2SettingsId.MAX_FRAME_SIZE, UInt32(16384)),
        ]
        let _ = encodeSettings(settings)
    }
}

@Test public class Http2PriorityBench {
    @Bench
    public func addStreams(): Unit {
        let tree = PriorityTree()
        var j: UInt32 = 1
        while (j <= 64) {
            tree.addStream(j, weight: 16, parent: None)
            j += 1
        }
    }
}
