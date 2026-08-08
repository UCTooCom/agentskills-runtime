package http_lib.message

import http_lib.core.{assertTrue, assertFalse, HttpHeaders, HttpMethod, HttpVersion}

/**
 * HTTP/1.1 分块传输编码边界情况的 RFC 合规性测试。
 */
@Test
public class ChunkedConformanceTest {

    @TestCase
    public func testChunkedWithTrailerHeaders(): Unit {
        // 分块编码测试：5\r\nHello\r\n0\r\nX-Checksum: abc123\r\n\r\n"
        let data: Array<UInt8> = [
            b'5', b'\r', b'\n', b'H', b'e', b'l', b'l', b'o', b'\r', b'\n',
            b'0', b'\r', b'\n',
            b'X', b'-', b'C', b'h', b'e', b'c', b'k', b's', b'u', b'm', b':', b' ', b'a', b'b', b'c', b'1', b'2', b'3', b'\r', b'\n',
            b'\r', b'\n'
        ]
        let decoded = ChunkedDecoder.decode(data)
        assertTrue(decoded.size == 5, message: "Should decode 5 bytes of chunked data with trailers")
    }

    @TestCase
    public func testChunkedWithExtension(): Unit {
        // 分块编码扩展测试：5;chunk-extension=value\r\nHello\r\n0\r\n\r\n"
        let data: Array<UInt8> = [
            b'5', b';', b'c', b'h', b'u', b'n', b'k', b'-', b'e', b'x', b't', b'e', b'n', b's', b'i', b'o', b'n', b'=', b'v', b'a', b'l', b'u', b'e', b'\r', b'\n',
            b'H', b'e', b'l', b'l', b'o', b'\r', b'\n',
            b'0', b'\r', b'\n',
            b'\r', b'\n'
        ]
        let decoded = ChunkedDecoder.decode(data)
        assertTrue(decoded.size == 5, message: "Should decode chunk with extension, got ${decoded.size}")
    }

    @TestCase
    public func testChunkedMultipleExtensions(): Unit {
        // 多扩展测试：A;ext1=val1;ext2=val2\r\nHelloWorld\r\n0\r\n\r\n"
        let data: Array<UInt8> = [
            b'A', b';', b'e', b'x', b't', b'1', b'=', b'v', b'a', b'l', b'1', b';', b'e', b'x', b't', b'2', b'=', b'v', b'a', b'l', b'2', b'\r', b'\n',
            b'H', b'e', b'l', b'l', b'o', b'W', b'o', b'r', b'l', b'd', b'\r', b'\n',
            b'0', b'\r', b'\n', b'\r', b'\n'
        ]
        let decoded = ChunkedDecoder.decode(data)
        assertTrue(decoded.size == 10, message: "Should decode chunk with multiple extensions")
    }

    @TestCase
    public func testChunkedUpperCaseHex(): Unit {
        // 分块测试：A\r\nHelloWorld\r\n0\r\n\r\n"
        let data: Array<UInt8> = [
            b'A', b'\r', b'\n',
            b'H', b'e', b'l', b'l', b'o', b'W', b'o', b'r', b'l', b'd', b'\r', b'\n',
            b'0', b'\r', b'\n', b'\r', b'\n'
        ]
        let decoded = ChunkedDecoder.decode(data)
        assertTrue(decoded.size == 10, message: "Should decode uppercase hex chunk size")
    }

    @TestCase
    public func testChunkedSingleDigitSize(): Unit {
        // 最小分块测试：1\r\nX\r\n0\r\n\r\n"
        let data: Array<UInt8> = [
            b'1', b'\r', b'\n', b'X', b'\r', b'\n',
            b'0', b'\r', b'\n', b'\r', b'\n'
        ]
        let decoded = ChunkedDecoder.decode(data)
        assertTrue(decoded.size == 1, message: "Should decode single-byte chunk")
        assertTrue(decoded[0] == b'X', message: "Should decode 'X'")
    }

    @TestCase
    public func testChunkedEmpty(): Unit {
        // "0\r\n\r\n" — 仅结束标记，无数据
        let data: Array<UInt8> = [b'0', b'\r', b'\n', b'\r', b'\n']
        let decoded = ChunkedDecoder.decode(data)
        assertTrue(decoded.size == 0, message: "Empty chunked body should decode to empty")
    }
}

/**
 * HTTP 头部边界情况的 RFC 合规性测试。
 */
@Test
public class HeaderConformanceTest {

    @TestCase
    public func testHeaderCaseInsensitive(): Unit {
        let headers = HttpHeaders()
        headers.set("Content-Type", "text/html")
        match (headers.get("content-type")) {
            case Some(v) => assertTrue(v == "text/html", message: "Should be case-insensitive")
            case None => assertTrue(false, message: "Should find header")
        }
        match (headers.get("CONTENT-TYPE")) {
            case Some(v) => assertTrue(v == "text/html", message: "Should be case-insensitive (uppercase)")
            case None => assertTrue(false, message: "Should find header")
        }
    }

    @TestCase
    public func testHeaderMultipleValues(): Unit {
        let headers = HttpHeaders()
        headers.add("Set-Cookie", "a=1")
        headers.add("Set-Cookie", "b=2")
        let values = headers.getAll("set-cookie")
        assertTrue(values.size == 2, message: "Should have 2 values, got ${values.size}")
    }

    @TestCase
    public func testHeaderRemove(): Unit {
        let headers = HttpHeaders()
        headers.set("X-Test", "value")
        headers.remove("x-test")
        assertTrue(headers.get("x-test").isNone(), message: "Header should be removed")
    }

    @TestCase
    public func testHeaderEmpty(): Unit {
        let headers = HttpHeaders()
        assertTrue(headers.isEmpty(), message: "New headers should be empty")
        assertTrue(headers.size == 0, message: "Size should be 0")
    }
}

/**
 * HTTP 版本和方法处理的 RFC 合规性测试。
 */
@Test
public class VersionMethodConformanceTest {

    @TestCase
    public func testHttp10Explicit(): Unit {
        assertTrue(HttpVersion.HTTP_1_0.toString() == "HTTP/1.0", message: "ToString should return HTTP/1.0")
        assertFalse(HttpVersion.HTTP_1_0.supportsPersistentConnection(), message: "1.0 should not support persistent connections")
    }

    @TestCase
    public func testHttp11SupportsPersistentConnection(): Unit {
        assertTrue(HttpVersion.HTTP_1_1.supportsPersistentConnection(), message: "1.1 should support persistent connections")
        assertTrue(HttpVersion.HTTP_2_0.supportsPersistentConnection(), message: "2.0 should support persistent connections")
    }

    @TestCase
    public func testAllMethodsParsable(): Unit {
        let methods = ["GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH"]
        for (m in methods) {
            match (HttpMethod.parse(m)) {
                case Some(_) => () // 通过
                case None => assertTrue(false, message: "Should parse method: ${m}")
            }
        }
        assertTrue(true, message: "All 9 methods parse successfully")
    }

    @TestCase
    public func testMethodEquality(): Unit {
        assertTrue(HttpMethod.GET == HttpMethod.GET, message: "GET should equal GET")
        let get1 = HttpMethod.GET
        let get2 = HttpMethod.parse("GET")
        match (get2) {
            case Some(g) => assertTrue(get1 == g, message: "Parsed GET should equal enum GET")
            case None => assertTrue(false, message: "Should parse GET")
        }
    }
}

/**
 * 带 Trailer 的分块解码的 RFC 合规性测试。
 */
@Test
public class ChunkedTrailerConformanceTest {

    @TestCase
    public func testTrailerWithMultipleFields(): Unit {
        let data = "5\r\nHello\r\n0\r\nX-Cksum: abc\r\nX-Time: 12345\r\n\r\n"
        let result = ChunkedDecoder.decodeWithTrailers(unsafe { data.rawData() })
        let decoded = String.fromUtf8(result.data)
        assertTrue(decoded == "Hello")
        match (result.trailers.get("x-cksum")) {
            case Some(v) => assertTrue(v == "abc")
            case None => assertTrue(false)
        }
        match (result.trailers.get("x-time")) {
            case Some(v) => assertTrue(v == "12345")
            case None => assertTrue(false)
        }
        assertTrue(result.trailers.size == 2)
    }

    @TestCase
    public func testTrailerWithWhitespace(): Unit {
        let data = "5\r\nHello\r\n0\r\nX-Test:  value  \r\n\r\n"
        let result = ChunkedDecoder.decodeWithTrailers(unsafe { data.rawData() })
        match (result.trailers.get("x-test")) {
            case Some(v) => assertTrue(v == "value")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testTrailerEmptySection(): Unit {
        let data = "5\r\nHello\r\n0\r\n\r\n"
        let result = ChunkedDecoder.decodeWithTrailers(unsafe { data.rawData() })
        assertTrue(result.trailers.isEmpty())
    }

    @TestCase
    public func testParseTrailersConsumed(): Unit {
        let trailerData = "X-One: v1\r\nX-Two: v2\r\n\r\nextra"
        let (trailers, consumed) = ChunkedDecoder.parseTrailers(unsafe { trailerData.rawData() }, 0, trailerData.size)
        assertTrue(trailers.size == 2)
        assertTrue(consumed > 0)
        assertTrue(consumed < trailerData.size)  // 应在空行处停止
    }

    @TestCase
    public func testChunkedEncodeDecodeRoundtrip(): Unit {
        let data = "This is test data for roundtrip encoding and decoding of chunked transfer encoding."
        let encoded = ChunkedWriter.encodeChunked(unsafe { data.rawData() })
        let decoded = ChunkedDecoder.decode(encoded)
        let result = String.fromUtf8(decoded)
        assertTrue(result == data)
    }
}
