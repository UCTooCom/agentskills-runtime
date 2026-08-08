package http_lib.message

import std.collection.ArrayList
import http_lib.core.{assertTrue, assertFalse}

@Test
public class RangeTest {

    @TestCase
    public func testParseSimpleRange(): Unit {
        let ranges = parseRange("bytes=0-499", 10000)
        assertTrue(ranges.size == 1)
        assertTrue(ranges[0].start == 0)
        assertTrue(ranges[0].end == 499)
    }

    @TestCase
    public func testParseOpenEndRange(): Unit {
        let ranges = parseRange("bytes=500-", 10000)
        assertTrue(ranges.size == 1)
        assertTrue(ranges[0].start == 500)
        // end 默认为 -1 表示"到末尾"
    }

    @TestCase
    public func testParseSuffixRange(): Unit {
        let ranges = parseRange("bytes=-500", 10000)
        assertTrue(ranges.size == 1)
        assertTrue(ranges[0].suffix == true)
    }

    @TestCase
    public func testParseMultipleRanges(): Unit {
        let ranges = parseRange("bytes=0-49,100-149", 10000)
        assertTrue(ranges.size == 2)
        assertTrue(ranges[0].start == 0)
        assertTrue(ranges[0].end == 49)
        assertTrue(ranges[1].start == 100)
        assertTrue(ranges[1].end == 149)
    }

    @TestCase
    public func testParseRangeInvalid(): Unit {
        let ranges = parseRange("not-bytes=0-10", 1000)
        assertTrue(ranges.size == 0)
    }

    @TestCase
    public func testParseRangeEmpty(): Unit {
        let ranges = parseRange("", 1000)
        assertTrue(ranges.size == 0)
    }

    @TestCase
    public func testExtractRange(): Unit {
        let data = Array<UInt8>(10, { i => UInt8(i + 0x41) })
        let range = ByteRange(2, end: 5)
        let extracted = extractRange(data, range)
        assertTrue(extracted.size == 4)  // 5 - 2 + 1 = 4
        assertTrue(extracted[0] == 0x43) // ASCII 字符 'C'（0x43）
        assertTrue(extracted[3] == 0x46) // ASCII 字符 'F'（0x46）
    }

    @TestCase
    public func testBuildContentRange(): Unit {
        let range = ByteRange(0, end: 499)
        let header = buildContentRange(range, 1000)
        assertTrue(header == "bytes 0-499/1000")
    }

    @TestCase
    public func testAcceptRangesHeader(): Unit {
        let header = acceptRangesHeader()
        assertTrue(header == "bytes")
    }

    @TestCase
    public func testBuildMultipartRanges(): Unit {
        // 创建 10 字节数据：ABCDEFGHIJ
        let data = Array<UInt8>(10, { i => UInt8(i + 0x41) })
        let ranges = ArrayList<ByteRange>()
        ranges.add(ByteRange(0, end: 2))  // ABC 范围
        ranges.add(ByteRange(5, end: 7))  // FGH 范围
        let result = buildMultipartRanges(data, ranges, "text/plain", 10)
        assertTrue(result.size > 0)
        let str = String.fromUtf8(result)
        assertTrue(str.contains("Content-Type: text/plain"))
        assertTrue(str.contains("Content-Range"))
    }

    @TestCase
    public func testBuildMultipartRangesEmpty(): Unit {
        let data = Array<UInt8>(10, { i => UInt8(i) })
        let ranges = ArrayList<ByteRange>()
        let result = buildMultipartRanges(data, ranges, "text/plain", 10)
        assertTrue(result.size == 0)
    }

    @TestCase
    public func testBuildMultipartRangesSingle(): Unit {
        let data = Array<UInt8>(5, { i => UInt8(i + 0x41) })
        let ranges = ArrayList<ByteRange>()
        ranges.add(ByteRange(1, end: 3))
        let result = buildMultipartRanges(data, ranges, "application/octet-stream", 5)
        assertTrue(result.size > 0)
    }
}
