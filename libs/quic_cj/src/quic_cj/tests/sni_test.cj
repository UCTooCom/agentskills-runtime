package quic_cj.tests

import quic_cj.core.findSniAndEch

@Test
public class SniTestSuite {
    @TestCase
    public func testFindSniShortData(): Unit {
        let none1 = match (findSniAndEch([0x01u8])) { case None => true; case _ => false }
        @Assert(none1, true)
    }

    @TestCase
    public func testFindSniNotClientHello(): Unit {
        let none2 = match (findSniAndEch([0x02u8, 0x00u8, 0x00u8, 0x00u8])) { case None => true; case _ => false }
        @Assert(none2, true)
    }

    @TestCase
    public func testFindSniEmptyData(): Unit {
        let none3 = match (findSniAndEch([])) { case None => true; case _ => false }
        @Assert(none3, true)
    }

    @TestCase
    public func testFindSniHandshakeLenMismatch(): Unit {
        let data: Array<Byte> = [0x01u8, 0x00u8, 0x00u8, 0x05u8, 0x00u8]
        let none4 = match (findSniAndEch(data)) { case None => true; case _ => false }
        @Assert(none4, true)
    }

    @TestCase
    public func testFindSniNoExtensions(): Unit {
        let data = buildNoExtClientHello()
        let some1 = match (findSniAndEch(data)) { case Some(_) => true; case _ => false }
        @Assert(some1, true)
    }
}

private func buildNoExtClientHello(): Array<Byte> {
    let random: Array<Byte> = Array<Byte>(32, repeat: 0xaau8)
    let outlen: Int64 = 4 + 2 + 32 + 1 + 0 + 2 + 2 + 1 + 1 + 2 + 0
    var out: Array<Byte> = Array<Byte>(outlen, repeat: 0x00u8)
    var pos: Int64 = 0
    out[pos] = 0x01u8; pos += 1
    let bodyLen: Int64 = outlen - 4
    out[pos] = UInt8((bodyLen >> 16) & 0xff); pos += 1
    out[pos] = UInt8((bodyLen >> 8) & 0xff); pos += 1
    out[pos] = UInt8(bodyLen & 0xff); pos += 1
    out[pos] = 0x03u8; pos += 1
    out[pos] = 0x03u8; pos += 1
    var i: Int64 = 0
    while (i < 32) { out[pos] = random[i]; pos += 1; i += 1 }
    out[pos] = 0x00u8; pos += 1
    out[pos] = 0x00u8; pos += 1
    out[pos] = 0x02u8; pos += 1
    out[pos] = 0x13u8; pos += 1
    out[pos] = 0x01u8; pos += 1
    out[pos] = 0x01u8; pos += 1
    out[pos] = 0x00u8; pos += 1
    out[pos] = 0x00u8; pos += 1
    out[pos] = 0x00u8; pos += 1
    out
}
