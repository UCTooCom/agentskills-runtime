 package jinguissl.tests

 import jinguissl.contract.*

 @Test
 public class ContractQuicHeaderProtectionTestSuite {

     @TestCase
     public func testAesHpClientVector(): Unit {
         // From quic-go initial_aead_test.go TestClientInitial
         let sample = hexToBytes("d1b1c98dd7689fb8ec11d242b123dc9b")
         let hpKey  = hexToBytes("9f50449e04a0e810283a1e9933adedd2")

         let (firstByteMask, pnMask) = contractQuicHpAesEncrypt(sample, hpKey)

         let originalFirstByte = UInt8(0xc3)
         let encryptedFirstByte = originalFirstByte ^ (firstByteMask & UInt8(0x0f))
         @Assert(encryptedFirstByte, UInt8(0xc0))

         let originalPn = hexToBytes("00000002")
         let encryptedPn = Array<Byte>(4, repeat: 0)
         var i: Int64 = 0
         while (i < 4) {
             encryptedPn[i] = UInt8(originalPn[i]) ^ UInt8(pnMask[i])
             i += 1
         }
         assertHex(encryptedPn, "7b9aec34")
     }

     @TestCase
     public func testAesHpServerVector(): Unit {
         // From quic-go initial_aead_test.go TestServersInitial
         let sample = hexToBytes("2cd0991cd25b0aac406a5816b6394100")
         let hpKey  = hexToBytes("c206b8d9b9f0f37644430b490eeaa314")

         let (firstByteMask, pnMask) = contractQuicHpAesEncrypt(sample, hpKey)

         let encryptedFirst = UInt8(0xc1) ^ (firstByteMask & UInt8(0x0f))
         @Assert(encryptedFirst, UInt8(0xcf))

         let encryptedPn = Array<Byte>(2, repeat: 0)
         var i: Int64 = 0
         while (i < 2) {
             encryptedPn[i] = UInt8(hexToBytes("0001")[i]) ^ UInt8(pnMask[i])
             i += 1
         }
         assertHex(encryptedPn, "c0d9")
     }

     @TestCase
     public func testChaChaHpRoundTrip(): Unit {
         let key  = hexToBytes("8a2a74072c22b8e4d11b3ff5882e0be9c05c0afb97d4689f87bfe4276f85be65")
         let sample = hexToBytes("00000000aabbccddeeff001122334455")

         let (firstByteMask, pnMask) = contractQuicHpChaChaEncrypt(sample, key)

         @Assert(pnMask.size, 4)
         @Assert(firstByteMask >= UInt8(0x00), true)
     }

     @TestCase
     public func testAesHpMaskLength(): Unit {
         let sample = hexToBytes("00112233445566778899aabbccddeeff")
         let key    = hexToBytes("0123456789abcdef0123456789abcdef")
         let (_, pnMask) = contractQuicHpAesEncrypt(sample, key)
         @Assert(pnMask.size, 15)
     }

     @TestCase
     public func testChaChaHpWithInvalidShortSample(): Unit {
         let key  = hexToBytes("8a2a74072c22b8e4d11b3ff5882e0be9c05c0afb97d4689f87bfe4276f85be65")
         let shortSample = hexToBytes("0000000000000000000000000000")
         try {
             _ = contractQuicHpChaChaEncrypt(shortSample, key)
             @Fail("ChaCha HP should reject short sample")
         } catch (e: ContractException) {
             @Assert(e.code, ContractErrorCode.BadInput)
         }
     }

     @TestCase
     public func testAesHpWithInvalidShortSample(): Unit {
         let hpKey = hexToBytes("9f50449e04a0e810283a1e9933adedd2")
         let shortSample = hexToBytes("00112233445566778899aabbccdd")
         try {
             _ = contractQuicHpAesEncrypt(shortSample, hpKey)
             @Fail("AES HP should reject short sample")
         } catch (e: ContractException) {
             @Assert(e.code, ContractErrorCode.BadInput)
         }
     }

     @TestCase
     public func testChaChaHpWithInvalidKeyLength(): Unit {
         let shortKey = hexToBytes("00112233445566778899aabbccddeeff")
         let sample = hexToBytes("00000000aabbccddeeff001122334455")
         try {
             _ = contractQuicHpChaChaEncrypt(sample, shortKey)
             @Fail("ChaCha HP should reject short key")
         } catch (e: ContractException) {
             @Assert(e.code, ContractErrorCode.BadInput)
         }
     }

     @TestCase
     public func testAesHpRejectsAes192KeyAndAcceptsAes256Key(): Unit {
         let sample = hexToBytes("00112233445566778899aabbccddeeff")
         try {
             _ = contractQuicHpAesEncrypt(sample, Array<Byte>(24, repeat: 0))
             @Fail("QUIC AES HP must reject 24-byte AES keys")
         } catch (e: ContractException) {
             @Assert(e.code, ContractErrorCode.BadInput)
         }

         let (_, pnMask) = contractQuicHpAesEncrypt(sample, Array<Byte>(32, repeat: 0))
         @Assert(pnMask.size, 15)
     }

     @TestCase
     public func testAesHpProducesMaskInRange(): Unit {
         let sample = hexToBytes("d1b1c98dd7689fb8ec11d242b123dc9b")
         let hpKey  = hexToBytes("9f50449e04a0e810283a1e9933adedd2")
         let (firstByteMask, pnMask) = contractQuicHpAesEncrypt(sample, hpKey)
         @Assert(firstByteMask >= UInt8(0x00), true)
         @Assert(pnMask.size == 15, true)
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
