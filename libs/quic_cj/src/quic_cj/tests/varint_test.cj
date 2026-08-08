package quic_cj.tests

import quic_cj.wire.{readVarint, writeVarintLen, appendVarint, VARINT_MAX_1, VARINT_MAX_2, VARINT_MAX_4}

@Test
public class VarintTestSuite {
    @TestCase
    public func testReadVarint1Byte(): Unit {
        let data: Array<Byte> = [0x25u8]
        let (v, n) = readVarint(data)
        @Assert(v, 37)
        @Assert(n, 1)
    }

    @TestCase
    public func testReadVarint2Byte(): Unit {
        let data: Array<Byte> = [0x7b_u8, 0xbd_u8]
        let (v, n) = readVarint(data)
        @Assert(v, 15293)
        @Assert(n, 2)
    }

    @TestCase
    public func testReadVarint4Byte(): Unit {
        let data: Array<Byte> = [0x9d_u8, 0x7f_u8, 0x3e_u8, 0x7d_u8]
        let (v, n) = readVarint(data)
        @Assert(v, 494878333)
        @Assert(n, 4)
    }

    @TestCase
    public func testWriteVarintLen(): Unit {
        @Assert(writeVarintLen(0), 1)
        @Assert(writeVarintLen(VARINT_MAX_1), 1)
        @Assert(writeVarintLen(VARINT_MAX_1 + 1), 2)
        @Assert(writeVarintLen(VARINT_MAX_2), 2)
        @Assert(writeVarintLen(VARINT_MAX_2 + 1), 4)
        @Assert(writeVarintLen(VARINT_MAX_4), 4)
        @Assert(writeVarintLen(VARINT_MAX_4 + 1), 8)
    }

    @TestCase
    public func testAppendVarintRoundTrip(): Unit {
        let values: Array<Int64> = [0, 1, 63, 64, 16383, 16384, 1073741823, 1073741824, VARINT_MAX_4 + 1]
        var i: Int64 = 0
        while (i < values.size) {
            let v = values[i]
            let buf = appendVarint([], v)
            let (decoded, n) = readVarint(buf)
            @Assert(decoded, v)
            @Assert(n, buf.size)
            i += 1
        }
    }

    @TestCase
    public func testAppendToExisting(): Unit {
        let 前缀: Array<Byte> = [0x01u8, 0x02u8]
        let buf = appendVarint(前缀, 42)
        @Assert(buf.size, 2 + 1)
        @Assert(UInt8(buf[0]), 0x01u8)
        @Assert(UInt8(buf[1]), 0x02u8)
        @Assert(Int64(UInt8(buf[2])), 42)
    }
}
