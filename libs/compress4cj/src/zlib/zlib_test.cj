package compress4cj.zlib
import compress4cj.common.Zlib4cjException

// Helper: convert ASCII string to byte array using byte access
func sb(s: String): Array<UInt8> {
    let result = Array<UInt8>(s.size, {i => s[i]})
    return result
}

@Test
func testCompressRoundtripZlib(): Unit {
    let orig = sb("Hello, World! Roundtrip zlib test.")
    let comp = Zlib.compress(orig, wrap: ZlibType.ZLIB, level: 6)
    if (!(comp.size > 0)) { throw Exception("comp size") }
    let decomp = Zlib.uncompress(comp, wrap: ZlibType.ZLIB)
    let expected = sb("Hello, World! Roundtrip zlib test.")
    if (!(decomp.size == expected.size)) { throw Exception("size mismatch") }
}

@Test
func testCompressRoundtripGzip(): Unit {
    let orig = sb("Gzip format roundtrip test!")
    let comp = Zlib.compress(orig, wrap: ZlibType.GZIP, level: 6)
    if (!(comp.size > 0)) { throw Exception("comp size") }
    let decomp = Zlib.uncompress(comp, wrap: ZlibType.GZIP)
    let expected = sb("Gzip format roundtrip test!")
    if (!(decomp.size == expected.size)) { throw Exception("size mismatch") }
}

@Test
func testCompressRoundtripRawDeflate(): Unit {
    let orig = sb("Raw deflate test.")
    let comp = Zlib.compress(orig, wrap: ZlibType.DEFLATE, level: 6)
    if (!(comp.size > 0)) { throw Exception("comp size") }
    let decomp = Zlib.uncompress(comp, wrap: ZlibType.DEFLATE)
    let expected = sb("Raw deflate test.")
    if (!(decomp.size == expected.size)) { throw Exception("size mismatch") }
}

@Test
func testCompressRoundtripAutoDetect(): Unit {
    let orig = sb("Auto-detect roundtrip.")
    let comp = Zlib.compress(orig, wrap: ZlibType.ZLIB, level: 6)
    if (!(comp.size > 0)) { throw Exception("comp size") }
    let decomp = Zlib.uncompress(comp, wrap: ZlibType.AUTO_DETECT)
    let expected = sb("Auto-detect roundtrip.")
    if (!(decomp.size == expected.size)) { throw Exception("size mismatch") }
}

@Test
func testCompressEmptyData(): Unit {
    let orig = Array<Byte>()
    let comp = Zlib.compress(orig)
    if (!(comp.size == 0)) { throw Exception("comp size") }
}

@Test
func testUncompressEmptyData(): Unit {
    let data = Array<Byte>()
    let result = Zlib.uncompress(data)
    if (!(result.size == 0)) { throw Exception("result size") }
}


@Test
func testCompressSmallBuffer(): Unit {
    let orig = sb("Small buffer size test for chunked processing.")
    let comp = Zlib.compress(orig, bufferSize: 8)
    let decomp = Zlib.uncompress(comp, bufferSize: 8)
    let expected = sb("Small buffer size test for chunked processing.")
    if (!(decomp.size == expected.size)) { throw Exception("size mismatch") }
}

@Test
func testCompressLargeData(): Unit {
    let orig = Array<Byte>(10240, {i => UInt8(i % 256)})
    let comp = Zlib.compress(orig, wrap: ZlibType.ZLIB, level: 6)
    let decomp = Zlib.uncompress(comp, wrap: ZlibType.ZLIB)
    if (!(decomp.size == orig.size)) { throw Exception("size mismatch") }
}

@Test
func testCompressRepeatedData(): Unit {
    let orig = Array<Byte>(5000, repeat: 65)
    let comp = Zlib.compress(orig, wrap: ZlibType.ZLIB, level: 6)
    if (!(comp.size > 0)) { throw Exception("comp size") }
    if (!(comp.size < orig.size)) { throw Exception("compression expected") }
    let decomp = Zlib.uncompress(comp, wrap: ZlibType.ZLIB)
    if (!(decomp.size == 5000)) { throw Exception("decomp size") }
}

@Test
func testMaxOutputSizeProtection(): Unit {
    let orig = Array<Byte>(5000, {i => UInt8(i % 256)})
    let comp = Zlib.compress(orig, wrap: ZlibType.ZLIB, level: 6)
    var threw = false
    try {
        Zlib.uncompress(comp, wrap: ZlibType.ZLIB, maxOutputSize: 10)
    } catch (e: Zlib4cjException) {
        threw = true
    }
    if (!(threw)) { throw Exception("maxOutputSize not enforced") }
}

@Test
func testCompressWithDictZlib(): Unit {
    let dict = sb("my-custom-dict-for-test")
    let orig = sb("Data with dictionary for better compression.")
    let comp = Zlib.compress(orig, wrap: ZlibType.ZLIB, dict: dict)
    let decomp = Zlib.uncompress(comp, wrap: ZlibType.ZLIB, dict: dict)
    let expected = sb("Data with dictionary for better compression.")
    if (!(decomp.size == expected.size)) { throw Exception("size mismatch") }
}

@Test
func testCompressEmptyDict(): Unit {
    let orig = sb("some data")
    var threw = false
    try {
        Zlib.compress(orig, dict: Array<Byte>())
    } catch (e: Zlib4cjException) {
        threw = true
    }
    if (!(threw)) { throw Exception("empty dict not rejected") }
}
