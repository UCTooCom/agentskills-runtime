 package jinguissl.tests

 import jinguissl.contract.*

 @Test
 public class ContractQuicRetryTestSuite {

     @TestCase
     public func testRetryTagV1(): Unit {
         let fullPacket = hexToBytes(
             "ff000000010008f067a5502a4262b5746f6b656e04a265ba2eff4d829058fb3f0f2496ba"
         )
         let origDestConnId = hexToBytes("8394c8f03e515708")
         let retryPacket = fullPacket[..(fullPacket.size - 16)]
         let expectedTag = fullPacket[(fullPacket.size - 16)..]

         let tag = contractQuicRetryIntegrityTag(retryPacket, origDestConnId, false)
         @Assert(tag.size, 16)
         @Assert(tag, expectedTag)
     }

     @TestCase
     public func testRetryTagV2(): Unit {
         let fullPacket = hexToBytes(
             "cf6b3343cf0008f067a5502a4262b5746f6b656ec8646ce8bfe33952d955543665dcc7b6"
         )
         let origDestConnId = hexToBytes("8394c8f03e515708")
         let retryPacket = fullPacket[..(fullPacket.size - 16)]
         let expectedTag = fullPacket[(fullPacket.size - 16)..]

         let tag = contractQuicRetryIntegrityTag(retryPacket, origDestConnId, true)
         @Assert(tag.size, 16)
         @Assert(tag, expectedTag)
     }

     @TestCase
     public func testVerifyRetryIntegrity(): Unit {
         let fullPacket = hexToBytes(
             "ff000000010008f067a5502a4262b5746f6b656e04a265ba2eff4d829058fb3f0f2496ba"
         )
         let origDestConnId = hexToBytes("8394c8f03e515708")

         @Assert(contractQuicVerifyRetryIntegrity(fullPacket, origDestConnId, false), true)

         let corrupted = fullPacket.clone()
         corrupted[corrupted.size - 1] = UInt8(corrupted[corrupted.size - 1]) ^ UInt8(0xff)
         @Assert(contractQuicVerifyRetryIntegrity(corrupted, origDestConnId, false), false)
     }

     @TestCase
     public func testVerifyTooShort(): Unit {
         let shortBuf = hexToBytes("001122")
         @Assert(contractQuicVerifyRetryIntegrity(shortBuf, hexToBytes("00"), false), false)
     }

     @TestCase
     public func testDifferentConnIdsProduceDifferentTags(): Unit {
         let retryPacket = hexToBytes(
             "ff000000010008f067a5502a4262b5746f6b656e"
         )
         let connId1 = hexToBytes("8394c8f03e515708")
         let connId2 = hexToBytes("1234567890abcdef")

         let tag1 = contractQuicRetryIntegrityTag(retryPacket, connId1, false)
         let tag2 = contractQuicRetryIntegrityTag(retryPacket, connId2, false)
         @Assert(tag1 != tag2, true)
     }

     @TestCase
     public func testRetryTagWithEmptyOrigDestConnId(): Unit {
         let retryPacket = hexToBytes(
             "ff000000010008f067a5502a4262b5746f6b656e04a265ba2eff4d829058fb3f0f2496ba"
         )
         let emptyConnId: Array<Byte> = []
         let retryOnly = retryPacket[..(retryPacket.size - 16)]
         let tag = contractQuicRetryIntegrityTag(retryOnly, emptyConnId, false)
         @Assert(tag.size, 16)
     }

     @TestCase
     public func testVerifyRetryIntegrityV2(): Unit {
         let fullPacket = hexToBytes(
             "cf6b3343cf0008f067a5502a4262b5746f6b656ec8646ce8bfe33952d955543665dcc7b6"
         )
         let origDestConnId = hexToBytes("8394c8f03e515708")

         @Assert(contractQuicVerifyRetryIntegrity(fullPacket, origDestConnId, true), true)

         // V2 tag should not verify under V1
         @Assert(contractQuicVerifyRetryIntegrity(fullPacket, origDestConnId, false), false)
     }

     @TestCase
     public func testVerifyRetryWithWrongOrigDestConnId(): Unit {
         let fullPacket = hexToBytes(
             "ff000000010008f067a5502a4262b5746f6b656e04a265ba2eff4d829058fb3f0f2496ba"
         )
         let wrongConnId = hexToBytes("0000000000000000")

         @Assert(contractQuicVerifyRetryIntegrity(fullPacket, wrongConnId, false), false)
     }

     @TestCase
     public func testRetryRejectsOversizedOrigDestConnId(): Unit {
         try {
             _ = contractQuicRetryIntegrityTag(
                 [0x00], Array<Byte>(21, repeat: 0), false
             )
             @Fail("QUIC original destination connection ID must not exceed 20 bytes")
         } catch (e: ContractException) {
             @Assert(e.code, ContractErrorCode.BadInput)
         }
     }
 }

 private func hexToBytes(hex: String): Array<Byte> {
     let clean = hex.trimAscii().replace(" ", "").replace("\n", "").replace("\t", "")
     if ((clean.size % 2) != 0) {
         throw Exception("invalid hex length")
     }
     let out = Array<Byte>(clean.size / 2, repeat: 0)
     var i = 0
     while (i < clean.size) {
         let hi = hexNibble(clean[i])
         let lo = hexNibble(clean[i + 1])
         out[i / 2] = UInt8((hi << 4) | lo)
         i += 2
     }
     out
 }

 private func hexNibble(ch: Byte): UInt8 {
     if (ch >= b'0' && ch <= b'9') { return UInt8(ch - b'0') }
     let lower = if (ch >= b'A' && ch <= b'F') { ch + 32 } else { ch }
     if (lower >= b'a' && lower <= b'f') { return UInt8(lower - b'a' + 10) }
     throw Exception("invalid hex char")
 }

 private func assertHex(actual: Array<Byte>, expectedHex: String): Unit {
     @Assert(contractBytesToHexLower(actual), expectedHex.toAsciiLower())
 }
