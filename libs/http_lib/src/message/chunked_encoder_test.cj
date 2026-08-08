package http_lib.message

import std.collection.ArrayList
import http_lib.core.{assertTrue, assertFalse}
import http_lib.connection.MockConnection

/**
 * 测试 ChunkedWriter（RFC 7230 第 4.1 节）。
 */
@Test
public class ChunkedEncoderTest {

    @TestCase
    public func testEncodeChunkedProducesTerminator(): Unit {
        let encoded = ChunkedWriter.encodeChunked([])
        // 至少应生成块结束标记 "0\r\n\r\n"
        assertTrue(encoded.size > 0, message: "chunked encoding should produce output")
    }

    @TestCase
    public func testChunkTerminatorFormat(): Unit {
        let terminator = ChunkedWriter.chunkTerminator()
        assertTrue(terminator.size == 5, message: "terminator should be 5 bytes: 0\\r\\n\\r\\n")
        assertTrue(terminator[0] == b'0', message: "first byte should be '0'")
        assertTrue(terminator[1] == b'\r', message: "second byte should be CR")
        assertTrue(terminator[2] == b'\n', message: "third byte should be LF")
        assertTrue(terminator[3] == b'\r', message: "fourth byte should be CR")
        assertTrue(terminator[4] == b'\n', message: "fifth byte should be LF")
    }

    @TestCase
    public func testEncodeChunkedSmallData(): Unit {
        let data = unsafe { "hello".rawData() }
        let encoded = ChunkedWriter.encodeChunked(data)
        let decoded = ChunkedDecoder.decode(encoded)
        let decodedStr = String.fromUtf8(decoded)
        assertTrue(decodedStr == "hello", message: "roundtrip should preserve data")
    }

    @TestCase
    public func testEncodeChunkedRoundtrip(): Unit {
        // 测试分块编码→解码往返
        var testData = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < 256) {
            testData.add(UInt8(i))
            i++
        }
        let data = testData.toArray()
        let encoded = ChunkedWriter.encodeChunked(data)
        let decoded = ChunkedDecoder.decode(encoded)
        assertTrue(decoded.size == data.size, message: "roundtrip should preserve size")
        i = 0
        while (i < data.size) {
            assertTrue(decoded[i] == data[i], message: "byte ${i} should match")
            i++
        }
    }

    @TestCase
    public func testWriteChunkWithConnection(): Unit {
        let conn = MockConnection([])
        let writer = ChunkedWriter(conn)
        let testData = Array<UInt8>(10, repeat: 0x41)
        writer.writeChunk(testData)
        writer.finish(trailers: None)
        let written = conn.getWrittenBytes()
        assertTrue(written.size > 0,
            message: "Written data should have content")
        let decoded = ChunkedDecoder.decode(written)
        assertTrue(decoded.size == 10,
            message: "Decoded size should match original")
    }

    @TestCase
    public func testWriteChunkMultipleWithConnection(): Unit {
        let conn = MockConnection([])
        let writer = ChunkedWriter(conn)
        writer.writeChunk(Array<UInt8>(5, repeat: 0x42))
        writer.writeChunk(Array<UInt8>(5, repeat: 0x43))
        writer.finish(trailers: None)
        let written = conn.getWrittenBytes()
        let decoded = ChunkedDecoder.decode(written)
        assertTrue(decoded.size == 10,
            message: "Multiple chunks should combine to 10 bytes")
    }

    @TestCase
    public func testFinishEmptyWriter(): Unit {
        let conn = MockConnection([])
        let writer = ChunkedWriter(conn)
        writer.finish(trailers: None)
        let written = conn.getWrittenBytes()
        assertTrue(written.size > 0,
            message: "Empty writer finish should produce terminating chunk")
    }

    @TestCase
    public func testFinishNone(): Unit {
        let conn = MockConnection([])
        let writer = ChunkedWriter(conn)
        writer.finish(trailers: None)
        let written = conn.getWrittenBytes()
        assertTrue(written.size > 0,
            message: "Finish with None should produce terminator")
    }

    @TestCase
    public func testEncodeChunkedRoundtripEmpty(): Unit {
        let encoded = ChunkedWriter.encodeChunked([])
        let decoded = ChunkedDecoder.decode(encoded)
        assertTrue(decoded.size == 0,
            message: "Empty roundtrip should produce empty result")
    }

    @TestCase
    public func testEncodeChunkedLargeData(): Unit {
        let data = Array<UInt8>(65536, repeat: 0x41)
        let encoded = ChunkedWriter.encodeChunked(data)
        let decoded = ChunkedDecoder.decode(encoded)
        assertTrue(decoded.size == data.size,
            message: "Large data roundtrip should preserve size")
    }
}
