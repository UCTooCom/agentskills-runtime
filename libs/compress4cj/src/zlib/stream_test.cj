package compress4cj.zlib

@Test
func testStreamInit(): Unit {
    let s = Stream()
    if (!(s.isInbufEmpty())) { throw Exception("isInbufEmpty") }
    if (!(!s.isHaveOutData())) { throw Exception("isHaveOutData") }
    if (!(s.getTotalIn() == 0)) { throw Exception("getTotalIn") }
    if (!(s.getTotalOut() == 0)) { throw Exception("getTotalOut") }
    if (!(s.getOutDataLength() == 0)) { throw Exception("getOutDataLength") }
}

@Test
func testStreamSetInBuf(): Unit {
    let s = Stream()
    let buf = Array<UInt8>(10, {i => UInt8(i)})
    let len = s.setInBuf(buf)
    if (!(len == 10)) { throw Exception("len") }
    if (!(!s.isInbufEmpty())) { throw Exception("isInbufEmpty") }
}

@Test
func testStreamSetInBufWithStart(): Unit {
    let s = Stream()
    let buf = Array<UInt8>(10, {i => UInt8(i)})
    let len = s.setInBuf(buf, 3, 4)
    if (!(len == 4)) { throw Exception("len") }
}

@Test
func testStreamSetInBufInvalid(): Unit {
    let s = Stream()
    let buf = Array<UInt8>(10, {i => UInt8(i)})
    let len1 = s.setInBuf(buf, 0, -1)
    if (!(len1 == 0)) { throw Exception("len1") }
    let len2 = s.setInBuf(buf, 100, 5)
    if (!(len2 == 0)) { throw Exception("len2") }
}

@Test
func testStreamSetOutBuf(): Unit {
    let s = Stream()
    let buf = Array<UInt8>(10, {i => UInt8(i)})
    let len = s.setOutBuf(buf)
    if (!(len == 10)) { throw Exception("len") }
}

@Test
func testStreamSetOutBufWithStart(): Unit {
    let s = Stream()
    let buf = Array<UInt8>(10, {i => UInt8(i)})
    let len = s.setOutBuf(buf, 2, 5)
    if (!(len == 5)) { throw Exception("len") }
}

@Test
func testStreamSetOutBufInvalid(): Unit {
    let s = Stream()
    let buf = Array<UInt8>(10, {i => UInt8(i)})
    let len1 = s.setOutBuf(buf, 0, -1)
    if (!(len1 == 0)) { throw Exception("len1") }
    let len2 = s.setOutBuf(buf, 100, 5)
    if (!(len2 == 0)) { throw Exception("len2") }
}

@Test
func testStreamResetOutBuf(): Unit {
    let s = Stream()
    let buf = Array<UInt8>(10, {i => UInt8(i)})
    s.setOutBuf(buf)
    s.resetOutBuf()
    if (!(s.getOutDataLength() == 0)) { throw Exception("getOutDataLength") }
}
