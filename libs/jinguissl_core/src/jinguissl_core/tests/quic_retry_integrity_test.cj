 package jinguissl_core.tests

 import jinguissl_core.crypto.quic.{quicRetryIntegrityTag, quicVerifyRetryIntegrity}
 import jinguissl_core.crypto.digest.bytesToHexLower
 import jinguissl_core.crypto.error.CryptoException

 @Test
 public class QuicRetryIntegrityTestSuite {

     @TestCase
     public func testRetryTagAgainstQuicGoVectorV1(): Unit {
         // From quic-go internal/handshake/retry_test.go TestRetryIntegrityTagWithTestVectors
         // data (with tag): ff000000010008f067a5502a4262b5746f6b656e04a265ba2eff4d829058fb3f0f2496ba
         // origDestConnId: 0x8394c8f03e515708
         let fullPacket = hexToBytes(
             "ff000000010008f067a5502a4262b5746f6b656e04a265ba2eff4d829058fb3f0f2496ba"
         )
         let origDestConnId = hexToBytes("8394c8f03e515708")

         // Split: first part is retry packet data without tag, last 16 bytes are tag
         let retryPacket = fullPacket[..(fullPacket.size - 16)]
         let expectedTag = fullPacket[(fullPacket.size - 16)..]

         let tag = quicRetryIntegrityTag(retryPacket, origDestConnId, false)
         @Assert(tag.size, 16)
         @Assert(tag, expectedTag)
     }

     @TestCase
     public func testRetryTagAgainstQuicGoVectorV2(): Unit {
         // QUIC v2 retry integrity test vector (from quic-go)
         let fullPacket = hexToBytes(
             "cf6b3343cf0008f067a5502a4262b5746f6b656ec8646ce8bfe33952d955543665dcc7b6"
         )
         let origDestConnId = hexToBytes("8394c8f03e515708")

         let retryPacket = fullPacket[..(fullPacket.size - 16)]
         let expectedTag = fullPacket[(fullPacket.size - 16)..]

         let tag = quicRetryIntegrityTag(retryPacket, origDestConnId, true)
         @Assert(tag.size, 16)
         @Assert(tag, expectedTag)
     }

     @TestCase
     public func testVerifyRetryIntegrity(): Unit {
         let fullPacket = hexToBytes(
             "ff000000010008f067a5502a4262b5746f6b656e04a265ba2eff4d829058fb3f0f2496ba"
         )
         let origDestConnId = hexToBytes("8394c8f03e515708")

         // Valid tag should verify true
         @Assert(quicVerifyRetryIntegrity(fullPacket, origDestConnId, false), true)

         // Invalid tag should verify false
         let corrupted = fullPacket.clone()
         corrupted[corrupted.size - 1] = UInt8(corrupted[corrupted.size - 1]) ^ UInt8(0xff)
         @Assert(quicVerifyRetryIntegrity(corrupted, origDestConnId, false), false)
     }

     @TestCase
     public func testVerifyRetryTooShort(): Unit {
         let shortBuf = hexToBytes("001122")
         @Assert(quicVerifyRetryIntegrity(shortBuf, hexToBytes("00"), false), false)
     }

     @TestCase
     public func testRetryTagDifferentConnIdsProduceDifferentTags(): Unit {
         let retryPacket = hexToBytes(
             "ff000000010008f067a5502a4262b5746f6b656e"
         )
         let connId1 = hexToBytes("8394c8f03e515708")
         let connId2 = hexToBytes("1234567890abcdef")

         let tag1 = quicRetryIntegrityTag(retryPacket, connId1, false)
         let tag2 = quicRetryIntegrityTag(retryPacket, connId2, false)
         @Assert(tag1 != tag2, true)
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
     @Assert(bytesToHexLower(actual), expectedHex.toAsciiLower())
 }
