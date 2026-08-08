package compress4cj.zlib
import compress4cj.common.Zlib4cjException

@Test
func testAdler32Empty(): Unit {
    let result = adler32(1, NULL_ARR_UINT8, 0, 0)
    if (!(result == UInt32(1))) { throw Exception("testAdler32Empty") }
}

@Test
func testAdler32OneByte(): Unit {
    let data = Array<UInt8>(1, repeat: 0)
    data[0] = 65
    let result = adler32(1, data, 0, 1)
    let expected = UInt32(66) | (UInt32(66) << 16) // 0x00420042
    if (!(result == expected)) { throw Exception("testAdler32OneByte") }
}

@Test
func testAdler32FiveBytes(): Unit {
    let data = Array<UInt8>(5, repeat: 0)
    for (i in 0..5) { data[i] = UInt8(65 + i) }
    let result = adler32(1, data, 0, 5)
    // Verify by computing manually
    var adler: UInt32 = 1
    var sum2: UInt32 = 0
    for (i in 0..5) {
        adler += UInt32(data[i])
        if (adler >= 65521) { adler -= 65521 }
        sum2 += adler
        if (sum2 >= 65521) { sum2 -= 65521 }
    }
    let expected = adler | (sum2 << 16)
    if (!(result == expected)) { throw Exception("testAdler32FiveBytes") }
}

@Test
func testCrc32Empty(): Unit {
    let result = crc32(UInt32(0), NULL_ARR_UINT8, 0, 0)
    if (!(result == UInt32(0))) { throw Exception("testCrc32Empty") }
}

@Test
func testCrc32EmptyWithInitValue(): Unit {
    let result = crc32(UInt32(0x12345678), NULL_ARR_UINT8, 0, -1)
    if (!(result == UInt32(0x12345678))) { throw Exception("testCrc32EmptyWithInitValue") }
}

@Test
func testCrc32Continuation(): Unit {
    let data1 = Array<UInt8>(3, {i => UInt8([72, 101, 108][i])})
    let data2 = Array<UInt8>(2, {i => UInt8([108, 111][i])})
    let partial = crc32(UInt32(0), data1, 0, 3)
    let final_result = crc32(partial, data2, 0, 2)
    let direct = crc32(UInt32(0), Array<UInt8>(5, {i => UInt8([72, 101, 108, 108, 111][i])}), 0, 5)
    if (!(final_result == direct)) { throw Exception("testCrc32Continuation") }
}

@Test
func testAdler32Continuation(): Unit {
    let data1 = Array<UInt8>(2, {i => UInt8([65, 66][i])})
    let data2 = Array<UInt8>(2, {i => UInt8([67, 68][i])})
    let partial = adler32(1, data1, 0, 2)
    let final_result = adler32(partial, data2, 0, 2)
    let direct = adler32(1, Array<UInt8>(4, {i => UInt8([65, 66, 67, 68][i])}), 0, 4)
    if (!(final_result == direct)) { throw Exception("testAdler32Continuation") }
}

@Test
func testZlib4cjException(): Unit {
    let e = Zlib4cjException("test error")
    if (!(e.message == "test error")) { throw Exception("testZlib4cjException message") }
}

@Test
func testZlib4cjExceptionEmpty(): Unit {
    let e = Zlib4cjException("")
    if (!(e.toString() == "Zlib4cjException")) { throw Exception("testZlib4cjExceptionEmpty") }
}

@Test
func testGZIPHeaderInit(): Unit {
    let h = GZIPHeader()
    if (!(h.text == 0)) { throw Exception("testGZIPHeaderInit text") }
    if (!(h.time == 0)) { throw Exception("testGZIPHeaderInit time") }
    if (!(h.os == 255)) { throw Exception("testGZIPHeaderInit os") }
    if (!(h.done == 0)) { throw Exception("testGZIPHeaderInit done") }
}
