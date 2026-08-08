package jinguissl_core.tests

import std.fs.*
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.digest.{bytesToHexLower, hmac, HashAlgorithm}
import jinguissl_core.crypto.ecc.*
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.kem.*
import jinguissl_core.crypto.rsa.*

private let P256_GX: BigNum = BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296")
private let P256_GY: BigNum = BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")
private let TEST_HKDF_SHA256_LEN: Int64 = 32

@Test
public class KemTestSuite {
    @TestCase
    public func testRsaKemRoundTrip(): Unit {
        let privateKey = loadRsa2048PrivateKey()
        let info = "stage3-rsa-kem".toArray()
        let (ciphertext, secretEnc) = rsaKemEncapsulate(
            privateKey.publicKey,
            sharedSecretLen: 48,
            info: info
        )
        let secretDec = rsaKemDecapsulate(
            privateKey,
            ciphertext,
            sharedSecretLen: 48,
            info: info
        )

        @Assert(ciphertext.size, 256)
        @Assert(secretEnc.size, 48)
        @Assert(secretEnc, secretDec)
    }

    @TestCase
    public func testRsaKemDecapsulationMatchesRawPrivateTransformBoundary(): Unit {
        let privateKey = loadRsa2048PrivateKey()
        let k = privateKey.publicKey.modulus.toBytesBE().size
        let representative = BigNum.fromHex("02")
        let ciphertext = representative
            .modExp(privateKey.publicKey.exponent, privateKey.publicKey.modulus)
            .toBytesBE(paddedLen: k)
        let info = "rsa-kem-raw-transform-boundary".toArray()

        let ikm = rsaPrivateTransformRawForProtocol(privateKey, ciphertext)
        let expectedSecret = testHkdfSha256(ikm, testAppendContext("RSA-KEM", info), 40)
        let actualSecret = rsaKemDecapsulate(privateKey, ciphertext, sharedSecretLen: 40, info: info)

        @Assert(actualSecret, expectedSecret)
    }

    @TestCase
    public func testRsaKemKdfInfoAndLengthBoundary(): Unit {
        let privateKey = loadRsa2048PrivateKey()
        let (ciphertext, secretA) = rsaKemEncapsulate(
            privateKey.publicKey,
            sharedSecretLen: 32,
            info: "kdf-info-a".toArray()
        )
        let decA = rsaKemDecapsulate(
            privateKey,
            ciphertext,
            sharedSecretLen: 32,
            info: "kdf-info-a".toArray()
        )
        let decB = rsaKemDecapsulate(
            privateKey,
            ciphertext,
            sharedSecretLen: 32,
            info: "kdf-info-b".toArray()
        )
        @Assert(secretA, decA)
        @Assert(bytesToHexLower(decA) != bytesToHexLower(decB), true)

        try {
            _ = rsaKemDecapsulate(privateKey, ciphertext, sharedSecretLen: 0)
            @Fail("RSA-KEM should reject zero-length shared secret requests")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            _ = rsaKemDecapsulate(privateKey, ciphertext, sharedSecretLen: 8161)
            @Fail("RSA-KEM should reject HKDF output beyond 255 SHA-256 blocks")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "OUT_OF_BOUNDS")
        }
    }

    @TestCase
    public func testRsaKemRejectInvalidCiphertext(): Unit {
        let privateKey = loadRsa2048PrivateKey()

        let shortCipher = Array<Byte>(255, repeat: 0)
        try {
            _ = rsaKemDecapsulate(privateKey, shortCipher)
            @Fail("short RSA-KEM ciphertext should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        let outOfRangeCipher = Array<Byte>(256, repeat: UInt8(0xff))
        try {
            _ = rsaKemDecapsulate(privateKey, outOfRangeCipher)
            @Fail("RSA-KEM ciphertext representative out of range should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testEcdhKemRoundTrip(): Unit {
        let receiverPrivate = EcPrivateKey(P256, BigNum.one())
        let receiverPublic = EcPublicKey(P256, P256_GX, P256_GY)
        let info = "stage3-ecdh-kem".toArray()

        let (encapsulatedKey, secretEnc) = ecdhKemEncapsulate(
            receiverPublic,
            sharedSecretLen: 32,
            info: info
        )
        let secretDec = ecdhKemDecapsulate(
            receiverPrivate,
            encapsulatedKey,
            sharedSecretLen: 32,
            info: info
        )

        @Assert(encapsulatedKey.size, 65)
        @Assert(UInt8(encapsulatedKey[0]), UInt8(0x04))
        @Assert(secretEnc.size, 32)
        @Assert(secretEnc, secretDec)
    }

    @TestCase
    public func testEcdhKemRejectInvalidInput(): Unit {
        let receiverPrivate = EcPrivateKey(P256, BigNum.one())
        let receiverPublic = EcPublicKey(P256, P256_GX, P256_GY)

        let (encapsulatedKey, _) = ecdhKemEncapsulate(receiverPublic)
        let broken = encapsulatedKey.clone()
        broken[0] = UInt8(0x05)

        try {
            _ = ecdhKemDecapsulate(receiverPrivate, broken)
            @Fail("broken ECDH-KEM point prefix should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let p384Private = EcPrivateKey(P384, BigNum.one())
        try {
            _ = ecdhKemDecapsulate(p384Private, encapsulatedKey)
            @Fail("non-P256 ECDH-KEM decapsulation should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testKemComplianceRequireAllowed(): Unit {
        let defaultProfile = FipsProfile.phase1Default()
        rsaKemRequireAllowed(defaultProfile)
        ecdhKemRequireAllowed(defaultProfile)

        let kemOnly = FipsProfile.fromText("RSA-KEM\nECDH-KEM")
        rsaKemRequireAllowed(kemOnly)
        ecdhKemRequireAllowed(kemOnly)

        let blockedProfile = FipsProfile.fromText("AES-GCM")
        try {
            rsaKemRequireAllowed(blockedProfile)
            @Fail("RSA-KEM should be blocked when neither RSA-KEM nor RSA is allowed")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        try {
            ecdhKemRequireAllowed(blockedProfile)
            @Fail("ECDH-KEM should be blocked when neither ECDH-KEM nor ECDH is allowed")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }
}

private func testAppendContext(label: String, info: Array<Byte>): Array<Byte> {
    let labelBytes = label.toArray()
    let out = Array<Byte>(labelBytes.size + info.size, repeat: 0)
    var i = 0
    while (i < labelBytes.size) {
        out[i] = labelBytes[i]
        i += 1
    }
    var j = 0
    while (j < info.size) {
        out[labelBytes.size + j] = info[j]
        j += 1
    }
    out
}

private func testHkdfSha256(ikm: Array<Byte>, info: Array<Byte>, outputLen: Int64): Array<Byte> {
    let zeroSalt = Array<Byte>(TEST_HKDF_SHA256_LEN, repeat: 0)
    let prk = hmac(HashAlgorithm.SHA256, zeroSalt, ikm)
    let blocks = (outputLen + TEST_HKDF_SHA256_LEN - 1) / TEST_HKDF_SHA256_LEN
    let out = Array<Byte>(outputLen, repeat: 0)
    var t = Array<Byte>(0, repeat: 0)
    var offset: Int64 = 0
    var counter: Int64 = 1

    while (counter <= blocks) {
        let input = Array<Byte>(t.size + info.size + 1, repeat: 0)
        var i = 0
        while (i < t.size) {
            input[i] = t[i]
            i += 1
        }
        var j = 0
        while (j < info.size) {
            input[t.size + j] = info[j]
            j += 1
        }
        input[input.size - 1] = UInt8(counter)

        t = hmac(HashAlgorithm.SHA256, prk, input)

        let remain = outputLen - offset
        let take = if (remain < TEST_HKDF_SHA256_LEN) {
            remain
        } else {
            TEST_HKDF_SHA256_LEN
        }
        var k = 0
        while (k < take) {
            out[offset + k] = t[k]
            k += 1
        }

        offset += take
        counter += 1
    }

    out
}

private func loadRsa2048PrivateKey(): RsaPrivateKey {
    let path = "testdata/stage3/rsa_params_sample.txt"
    if (!exists(path)) {
        throw Exception("missing RSA vector file: ${path}")
    }

    let lines = String.fromUtf8(File.readFrom(path)).replace("\r", "\n").split('\n')
    var inTarget = false
    var n = ""
    var e = ""
    var d = ""

    for (rawLine in lines) {
        let line = rawLine.trimAscii()
        if (line.size == 0 || line.startsWith("#")) {
            continue
        }
        if (let Some(pos) <- line.indexOf("=")) {
            let key = line[..pos].trimAscii()
            let value = line[(pos + 1)..].trimAscii()
            if (key == "Vector") {
                if (inTarget && value != "RSA-2048") {
                    break
                }
                inTarget = (value == "RSA-2048")
                continue
            }
            if (!inTarget) {
                continue
            }
            if (key == "N") {
                n = value
            } else if (key == "E") {
                e = value
            } else if (key == "D") {
                d = value
            }
        }
    }

    if (n.size == 0 || e.size == 0 || d.size == 0) {
        throw Exception("RSA-2048 key vector is incomplete")
    }

    rsaPrivateKeyFromHex(n, e, d)
}
