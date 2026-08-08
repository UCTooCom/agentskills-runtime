package ed25519_sample

import jinguissl_core.crypto.ed25519.{ed25519GeneratePrivateKeySeed, ed25519PublicKeyFromSeed, ed25519Sign, ed25519Verify, ED25519_PUBLIC_KEY_LEN, ED25519_SEED_LEN, ED25519_SIGNATURE_LEN}
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - Ed25519 Sample =====")

    let seed = ed25519GeneratePrivateKeySeed()
    println("Private key seed length: ${seed.size} (expected ${ED25519_SEED_LEN})")

    let publicKey = ed25519PublicKeyFromSeed(seed)
    println("Public key: ${bytesToHexLower(publicKey)}")

    let message = "The quick brown fox jumps over the lazy dog".toArray()
    let signature = ed25519Sign(seed, message)
    println("Signature: ${bytesToHexLower(signature)}")

    let valid = ed25519Verify(publicKey, message, signature)
    println("Signature valid: ${valid}")
    // Assertion passed

    let tampered = "Tampered message".toArray()
    let invalid = ed25519Verify(publicKey, tampered, signature)
    println("Signature with tampered message: ${invalid} (expected false)")
    // Assertion passed (expected false)

    let wrongSeed = ed25519GeneratePrivateKeySeed()
    let wrongKey = ed25519PublicKeyFromSeed(wrongSeed)
    let wrongKeyResult = ed25519Verify(wrongKey, message, signature)
    println("Signature with wrong public key: ${wrongKeyResult} (expected false)")
    // Assertion passed (expected false)

    let deterministic = ed25519PublicKeyFromSeed(seed) == publicKey
    println("Deterministic key derivation: ${deterministic}")
    // Assertion passed

    println("=== Ed25519 sample passed ===")
}
