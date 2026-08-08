 package quic_cj.tests
 
 import quic_cj.tls.{UpdatableAEAD, newInitialAEAD}
 
 @Test
 public class AeadQuicTestSuite {
     private let TEST_CONN_ID: Array<Byte> = [
         0x83u8, 0x94u8, 0xc8u8, 0xf0u8, 0x3eu8, 0x51u8, 0x57u8, 0x08u8
     ]
 
     @TestCase
     public func testUpdatableAEADCreation(): Unit {
         let key = Array<Byte>(16, repeat: 0xabu8)
         let iv = Array<Byte>(12, repeat: 0xcdu8)
         let aead = UpdatableAEAD(key, iv)
         @Assert(aead.getKey(), key)
         @Assert(aead.getIv(), iv)
     }
 
     @TestCase
     public func testUpdatableAEADEncryptDecrypt(): Unit {
         let key = Array<Byte>(16, repeat: 0xabu8)
         let iv = Array<Byte>(12, repeat: 0xcdu8)
         let aead = UpdatableAEAD(key, iv)
         let pt: Array<Byte> = [0x01u8, 0x02u8, 0x03u8]
         let aad: Array<Byte> = [0xc0u8, 0x00u8]
         let ct = aead.encrypt(0, pt, aad)
         @Assert(ct.size, pt.size + 16)
         let recovered = aead.decrypt(0, ct, aad)
         @Assert(recovered, pt)
     }
 
     @TestCase
    public func testUpdatableAEADDecryptWrongPn(): Unit {
        let key = Array<Byte>(16, repeat: 0xabu8)
        let iv = Array<Byte>(12, repeat: 0xcdu8)
        let aead = UpdatableAEAD(key, iv)
        let pt: Array<Byte> = [0x01u8, 0x02u8]
        let aad: Array<Byte> = [0xc0u8]
        let ct = aead.encrypt(0, pt, aad)
        // Different PN should yield different nonce, decryption fails silently
        let result = aead.decrypt(1, ct, aad)
        @Assert(result.size, 0)
    }

    @TestCase
     public func testInitialAEADEncryptDecryptEmpty(): Unit {
         let aead = newInitialAEAD(TEST_CONN_ID)
         let pt: Array<Byte> = []
         let aad: Array<Byte> = [0xc0u8]
         let ct = aead.encrypt(0, pt, aad)
         @Assert(ct.size, 16)
         let recovered = aead.decrypt(0, ct, aad)
         @Assert(recovered.size, 0)
     }
 
     @TestCase
     public func testInitialAEADLargePayload(): Unit {
         let aead = newInitialAEAD(TEST_CONN_ID)
         let pt = Array<Byte>(1000, repeat: 0x42u8)
         let aad: Array<Byte> = [0xc0u8, 0x00u8, 0x00u8, 0x00u8, 0x01u8]
         let ct = aead.encrypt(0, pt, aad)
         @Assert(ct.size, pt.size + 16)
         let recovered = aead.decrypt(0, ct, aad)
         @Assert(recovered, pt)
     }
 
     @TestCase
    public func testAeadDifferentKeys(): Unit {
        let key1 = Array<Byte>(16, repeat: 0xabu8)
        let key2 = Array<Byte>(16, repeat: 0xcdu8)
        let iv = Array<Byte>(12, repeat: 0x00u8)
        let aead1 = UpdatableAEAD(key1, iv)
        let aead2 = UpdatableAEAD(key2, iv)
        let pt: Array<Byte> = [0x01u8, 0x02u8]
        let aad: Array<Byte> = [0xc0u8]
        let ct = aead1.encrypt(0, pt, aad)
        // Wrong key should fail silently (return empty)
        let result = aead2.decrypt(0, ct, aad)
        @Assert(result.size, 0)
    }
}
