package http_lib.message
import http_lib.core.{assertTrue, assertFalse}
import std.collection.ArrayList

@Test
public class ChunkedDecoderTest {
    @TestCase
    public func testDecodeSimpleChunk(): Unit {
        let chunked = "5\r\nHello\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        let str = String.fromUtf8(result)
        assertTrue(str == "Hello")
    }

    @TestCase
    public func testDecodeMultipleChunks(): Unit {
        let chunked = "6\r\nHello \r\n6\r\nWorld!\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        let str = String.fromUtf8(result)
        assertTrue(str == "Hello World!")
    }

    @TestCase
    public func testDecodeWithExtensions(): Unit {
        let chunked = "5;ext=1\r\nHello\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        let str = String.fromUtf8(result)
        assertTrue(str == "Hello")
    }

    @TestCase
    public func testDecodeEmptyChunk(): Unit {
        let chunked = "0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testDecodeHexSizes(): Unit {
        let chunked = "A\r\n0123456789\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        assertTrue(result.size == 10)
        let str = String.fromUtf8(result)
        assertTrue(str == "0123456789")
    }

    @TestCase
    public func testDecodeSmallHex(): Unit {
        let chunked = "1\r\nX\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        let str = String.fromUtf8(result)
        assertTrue(str == "X")
    }

    @TestCase
    public func testDecodeTrailers(): Unit {
        let chunked = "5\r\nHello\r\n0\r\nX-Trailer: value\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        let str = String.fromUtf8(result)
        assertTrue(str == "Hello")
    }

    @TestCase
    public func testDecodeWithTrailers(): Unit {
        let chunked = "5\r\nHello\r\n0\r\nX-Custom: trailer-value\r\nX-Checksum: abc123\r\n\r\n"
        let result = ChunkedDecoder.decodeWithTrailers(unsafe { chunked.rawData() })
        let str = String.fromUtf8(result.data)
        assertTrue(str == "Hello")
        match (result.trailers.get("x-custom")) {
            case Some(v) => assertTrue(v == "trailer-value")
            case None => assertTrue(false)
        }
        match (result.trailers.get("x-checksum")) {
            case Some(v) => assertTrue(v == "abc123")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testDecodeWithTrailersNoTrailers(): Unit {
        let chunked = "A\r\n0123456789\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decodeWithTrailers(unsafe { chunked.rawData() })
        let str = String.fromUtf8(result.data)
        assertTrue(str == "0123456789")
        assertTrue(result.trailers.isEmpty())
    }

    @TestCase
    public func testParseTrailers(): Unit {
        let trailerData = "X-Custom: value1\r\nX-Other: value2\r\n\r\n"
        let (trailers, consumed) = ChunkedDecoder.parseTrailers(unsafe { trailerData.rawData() }, 0, trailerData.size)
        match (trailers.get("x-custom")) {
            case Some(v) => assertTrue(v == "value1")
            case None => assertTrue(false)
        }
        match (trailers.get("x-other")) {
            case Some(v) => assertTrue(v == "value2")
            case None => assertTrue(false)
        }
        assertTrue(consumed > 0)
    }

    @TestCase
    public func testDecodeLargeChunk(): Unit {
        // 10KB 数据块
        var data = ""
        var i: Int64 = 0
        while (i < 10240) { data += "X"; i += 1 }
        let chunked = "2800\r\n${data}\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        assertTrue(result.size == 10240)
    }

    @TestCase
    public func testDecodeMultipleChunksLarge(): Unit {
        var chunks = ""
        var i: Int64 = 0
        while (i < 50) {
            let data = "ABCDEFGHIJKLMNOPQRST"  // 20 字节
            let hexSize = toUpperHexStr(data.size)
            chunks += "${hexSize}\r\n${data}\r\n"
            i += 1
        }
        chunks += "0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunks.rawData() })
        assertTrue(result.size == 1000)
    }

    @TestCase
    public func testDecodeChunkExtensionsWithValues(): Unit {
        let chunked = "5;foo=bar;baz=qux\r\nHello\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decode(unsafe { chunked.rawData() })
        let str = String.fromUtf8(result)
        assertTrue(str == "Hello")
    }

    @TestCase
    public func testDecodeIncompleteThrows(): Unit {
        try {
            ChunkedDecoder.decode(unsafe { "5\r\nHel".rawData() })
            assertTrue(false)
        } catch (_: Exception) {
            assertTrue(true)
        }
    }

    @TestCase
    public func testDecodeInvalidHexThrows(): Unit {
        try {
            ChunkedDecoder.decode(unsafe { "ZZ\r\nHello\r\n0\r\n\r\n".rawData() })
            assertTrue(false)
        } catch (_: Exception) {
            assertTrue(true)
        }
    }

    @TestCase
    public func testDecodeMissingCrlfThrows(): Unit {
        try {
            ChunkedDecoder.decode(unsafe { "5\r\nHello0\r\n\r\n".rawData() })
            assertTrue(false)
        } catch (_: Exception) {
            assertTrue(true)
        }
    }

    @TestCase
    public func testFeedSingleChunk(): Unit {
        let chunkedData = unsafe { "5\r\nHello\r\n0\r\n\r\n".rawData() }
        let (decoded, remaining) = ChunkedDecoder.feed(chunkedData, [])
        let str = String.fromUtf8(decoded)
        assertTrue(str == "Hello")
        assertTrue(remaining.size == 0)
    }





    @TestCase
    public func testFeedWithExtensions(): Unit {
        let chunkedData = unsafe { "5;ext=val\r\nHello\r\n0\r\n\r\n".rawData() }
        let (decoded, remaining) = ChunkedDecoder.feed(chunkedData, [])
        let str = String.fromUtf8(decoded)
        assertTrue(str == "Hello")
        assertTrue(remaining.size == 0)
    }

    @TestCase
    public func testFeedEmpty(): Unit {
        let chunkedData = unsafe { "0\r\n\r\n".rawData() }
        let (decoded, remaining) = ChunkedDecoder.feed(chunkedData, [])
        assertTrue(decoded.size == 0)
        assertTrue(remaining.size == 0)
    }


}

private func toUpperHexStr(value: Int64): String {
    if (value == 0) { return "0" }
    let hexChars = "0123456789ABCDEF".toRuneArray()
    var runes = ArrayList<Rune>()
    var v = value
    while (v > 0) {
        let idx = Int64(v % 16)
        runes.add(hexChars[idx])
        v /= 16
    }
    let reversed = ArrayList<Rune>()
    var ri = runes.size - 1
    while (ri >= 0) { reversed.add(runes[ri]); ri -= 1 }
    String(reversed.toArray())
}
