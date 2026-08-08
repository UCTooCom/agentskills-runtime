package chacha20_sample

import jinguissl_core.crypto.chacha20.{chacha20Block, chacha20Xor, chacha20Poly1305Encrypt, chacha20Poly1305Decrypt, chacha20Poly1305NewContext, chacha20Poly1305EncryptWithContext, chacha20Poly1305DecryptWithContext, poly1305Mac, CHACHA20_KEY_LEN, CHACHA20_NONCE_LEN, CHACHA20_BLOCK_LEN, POLY1305_TAG_LEN}
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - ChaCha20-Poly1305 Sample =====")

    let key = Array<Byte>(CHACHA20_KEY_LEN, repeat: UInt8(0x00))
    let nonce = Array<Byte>(CHACHA20_NONCE_LEN, repeat: UInt8(0x00))

    // ChaCha20 block generation
    let block = chacha20Block(key, 0, nonce)
    println("ChaCha20 block[0] len: ${block.size}")
    if (block.size != CHACHA20_BLOCK_LEN) { throw Exception("ChaCha20 block size wrong") }

    // ChaCha20 XOR (initialCounter is named)
    let msg = "ChaCha20 stream test".toArray()
    let ct = chacha20Xor(key, nonce, msg, initialCounter: 0)
    let pt = chacha20Xor(key, nonce, ct, initialCounter: 0)
    println("Stream XOR roundtrip: ${pt == msg}")
    if (pt != msg) { throw Exception("ChaCha20 XOR roundtrip failed") }

    // ChaCha20-Poly1305 AEAD (aad is named, decrypt returns Array<Byte>)
    let aadData = "aad".toArray()
    let (cipher, tag) = chacha20Poly1305Encrypt(key, nonce, msg, aad: aadData)
    let dec = chacha20Poly1305Decrypt(key, nonce, cipher, tag, aad: aadData)
    println("AEAD roundtrip: ${dec == msg}")
    if (tag.size != POLY1305_TAG_LEN) { throw Exception("Tag length wrong") }
    if (dec != msg) { throw Exception("ChaCha20-Poly1305 roundtrip failed") }

    // With context
    let ctx = chacha20Poly1305NewContext(key)
    let (cipherCtx, tagCtx) = chacha20Poly1305EncryptWithContext(ctx, nonce, msg, aad: aadData)
    let decCtx = chacha20Poly1305DecryptWithContext(ctx, nonce, cipherCtx, tagCtx, aad: aadData)
    println("Context AEAD roundtrip: ${decCtx == msg}")
    if (decCtx != msg) { throw Exception("ChaCha20-Poly1305 context roundtrip failed") }

    println("=== ChaCha20 sample passed ===")
}
