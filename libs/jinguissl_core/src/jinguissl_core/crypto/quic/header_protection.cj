 package jinguissl_core.crypto.quic

 import jinguissl_core.crypto.aes.aesBlockEncrypt
 import jinguissl_core.crypto.chacha20.chacha20Block
 import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

 // ── AES-based header protection ──────────────────────────────────
 //
 // RFC 9001 §5.4.1: mask = AES-ECB(hp_key, sample)
 // The mask is a full 16-byte block.
 //
 // Returns (first_byte_mask, pn_mask_bytes) where:
 //   - first_byte_mask = mask[0] (to be AND-masked with 0x0f / 0x1f then XOR'd into header[0])
 //   - pn_mask_bytes   = mask[1..16] up to 15 bytes for PN encoding
 public func quicHpAesEncrypt(sample: Array<Byte>, key: Array<Byte>): (Byte, Array<Byte>) {
     if (sample.size != 16) {
         throw CryptoException(InvalidArgument, "QUIC AES HP sample must be 16 bytes")
     }
     let mask = aesBlockEncrypt(key, sample)
     let pnMask = mask[1..]
     (mask[0], pnMask)
 }

 // ── ChaCha20-based header protection ─────────────────────────────
 //
 // RFC 9001 §5.4.2: mask = ChaCha20(hp_key, counter, nonce)
 // where counter = sample[0..4] (little-endian UInt32)
 //       nonce   = sample[4..16] (12 bytes)
 //
 // Returns (first_byte_mask, [mask[1..5]]) — 5-byte mask total.
 public func quicHpChaChaEncrypt(sample: Array<Byte>, key: Array<Byte>): (Byte, Array<Byte>) {
     if (sample.size != 16) {
         throw CryptoException(InvalidArgument, "QUIC ChaCha HP sample must be 16 bytes")
     }
     let counter = decodeUInt32LE(sample, 0)
     let nonce = sample[4..16]
     let block = chacha20Block(key, Int64(counter), nonce)
     (block[0], block[1..5])
 }

 // ── Internal helpers ─────────────────────────────────────────────

 private func decodeUInt32LE(bytes: Array<Byte>, offset: Int64): UInt32 {
     if (offset < 0 || offset + 4 > bytes.size) {
         throw CryptoException(OutOfBounds, "uint32 LE decode out of bounds")
     }
     UInt32(UInt8(bytes[offset])) |
         (UInt32(UInt8(bytes[offset + 1])) << 8) |
         (UInt32(UInt8(bytes[offset + 2])) << 16) |
         (UInt32(UInt8(bytes[offset + 3])) << 24)
 }
