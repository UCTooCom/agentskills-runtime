 package jinguissl_core.tests

 import jinguissl_core.crypto.digest.{HashAlgorithm, hkdfExtract, hkdfExpand, bytesToHexLower}
 import jinguissl_core.crypto.quic.{QUIC_SALT_V1, QUIC_SALT_V2, quicInitialSecrets, quicInitialKeyIv, quicInitialHpKey, quicInitialKeyDerive}

 @Test
 public class QuicInitialSaltTestSuite {

     @TestCase
     public func testSaltConstants(): Unit {
         // QUIC v1 salt from RFC 9001 §5.2
         let expectedV1 = hexToBytes("38762cf7f55934b34d179ae6a4c80cadccbb7f0a")
         @Assert(QUIC_SALT_V1, expectedV1)

         // QUIC v2 salt from RFC 9369 §5.2
         let expectedV2 = hexToBytes("0dede3def700a6db819381be6e269dcbf9bd2ed9")
         @Assert(QUIC_SALT_V2, expectedV2)
     }

     @TestCase
     public func testClientSecretsWithQuicGoVectors(): Unit {
         // Test vector from quic-go internal/handshake/initial_aead_test.go
         // conn_id = 0x8394c8f03e515708
         let connId = hexToBytes("8394c8f03e515708")

         // ── QUIC v1 ──
         let (clientSecretV1, serverSecretV1) = quicInitialSecrets(connId, false)
         let expectedClientSecretV1 = hexToBytes(
             "c00cf151ca5be075ed0ebfb5c80323c42d6b7db67881289af4008f1f6c357aea"
         )
         let expectedServerSecretV1 = hexToBytes(
             "3c199828fd139efd216c155ad844cc81fb82fa8d7446fa7d78be803acdda951b"
         )
         @Assert(clientSecretV1, expectedClientSecretV1)
         @Assert(serverSecretV1, expectedServerSecretV1)

         let (keyV1, ivV1) = quicInitialKeyIv(clientSecretV1, false)
         let expectedKeyV1 = hexToBytes("1f369613dd76d5467730efcbe3b1a22d")
         let expectedIvV1 = hexToBytes("fa044b2f42a3fd3b46fb255c")
         @Assert(keyV1, expectedKeyV1)
         @Assert(ivV1, expectedIvV1)

         let serverHpKey = quicInitialHpKey(serverSecretV1, false)
        let expectedServerHp = hexToBytes("c206b8d9b9f0f37644430b490eeaa314")
         @Assert(serverHpKey, expectedServerHp)

         // ── QUIC v2 ──
         let (clientSecretV2, serverSecretV2) = quicInitialSecrets(connId, true)
         let expectedClientSecretV2 = hexToBytes(
             "14ec9d6eb9fd7af83bf5a668bc17a7e283766aade7ecd0891f70f9ff7f4bf47b"
         )
         let expectedServerSecretV2 = hexToBytes(
             "0263db1782731bf4588e7e4d93b7463907cb8cd8200b5da55a8bd488eafc37c1"
         )
         @Assert(clientSecretV2, expectedClientSecretV2)
         @Assert(serverSecretV2, expectedServerSecretV2)

         let (keyV2, ivV2) = quicInitialKeyIv(clientSecretV2, true)
         let expectedKeyV2 = hexToBytes("8b1a0bc121284290a29e0971b5cd045d")
         let expectedIvV2 = hexToBytes("91f73e2351d8fa91660e909f")
         @Assert(keyV2, expectedKeyV2)
         @Assert(ivV2, expectedIvV2)
     }

     @TestCase
     public func testQuicInitialKeyDeriveOneShot(): Unit {
         // One-shot API returns (key, iv, hpKey) for the client perspective
         let connId = hexToBytes("8394c8f03e515708")

         // QUIC v1
         let (keyV1, ivV1, hpKeyV1) = quicInitialKeyDerive(connId, false)
         @Assert(keyV1, hexToBytes("1f369613dd76d5467730efcbe3b1a22d"))
         @Assert(ivV1, hexToBytes("fa044b2f42a3fd3b46fb255c"))
        assertHex(hpKeyV1, "9f50449e04a0e810283a1e9933adedd2")

         // QUIC v2
         let (keyV2, ivV2, hpKeyV2) = quicInitialKeyDerive(connId, true)
         @Assert(keyV2, hexToBytes("8b1a0bc121284290a29e0971b5cd045d"))
         @Assert(ivV2, hexToBytes("91f73e2351d8fa91660e909f"))
        assertHex(hpKeyV2, "45b95e15235d6f45a6b19cbcb0294ba9")
     }

     @TestCase
     public func testDifferentConnIdsProduceDifferentKeys(): Unit {
         let connId1 = hexToBytes("8394c8f03e515708")
         let connId2 = hexToBytes("1234567890abcdef")

         let (key1, _, _) = quicInitialKeyDerive(connId1, false)
         let (key2, _, _) = quicInitialKeyDerive(connId2, false)
         @Assert(key1 != key2, true)
     }

     @TestCase
     public func testEmptyConnId(): Unit {
         let connId: Array<Byte> = []
         let (key, _, _) = quicInitialKeyDerive(connId, false)
         @Assert(key.size, 16)
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
