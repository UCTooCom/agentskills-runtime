 package quic_cj.tests
 
 import quic_cj.wire.{appendByte, appendBytes}
 
 @Test
 public class BufferOpsTestSuite {
     @TestCase
     public func testAppendByteEmpty(): Unit {
         let buf = appendByte([], 0x42u8)
         @Assert(buf.size, 1)
         @Assert(Int64(UInt8(buf[0])), 0x42)
     }
 
     @TestCase
     public func testAppendByteNonEmpty(): Unit {
         let buf = appendByte([0x01u8, 0x02u8], 0x03u8)
         @Assert(buf.size, 3)
         @Assert(Int64(UInt8(buf[0])), 1)
         @Assert(Int64(UInt8(buf[2])), 3)
     }
 
     @TestCase
     public func testAppendByteMaxValue(): Unit {
         let buf = appendByte([], 0xffu8)
         @Assert(buf.size, 1)
         @Assert(Int64(UInt8(buf[0])), 255)
     }
 
     @TestCase
     public func testAppendBytesEmpty(): Unit {
         let buf = appendBytes([], [])
         @Assert(buf.size, 0)
     }
 
     @TestCase
     public func testAppendBytesSingle(): Unit {
         let buf = appendBytes([0x01u8], [0x02u8])
         @Assert(buf.size, 2)
         @Assert(Int64(UInt8(buf[0])), 1)
         @Assert(Int64(UInt8(buf[1])), 2)
     }
 
     @TestCase
     public func testAppendBytesMultiple(): Unit {
         let buf = appendBytes([0x01u8, 0x02u8], [0x03u8, 0x04u8, 0x05u8])
         @Assert(buf.size, 5)
         var i: Int64 = 0
         while (i < 5) {
             @Assert(Int64(UInt8(buf[i])), i + 1)
             i += 1
         }
     }
 
     @TestCase
     public func testAppendBytesLarge(): Unit {
         var src = Array<Byte>(1000, repeat: 0xabu8)
         let extra = Array<Byte>(500, repeat: 0xcdu8)
         let buf = appendBytes(src, extra)
         @Assert(buf.size, 1500)
     }
 }
