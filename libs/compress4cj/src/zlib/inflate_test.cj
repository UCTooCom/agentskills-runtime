package compress4cj.zlib

@Test
func testInflateInitRawDeflate(): Unit {
    let inf = Inflate(-1)
    let ret = inf.inflateEnd()
    if (!(ret == Z_OK)) { throw Exception("inflateEnd") }
}

@Test
func testInflateInitZlib(): Unit {
    let inf = Inflate(1)
    let ret = inf.inflateEnd()
    if (!(ret == Z_OK)) { throw Exception("inflateEnd") }
}

@Test
func testInflateInitGzip(): Unit {
    let inf = Inflate(2)
    let ret = inf.inflateEnd()
    if (!(ret == Z_OK)) { throw Exception("inflateEnd") }
}

@Test
func testInflateEndIdempotent(): Unit {
    let inf = Inflate(-1)
    let ret1 = inf.inflateEnd()
    let ret2 = inf.inflateEnd()
    if (!(ret1 == Z_OK)) { throw Exception("ret1") }
    if (!(ret2 == Z_OK)) { throw Exception("ret2") }
}

@Test
func testInflateEndMethod(): Unit {
    let inf = Inflate(-1)
    inf.end()
    let ret = inf.inflateEnd()
    if (!(ret == Z_OK)) { throw Exception("inflateEnd after end") }
}

@Test
func testInflateSync(): Unit {
    let inf = Inflate(-1)
    let data = Array<Byte>(4, {i => UInt8([0, 0, 0xFF, 0xFF][i])})
    inf.setInBuf(data)
    let outBuf = Array<Byte>(32, repeat: 0)
    inf.setOutBuf(outBuf)
    let ret = inf.inflateSync()
    if (!(ret == Z_OK || ret == Z_BUF_ERROR)) { throw Exception("inflateSync") }
    inf.inflateEnd()
}

@Test
func testInflateDecompressesDeflate(): Unit {
    let d = Deflate()
    d.deflateInit2(6, -15, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY)
    let input = Array<Byte>(200, {i => UInt8(i % 256)})
    let compBuf = Array<Byte>(400, repeat: 0)
    d.setInBuf(input)
    d.setOutBuf(compBuf)
    while (d.avail_in > 0) { d.deflate(Z_NO_FLUSH) }
    d.resetOutBuf()
    d.setOutBuf(compBuf)
    while (true) {
        let err = d.deflate(Z_FINISH)
        if (err == Z_STREAM_END) { break }
        if (err == Z_BUF_ERROR && d.avail_out <= 0) { break }
    }
    let compLen = d.pos_out
    d.deflateEnd()

    let inf = Inflate(-1)
    let compData = Array<Byte>(compLen, repeat: 0)
    compBuf.copyTo(compData, 0, 0, compLen)
    let decompBuf = Array<Byte>(400, repeat: 0)
    inf.setInBuf(compData)
    inf.setOutBuf(decompBuf)
    inf.inflate(Z_NO_FLUSH)
    let decompLen = inf.pos_out
    if (!(decompLen == 200)) { throw Exception("decompLen") }
    inf.inflateEnd()
}

@Test
func testInflateDefaultInit(): Unit {
    let inf = Inflate()
    inf.inflateInit()
    let ret = inf.inflateEnd()
    if (!(ret == Z_OK)) { throw Exception("inflateEnd after default init") }
}

@Test
func testInflateInit2(): Unit {
    let inf = Inflate()
    let ret = inf.inflateInit2(15)
    if (!(ret == Z_OK)) { throw Exception("inflateInit2") }
    inf.inflateEnd()
}

@Test
func testInflateSetDictionary(): Unit {
    let inf = Inflate(1)
    let dict = Array<UInt8>(32, {i => UInt8(i)})
    // Before inflate starts, setDictionary may return STREAM_ERROR
    let ret = inf.setDictionary(dict)
    // Either OK or STREAM_ERROR is acceptable depending on state
    if (!(ret == Z_OK || ret == Z_STREAM_ERROR)) { throw Exception("setDictionary") }
    inf.inflateEnd()
}

@Test
func testInflateGetGzipHeader(): Unit {
    let inf = Inflate(-1)
    let header = inf.getGzipHeader()
    // For raw deflate, getGzipHeader should return None
    if (let Some(_) <- header) { throw Exception("getGzipHeader should be None") }
    inf.inflateEnd()
}

