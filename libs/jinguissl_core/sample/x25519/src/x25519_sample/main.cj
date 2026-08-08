package x25519_sample

import jinguissl_core.crypto.x25519.{x25519GeneratePrivateKey, x25519PublicFromPrivate, x25519DeriveSharedSecret, X25519_KEY_LEN}
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - X25519 Sample =====")

    let alicePriv = x25519GeneratePrivateKey()
    let alicePub = x25519PublicFromPrivate(alicePriv)
    println("Alice pub: ${bytesToHexLower(alicePub)} (${alicePub.size} bytes)")
    if (alicePub.size != X25519_KEY_LEN) { throw Exception("Alice public key length wrong") }

    let bobPriv = x25519GeneratePrivateKey()
    let bobPub = x25519PublicFromPrivate(bobPriv)
    println("Bob pub:   ${bytesToHexLower(bobPub)} (${bobPub.size} bytes)")

    let aliceShared = x25519DeriveSharedSecret(alicePriv, bobPub)
    let bobShared = x25519DeriveSharedSecret(bobPriv, alicePub)
    println("Shared secret match: ${aliceShared == bobShared}")
    if (aliceShared != bobShared) { throw Exception("X25519 shared secret mismatch") }
    if (aliceShared.size != 32) { throw Exception("Shared secret length wrong") }

    let alicePub2 = x25519PublicFromPrivate(alicePriv)
    println("Deterministic key derivation: ${alicePub == alicePub2}")
    if (alicePub != alicePub2) { throw Exception("Key derivation not deterministic") }

    println("=== X25519 sample passed ===")
}
