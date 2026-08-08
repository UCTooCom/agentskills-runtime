package rsa_sample

import jinguissl_core.crypto.rsa.{rsaGenerateKey, rsaSignPkcs1v15, rsaVerifyPkcs1v15, rsaSignPkcs1v15WithHash, rsaVerifyPkcs1v15WithHash, rsaSignPss, rsaVerifyPss, RsaHashAlgorithm}
import jinguissl_core.crypto.digest.{sha256, bytesToHexLower}

main() {
    println("===== JinguiSSL Core - RSA Sample =====")

    let privKey = rsaGenerateKey(2048)
    let pubKey = privKey.publicKey
    println("RSA 2048-bit key pair generated")

    let msg = "RSA test".toArray()
    let digest = sha256(msg)

    // PKCS1v1.5 (takes pre-hashed digest)
    let sig1 = rsaSignPkcs1v15(privKey, digest)
    let valid1 = rsaVerifyPkcs1v15(pubKey, digest, sig1)
    println("PKCS1v1.5 valid: ${valid1}")
    if (!valid1) { throw Exception("PKCS1v1.5 sign/verify failed") }

    // PKCS1v1.5 with hash OID
    let sig2 = rsaSignPkcs1v15WithHash(privKey, digest, RsaHashAlgorithm.SHA256)
    let valid2 = rsaVerifyPkcs1v15WithHash(pubKey, digest, sig2, RsaHashAlgorithm.SHA256)
    println("PKCS1v1.5 w/hash valid: ${valid2}")
    if (!valid2) { throw Exception("PKCS1v1.5 with hash sign/verify failed") }

    // PSS (takes pre-hashed digest, saltLen is named)
    let sig3 = rsaSignPss(privKey, digest)
    let valid3 = rsaVerifyPss(pubKey, digest, sig3)
    println("PSS valid: ${valid3}")
    if (!valid3) { throw Exception("PSS sign/verify failed") }

    println("=== RSA sample passed ===")
}
