package compress4cj.zlib

@Test
func testDeflateInit(): Unit {
    let d = Deflate()
    let ret = d.deflateInit(6)
    if (!(ret == Z_OK)) { throw Exception("deflateInit") }
    d.deflateEnd()
}

@Test
func testDeflateInitWithWindowBits(): Unit {
    let d = Deflate()
    let ret = d.deflateInit(6, -15)
    if (!(ret == Z_OK)) { throw Exception("deflateInit with wbits") }
    d.deflateEnd()
}

@Test
func testDeflateInit2Level0(): Unit {
    let d = Deflate()
    let ret = d.deflateInit2(0, 15, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY)
    if (!(ret == Z_OK)) { throw Exception("deflateInit2") }
    d.deflateEnd()
}

@Test
func testDeflateInit2Level6(): Unit {
    let d = Deflate()
    let ret = d.deflateInit2(6, 15, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY)
    if (!(ret == Z_OK)) { throw Exception("deflateInit2 level6") }
    d.deflateEnd()
}

@Test
func testDeflateBound(): Unit {
    let d = Deflate()
    d.deflateInit(6)
    let bound = d.deflateBound(1000)
    if (!(bound > 1000)) { throw Exception("bound") }
    d.deflateEnd()
}

@Test
func testDeflateCompressDecompressRaw(): Unit {
    let d = Deflate()
    d.deflateInit2(6, -15, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY)
    let input = Array<Byte>(100, {i => UInt8(i % 256)})
    let outBuf = Array<Byte>(200, repeat: 0)
    d.setInBuf(input)
    d.setOutBuf(outBuf)
    while (d.avail_in > 0) { d.deflate(Z_NO_FLUSH) }
    d.resetOutBuf()
    d.setOutBuf(outBuf)
    while (true) {
        let err = d.deflate(Z_FINISH)
        if (err == Z_STREAM_END) { break }
        if (err == Z_BUF_ERROR && d.avail_out <= 0) { break }
    }
    let compLen = d.pos_out
    if (!(compLen > 0)) { throw Exception("compLen") }
    d.deflateEnd()

    let inf = Inflate(-1)
    let decompBuf = Array<Byte>(200, repeat: 0)
    let compData = Array<Byte>(compLen, repeat: 0)
    outBuf.copyTo(compData, 0, 0, compLen)
    inf.setInBuf(compData)
    inf.setOutBuf(decompBuf)
    inf.inflate(Z_NO_FLUSH)
    let decompLen = inf.pos_out
    if (!(decompLen == 100)) { throw Exception("decompLen") }
    inf.inflateEnd()
}

@Test
func testDeflateSetDictionary(): Unit {
    let d = Deflate()
    d.deflateInit2(6, 15, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY)
    let dict = Array<UInt8>(32, {i => UInt8(i)})
    let ret = d.setDictionary(dict)
    if (!(ret == Z_OK)) { throw Exception("setDictionary") }
    d.deflateEnd()
}

@Test
func testDeflateSetHeader(): Unit {
    let d = Deflate()
    d.deflateInit2(6, 15 + 16, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY) // gzip
    let header = GZIPHeader()
    header.text = 1
    header.time = 12345
    let ret = d.deflateSetHeader(header)
    if (!(ret == Z_OK)) { throw Exception("deflateSetHeader") }
    d.deflateEnd()
}

@Test
func testDeflateSetHeaderWrongWrap(): Unit {
    let d = Deflate()
    d.deflateInit2(6, -15, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY) // raw deflate
    let header = GZIPHeader()
    let ret = d.deflateSetHeader(header)
    // Should fail because wrap != 2 (gzip)
    if (!(ret == Z_STREAM_ERROR)) { throw Exception("deflateSetHeader should fail for non-gzip") }
    d.deflateEnd()
}

