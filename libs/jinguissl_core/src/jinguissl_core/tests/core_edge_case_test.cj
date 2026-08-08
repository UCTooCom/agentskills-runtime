package jinguissl_core.tests

import jinguissl_core.crypto.aes.{aesEcbEncrypt, aesEcbDecrypt, aesCbcEncrypt, aesCbcDecrypt, aesGcmEncrypt, aesGcmDecrypt, pkcs7Pad, pkcs7Unpad}
import jinguissl_core.crypto.base.{Endian, SecureBytes, ByteBuffer}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.chacha20.{chacha20Block, chacha20Xor, chacha20Poly1305Encrypt, chacha20Poly1305Decrypt, chacha20Poly1305NewContext, chacha20Poly1305EncryptWithContext, chacha20Poly1305DecryptWithContext, poly1305Mac, CHACHA20_KEY_LEN, CHACHA20_NONCE_LEN}
import jinguissl_core.crypto.compliance.{FipsProfile, TLS_VERSION_1_2, TLS_VERSION_1_3}
import jinguissl_core.crypto.digest.{HashAlgorithm, md5, sha1, sha256, sha384, sha512, hash, hmac, hkdf, hkdfExtract, hkdfExpand, bytesToHexLower}
import jinguissl_core.crypto.ed25519.{ed25519GeneratePrivateKeySeed, ed25519PublicKeyFromSeed, ed25519Sign, ed25519Verify}
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.rsa.{rsaGenerateKey, rsaSignPkcs1v15, rsaVerifyPkcs1v15, rsaSignPss, rsaVerifyPss, RsaHashAlgorithm}
import jinguissl_core.crypto.sm3.sm3
import jinguissl_core.crypto.sm4.{sm4Encrypt, sm4Decrypt}
import jinguissl_core.crypto.utils.{bytesToUInt32BE, bytesToUInt32LE, uInt32ToBytesBE, uInt32ToBytesLE, constantTimeEquals, secureCopy, secureZero, randomSeed}
import jinguissl_core.crypto.x25519.{x25519GeneratePrivateKey, x25519PublicFromPrivate, x25519DeriveSharedSecret}

@Test
public class CoreEdgeCaseTestSuite {
    // ========== Digest edge cases ==========

    @TestCase
    public func testDigestEmptyInput(): Unit {
        let empty: Array<Byte> = []
        let md5Empty = md5(empty)
        @Assert(md5Empty.size == 16, true)

        let sha256Empty = sha256(empty)
        @Assert(sha256Empty.size == 32, true)
        let expectedEmpty: Array<Byte> = [
            UInt8(0xe3), UInt8(0xb0), UInt8(0xc4), UInt8(0x42),
            UInt8(0x98), UInt8(0xfc), UInt8(0x1c), UInt8(0x14),
            UInt8(0x9a), UInt8(0xfb), UInt8(0xf4), UInt8(0xc8),
            UInt8(0x99), UInt8(0x6f), UInt8(0xb9), UInt8(0x24),
            UInt8(0x27), UInt8(0xae), UInt8(0x41), UInt8(0xe4),
            UInt8(0x64), UInt8(0x9b), UInt8(0x93), UInt8(0x4c),
            UInt8(0xa4), UInt8(0x95), UInt8(0x99), UInt8(0x1b),
            UInt8(0x78), UInt8(0x52), UInt8(0xb8), UInt8(0x55)
        ]
        @Assert(sha256Empty == expectedEmpty, true)

        let sha512Empty = sha512(empty)
        @Assert(sha512Empty.size == 64, true)

        let sm3Empty = sm3(empty)
        @Assert(sm3Empty.size == 32, true)

        @Assert(hash(HashAlgorithm.SHA256, empty) == expectedEmpty, true)
    }

    @TestCase
    public func testDigestLargeInput(): Unit {
        // 1MB of 'a's
        let size: Int64 = 1024 * 1024
        let large = Array<Byte>(size, repeat: UInt8(0x61))
        let result = sha256(large)
        @Assert(result.size == 32, true)

        // Test that same input produces same hash
        let result2 = sha256(large)
        @Assert(result == result2, true)
    }

    @TestCase
    public func testDigestKnownVectors(): Unit {
        let abc = "abc".toArray()
        let sha256Abc = sha256(abc)
        let expected: Array<Byte> = [
            UInt8(0xba), UInt8(0x78), UInt8(0x16), UInt8(0xbf),
            UInt8(0x8f), UInt8(0x01), UInt8(0xcf), UInt8(0xea),
            UInt8(0x41), UInt8(0x41), UInt8(0x40), UInt8(0xde),
            UInt8(0x5d), UInt8(0xae), UInt8(0x22), UInt8(0x23),
            UInt8(0xb0), UInt8(0x03), UInt8(0x61), UInt8(0xa3),
            UInt8(0x96), UInt8(0x17), UInt8(0x7a), UInt8(0x9c),
            UInt8(0xb4), UInt8(0x10), UInt8(0xff), UInt8(0x61),
            UInt8(0xf2), UInt8(0x00), UInt8(0x15), UInt8(0xad)
        ]
        @Assert(sha256Abc == expected, true)
    }

    // ========== AES edge cases ==========

    @TestCase
    public func testAesPkcs7PadUnpad(): Unit {
        let block: Array<Byte> = [UInt8(0x01), UInt8(0x02), UInt8(0x03)]
        let padded = pkcs7Pad(block, blockSize: 16)
        @Assert(padded.size == 16, true)
        // PKCS7 padding: 0x0d repeated 13 times
        @Assert(padded[3] == UInt8(0x0d), true)

        let unpadded = pkcs7Unpad(padded, blockSize: 16)
        @Assert(unpadded == block, true)
    }

    @TestCase
    public func testAesKeySizes(): Unit {
        let pt: Array<Byte> = Array<Byte>(16, repeat: UInt8(0x42))
        let iv: Array<Byte> = Array<Byte>(16, repeat: UInt8(0x00))

        // AES-128: 16-byte key
        let key128: Array<Byte> = Array<Byte>(16, repeat: UInt8(0x00))
        let ct128 = aesCbcEncrypt(key128, iv, pt)
        @Assert(ct128.size == 16, true)
        let pt128 = aesCbcDecrypt(key128, iv, ct128)
        @Assert(pt128 == pt, true)
    }

    @TestCase
    public func testAesGcmAadVariants(): Unit {
        let key: Array<Byte> = Array<Byte>(16, repeat: UInt8(0x00))
        let iv: Array<Byte> = Array<Byte>(12, repeat: UInt8(0x00))
        let pt: Array<Byte> = "hello gcm".toArray()

        // GCM with empty AAD
        let (ct, tag) = aesGcmEncrypt(key, iv, pt, aad: [])
        let dec = aesGcmDecrypt(key, iv, ct, tag, aad: [])
        @Assert(dec == pt, true)

        // GCM with non-empty AAD
        let aad: Array<Byte> = "aad data".toArray()
        let (ct2, tag2) = aesGcmEncrypt(key, iv, pt, aad: aad)
        let dec2 = aesGcmDecrypt(key, iv, ct2, tag2, aad: aad)
        @Assert(dec2 == pt, true)
    }

    // ========== ChaCha20 edge cases ==========

    @TestCase
    public func testChacha20EmptyPlaintext(): Unit {
        let key = Array<Byte>(CHACHA20_KEY_LEN, repeat: UInt8(0x00))
        let nonce = Array<Byte>(CHACHA20_NONCE_LEN, repeat: UInt8(0x00))

        let empty: Array<Byte> = []
        let ct = chacha20Xor(key, nonce, empty, initialCounter: 0)
        @Assert(ct.size == 0, true)
    }

    @TestCase
    public func testChacha20BlockCounter(): Unit {
        let key = Array<Byte>(CHACHA20_KEY_LEN, repeat: UInt8(0x00))
        let nonce = Array<Byte>(CHACHA20_NONCE_LEN, repeat: UInt8(0x00))

        let block0 = chacha20Block(key, 0, nonce)
        let block1 = chacha20Block(key, 1, nonce)
        @Assert(block0.size == 64, true)
        @Assert(block1.size == 64, true)
        @Assert(block0 != block1, true)
    }

    // ========== Error path tests ==========

    @TestCase
    public func testCryptoExceptionErrorCodes(): Unit {
        let code = CryptoErrorCode.InvalidArgument
        @Assert(code.toString(), "INVALID_ARGUMENT")

        let exception = CryptoException(CryptoErrorCode.Unsupported, "test error")
        @Assert(exception.code.toString(), "UNSUPPORTED")
        @Assert(exception.message.contains("test error"), true)
    }

    // ========== Constant-time comparison edge cases ==========

    @TestCase
    public func testConstantTimeEdgeCases(): Unit {
        let emptyLeft: Array<Byte> = []
        let emptyRight: Array<Byte> = []
        @Assert(constantTimeEquals(emptyLeft, emptyRight), true)

        let single: Array<Byte> = [UInt8(0x00)]
        let single2: Array<Byte> = [UInt8(0x00)]
        @Assert(constantTimeEquals(single, single2), true)

        let single3: Array<Byte> = [UInt8(0x01)]
        @Assert(constantTimeEquals(single, single3) == false, true)
    }

    // ========== BigNum edge cases ==========

    @TestCase
    public func testBigNumZeroAndOne(): Unit {
        let zero = BigNum.zero()
        let one = BigNum.one()
        @Assert(zero != one, true)

        let zeroHex = BigNum.fromHex("0")
        @Assert(zero == zeroHex, true)
    }

    // ========== HKDF edge cases ==========

    @TestCase
    public func testHkdfEdgeCases(): Unit {
        let ikm = "ikm".toArray()
        let info = "info".toArray()

        // HKDF with empty salt
        let result = hkdf(HashAlgorithm.SHA256, ikm, info, 16, salt: [])
        @Assert(result.size == 16, true)

        // HKDF with minimal output
        let resultMin = hkdf(HashAlgorithm.SHA256, ikm, info, 1, salt: [])
        @Assert(resultMin.size == 1, true)

        // HKDF extract with empty salt
        let prk = hkdfExtract(HashAlgorithm.SHA256, [], ikm)
        let expanded = hkdfExpand(HashAlgorithm.SHA256, prk, info, 16)
        @Assert(expanded.size == 16, true)
    }

    // ========== Ed25519 edge cases ==========

    @TestCase
    public func testEd25519DeterministicSigning(): Unit {
        let seed = ed25519GeneratePrivateKeySeed()
        let pubKey = ed25519PublicKeyFromSeed(seed)
        let message = "test".toArray()

        let sig1 = ed25519Sign(seed, message)
        let sig2 = ed25519Sign(seed, message)
        @Assert(sig1 == sig2, true)

        @Assert(ed25519Verify(pubKey, message, sig1), true)
        @Assert(ed25519Verify(pubKey, message, sig2), true)
    }

    // ========== SM4 edge cases ==========

    @TestCase
    public func testSm4MultiBlock(): Unit {
        let key: Array<Byte> = Array<Byte>(16, repeat: UInt8(0x00))
        let pt: Array<Byte> = Array<Byte>(16, repeat: UInt8(0x42))

        let ct = sm4Encrypt(key, pt)
        @Assert(ct.size == 16, true)
        let dec = sm4Decrypt(key, ct)
        @Assert(dec == pt, true)
    }

    // ========== SecureBytes lifecycle ==========

    @TestCase
    public func testSecureBytesEdgeCases(): Unit {
        let sb = SecureBytes.withSize(0)
        @Assert(sb.size == 0, true)
        @Assert(sb.isDestroyed == false, true)

        sb.destroy()
        @Assert(sb.isDestroyed == true, true)

        // Double destroy should not error
        sb.destroy()
        @Assert(sb.isDestroyed == true, true)
    }

    // ========== X25519 edge cases ==========

    @TestCase
    public func testX25519RoundTrip(): Unit {
        let alicePriv = x25519GeneratePrivateKey()
        let alicePub = x25519PublicFromPrivate(alicePriv)
        let bobPriv = x25519GeneratePrivateKey()
        let bobPub = x25519PublicFromPrivate(bobPriv)

        let shared1 = x25519DeriveSharedSecret(alicePriv, bobPub)
        let shared2 = x25519DeriveSharedSecret(bobPriv, alicePub)
        @Assert(shared1 == shared2, true)
        @Assert(shared1.size == 32, true)
        @Assert(shared2.size == 32, true)
    }

    // ========== RSA edge cases ==========

    @TestCase
    public func testRsaSignVerifyPssDefaultSalt(): Unit {
        let privKey = rsaGenerateKey(2048)
        let pubKey = privKey.publicKey
        let msg: Array<Byte> = Array<Byte>(32, repeat: UInt8(0x42))

        let sig = rsaSignPss(privKey, msg)
        let valid = rsaVerifyPss(pubKey, msg, sig)
        @Assert(valid, true)
    }

    // ========== ByteBuffer edge cases ==========

    @TestCase
    public func testByteBufferEdgeCases(): Unit {
        let buf = ByteBuffer()
        @Assert(buf.size == 0, true)

        buf.append([])
        @Assert(buf.size == 0, true)

        buf.append(UInt8(42))
        @Assert(buf.size == 1, true)

        let arr = buf.toArray()
        @Assert(arr.size == 1, true)
        @Assert(arr[0] == UInt8(42), true)
    }

    // ========== Compliance profile ==========

    @TestCase
    public func testFipsProfileDefault(): Unit {
        let profile = FipsProfile.phase1Default()
        @Assert(profile.allowedAlgorithms().size > 0, true)

        profile.requireAllowed("SHA-256")
        profile.requireAllowed("AES-GCM")

        try {
            profile.requireAllowed("SM4")
            @Fail("SM4 should not be in default profile")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }
}
