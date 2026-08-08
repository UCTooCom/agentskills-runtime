package sample_tls_integration

 /**
 * tls_integration.cj — TLS 1.3 集成演示
 *
 * 展示 QUIC 中 TLS 1.3 的集成，包括初始 AEAD 密钥派生、
 * 密码套件选择、包头保护等机制。
 */
 
 import quic_cj.tls.{newInitialAEAD, newInitialAEADV2, AesHeaderProtector, ChaChaHeaderProtector, CipherSuite, selectCipherSuite, TlsConfig, defaultTlsConfig, TLS_AES_128_GCM_SHA256, TLS_CHACHA20_POLY1305_SHA256, DEFAULT_CIPHER_SUITES}
 import quic_cj.protocol.{VERSION_1, VERSION_2}
 
 main(): Int64 {
     println("=== TLS 1.3 Integration Demo ===\n")
 
     // ── 1. 初始 AEAD 密钥派生 ──
     println("── 1. Initial AEAD Key Derivation ──")
     let connId: Array<Byte> = [0x83u8, 0x94u8, 0xc8u8, 0xf0u8, 0x3eu8, 0x51u8, 0x57u8, 0x08u8]
     let aeadV1 = newInitialAEAD(connId)
     println("  QUIC v1: key=" + aeadV1.getKey().size.toString() + " bytes" +
             ", iv=" + aeadV1.getIv().size.toString() + " bytes" +
             ", hp=" + aeadV1.getHpKey().size.toString() + " bytes")
 
     let aeadV2 = newInitialAEADV2(connId)
     println("  QUIC v2: key=" + aeadV2.getKey().size.toString() + " bytes" +
             ", iv=" + aeadV2.getIv().size.toString() + " bytes" +
             ", hp=" + aeadV2.getHpKey().size.toString() + " bytes")
 
     // ── 2. AEAD 加密/解密 ──
     println("\n── 2. AEAD Encrypt/Decrypt ──")
     let plaintext: Array<Byte> = [0x48u8, 0x65u8, 0x6cu8, 0x6cu8, 0x6fu8]  // "Hello"
     let aad: Array<Byte> = [0xc0u8, 0x00u8, 0x00u8, 0x00u8, 0x01u8]
     let ciphertext = aeadV1.encrypt(0, plaintext, aad)
     println("  Plaintext: " + plaintext.size.toString() + " bytes")
     println("  Ciphertext: " + ciphertext.size.toString() + " bytes (+" +
             (ciphertext.size - plaintext.size).toString() + " tag)")
     let decrypted = aeadV1.decrypt(0, ciphertext, aad)
     println("  Decrypted: " + decrypted.size.toString() + " bytes")
     println("  Round-trip success: " + (decrypted == plaintext).toString())
 
     // ── 3. 包头保护 ──
     println("\n── 3. Header Protection ──")
     let sample: Array<Byte> = Array<Byte>(16, repeat: 0xabu8)
     let hpKey: Array<Byte> = Array<Byte>(16, repeat: 0xcdu8)
     let hp = AesHeaderProtector(hpKey)
     let (_, pnMask) = hp.encryptHeader(sample)
     println("  AES header protection: PN mask size=" + pnMask.size.toString())
 
     let chachaHpKey: Array<Byte> = Array<Byte>(32, repeat: 0xcdu8)
    let chachaHp = ChaChaHeaderProtector(chachaHpKey)
     let (_, pnMask2) = chachaHp.encryptHeader(sample)
     println("  ChaCha20 header protection: PN mask size=" + pnMask2.size.toString())
 
     // ── 4. 密码套件 ──
     println("\n── 4. Cipher Suites ──")
     let aes128 = CipherSuite(TLS_AES_128_GCM_SHA256)
     println("  AES-128-GCM: keyLen=" + aes128.keyLen.toString() +
             " ivLen=" + aes128.ivLen.toString() +
             " isChaCha=" + aes128.isChaCha.toString())
     let chacha = CipherSuite(TLS_CHACHA20_POLY1305_SHA256)
     println("  ChaCha20-Poly1305: keyLen=" + chacha.keyLen.toString() +
             " isChaCha=" + chacha.isChaCha.toString())
     println("  Default suites: " + DEFAULT_CIPHER_SUITES.size.toString())
 
      if (let Some(selected) <- selectCipherSuite(
          [TLS_AES_128_GCM_SHA256, TLS_CHACHA20_POLY1305_SHA256],
          [TLS_CHACHA20_POLY1305_SHA256])) {
          println("  Selected cipher: 0x" + selected.toString())
      } else {
          println("  No common cipher suite selected")
      }
 
     // ── 5. TLS 配置 ──
     println("\n── 5. TLS Configuration ──")
     let tlsCfg = defaultTlsConfig()
     tlsCfg.serverName = "example.com"
     tlsCfg.alpn = ["h3", "hq-interop"]
     println("  Server name: " + tlsCfg.serverName)
     println("  ALPN: " + tlsCfg.alpn.size.toString() + " protocols")
     println("  Early data: " + tlsCfg.enableEarlyData.toString())
 
     println("\n=== TLS Integration Demo Complete ===")
     0
 }
