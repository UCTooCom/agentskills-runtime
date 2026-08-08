package compress4cj.lzw

import compress4cj.common.strToBytes
import compress4cj.common.bytesEqual

private func testRoundtrip(data: Array<UInt8>, order: LzwOrder, litWidth: Int64): Unit {
    let compressed = lzwCompress(data, order: order, litWidth: litWidth)
    let decompressed = lzwDecompress(compressed, order: order, litWidth: litWidth)
    if (!bytesEqual(data, decompressed)) {
        throw Exception("LZW roundtrip failed")
    }
}

@Test
func testLzwRoundtripEmpty(): Unit {
    let data: Array<UInt8> = []
    let compressed = lzwCompress(data)
    if (!(compressed.size == 0)) { throw Exception("empty compress") }
    let decompressed = lzwDecompress(compressed)
    if (!(decompressed.size == 0)) { throw Exception("empty decompress") }
}

@Test
func testLzwRoundtripSmall(): Unit {
    let data = strToBytes("Hello, LZW!")
    testRoundtrip(data, LzwOrder.LSB, 8)
}

@Test
func testLzwRoundtripAllSame(): Unit {
    let data = Array<UInt8>(100, repeat: 0x42)
    testRoundtrip(data, LzwOrder.LSB, 8)
}

@Test
func testLzwRoundtripAlternating(): Unit {
    let data = Array<UInt8>(100, {i => if (i % 2 == 0) { UInt8(0x41) } else { UInt8(0x42) }})
    testRoundtrip(data, LzwOrder.LSB, 8)
}

@Test
func testLzwRoundtripIncrementing(): Unit {
    let data = Array<UInt8>(256, {i => UInt8(i % 256)})
    testRoundtrip(data, LzwOrder.LSB, 8)
}

@Test
func testLzwRoundtripMsb(): Unit {
    let data = strToBytes("MSB order LZW test data")
    testRoundtrip(data, LzwOrder.MSB, 8)
}

@Test
func testLzwRoundtripLitWidth4(): Unit {
    let data: Array<UInt8> = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F]
    testRoundtrip(data, LzwOrder.LSB, 4)
}

@Test
func testLzwRoundtripLitWidth2(): Unit {
    let data: Array<UInt8> = [0x00, 0x01, 0x02, 0x03]
    testRoundtrip(data, LzwOrder.LSB, 2)
}

@Test
func testLzwRoundtripLarge(): Unit {
    let data = Array<UInt8>(1024, {i => UInt8(i % 256)})
    testRoundtrip(data, LzwOrder.LSB, 8)
}

@Test
func testLzwRoundtripLargeMsb(): Unit {
    let data = Array<UInt8>(1024, {i => UInt8(i % 256)})
    testRoundtrip(data, LzwOrder.MSB, 8)
}

@Test
func testLzwRoundtripRepeatingPattern(): Unit {
    let data = Array<UInt8>(500, {i => UInt8((i % 10) + 0x30)})
    testRoundtrip(data, LzwOrder.LSB, 8)
}

@Test
func testLzwInvalidLitWidth(): Unit {
    try {
        let _ = lzwCompress([0x41], litWidth: 1)
        throw Exception("should have thrown")
    } catch (e: Exception) {
        // expected
    }
}

@Test
func testLzwInvalidLitWidthDecompress(): Unit {
    try {
        let _ = lzwDecompress([0x41], litWidth: 9)
        throw Exception("should have thrown")
    } catch (e: Exception) {
        // expected
    }
}

@Test
func testLzwByteTooLarge(): Unit {
    try {
        let _ = lzwCompress([0xFF], litWidth: 7)
        throw Exception("should have thrown")
    } catch (e: Exception) {
        // expected
    }
}
