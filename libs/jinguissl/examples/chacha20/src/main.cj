package sample_chacha20
/** chacha20 — ChaCha20-Poly1305 AEAD 加解密 (RFC 8439) */
import jinguissl.contract.*

main() {
    println("=== ChaCha20-Poly1305 AEAD Sample ===")

    // Algorithm name
    let algo = contractChacha20Poly1305AlgorithmName()
    println("Algorithm: ${algo}")
    println("Key length: ${CHACHA20_KEY_LEN} bytes")
    println("Nonce length: ${CHACHA20_NONCE_LEN} bytes")
    println("Tag length: ${CHACHA20_POLY1305_TAG_LEN} bytes")

    // AEAD encrypt
    let key = Array<Byte>(32, repeat: 0x10)
    let nonce = Array<Byte>(12, repeat: 0x20)
    let plaintext = "Hello, JinguiSSL ChaCha20-Poly1305!".toArray()
    let aad = "aad-data".toArray()

    let (ciphertext, tag) = contractChacha20Poly1305Encrypt(key, nonce, plaintext, aad: aad)
    println("Plaintext:  ${String.fromUtf8(plaintext)}")
    println("Ciphertext: ${contractBytesToHexLower(ciphertext)}")
    println("Auth tag:   ${contractBytesToHexLower(tag)}")

    // AEAD decrypt
    let opened = contractChacha20Poly1305Decrypt(key, nonce, ciphertext, tag, aad: aad)
    println("Decrypted:  ${String.fromUtf8(opened)}")

    // Verify round-trip
    if (opened == plaintext) {
        println("SUCCESS: Round-trip encryption/decryption works.")
    } else {
        println("FAIL: Decrypted text does not match original.")
    }
}
