package quic_cj.tests

import quic_cj.core.{CryptoStream, InitialCryptoStream, newCryptoStream, newInitialCryptoStream}
import quic_cj.wire.CryptoFrame

@Test
public class CryptoStreamTestSuite {
    @TestCase
    public func testNewCryptoStreamNoData(): Unit {
        let cs = newCryptoStream()
        @Assert(cs.hasData(), false)
        let data = cs.getCryptoData()
        @Assert(data.size, 0)
    }

    @TestCase
    public func testWriteDataAndPopFrame(): Unit {
        let cs = newCryptoStream()
        cs.writeData([0x01u8, 0x02u8, 0x03u8])
        @Assert(cs.hasData(), true)
        if (let Some(cf) <- cs.popCryptoFrame(100)) {
            @Assert(cf.data.size, 3)
            @Assert(cf.offset, 0)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testPopFrameRespectsMaxLen(): Unit {
        let cs = newCryptoStream()
        cs.writeData([0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8])
        if (let Some(cf) <- cs.popCryptoFrame(3)) {
            @Assert(cf.data.size, 3)
            @Assert(cf.offset, 0)
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testPopFrameMultipleChunks(): Unit {
        let cs = newCryptoStream()
        cs.writeData([0x01u8, 0x02u8, 0x03u8])
        if (let Some(cf1) <- cs.popCryptoFrame(2)) {
            @Assert(cf1.data.size, 2)
            @Assert(cf1.offset, 0)
            if (let Some(cf2) <- cs.popCryptoFrame(2)) {
                @Assert(cf2.data.size, 1)
                @Assert(cf2.offset, 2)
            } else {
                @Assert(false, true)
            }
        } else {
            @Assert(false, true)
        }
    }

    @TestCase
    public func testPopFrameEmptyWhenNoData(): Unit {
        let cs = newCryptoStream()
        let none = match (cs.popCryptoFrame(100)) { case None => true; case _ => false }
        @Assert(none, true)
    }

    @TestCase
    public func testHandleCryptoFrame(): Unit {
        let cs = newCryptoStream()
        let cf = CryptoFrame()
        cf.offset = 0
        cf.data = [0x0au8, 0x0bu8]
        let result = cs.handleCryptoFrame(cf)
        @Assert(result, true)
        let data = cs.getCryptoData()
        @Assert(data.size, 2)
    }

    @TestCase
    public func testInitialCryptoStreamIsIndependent(): Unit {
        let ics = newInitialCryptoStream()
        @Assert(ics.hasData(), false)
        ics.writeData([0xaau8])
        @Assert(ics.hasData(), true)
    }
}
