package jinguissl.tests

import jinguissl.contract.*

private let TEST_KEY_AES128: Array<Byte> = [
    0x1f, 0x36, 0x96, 0x13, 0xdd, 0x76, 0xd5, 0x46,
    0x77, 0x30, 0xef, 0xcb, 0xe3, 0xb1, 0xa2, 0x2d
]
private let TEST_KEY_AES256: Array<Byte> = Array<Byte>(32, repeat: 0x22)
private let TEST_KEY_CHACHA: Array<Byte> = [
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97,
    0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f
]
private let TEST_IV: Array<Byte> = [
    0xfa, 0x04, 0x4b, 0x2f, 0x42, 0xa3,
    0xfd, 0x3b, 0x46, 0xfb, 0x25, 0x5c
]

@Test
public class ContractQuicAeadTestSuite {
    @TestCase
    public func testContractQuicAeadAlgorithmNamesAndOrdinals(): Unit {
        @Assert(ContractQuicAeadAlgorithm.Aes128Gcm.toString(), "AES-128-GCM")
        @Assert(ContractQuicAeadAlgorithm.Aes256Gcm.toString(), "AES-256-GCM")
        @Assert(ContractQuicAeadAlgorithm.ChaCha20Poly1305.toString(), "ChaCha20-Poly1305")
        @Assert(ContractQuicAeadAlgorithm.Aes128Gcm.ordinalValue(), 0)
        @Assert(ContractQuicAeadAlgorithm.Aes256Gcm.ordinalValue(), 1)
        @Assert(ContractQuicAeadAlgorithm.ChaCha20Poly1305.ordinalValue(), 2)
    }

    @TestCase
    public func testAes128RoundTrip(): Unit {
        assertRoundTrip(TEST_KEY_AES128, ContractQuicAeadAlgorithm.Aes128Gcm)
    }

    @TestCase
    public func testAes256RoundTrip(): Unit {
        assertRoundTrip(TEST_KEY_AES256, ContractQuicAeadAlgorithm.Aes256Gcm)
    }

    @TestCase
    public func testChaCha20Poly1305RoundTrip(): Unit {
        assertRoundTrip(TEST_KEY_CHACHA, ContractQuicAeadAlgorithm.ChaCha20Poly1305)
    }

    @TestCase
    public func testWrongPacketNumberMapsToVerifyFailed(): Unit {
        let plaintext = "hello quic".toArray()
        let aad = "aad".toArray()
        let sealed = contractQuicAeadEncrypt(
            TEST_KEY_AES128, TEST_IV, 7, plaintext, aad,
            ContractQuicAeadAlgorithm.Aes128Gcm
        )
        try {
            _ = contractQuicAeadDecrypt(
                TEST_KEY_AES128, TEST_IV, 99, sealed, aad,
                ContractQuicAeadAlgorithm.Aes128Gcm
            )
            @Fail("AEAD should fail with the wrong packet number")
        } catch (e: ContractException) {
            @Assert(e.code, ContractErrorCode.VerifyFailed)
        }
    }

    @TestCase
    public func testAlgorithmKeyLengthMismatchRejectedOnEncrypt(): Unit {
        let key192 = Array<Byte>(24, repeat: 0x5a)
        assertEncryptKeyMismatch(TEST_KEY_AES256, ContractQuicAeadAlgorithm.Aes128Gcm)
        assertEncryptKeyMismatch(key192, ContractQuicAeadAlgorithm.Aes128Gcm)
        assertEncryptKeyMismatch(TEST_KEY_AES128, ContractQuicAeadAlgorithm.Aes256Gcm)
        assertEncryptKeyMismatch(key192, ContractQuicAeadAlgorithm.Aes256Gcm)
        assertEncryptKeyMismatch(TEST_KEY_AES128, ContractQuicAeadAlgorithm.ChaCha20Poly1305)
        assertEncryptKeyMismatch(key192, ContractQuicAeadAlgorithm.ChaCha20Poly1305)
    }

    @TestCase
    public func testAlgorithmKeyLengthMismatchRejectedOnDecrypt(): Unit {
        let key192 = Array<Byte>(24, repeat: 0x5a)
        let ciphertextWithTag = Array<Byte>(16, repeat: 0)
        assertDecryptKeyMismatch(
            TEST_KEY_AES256, ContractQuicAeadAlgorithm.Aes128Gcm, ciphertextWithTag
        )
        assertDecryptKeyMismatch(
            key192, ContractQuicAeadAlgorithm.Aes128Gcm, ciphertextWithTag
        )
        assertDecryptKeyMismatch(
            TEST_KEY_AES128, ContractQuicAeadAlgorithm.Aes256Gcm, ciphertextWithTag
        )
        assertDecryptKeyMismatch(
            key192, ContractQuicAeadAlgorithm.Aes256Gcm, ciphertextWithTag
        )
        assertDecryptKeyMismatch(
            TEST_KEY_AES128, ContractQuicAeadAlgorithm.ChaCha20Poly1305, ciphertextWithTag
        )
        assertDecryptKeyMismatch(
            key192, ContractQuicAeadAlgorithm.ChaCha20Poly1305, ciphertextWithTag
        )
    }

    @TestCase
    public func testMalformedAeadInputsStayContractOwned(): Unit {
        assertEncryptBadInput(
            TEST_KEY_AES128, Array<Byte>(11, repeat: 0), 0,
            ContractQuicAeadAlgorithm.Aes128Gcm
        )
        assertEncryptBadInput(
            TEST_KEY_AES128, TEST_IV, -1,
            ContractQuicAeadAlgorithm.Aes128Gcm
        )
        assertDecryptBadInput(
            TEST_KEY_AES128, TEST_IV, 0, [0x00],
            ContractQuicAeadAlgorithm.Aes128Gcm
        )
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

        let sealed = contractQuicAeadEncrypt(
            key, iv, 1, plaintext, aad,
            ContractQuicAeadAlgorithm.Aes128Gcm
        )
        assertHex(sealed, expected)
        @Assert(
            contractQuicAeadDecrypt(
                key, iv, 1, sealed, aad,
                ContractQuicAeadAlgorithm.Aes128Gcm
            ),
            plaintext
        )
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

        let sealed = contractQuicAeadEncrypt(
            key, iv, 654360564, plaintext, aad,
            ContractQuicAeadAlgorithm.ChaCha20Poly1305
        )
        assertHex(sealed, expected)
        @Assert(
            contractQuicAeadDecrypt(
                key, iv, 654360564, sealed, aad,
                ContractQuicAeadAlgorithm.ChaCha20Poly1305
            ),
            plaintext
        )
    }
}

private func assertRoundTrip(
    key: Array<Byte>,
    algorithm: ContractQuicAeadAlgorithm
): Unit {
    let plaintext = "hello quic".toArray()
    let aad = "aad".toArray()
    let sealed = contractQuicAeadEncrypt(key, TEST_IV, 42, plaintext, aad, algorithm)
    @Assert(sealed.size, plaintext.size + 16)
    let recovered = contractQuicAeadDecrypt(key, TEST_IV, 42, sealed, aad, algorithm)
    @Assert(recovered, plaintext)
}

private func assertEncryptKeyMismatch(
    key: Array<Byte>,
    algorithm: ContractQuicAeadAlgorithm
): Unit {
    try {
        _ = contractQuicAeadEncrypt(key, TEST_IV, 0, [], [], algorithm)
        @Fail("QUIC AEAD encrypt must reject algorithm and key length mismatch")
    } catch (e: ContractException) {
        @Assert(e.code, ContractErrorCode.BadInput)
    }
}

private func assertDecryptKeyMismatch(
    key: Array<Byte>,
    algorithm: ContractQuicAeadAlgorithm,
    ciphertextWithTag: Array<Byte>
): Unit {
    try {
        _ = contractQuicAeadDecrypt(key, TEST_IV, 0, ciphertextWithTag, [], algorithm)
        @Fail("QUIC AEAD decrypt must reject algorithm and key length mismatch")
    } catch (e: ContractException) {
        @Assert(e.code, ContractErrorCode.BadInput)
    }
}

private func assertEncryptBadInput(
    key: Array<Byte>,
    iv: Array<Byte>,
    pn: Int64,
    algorithm: ContractQuicAeadAlgorithm
): Unit {
    try {
        _ = contractQuicAeadEncrypt(key, iv, pn, [], [], algorithm)
        @Fail("QUIC facade must reject malformed input")
    } catch (e: ContractException) {
        @Assert(e.code, ContractErrorCode.BadInput)
    }
}

private func assertDecryptBadInput(
    key: Array<Byte>,
    iv: Array<Byte>,
    pn: Int64,
    ciphertextWithTag: Array<Byte>,
    algorithm: ContractQuicAeadAlgorithm
): Unit {
    try {
        _ = contractQuicAeadDecrypt(key, iv, pn, ciphertextWithTag, [], algorithm)
        @Fail("QUIC facade must reject malformed input")
    } catch (e: ContractException) {
        @Assert(e.code, ContractErrorCode.BadInput)
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
