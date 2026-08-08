 package jinguissl_core.tests

 import jinguissl_core.crypto.aes.{AesGcmContext, aesGcmEncryptWithContext, aesGcmDecryptWithContext, aesNewGcmContext}
 import jinguissl_core.crypto.chacha20.{Chacha20Poly1305Context, chacha20Poly1305EncryptWithContext, chacha20Poly1305DecryptWithContext, chacha20Poly1305NewContext}
 import jinguissl_core.crypto.quic.{quicAeadEncrypt, quicAeadDecrypt, quicAeadAesGcmEncrypt, quicAeadAesGcmDecrypt, quicAeadChaCha20Encrypt, quicAeadChaCha20Decrypt, QuicAeadAlgorithm}
 import jinguissl_core.crypto.digest.bytesToHexLower
 import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

 // ── Test keys ─────────────────────────────────────────────────────

 private let TEST_KEY_128: Array<Byte> = [
     UInt8(0x1f), UInt8(0x36), UInt8(0x96), UInt8(0x13),
     UInt8(0xdd), UInt8(0x76), UInt8(0xd5), UInt8(0x46),
     UInt8(0x77), UInt8(0x30), UInt8(0xef), UInt8(0xcb),
     UInt8(0xe3), UInt8(0xb1), UInt8(0xa2), UInt8(0x2d)
 ]

 private let TEST_KEY_256: Array<Byte> = [
     UInt8(0x00), UInt8(0x01), UInt8(0x02), UInt8(0x03),
     UInt8(0x04), UInt8(0x05), UInt8(0x06), UInt8(0x07),
     UInt8(0x08), UInt8(0x09), UInt8(0x0a), UInt8(0x0b),
     UInt8(0x0c), UInt8(0x0d), UInt8(0x0e), UInt8(0x0f),
     UInt8(0x10), UInt8(0x11), UInt8(0x12), UInt8(0x13),
     UInt8(0x14), UInt8(0x15), UInt8(0x16), UInt8(0x17),
     UInt8(0x18), UInt8(0x19), UInt8(0x1a), UInt8(0x1b),
     UInt8(0x1c), UInt8(0x1d), UInt8(0x1e), UInt8(0x1f)
 ]

 private let TEST_KEY_CHACHA: Array<Byte> = [
     UInt8(0x80), UInt8(0x81), UInt8(0x82), UInt8(0x83),
     UInt8(0x84), UInt8(0x85), UInt8(0x86), UInt8(0x87),
     UInt8(0x88), UInt8(0x89), UInt8(0x8a), UInt8(0x8b),
     UInt8(0x8c), UInt8(0x8d), UInt8(0x8e), UInt8(0x8f),
     UInt8(0x90), UInt8(0x91), UInt8(0x92), UInt8(0x93),
     UInt8(0x94), UInt8(0x95), UInt8(0x96), UInt8(0x97),
     UInt8(0x98), UInt8(0x99), UInt8(0x9a), UInt8(0x9b),
     UInt8(0x9c), UInt8(0x9d), UInt8(0x9e), UInt8(0x9f)
 ]

 private let TEST_IV: Array<Byte> = [
     UInt8(0xfa), UInt8(0x04), UInt8(0x4b), UInt8(0x2f),
     UInt8(0x42), UInt8(0xa3), UInt8(0xfd), UInt8(0x3b),
     UInt8(0x46), UInt8(0xfb), UInt8(0x25), UInt8(0x5c)
 ]

 @Test
 public class QuicAeadTestSuite {

     // ── AES-128-GCM ──────────────────────────────────────────────

     @TestCase
     public func testAead128GcmRoundTrip(): Unit {
         let ctx = aesNewGcmContext(TEST_KEY_128)
         let pt = "hello quic".toArray()
         let aad = "aad".toArray()

         let sealed = quicAeadAesGcmEncrypt(ctx, TEST_IV, 42, pt, aad)
         @Assert(sealed.size, pt.size + 16)

         let recovered = quicAeadAesGcmDecrypt(ctx, TEST_IV, 42, sealed, aad)
         @Assert(recovered, pt)
     }

     @TestCase
     public func testAead128GcmWrongPnFails(): Unit {
         let ctx = aesNewGcmContext(TEST_KEY_128)
         let pt = "hello quic".toArray()
         let aad = "aad".toArray()
         let sealed = quicAeadAesGcmEncrypt(ctx, TEST_IV, 42, pt, aad)

         try {
             _ = quicAeadAesGcmDecrypt(ctx, TEST_IV, 99, sealed, aad)
             @Fail("AEAD should fail with wrong packet number")
         } catch (_: CryptoException) {
             @Assert(true)
         }
     }

     @TestCase
     public func testAead128GcmConveniencePath(): Unit {
         let pt = "hello quic".toArray()
         let aad = "aad".toArray()

         let sealed = quicAeadEncrypt(TEST_KEY_128, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.Aes128Gcm)
         @Assert(sealed.size, pt.size + 16)

         let recovered = quicAeadDecrypt(TEST_KEY_128, TEST_IV, 7, sealed, aad, QuicAeadAlgorithm.Aes128Gcm)
         @Assert(recovered, pt)
     }

     @TestCase
     public func testAead128GcmWrongKeyFails(): Unit {
         let pt = "hello quic".toArray()
         let aad = "aad".toArray()
         let sealed = quicAeadEncrypt(TEST_KEY_128, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.Aes128Gcm)

         let badKey = Array<Byte>(16, repeat: 0xab)
         try {
             _ = quicAeadDecrypt(badKey, TEST_IV, 7, sealed, aad, QuicAeadAlgorithm.Aes128Gcm)
             @Fail("AEAD should fail with wrong key")
         } catch (_: CryptoException) {
             @Assert(true)
         }
     }

     @TestCase
     public func testAead128GcmEmptyPlaintext(): Unit {
         let ctx = aesNewGcmContext(TEST_KEY_128)
         let aad = "aad".toArray()

         let sealed = quicAeadAesGcmEncrypt(ctx, TEST_IV, 0, [], aad)
         @Assert(sealed.size, 16)

         let recovered = quicAeadAesGcmDecrypt(ctx, TEST_IV, 0, sealed, aad)
         @Assert(recovered, [])
     }

     @TestCase
     public func testAead128GcmShortCiphertextRejected(): Unit {
         let ctx = aesNewGcmContext(TEST_KEY_128)
         try {
             _ = quicAeadAesGcmDecrypt(ctx, TEST_IV, 0, hexToBytes("00"), hexToBytes(""))
             @Fail("short ciphertext should be rejected")
         } catch (_: CryptoException) {
             @Assert(true)
         }
     }

     @TestCase
     public func testAead128GcmDifferentPnChangesCiphertext(): Unit {
         let ctx = aesNewGcmContext(TEST_KEY_128)
         let pt = "hello quic".toArray()
         let aad = "aad".toArray()

         let s1 = quicAeadAesGcmEncrypt(ctx, TEST_IV, 1, pt, aad)
         let s2 = quicAeadAesGcmEncrypt(ctx, TEST_IV, 2, pt, aad)
         @Assert(s1 != s2, true)
     }

     @TestCase
     public func testRfc9001ServerInitialAes128Vector(): Unit {
         let key = hexToBytes("cf3a5331653c364c88f0f379b6067e37")
         let iv = hexToBytes("0ac1493ca1905853b0bba03e")
         let aad = hexToBytes("c1000000010008f067a5502a4262b50040750001")
         let plaintext = hexToBytes(
             "02000000000600405a020000560303ee" +
             "fce7f7b37ba1d1632e96677825ddf739" +
             "88cfc79825df566dc5430b9a045a1200" +
             "130100002e00330024001d00209d3c94" +
             "0d89690b84d08a60993c144eca684d10" +
             "81287c834d5311bcf32bb9da1a002b00" +
             "020304"
         )
         let expected =
             "5a482cd0991cd25b0aac406a5816b639" +
             "4100f37a1c69797554780bb38cc5a99f" +
             "5ede4cf73c3ec2493a1839b3dbcba3f6" +
             "ea46c5b7684df3548e7ddeb9c3bf9c73" +
             "cc3f3bded74b562bfb19fb84022f8ef4" +
             "cdd93795d77d06edbb7aaf2f58891850" +
             "abbdca3d20398c276456cbc42158407d" +
             "d074ee"

         let sealed = quicAeadEncrypt(key, iv, 1, plaintext, aad, QuicAeadAlgorithm.Aes128Gcm)
         assertHex(sealed, expected)
         @Assert(quicAeadDecrypt(key, iv, 1, sealed, aad, QuicAeadAlgorithm.Aes128Gcm), plaintext)
     }

     // ── AES-256-GCM ──────────────────────────────────────────────

     @TestCase
     public func testAead256GcmRoundTrip(): Unit {
         let ctx = aesNewGcmContext(TEST_KEY_256)
         let pt = "hello quic aes256".toArray()
         let aad = "aad256".toArray()

         let sealed = quicAeadAesGcmEncrypt(ctx, TEST_IV, 13, pt, aad)
         @Assert(sealed.size, pt.size + 16)

         let recovered = quicAeadAesGcmDecrypt(ctx, TEST_IV, 13, sealed, aad)
         @Assert(recovered, pt)
     }

     @TestCase
     public func testAead256GcmConveniencePath(): Unit {
         let pt = "hello quic aes256".toArray()
         let aad = "aad256".toArray()

         let sealed = quicAeadEncrypt(TEST_KEY_256, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.Aes256Gcm)
         @Assert(sealed.size, pt.size + 16)

         let recovered = quicAeadDecrypt(TEST_KEY_256, TEST_IV, 7, sealed, aad, QuicAeadAlgorithm.Aes256Gcm)
         @Assert(recovered, pt)
     }

     @TestCase
     public func testAead256GcmWrongKeyFails(): Unit {
         let pt = "hello quic aes256".toArray()
         let aad = "aad256".toArray()
         let sealed = quicAeadEncrypt(TEST_KEY_256, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.Aes256Gcm)

         let badKey = Array<Byte>(32, repeat: 0xcc)
         try {
             _ = quicAeadDecrypt(badKey, TEST_IV, 7, sealed, aad, QuicAeadAlgorithm.Aes256Gcm)
             @Fail("AES-256 AEAD should fail with wrong key")
         } catch (_: CryptoException) {
             @Assert(true)
         }
     }

     @TestCase
     public func testAead256GcmEmptyPlaintext(): Unit {
         let ctx = aesNewGcmContext(TEST_KEY_256)
         let aad = "aad256".toArray()

         let sealed = quicAeadAesGcmEncrypt(ctx, TEST_IV, 0, [], aad)
         @Assert(sealed.size, 16)

         let recovered = quicAeadAesGcmDecrypt(ctx, TEST_IV, 0, sealed, aad)
         @Assert(recovered, [])
     }

     // ── ChaCha20-Poly1305 ────────────────────────────────────────

     @TestCase
     public func testAeadChaCha20Poly1305ContextRoundTrip(): Unit {
         let ctx = chacha20Poly1305NewContext(TEST_KEY_CHACHA)
         let pt = "hello quic chacha".toArray()
         let aad = "aad_chacha".toArray()

         let sealed = quicAeadChaCha20Encrypt(ctx, TEST_IV, 42, pt, aad)
         @Assert(sealed.size, pt.size + 16)

         let recovered = quicAeadChaCha20Decrypt(ctx, TEST_IV, 42, sealed, aad)
         @Assert(recovered, pt)
     }

     @TestCase
     public func testAeadChaCha20Poly1305ConveniencePath(): Unit {
         let pt = "hello quic chacha".toArray()
         let aad = "aad_chacha".toArray()

         let sealed = quicAeadEncrypt(TEST_KEY_CHACHA, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.ChaCha20Poly1305)
         @Assert(sealed.size, pt.size + 16)

         let recovered = quicAeadDecrypt(TEST_KEY_CHACHA, TEST_IV, 7, sealed, aad, QuicAeadAlgorithm.ChaCha20Poly1305)
         @Assert(recovered, pt)
     }

     @TestCase
     public func testAeadChaCha20Poly1305WrongPnFails(): Unit {
         let ctx = chacha20Poly1305NewContext(TEST_KEY_CHACHA)
         let pt = "hello quic chacha".toArray()
         let aad = "aad_chacha".toArray()
         let sealed = quicAeadChaCha20Encrypt(ctx, TEST_IV, 42, pt, aad)

         try {
             _ = quicAeadChaCha20Decrypt(ctx, TEST_IV, 99, sealed, aad)
             @Fail("ChaCha20 AEAD should fail with wrong packet number")
         } catch (_: CryptoException) {
             @Assert(true)
         }
     }

     @TestCase
     public func testAeadChaCha20Poly1305EmptyPlaintext(): Unit {
         let ctx = chacha20Poly1305NewContext(TEST_KEY_CHACHA)
         let aad = "aad_chacha".toArray()

         let sealed = quicAeadChaCha20Encrypt(ctx, TEST_IV, 0, [], aad)
         @Assert(sealed.size, 16)

         let recovered = quicAeadChaCha20Decrypt(ctx, TEST_IV, 0, sealed, aad)
         @Assert(recovered, [])
     }

     @TestCase
     public func testAeadChaCha20Poly1305ShortCiphertextRejected(): Unit {
         let ctx = chacha20Poly1305NewContext(TEST_KEY_CHACHA)
         try {
             _ = quicAeadChaCha20Decrypt(ctx, TEST_IV, 0, hexToBytes("00"), hexToBytes(""))
             @Fail("short ciphertext should be rejected")
         } catch (_: CryptoException) {
             @Assert(true)
         }
     }

     @TestCase
     public func testRfc9001ChaCha20Poly1305ShortHeaderVector(): Unit {
         let key = hexToBytes(
             "c6d98ff3441c3fe1b2182094f69caa2e" +
             "d4b716b65488960a7a984979fb23e1c8"
         )
         let iv = hexToBytes("e0459b3474bdd0e44a41c144")
         let aad = hexToBytes("4200bff4")
         let plaintext = hexToBytes("01")
         let expected = "655e5cd55c41f69080575d7999c25a5bfb"

         let sealed = quicAeadEncrypt(
             key, iv, 654360564, plaintext, aad,
             QuicAeadAlgorithm.ChaCha20Poly1305
         )
         assertHex(sealed, expected)
         @Assert(
             quicAeadDecrypt(
                 key, iv, 654360564, sealed, aad,
                 QuicAeadAlgorithm.ChaCha20Poly1305
             ),
             plaintext
         )
     }

     // ── Cross-algorithm ──────────────────────────────────────────

     @TestCase
     public func testAeadDifferentAlgorithmsProduceDifferently(): Unit {
         let pt = "hello quic".toArray()
         let aad = "aad".toArray()

         let s128 = quicAeadEncrypt(TEST_KEY_128, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.Aes128Gcm)
         let s256 = quicAeadEncrypt(TEST_KEY_256, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.Aes256Gcm)
         let sChacha = quicAeadEncrypt(TEST_KEY_CHACHA, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.ChaCha20Poly1305)

         @Assert(s128 != s256, true)
         @Assert(s128 != sChacha, true)
         @Assert(s256 != sChacha, true)
     }

     @TestCase
     public func testAeadAlgorithmCrossDecryptFails(): Unit {
         let pt = "hello quic".toArray()
         let aad = "aad".toArray()

         let sealed = quicAeadEncrypt(TEST_KEY_128, TEST_IV, 7, pt, aad, QuicAeadAlgorithm.Aes128Gcm)
         try {
             _ = quicAeadDecrypt(TEST_KEY_CHACHA, TEST_IV, 7, sealed, aad, QuicAeadAlgorithm.ChaCha20Poly1305)
             @Fail("cross-algorithm decryption should fail")
         } catch (_: CryptoException) {
             @Assert(true)
         }
     }

     @TestCase
     public func testAeadAlgorithmRejectsMismatchedKeyLengthsOnEncrypt(): Unit {
         let key192 = Array<Byte>(24, repeat: 0x5a)

         assertQuicAeadEncryptRejectsKeyLength(
             TEST_KEY_256, QuicAeadAlgorithm.Aes128Gcm,
             "QUIC AES-128-GCM key must be 16 bytes"
         )
         assertQuicAeadEncryptRejectsKeyLength(
             key192, QuicAeadAlgorithm.Aes128Gcm,
             "QUIC AES-128-GCM key must be 16 bytes"
         )
         assertQuicAeadEncryptRejectsKeyLength(
             TEST_KEY_128, QuicAeadAlgorithm.Aes256Gcm,
             "QUIC AES-256-GCM key must be 32 bytes"
         )
         assertQuicAeadEncryptRejectsKeyLength(
             key192, QuicAeadAlgorithm.Aes256Gcm,
             "QUIC AES-256-GCM key must be 32 bytes"
         )
         assertQuicAeadEncryptRejectsKeyLength(
             TEST_KEY_128, QuicAeadAlgorithm.ChaCha20Poly1305,
             "QUIC ChaCha20-Poly1305 key must be 32 bytes"
         )
         assertQuicAeadEncryptRejectsKeyLength(
             key192, QuicAeadAlgorithm.ChaCha20Poly1305,
             "QUIC ChaCha20-Poly1305 key must be 32 bytes"
         )
     }

     @TestCase
     public func testAeadAlgorithmRejectsMismatchedKeyLengthsOnDecrypt(): Unit {
         let key192 = Array<Byte>(24, repeat: 0x5a)

         assertQuicAeadDecryptRejectsKeyLength(
             TEST_KEY_256, QuicAeadAlgorithm.Aes128Gcm,
             "QUIC AES-128-GCM key must be 16 bytes"
         )
         assertQuicAeadDecryptRejectsKeyLength(
             key192, QuicAeadAlgorithm.Aes128Gcm,
             "QUIC AES-128-GCM key must be 16 bytes"
         )
         assertQuicAeadDecryptRejectsKeyLength(
             TEST_KEY_128, QuicAeadAlgorithm.Aes256Gcm,
             "QUIC AES-256-GCM key must be 32 bytes"
         )
         assertQuicAeadDecryptRejectsKeyLength(
             key192, QuicAeadAlgorithm.Aes256Gcm,
             "QUIC AES-256-GCM key must be 32 bytes"
         )
         assertQuicAeadDecryptRejectsKeyLength(
             TEST_KEY_128, QuicAeadAlgorithm.ChaCha20Poly1305,
             "QUIC ChaCha20-Poly1305 key must be 32 bytes"
         )
         assertQuicAeadDecryptRejectsKeyLength(
             key192, QuicAeadAlgorithm.ChaCha20Poly1305,
             "QUIC ChaCha20-Poly1305 key must be 32 bytes"
         )
     }

     @TestCase
     public func testAeadEnumToString(): Unit {
         @Assert(QuicAeadAlgorithm.Aes128Gcm.toString(), "AES-128-GCM")
         @Assert(QuicAeadAlgorithm.Aes256Gcm.toString(), "AES-256-GCM")
         @Assert(QuicAeadAlgorithm.ChaCha20Poly1305.toString(), "ChaCha20-Poly1305")
     }
 }

 private func assertQuicAeadEncryptRejectsKeyLength(
     key: Array<Byte>, alg: QuicAeadAlgorithm, expectedMessage: String
 ): Unit {
     try {
         _ = quicAeadEncrypt(key, TEST_IV, 0, [], [], alg)
         @Fail("QUIC AEAD encrypt must reject mismatched key length")
     } catch (e: CryptoException) {
         @Assert(e.code, CryptoErrorCode.InvalidArgument)
         @Assert(e.message, expectedMessage)
     }
 }

 private func assertQuicAeadDecryptRejectsKeyLength(
     key: Array<Byte>, alg: QuicAeadAlgorithm, expectedMessage: String
 ): Unit {
     try {
         _ = quicAeadDecrypt(key, TEST_IV, 0, [], [], alg)
         @Fail("QUIC AEAD decrypt must reject mismatched key length")
     } catch (e: CryptoException) {
         @Assert(e.code, CryptoErrorCode.InvalidArgument)
         @Assert(e.message, expectedMessage)
     }
 }

 /// ── hex helpers (same pattern as core_aes_test.cj) ──────────────

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
