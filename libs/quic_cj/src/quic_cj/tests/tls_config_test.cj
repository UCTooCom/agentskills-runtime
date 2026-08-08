 package quic_cj.tests
 
 import quic_cj.tls.{TlsConfig, defaultTlsConfig, TLS_AES_128_GCM_SHA256, TLS_CHACHA20_POLY1305_SHA256}
 
 @Test
 public class TlsConfigTestSuite {
     @TestCase
     public func testDefaultConfig(): Unit {
         let cfg = defaultTlsConfig()
         @Assert(cfg.serverName, "")
         @Assert(cfg.alpn.size, 0)
         @Assert(cfg.密码套件s.size, 3)
         @Assert(cfg.enableEarlyData, false)
     }
 
     @TestCase
     public func testConfigServerName(): Unit {
         let cfg = TlsConfig()
         cfg.serverName = "example.com"
         @Assert(cfg.serverName, "example.com")
     }
 
     @TestCase
     public func testConfigAlpn(): Unit {
         let cfg = TlsConfig()
         cfg.alpn = ["h3", "hq-interop"]
         @Assert(cfg.alpn.size, 2)
         @Assert(cfg.alpn[0], "h3")
     }
 
     @TestCase
     public func testCustomCipherSuites(): Unit {
         let cfg = TlsConfig()
         cfg.密码套件s = [TLS_AES_128_GCM_SHA256]
         @Assert(cfg.密码套件s.size, 1)
     }
 
     @TestCase
     public func testEnableEarlyData(): Unit {
         let cfg = TlsConfig()
         cfg.enableEarlyData = true
         @Assert(cfg.enableEarlyData, true)
     }
 
     @TestCase
     public func testConfigRoundTrip(): Unit {
         let cfg = TlsConfig()
         cfg.serverName = "quic.example.com"
         cfg.alpn = ["h3"]
         cfg.enableEarlyData = false
         @Assert(cfg.serverName, "quic.example.com")
         @Assert(cfg.alpn.size, 1)
         @Assert(cfg.enableEarlyData, false)
     }
 }
