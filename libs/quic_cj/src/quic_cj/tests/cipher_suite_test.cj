 package quic_cj.tests
 
 import quic_cj.tls.{CipherSuite, selectCipherSuite, TLS_AES_128_GCM_SHA256, TLS_AES_256_GCM_SHA384, TLS_CHACHA20_POLY1305_SHA256, DEFAULT_CIPHER_SUITES}
 
 @Test
 public class CipherSuiteTestSuite {
     @TestCase
     public func testAes128Gcm(): Unit {
         let cs = CipherSuite(TLS_AES_128_GCM_SHA256)
         @Assert(cs.id, TLS_AES_128_GCM_SHA256)
         @Assert(cs.keyLen, 16)
         @Assert(cs.ivLen, 12)
         @Assert(cs.tagLen, 16)
         @Assert(cs.isChaCha, false)
     }
 
     @TestCase
     public func testAes256Gcm(): Unit {
         let cs = CipherSuite(TLS_AES_256_GCM_SHA384)
         @Assert(cs.id, TLS_AES_256_GCM_SHA384)
         @Assert(cs.keyLen, 32)
         @Assert(cs.ivLen, 12)
         @Assert(cs.isChaCha, false)
     }
 
     @TestCase
     public func testChaCha20Poly1305(): Unit {
         let cs = CipherSuite(TLS_CHACHA20_POLY1305_SHA256)
         @Assert(cs.id, TLS_CHACHA20_POLY1305_SHA256)
         @Assert(cs.keyLen, 32)
         @Assert(cs.ivLen, 12)
         @Assert(cs.isChaCha, true)
     }
 
     @TestCase
     public func testUnknownCipherSuite(): Unit {
         let cs = CipherSuite(0x1234u16)
         @Assert(cs.keyLen, 16)
         @Assert(cs.isChaCha, false)
     }
 
     @TestCase
     public func testDefaultCipherSuites(): Unit {
         @Assert(DEFAULT_CIPHER_SUITES.size, 3)
         @Assert(DEFAULT_CIPHER_SUITES[0], TLS_AES_128_GCM_SHA256)
         @Assert(DEFAULT_CIPHER_SUITES[1], TLS_CHACHA20_POLY1305_SHA256)
         @Assert(DEFAULT_CIPHER_SUITES[2], TLS_AES_256_GCM_SHA384)
     }
 
     @TestCase
     public func testSelectCipherSuiteMatch(): Unit {
         let ours: Array<UInt16> = [TLS_AES_128_GCM_SHA256, TLS_AES_256_GCM_SHA384]
         let theirs: Array<UInt16> = [TLS_AES_256_GCM_SHA384, TLS_CHACHA20_POLY1305_SHA256]
        if (let Some(selected) <- selectCipherSuite(ours, theirs)) {
            @Assert(selected, TLS_AES_256_GCM_SHA384)
        } else {
            @Assert(false, true)
        }
     }
 
     @TestCase
     public func testSelectCipherSuiteFirstMatch(): Unit {
         let ours: Array<UInt16> = [TLS_CHACHA20_POLY1305_SHA256, TLS_AES_128_GCM_SHA256]
         let theirs: Array<UInt16> = [TLS_AES_128_GCM_SHA256, TLS_CHACHA20_POLY1305_SHA256]
        if (let Some(selected) <- selectCipherSuite(ours, theirs)) {
            @Assert(selected, TLS_CHACHA20_POLY1305_SHA256)
        } else {
            @Assert(false, true)
        }
     }
 
     @TestCase
     public func testSelectCipherSuiteNoMatch(): Unit {
         let ours: Array<UInt16> = [TLS_AES_128_GCM_SHA256]
         let theirs: Array<UInt16> = [TLS_CHACHA20_POLY1305_SHA256, TLS_AES_256_GCM_SHA384]
        let none1 = match (selectCipherSuite(ours, theirs)) { case None => true; case _ => false }
        @Assert(none1, true)
     }
 
     @TestCase
     public func testSelectCipherSuiteEmpty(): Unit {
        let none2 = match (selectCipherSuite([], [TLS_AES_128_GCM_SHA256])) { case None => true; case _ => false }
        @Assert(none2, true)
     }
 }
