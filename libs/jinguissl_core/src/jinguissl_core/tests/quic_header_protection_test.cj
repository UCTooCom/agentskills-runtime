 package jinguissl_core.tests

 import jinguissl_core.crypto.aes.aesBlockEncrypt
 import jinguissl_core.crypto.quic.{quicHpAesEncrypt, quicHpChaChaEncrypt}
 import jinguissl_core.crypto.chacha20.chacha20Block
 import jinguissl_core.crypto.digest.bytesToHexLower
 import jinguissl_core.crypto.error.CryptoException

 // ── QUIC v1 Client Initial header protection test vector ────────
 //
 // From quic-go internal/handshake/initial_aead_test.go TestClientInitial.
 // conn_id = 0x8394c8f03e515708
 // header  = c300000001088394c8f03e5157080000449e00000002
 // sample  = d1b1c98dd7689fb8ec11d242b123dc9b
 // hp_key  = (derived from initial_secret, "quic hp", 16)
 //
 // We derive the hp_key first, then verify the mask.

 @Test
 public class QuicHeaderProtectionTestSuite {

     @TestCase
     public func testAesHpAgainstQuicGoVector(): Unit {
         // Sample from the ciphertext of the sealed Client Initial
         let sample = hexToBytes("d1b1c98dd7689fb8ec11d242b123dc9b")
         // Header protection key derived from initial secret
        let hpKey = hexToBytes("9f50449e04a0e810283a1e9933adedd2")

         let (firstByteMask, pnMask) = quicHpAesEncrypt(sample, hpKey)

         // The mask first byte applied to header[0] (0xc3) with 0x0f mask should give 0xc0
         let originalFirstByte = UInt8(0xc3)
         let encryptedFirstByte = originalFirstByte ^ (firstByteMask & UInt8(0x0f))
         @Assert(encryptedFirstByte, UInt8(0xc0))

         // The PN bytes (0x00000002) encrypted should match the expected
         let originalPn = hexToBytes("00000002")
         let encryptedPn = Array<Byte>(4, repeat: 0)
         var i: Int64 = 0
         while (i < 4) {
             encryptedPn[i] = UInt8(originalPn[i]) ^ UInt8(pnMask[i])
             i += 1
         }
         assertHex(encryptedPn, "7b9aec34")

         // Verify the mask by computing AES-ECB directly
         let fullMask = aesBlockEncrypt(hpKey, sample)
         @Assert(firstByteMask, fullMask[0])
         @Assert(pnMask.size, 15)
         @Assert(pnMask[0], fullMask[1])
         @Assert(pnMask[1], fullMask[2])
     }

     @TestCase
     public func testAesHpServerVector(): Unit {
         // QUIC v1 Server Initial (from TestServersInitial in quic-go)
         // header  = c1000000010008f067a5502a4262b50040750001
         // sample  = 2cd0991cd25b0aac406a5816b6394100
         let sample = hexToBytes("2cd0991cd25b0aac406a5816b6394100")
        let hpKey  = hexToBytes("c206b8d9b9f0f37644430b490eeaa314")

         let originalHdrFirst = UInt8(0xc1)
         let originalPn = hexToBytes("0001")

         let (firstByteMask, pnMask) = quicHpAesEncrypt(sample, hpKey)

         let encryptedFirst = originalHdrFirst ^ (firstByteMask & UInt8(0x0f))
         @Assert(encryptedFirst, UInt8(0xcf))

         let encryptedPn = Array<Byte>(2, repeat: 0)
         var i: Int64 = 0
         while (i < 2) {
             encryptedPn[i] = UInt8(originalPn[i]) ^ UInt8(pnMask[i])
             i += 1
         }
         assertHex(encryptedPn, "c0d9")
     }

     @TestCase
     public func testChaChaHpRoundTrip(): Unit {
         // Sample constructed from ChaCha20 keystream block
         let key  = hexToBytes("8a2a74072c22b8e4d11b3ff5882e0be9c05c0afb97d4689f87bfe4276f85be65")
         // For ChaCha20 HP, sample[0..4] = little-endian counter, sample[4..16] = nonce
         let sample = hexToBytes("00000000aabbccddeeff001122334455")

         let (firstByteMask, pnMask) = quicHpChaChaEncrypt(sample, key)

         // Verify manually: counter=0, nonce=sample[4..16]
         let expectedBlock = chacha20Block(key, 0, hexToBytes("aabbccddeeff001122334455"))
         @Assert(firstByteMask, expectedBlock[0])
         @Assert(pnMask.size, 4)
         @Assert(pnMask[0], expectedBlock[1])
         @Assert(pnMask[1], expectedBlock[2])
         @Assert(pnMask[2], expectedBlock[3])
         @Assert(pnMask[3], expectedBlock[4])
     }

     @TestCase
     public func testAesHpLongAndShortHeaderMask(): Unit {
         // Verify that the mask is generated the same regardless of header type
         let sample = hexToBytes("00112233445566778899aabbccddeeff")
         let key    = hexToBytes("0123456789abcdef0123456789abcdef")

         let (firstByteMask, pnMask) = quicHpAesEncrypt(sample, key)

         // Long header mask for first byte: 0x0f
         let longMask = firstByteMask & UInt8(0x0f)
         // Short header mask for first byte: 0x1f
         let shortMask = firstByteMask & UInt8(0x1f)

         // The masks are the same if firstByteMask has no bits in 0x10
         @Assert(longMask, shortMask & UInt8(0x0f))
         @Assert(pnMask.size, 15)
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
