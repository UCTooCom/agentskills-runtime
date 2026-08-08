package sample_x25519
/** x25519 — X25519 密钥对生成与密钥协商 (RFC 7748) */
import jinguissl.contract.*

main() {
    println("=== X25519 Key Agreement Sample ===")

    // Generate key pair
    let alicePair = contractX25519GenerateKeyPair()
    let bobPair = contractX25519GenerateKeyPair()
    println("Alice public key: ${contractBytesToHexLower(alicePair.publicKey)}")
    println("Bob public key:   ${contractBytesToHexLower(bobPair.publicKey)}")

    // Derive shared secrets
    let aliceResult = contractX25519DeriveKeyAgreement(alicePair.privateKey, bobPair.publicKey)
    let bobResult = contractX25519DeriveKeyAgreement(bobPair.privateKey, alicePair.publicKey)
    println("Alice shared secret: ${contractBytesToHexLower(aliceResult.sharedSecret)}")
    println("Bob shared secret:   ${contractBytesToHexLower(bobResult.sharedSecret)}")

    // Verify both sides agree
    if (aliceResult.sharedSecret == bobResult.sharedSecret) {
        println("SUCCESS: Shared secrets match (${CONTRACT_X25519_ALGORITHM}).")
    } else {
        println("FAIL: Shared secrets do not match.")
    }

    // Try-outcome API
    let outcome = contractTryX25519DeriveKeyAgreement(alicePair.privateKey, bobPair.publicKey)
    if (outcome.ok) {
        println("Try-outcome: OK — shared secret established.")
    }
}
