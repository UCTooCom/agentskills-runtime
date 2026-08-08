 package jinguissl.tests

 import jinguissl.contract.*

 @Test
 public class ContractQuicInitialTestSuite {

     @TestCase
     public func testSaltConstants(): Unit {
        let expectedV1 = hexToBytes("38762cf7f55934b34d179ae6a4c80cadccbb7f0a")
        @Assert(contractQuicSaltV1(), expectedV1)
        let expectedV2 = hexToBytes("0dede3def700a6db819381be6e269dcbf9bd2ed9")
        @Assert(contractQuicSaltV2(), expectedV2)
     }

     @TestCase
     public func testInitialSecretsV1(): Unit {
         let connId = hexToBytes("8394c8f03e515708")
         let (clientSecret, serverSecret) = contractQuicInitialSecrets(connId, false)
         let expectedClient = hexToBytes(
             "c00cf151ca5be075ed0ebfb5c80323c42d6b7db67881289af4008f1f6c357aea"
         )
         let expectedServer = hexToBytes(
             "3c199828fd139efd216c155ad844cc81fb82fa8d7446fa7d78be803acdda951b"
         )
         @Assert(clientSecret, expectedClient)
         @Assert(serverSecret, expectedServer)
     }

     @TestCase
     public func testInitialSecretsV2(): Unit {
         let connId = hexToBytes("8394c8f03e515708")
         let (clientSecret, serverSecret) = contractQuicInitialSecrets(connId, true)
         let expectedClient = hexToBytes(
             "14ec9d6eb9fd7af83bf5a668bc17a7e283766aade7ecd0891f70f9ff7f4bf47b"
         )
         let expectedServer = hexToBytes(
             "0263db1782731bf4588e7e4d93b7463907cb8cd8200b5da55a8bd488eafc37c1"
         )
         @Assert(clientSecret, expectedClient)
         @Assert(serverSecret, expectedServer)
     }

     @TestCase
     public func testKeyIvDeriveV1(): Unit {
         let secret = hexToBytes(
             "c00cf151ca5be075ed0ebfb5c80323c42d6b7db67881289af4008f1f6c357aea"
         )
         let (key, iv) = contractQuicInitialKeyIv(secret, false)
         @Assert(key, hexToBytes("1f369613dd76d5467730efcbe3b1a22d"))
         @Assert(iv, hexToBytes("fa044b2f42a3fd3b46fb255c"))
     }

     @TestCase
     public func testHpKeyDeriveV1(): Unit {
         let secret = hexToBytes(
             "3c199828fd139efd216c155ad844cc81fb82fa8d7446fa7d78be803acdda951b"
         )
         let hpKey = contractQuicInitialHpKey(secret, false)
         assertHex(hpKey, "c206b8d9b9f0f37644430b490eeaa314")
     }

     @TestCase
     public func testOneShotKeyDeriveV1(): Unit {
         let connId = hexToBytes("8394c8f03e515708")
         let (key, iv, hpKey) = contractQuicInitialKeyDerive(connId, false)
         @Assert(key, hexToBytes("1f369613dd76d5467730efcbe3b1a22d"))
         @Assert(iv, hexToBytes("fa044b2f42a3fd3b46fb255c"))
         assertHex(hpKey, "9f50449e04a0e810283a1e9933adedd2")
     }

     @TestCase
     public func testOneShotKeyDeriveV2(): Unit {
         let connId = hexToBytes("8394c8f03e515708")
         let (key, iv, hpKey) = contractQuicInitialKeyDerive(connId, true)
         @Assert(key, hexToBytes("8b1a0bc121284290a29e0971b5cd045d"))
         @Assert(iv, hexToBytes("91f73e2351d8fa91660e909f"))
         assertHex(hpKey, "45b95e15235d6f45a6b19cbcb0294ba9")
     }

     @TestCase
     public func testDifferentConnIdsProduceDifferentKeys(): Unit {
         let connId1 = hexToBytes("8394c8f03e515708")
         let connId2 = hexToBytes("1234567890abcdef")
         let (key1, _, _) = contractQuicInitialKeyDerive(connId1, false)
         let (key2, _, _) = contractQuicInitialKeyDerive(connId2, false)
         @Assert(key1 != key2, true)
     }

     @TestCase
     public func testEmptyConnId(): Unit {
         let (key, _, _) = contractQuicInitialKeyDerive([], false)
         @Assert(key.size, 16)
     }

     @TestCase
     public func testInitialSecretLengthIsContractOwned(): Unit {
         try {
             _ = contractQuicInitialKeyIv(Array<Byte>(31, repeat: 0), false)
             @Fail("QUIC initial traffic secret must be 32 bytes")
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
