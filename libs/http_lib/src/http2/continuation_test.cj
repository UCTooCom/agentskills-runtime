package http_lib.http2

import std.collection.ArrayList
import http_lib.core.{assertTrue, assertFalse, HttpHeaders}

/**
 * HTTP/2 CONTINUATION 帧、头部块分片和跨片的 HPACK 状态
 * 的边界情况测试。
 */
@Test
public class ContinuationEdgeTest {

    @TestCase
    public func testSingleHeaderNoContinuation(): Unit {
        let encoder = HPACK()
        let headers = HttpHeaders()
        headers.set(":method", "GET")
        headers.set(":path", "/normal")

        let encoded = encoder.encode(headers)
        assertTrue(encoded.size > 0, message: "Encoded single HEADERS should not be empty")
        assertTrue(encoded.size < 16384, message: "Simple headers should fit in default frame size")
    }

    @TestCase
    public func testConcatenatedFragmentsRoundtrip(): Unit {
        // 正确的 CONTINUATION 处理：拼接所有片段，然后一次解码。
        // 这是 connection 中 decodeAccumulatedHeaders() 的做法。
        let encoder = HPACK()
        let decoder = HPACK()

        let headers = HttpHeaders()
        headers.set(":method", "GET")
        headers.set(":path", "/test")
        headers.set(":scheme", "https")
        headers.set(":authority", "example.com")
        var i: Int64 = 0
        while (i < 30) {
            headers.set("x-custom-${i}", "value-number-${i}-with-padding-to-make-it-longer")
            i += 1
        }

        let fullBlock = encoder.encode(headers)
        // 分割为两个片段（模拟 HEADERS + CONTINUATION）
        let splitPoint = fullBlock.size / 2
        let fragment1 = Array<UInt8>(splitPoint, repeat: 0)
        let fragment2 = Array<UInt8>(fullBlock.size - splitPoint, repeat: 0)
        var j: Int64 = 0
        while (j < splitPoint) { fragment1[j] = fullBlock[j]; j += 1 }
        while (j < fullBlock.size) { fragment2[j - splitPoint] = fullBlock[j]; j += 1 }

        // 连接片段（处理 CONTINUATION 的正确方式）
        let combined = Array<UInt8>(fullBlock.size, repeat: 0)
        var k: Int64 = 0
        while (k < fragment1.size) { combined[k] = fragment1[k]; k += 1 }
        while (k < fullBlock.size) { combined[k] = fullBlock[k]; k += 1 }

        // 解码完整的头部块
        let decoded = decoder.decode(combined)
        assertTrue(decoded.size > 0, message: "Assembled fragments should decode correctly")

        match (decoded.get(":method")) {
            case Some(v) => assertTrue(v == "GET", message: "Method should survive fragment assembly")
            case None => assertTrue(false, message: "Method should be present")
        }
    }

    @TestCase
    public func testEmptyContinuationFrame(): Unit {
        let decoder = HPACK()
        let headers = decoder.decode([])
        assertTrue(headers.isEmpty(), message: "Empty decode should produce empty headers")
    }

    @TestCase
    public func testCompleteHeaderBlockRoundTrip(): Unit {
        let encoder = HPACK()
        let headers = HttpHeaders()
        headers.set(":method", "POST")
        headers.set(":path", "/api/v1/data")
        headers.set("content-type", "application/json")
        headers.set("x-request-id", "550e8400-e29b-41d4-a716-446655440000")

        var i: Int64 = 0
        while (i < 25) {
            headers.set("x-metadata-${i}", "metadata-value-${i}")
            i += 1
        }

        let encoded = encoder.encode(headers)
        let decoder2 = HPACK()
        let decoded = decoder2.decode(encoded)

        match (decoded.get(":method")) {
            case Some(v) => assertTrue(v == "POST", message: "Method should survive round-trip")
            case None => assertTrue(false, message: "Method should be present")
        }
        match (decoded.get("content-type")) {
            case Some(v) => assertTrue(v == "application/json", message: "Content-Type should survive")
            case None => assertTrue(false, message: "Content-Type should be present")
        }
    }
}
