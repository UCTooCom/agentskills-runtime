package compress4cj.brotli

import compress4cj.common.strToBytes

@Test
func testBrotliAvailable(): Unit {
    let available = brotliAvailable()
    if (!(available == true)) { throw Exception("brotliAvailable should return true") }
}

@Test
func testBrotliCompressEmpty(): Unit {
    let data: Array<UInt8> = []
    let result = brotliCompress(data)
    if (!(result.size == 0)) { throw Exception("empty compress should return empty") }
}

@Test
func testBrotliCompressSmall(): Unit {
    let data = Array<UInt8>(10, repeat: 0x41)
    let result = brotliCompress(data)
    if (!(result.size > 0)) { throw Exception("compressed data should not be empty") }
}

@Test
func testBrotliDecompress(): Unit {
    let data = Array<UInt8>(10, repeat: 0x41)
    let compressed = brotliCompress(data)
    if (!(compressed.size > 0)) { throw Exception("compression failed") }
    let decompressed = brotliDecompress(compressed)
    if (!(decompressed.size == data.size)) { throw Exception("decompressed size mismatch") }
    for (i in 0..data.size) {
        if (!(decompressed[i] == data[i])) { throw Exception("decompressed data mismatch at ${i}") }
    }
}

@Test
func testBrotliDecompressEmpty(): Unit {
    let data: Array<UInt8> = []
    let result = brotliDecompress(data)
    if (!(result.size == 0)) { throw Exception("empty decompress should return empty") }
}

@Test
func testBrotliRoundtripLargeData(): Unit {
    let orig = Array<UInt8>(1024, {i => UInt8(i % 256)})
    let compressed = brotliCompress(orig)
    if (!(compressed.size > 0)) { throw Exception("compression failed") }
    let decompressed = brotliDecompress(compressed)
    if (!(decompressed.size == orig.size)) { throw Exception("decompressed size mismatch") }
    for (i in 0..orig.size) {
        if (!(decompressed[i] == orig[i])) { throw Exception("data mismatch at ${i}") }
    }
}

@Test
func testBrotliRoundtripStringData(): Unit {
    let orig = strToBytes("Hello, Brotli! Roundtrip test in zlib4cj.")
    let compressed = brotliCompress(orig)
    if (!(compressed.size > 0)) { throw Exception("compression failed") }
    let decompressed = brotliDecompress(compressed)
    if (!(decompressed.size == orig.size)) { throw Exception("decompressed size mismatch") }
    for (i in 0..orig.size) {
        if (!(decompressed[i] == orig[i])) { throw Exception("data mismatch at ${i}") }
    }
}

@Test
func testBrotliRawEncodeDecode(): Unit {
    let data = Array<UInt8>(50, {i => UInt8((i + 65) % 256)})
    let encoded = brotliRawEncode(data)
    if (!(encoded.size > 0)) { throw Exception("encode should produce output") }
    let decoded = brotliDecompress(encoded)
    if (!(decoded.size == data.size)) { throw Exception("decoded size mismatch") }
}

@Test
func testBrotliDictionaryWord(): Unit {
    let word = brotliGetDictionaryWord(4, 0)
    if (!(word.size == 4)) { throw Exception("dictionary word should have length 4") }
}
