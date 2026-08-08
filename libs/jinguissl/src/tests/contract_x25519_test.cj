package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractX25519TestSuite {
    @TestCase
    public func testContractX25519Rfc7748KeyAgreement(): Unit {
        let alicePrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let bobPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")

        let alicePublic = contractX25519PublicFromPrivate(alicePrivate)
        let bobPublic = contractX25519PublicFromPrivate(bobPrivate)
        @Assert(contractBytesToHexLower(alicePublic), "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
        @Assert(contractBytesToHexLower(bobPublic), "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")

        let request = ContractX25519KeyAgreementRequest(alicePrivate, bobPublic)
        let result = contractX25519DeriveKeyAgreement(request)
        @Assert(result.algorithm, CONTRACT_X25519_ALGORITHM)
        @Assert(result.publicKey, alicePublic)
        @Assert(contractBytesToHexLower(result.sharedSecret), "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742")

        let reverseResult = contractX25519DeriveKeyAgreement(bobPrivate, alicePublic)
        @Assert(reverseResult.sharedSecret, result.sharedSecret)
    }

    @TestCase
    public func testContractTryX25519DeriveKeyAgreementSuccessOutcome(): Unit {
        let alicePrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        let bobPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
        let bobPublic = contractX25519PublicFromPrivate(bobPrivate)

        let outcome = contractTryX25519DeriveKeyAgreement(alicePrivate, bobPublic)
        @Assert(outcome.ok, true)
        @Assert(outcome.message, "OK")
        match (outcome.code) {
            case Some(_) =>
                @Fail("successful X25519 outcome should not carry contract code")
            case None => ()
        }
        match (outcome.igniteCode) {
            case Some(_) =>
                @Fail("successful X25519 outcome should not carry ignite code")
            case None => ()
        }
        match (outcome.result) {
            case Some(value) =>
                @Assert(
                    contractBytesToHexLower(value.sharedSecret),
                    "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742"
                )
            case None =>
                @Fail("successful X25519 outcome should carry result")
        }
    }

    @TestCase
    public func testContractTryX25519DeriveKeyAgreementRejectsBadInput(): Unit {
        let invalidPrivate = [UInt8(0x01), UInt8(0x02)]
        let peerPublic = Array<Byte>(CONTRACT_X25519_KEY_LEN, repeat: 0)

        let outcome = contractTryX25519DeriveKeyAgreement(invalidPrivate, peerPublic)
        @Assert(outcome.ok, false)
        match (outcome.code) {
            case Some(value) =>
                @Assert(value.toString(), "BAD_INPUT")
            case None =>
                @Fail("bad X25519 input should carry contract code")
        }
        match (outcome.igniteCode) {
            case Some(value) =>
                @Assert(value.toString(), "BAD_ENVELOPE")
            case None =>
                @Fail("bad X25519 input should carry ignite code")
        }
        match (outcome.result) {
            case Some(_) =>
                @Fail("bad X25519 input should not carry result")
            case None => ()
        }
    }

    @TestCase
    public func testContractTryX25519DeriveKeyAgreementRejectsAllZeroSharedSecret(): Unit {
        let privateKey = contractX25519ClampPrivateKey(
            hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
        )
        let lowOrderPoint = Array<Byte>(CONTRACT_X25519_KEY_LEN, repeat: 0)

        let outcome = contractTryX25519DeriveKeyAgreement(privateKey, lowOrderPoint)
        @Assert(outcome.ok, false)
        match (outcome.code) {
            case Some(value) =>
                @Assert(value.toString(), "BAD_INPUT")
            case None =>
                @Fail("all-zero X25519 shared secret should carry contract code")
        }
        match (outcome.igniteCode) {
            case Some(value) =>
                @Assert(value.toString(), "BAD_ENVELOPE")
            case None =>
                @Fail("all-zero X25519 shared secret should carry ignite code")
        }
    }

    @TestCase
    public func testContractX25519GenerateKeyPairShape(): Unit {
        let keyPair = contractX25519GenerateKeyPair()
        @Assert(keyPair.privateKey.size, CONTRACT_X25519_KEY_LEN)
        @Assert(keyPair.publicKey.size, CONTRACT_X25519_KEY_LEN)
        @Assert(UInt8(keyPair.privateKey[0]) & UInt8(0x07), UInt8(0))
        @Assert(UInt8(keyPair.privateKey[31]) & UInt8(0x80), UInt8(0))
        @Assert(UInt8(keyPair.privateKey[31]) & UInt8(0x40), UInt8(0x40))
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
    if (ch >= b'0' && ch <= b'9') {
        return UInt8(ch - b'0')
    }
    if (ch >= b'a' && ch <= b'f') {
        return UInt8(ch - b'a' + UInt8(10))
    }
    if (ch >= b'A' && ch <= b'F') {
        return UInt8(ch - b'A' + UInt8(10))
    }
    throw Exception("invalid hex char")
}

@Test
public class ContractSupplementaryX25519TestSuite {
    @TestCase
    public func testContractX25519KeyPairRejectsBadLength(): Unit {
        try {
            _ = ContractX25519KeyPair([0x01, 0x02], Array<Byte>(32, repeat: 0x00))
            @Fail("short private key should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractX25519Constants(): Unit {
        @Assert(CONTRACT_X25519_KEY_LEN, 32)
        @Assert(CONTRACT_X25519_SHARED_SECRET_LEN, 32)
        @Assert(CONTRACT_X25519_ALGORITHM, "X25519")
    }

    @TestCase
    public func testContractX25519KeyAgreementEdgeCases(): Unit {
        // Multiple key agreements with different peers
        let aliceKey = contractX25519GenerateKeyPair()
        let bobKey = contractX25519GenerateKeyPair()

        let aliceToBob = contractTryX25519DeriveKeyAgreement(
            aliceKey.privateKey, bobKey.publicKey
        )
        @Assert(aliceToBob.ok, true)
        match (aliceToBob.result) {
            case Some(secret) => @Assert(secret.sharedSecret.size == 32, true)
            case None => @Fail("alice-to-bob key agreement should succeed")
        }

        let bobToAlice = contractTryX25519DeriveKeyAgreement(
            bobKey.privateKey, aliceKey.publicKey
        )
        @Assert(bobToAlice.ok, true)
        match (bobToAlice.result) {
            case Some(secret) => @Assert(secret.sharedSecret.size == 32, true)
            case None => @Fail("bob-to-alice key agreement should succeed")
        }

        // Both sides produce 32-byte shared secrets (verified above)
    }
}
