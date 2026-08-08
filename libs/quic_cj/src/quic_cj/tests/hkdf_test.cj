 package quic_cj.tests
 
 import quic_cj.tls.{quicHkdfExpandLabel, quicHkdfExtract}
 
 @Test
 public class HkdfTestSuite {
     @TestCase
     public func testHkdfExtractSize(): Unit {
         let salt = Array<Byte>(32, repeat: 0x00u8)
         let ikm = Array<Byte>(32, repeat: 0xabu8)
         let prk = quicHkdfExtract(salt, ikm)
         @Assert(prk.size, 32)
     }
 
     @TestCase
     public func testHkdfExtractEmptySalt(): Unit {
         let salt = Array<Byte>(0, repeat: 0u8)
         let ikm = Array<Byte>(32, repeat: 0x01u8)
         let prk = quicHkdfExtract(salt, ikm)
         @Assert(prk.size, 32)
     }
 
     @TestCase
     public func testHkdfExpandLabelKey(): Unit {
         let secret = Array<Byte>(32, repeat: 0x01u8)
         let result = quicHkdfExpandLabel(secret, "quic key", [], 16)
         @Assert(result.size, 16)
     }
 
     @TestCase
     public func testHkdfExpandLabelIv(): Unit {
         let secret = Array<Byte>(32, repeat: 0x01u8)
         let result = quicHkdfExpandLabel(secret, "quic iv", [], 12)
         @Assert(result.size, 12)
     }
 
     @TestCase
     public func testHkdfExpandLabelHp(): Unit {
         let secret = Array<Byte>(32, repeat: 0x01u8)
         let result = quicHkdfExpandLabel(secret, "quic hp", [], 16)
         @Assert(result.size, 16)
     }
 
     @TestCase
     public func testHkdfExpandLabelWithContext(): Unit {
         let secret = Array<Byte>(32, repeat: 0x01u8)
         let ctx: Array<Byte> = [0x01u8, 0x02u8, 0x03u8]
         let result = quicHkdfExpandLabel(secret, "quic ku", ctx, 16)
         @Assert(result.size, 16)
     }
 
     @TestCase
     public func testHkdfExpandLabelLargeOutput(): Unit {
         let secret = Array<Byte>(32, repeat: 0x01u8)
         let result = quicHkdfExpandLabel(secret, "quic key", [], 64)
         @Assert(result.size, 64)
     }
 
     @TestCase
     public func testHkdfExtractDeterministic(): Unit {
         let salt = Array<Byte>(32, repeat: 0x00u8)
         let ikm = Array<Byte>(32, repeat: 0x01u8)
         let prk1 = quicHkdfExtract(salt, ikm)
         let prk2 = quicHkdfExtract(salt, ikm)
         // 检查两次结果一致
         @Assert(prk1.size, prk2.size)
         @Assert(prk1[0], prk2[0])
     }
 }
