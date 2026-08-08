package quic_cj.tests

import quic_cj.tls.{newInitialAEAD, newInitialAEADV2, AesHeaderProtector, ChaChaHeaderProtector, quicHkdfExpandLabel}

@Test
public class TlsTestSuite {
    private let TEST_CONN_ID: Array<Byte> = [
        0x83u8, 0x94u8, 0xc8u8, 0xf0u8, 0x3eu8, 0x51u8, 0x57u8, 0x08u8
    ]
    private let EXPECTED_KEY: Array<Byte> = [
        0x1fu8, 0x36u8, 0x96u8, 0x13u8, 0xddu8, 0x76u8, 0xd5u8, 0x46u8,
        0x77u8, 0x30u8, 0xefu8, 0xcbu8, 0xe3u8, 0xb1u8, 0xa2u8, 0x2du8
    ]

    @TestCase
    public func testInitialAEADKeyDeriveV1(): Unit {
        let aead = newInitialAEAD(TEST_CONN_ID)
        @Assert(aead.getKey(), EXPECTED_KEY)
        @Assert(aead.getIv().size, 12)
        @Assert(aead.getHpKey().size, 16)
    }

    @TestCase
    public func testInitialAEADKeyDeriveV2(): Unit {
        let aead = newInitialAEADV2(TEST_CONN_ID)
        @Assert(aead.getKey().size, 16)
    }

    @TestCase
    public func testInitialAEADRoundTrip(): Unit {
        let aead = newInitialAEAD(TEST_CONN_ID)
        let pt: Array<Byte> = [0x01u8, 0x02u8, 0x03u8]
        let aad: Array<Byte> = [0xa0u8, 0xb0u8]
        let ct = aead.encrypt(0, pt, aad)
        @Assert(ct.size, pt.size + 16)
        let recovered = aead.decrypt(0, ct, aad)
        @Assert(recovered, pt)
    }

    @TestCase
    public func testInitialAEADWrongPnFails(): Unit {
        let aead = newInitialAEAD(TEST_CONN_ID)
        let pt: Array<Byte> = [0x01u8, 0x02u8, 0x03u8]
        let aad: Array<Byte> = [0xa0u8, 0xb0u8]
        let ct = aead.encrypt(1, pt, aad)
        try {
            _ = aead.decrypt(999, ct, aad)
            @Fail("fail")
        } catch (_: Exception) {
            @Assert(true)
        }
    }

    @TestCase
    public func testAesHeaderProtector(): Unit {
        let sample: Array<Byte> = [
            0xd1u8, 0xb1u8, 0xc9u8, 0x8du8, 0xd7u8, 0x68u8, 0x9fu8, 0xb8u8,
            0xecu8, 0x11u8, 0xd2u8, 0x42u8, 0xb1u8, 0x23u8, 0xdcu8, 0x9bu8
        ]
        let hpKey: Array<Byte> = [
            0x9fu8, 0x50u8, 0x44u8, 0x9eu8, 0x04u8, 0xa0u8, 0xe8u8, 0x10u8,
            0x28u8, 0x3au8, 0x1eu8, 0x99u8, 0x33u8, 0xadu8, 0xedu8, 0xd2u8
        ]
        let hp = AesHeaderProtector(hpKey)
        let (firstMask, pnMask) = hp.encryptHeader(sample)
        let encryptedFirst = UInt8(0xc3) ^ (firstMask & UInt8(0x0f))
        @Assert(encryptedFirst, UInt8(0xc0))
        @Assert(pnMask.size, 15)
    }

    @TestCase
    public func testHkdfExpandLabel(): Unit {
        let secret = Array<Byte>(32, repeat: 0x01u8)
        let result = quicHkdfExpandLabel(secret, "quic key", [], 16)
        @Assert(result.size, 16)
    }
}
