package kem_sample

import jinguissl_core.crypto.kem.{ecdhKemEncapsulate, ecdhKemDecapsulate}
import jinguissl_core.crypto.ecc.{NamedCurve, EcPrivateKey, EcPublicKey, ecPublicFromPrivateKey}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.digest.bytesToHexLower

main() {
    println("===== JinguiSSL Core - KEM Sample =====")

    let p256 = NamedCurve.P256
    let d = BigNum.fromHex("519b423d715f8b581f4fa8ee59f4771a5b44c8130b4e3eacca54a56dda72b464")
    let recipientPriv = EcPrivateKey(p256, d)
    let recipientPub = ecPublicFromPrivateKey(recipientPriv)

    // ECDH-KEM encapsulate (encrypt for public key)
    let (encKey, sharedSecret) = ecdhKemEncapsulate(recipientPub)
    println("KEM enc key len: ${encKey.size}")
    println("KEM shared secret len: ${sharedSecret.size}")
    if (sharedSecret.size <= 0) { throw Exception("KEM shared secret empty") }

    // ECDH-KEM decapsulate (decrypt with private key) - params: (privateKey, encapsulatedKey)
    let decryptedSecret = ecdhKemDecapsulate(recipientPriv, encKey)
    println("KEM shared secret match: ${sharedSecret == decryptedSecret}")
    if (sharedSecret != decryptedSecret) { throw Exception("KEM decapsulate mismatch") }

    println("=== KEM sample passed ===")
}
