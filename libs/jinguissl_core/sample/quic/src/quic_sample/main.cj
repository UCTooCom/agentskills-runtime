package quic_sample

import jinguissl_core.crypto.quic.{quicAeadEncrypt, quicAeadDecrypt, quicAeadAesGcmEncrypt, quicAeadAesGcmDecrypt, quicAeadChaCha20Encrypt, quicAeadChaCha20Decrypt, QuicAeadAlgorithm}
import jinguissl_core.crypto.aes.{aesNewGcmContext}
import jinguissl_core.crypto.chacha20.{chacha20Poly1305NewContext}
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - QUIC AEAD Sample =====")

    let iv: Array<Byte> = [
        UInt8(0xfa), UInt8(0x04), UInt8(0x4b), UInt8(0x2f),
        UInt8(0x42), UInt8(0xa3), UInt8(0xfd), UInt8(0x3b),
        UInt8(0x46), UInt8(0xfb), UInt8(0x25), UInt8(0x5c)
    ]
    let plaintext = "hello quic aead".toArray()
    let aad = "quic-aad".toArray()

    // ── AES-128-GCM ──────────────────────────────────────────────
    let key128: Array<Byte> = [
        UInt8(0x1f), UInt8(0x36), UInt8(0x96), UInt8(0x13),
        UInt8(0xdd), UInt8(0x76), UInt8(0xd5), UInt8(0x46),
        UInt8(0x77), UInt8(0x30), UInt8(0xef), UInt8(0xcb),
        UInt8(0xe3), UInt8(0xb1), UInt8(0xa2), UInt8(0x2d)
    ]

    println("--- AES-128-GCM (convenience API) ---")
    let ct128 = quicAeadEncrypt(key128, iv, 0, plaintext, aad, QuicAeadAlgorithm.Aes128Gcm)
    let pt128 = quicAeadDecrypt(key128, iv, 0, ct128, aad, QuicAeadAlgorithm.Aes128Gcm)
    println("  roundtrip: ${pt128 == plaintext}")
    if (pt128 != plaintext) { throw Exception("AES-128-GCM convenience roundtrip failed") }

    println("--- AES-128-GCM (context API) ---")
    let ctx128 = aesNewGcmContext(key128)
    let ct128c = quicAeadAesGcmEncrypt(ctx128, iv, 1, plaintext, aad)
    let pt128c = quicAeadAesGcmDecrypt(ctx128, iv, 1, ct128c, aad)
    println("  roundtrip: ${pt128c == plaintext}")
    if (pt128c != plaintext) { throw Exception("AES-128-GCM context roundtrip failed") }

    // ── AES-256-GCM ──────────────────────────────────────────────
    let key256: Array<Byte> = [
        UInt8(0x00), UInt8(0x01), UInt8(0x02), UInt8(0x03),
        UInt8(0x04), UInt8(0x05), UInt8(0x06), UInt8(0x07),
        UInt8(0x08), UInt8(0x09), UInt8(0x0a), UInt8(0x0b),
        UInt8(0x0c), UInt8(0x0d), UInt8(0x0e), UInt8(0x0f),
        UInt8(0x10), UInt8(0x11), UInt8(0x12), UInt8(0x13),
        UInt8(0x14), UInt8(0x15), UInt8(0x16), UInt8(0x17),
        UInt8(0x18), UInt8(0x19), UInt8(0x1a), UInt8(0x1b),
        UInt8(0x1c), UInt8(0x1d), UInt8(0x1e), UInt8(0x1f)
    ]

    println("--- AES-256-GCM (convenience API) ---")
    let ct256 = quicAeadEncrypt(key256, iv, 0, plaintext, aad, QuicAeadAlgorithm.Aes256Gcm)
    let pt256 = quicAeadDecrypt(key256, iv, 0, ct256, aad, QuicAeadAlgorithm.Aes256Gcm)
    println("  roundtrip: ${pt256 == plaintext}")
    if (pt256 != plaintext) { throw Exception("AES-256-GCM convenience roundtrip failed") }

    println("--- AES-256-GCM (context API) ---")
    let ctx256 = aesNewGcmContext(key256)
    let ct256c = quicAeadAesGcmEncrypt(ctx256, iv, 1, plaintext, aad)
    let pt256c = quicAeadAesGcmDecrypt(ctx256, iv, 1, ct256c, aad)
    println("  roundtrip: ${pt256c == plaintext}")
    if (pt256c != plaintext) { throw Exception("AES-256-GCM context roundtrip failed") }

    // ── ChaCha20-Poly1305 ────────────────────────────────────────
    let keyChacha: Array<Byte> = [
        UInt8(0x80), UInt8(0x81), UInt8(0x82), UInt8(0x83),
        UInt8(0x84), UInt8(0x85), UInt8(0x86), UInt8(0x87),
        UInt8(0x88), UInt8(0x89), UInt8(0x8a), UInt8(0x8b),
        UInt8(0x8c), UInt8(0x8d), UInt8(0x8e), UInt8(0x8f),
        UInt8(0x90), UInt8(0x91), UInt8(0x92), UInt8(0x93),
        UInt8(0x94), UInt8(0x95), UInt8(0x96), UInt8(0x97),
        UInt8(0x98), UInt8(0x99), UInt8(0x9a), UInt8(0x9b),
        UInt8(0x9c), UInt8(0x9d), UInt8(0x9e), UInt8(0x9f)
    ]

    println("--- ChaCha20-Poly1305 (convenience API) ---")
    let ctChacha = quicAeadEncrypt(keyChacha, iv, 0, plaintext, aad, QuicAeadAlgorithm.ChaCha20Poly1305)
    let ptChacha = quicAeadDecrypt(keyChacha, iv, 0, ctChacha, aad, QuicAeadAlgorithm.ChaCha20Poly1305)
    println("  roundtrip: ${ptChacha == plaintext}")
    if (ptChacha != plaintext) { throw Exception("ChaCha20-Poly1305 convenience roundtrip failed") }

    println("--- ChaCha20-Poly1305 (context API) ---")
    let ctxChacha = chacha20Poly1305NewContext(keyChacha)
    let ctChachaC = quicAeadChaCha20Encrypt(ctxChacha, iv, 1, plaintext, aad)
    let ptChachaC = quicAeadChaCha20Decrypt(ctxChacha, iv, 1, ctChachaC, aad)
    println("  roundtrip: ${ptChachaC == plaintext}")
    if (ptChachaC != plaintext) { throw Exception("ChaCha20-Poly1305 context roundtrip failed") }

    // ── Algorithm enum demonstration ─────────────────────────────
    println("--- Algorithm Enum ---")
    println("  ${QuicAeadAlgorithm.Aes128Gcm}")
    println("  ${QuicAeadAlgorithm.Aes256Gcm}")
    println("  ${QuicAeadAlgorithm.ChaCha20Poly1305}")

    println("=== QUIC AEAD sample passed ===")
}
