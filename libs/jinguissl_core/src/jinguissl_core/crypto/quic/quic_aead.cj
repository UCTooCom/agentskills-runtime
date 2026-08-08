 package jinguissl_core.crypto.quic

 import jinguissl_core.crypto.aes.{AesGcmContext, aesGcmEncryptWithContext, aesGcmDecryptWithContext, aesNewGcmContext}
 import jinguissl_core.crypto.chacha20.{Chacha20Poly1305Context, chacha20Poly1305EncryptWithContext, chacha20Poly1305DecryptWithContext, chacha20Poly1305NewContext}
 import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
 import jinguissl_core.crypto.utils.secureCopyInto

 public enum QuicAeadAlgorithm <: ToString {
     | Aes128Gcm
     | Aes256Gcm
     | ChaCha20Poly1305

     public func toString(): String {
         match (this) {
             case Aes128Gcm => "AES-128-GCM"
             case Aes256Gcm => "AES-256-GCM"
             case ChaCha20Poly1305 => "ChaCha20-Poly1305"
         }
     }
 }

 private func quicRequireAeadKeyLength(key: Array<Byte>, alg: QuicAeadAlgorithm): Unit {
     let expected: Int64 = match (alg) {
         case Aes128Gcm => 16
         case Aes256Gcm => 32
         case ChaCha20Poly1305 => 32
     }
     if (key.size != expected) {
         throw CryptoException(InvalidArgument, "QUIC ${alg} key must be ${expected} bytes")
     }
 }

 // QUIC AEAD nonce construction (RFC 9001 §5.1):
 // nonce = IV XOR (packet_number << (8 * (IV_length - PN_length)))
 // For QUIC: IV=12 bytes, PN=8 bytes, so:
 //   nonce[0..3] = IV[0..3]
 //   nonce[4..11] = IV[4..11] XOR PN(8 bytes big-endian)
 private func quicBuildNonce(iv: Array<Byte>, pn: Int64): Array<Byte> {
     if (iv.size != 12) {
         throw CryptoException(InvalidArgument, "QUIC AEAD IV must be 12 bytes")
     }
     if (pn < 0) {
         throw CryptoException(InvalidArgument, "QUIC packet number must be non-negative")
     }
     let nonce = iv.clone()
     let seq = UInt64(pn)
     var i: Int64 = 0
     while (i < 8) {
         let shift = UInt64((7 - i) * 8)
         let seqByte = UInt8((seq >> shift) & UInt64(0xff))
         nonce[4 + i] = UInt8(nonce[4 + i]) ^ seqByte
         i += 1
     }
     nonce
 }

 /// QUIC AEAD encrypt.
 /// Returns ciphertext ‖ tag (as on the wire).
 public func quicAeadEncrypt(
     key: Array<Byte>, iv: Array<Byte>, pn: Int64,
     plaintext: Array<Byte>, aad: Array<Byte>,
     alg: QuicAeadAlgorithm
 ): Array<Byte> {
     quicRequireAeadKeyLength(key, alg)
     match (alg) {
         case Aes128Gcm => let ctx = aesNewGcmContext(key)
              quicAeadAesGcmEncrypt(ctx, iv, pn, plaintext, aad)
         case Aes256Gcm => let ctx = aesNewGcmContext(key)
              quicAeadAesGcmEncrypt(ctx, iv, pn, plaintext, aad)
         case ChaCha20Poly1305 => let ctx = chacha20Poly1305NewContext(key)
              quicAeadChaCha20Encrypt(ctx, iv, pn, plaintext, aad)
     }
 }

 /// QUIC AEAD decrypt.
 /// Input: ciphertext ‖ tag (as on the wire).
 public func quicAeadDecrypt(
     key: Array<Byte>, iv: Array<Byte>, pn: Int64,
     ciphertextWithTag: Array<Byte>, aad: Array<Byte>,
     alg: QuicAeadAlgorithm
 ): Array<Byte> {
     quicRequireAeadKeyLength(key, alg)
     match (alg) {
         case Aes128Gcm => let ctx = aesNewGcmContext(key)
              quicAeadAesGcmDecrypt(ctx, iv, pn, ciphertextWithTag, aad)
         case Aes256Gcm => let ctx = aesNewGcmContext(key)
              quicAeadAesGcmDecrypt(ctx, iv, pn, ciphertextWithTag, aad)
         case ChaCha20Poly1305 => let ctx = chacha20Poly1305NewContext(key)
              quicAeadChaCha20Decrypt(ctx, iv, pn, ciphertextWithTag, aad)
     }
 }

 /// QUIC AEAD encrypt with an explicit AES-GCM context.
 /// Returns ciphertext ‖ tag (as on the wire).
 public func quicAeadAesGcmEncrypt(
     ctx: AesGcmContext, iv: Array<Byte>, pn: Int64,
     plaintext: Array<Byte>, aad: Array<Byte>
 ): Array<Byte> {
     let nonce = quicBuildNonce(iv, pn)
     let (ct, tag) = aesGcmEncryptWithContext(ctx, nonce, plaintext, aad: aad)
     let total = ct.size + tag.size
     let out = Array<Byte>(total, repeat: 0)
     secureCopyInto(ct, out)
     secureCopyInto(tag, out, dstOffset: ct.size)
     out
 }

 /// QUIC AEAD decrypt with an explicit AES-GCM context.
 /// Input: ciphertext ‖ tag (as on the wire).
 public func quicAeadAesGcmDecrypt(
     ctx: AesGcmContext, iv: Array<Byte>, pn: Int64,
     ciphertextWithTag: Array<Byte>, aad: Array<Byte>
 ): Array<Byte> {
     if (ciphertextWithTag.size < 16) {
         throw CryptoException(InvalidArgument, "QUIC AEAD ciphertext+tag is too short")
     }
     let nonce = quicBuildNonce(iv, pn)
     let ctLen = ciphertextWithTag.size - 16
     let ct = ciphertextWithTag[..ctLen]
     let tag = ciphertextWithTag[ctLen..]
     aesGcmDecryptWithContext(ctx, nonce, ct, tag, aad: aad)
 }

 /// QUIC AEAD encrypt with an explicit ChaCha20-Poly1305 context.
 /// Returns ciphertext ‖ tag (as on the wire).
 public func quicAeadChaCha20Encrypt(
     ctx: Chacha20Poly1305Context, iv: Array<Byte>, pn: Int64,
     plaintext: Array<Byte>, aad: Array<Byte>
 ): Array<Byte> {
     let nonce = quicBuildNonce(iv, pn)
     let (ct, tag) = chacha20Poly1305EncryptWithContext(ctx, nonce, plaintext, aad: aad)
     let total = ct.size + tag.size
     let out = Array<Byte>(total, repeat: 0)
     secureCopyInto(ct, out)
     secureCopyInto(tag, out, dstOffset: ct.size)
     out
 }

 /// QUIC AEAD decrypt with an explicit ChaCha20-Poly1305 context.
 /// Input: ciphertext ‖ tag (as on the wire).
 public func quicAeadChaCha20Decrypt(
     ctx: Chacha20Poly1305Context, iv: Array<Byte>, pn: Int64,
     ciphertextWithTag: Array<Byte>, aad: Array<Byte>
 ): Array<Byte> {
     if (ciphertextWithTag.size < 16) {
         throw CryptoException(InvalidArgument, "QUIC AEAD ciphertext+tag is too short")
     }
     let nonce = quicBuildNonce(iv, pn)
     let ctLen = ciphertextWithTag.size - 16
     let ct = ciphertextWithTag[..ctLen]
     let tag = ciphertextWithTag[ctLen..]
     chacha20Poly1305DecryptWithContext(ctx, nonce, ct, tag, aad: aad)
 }
