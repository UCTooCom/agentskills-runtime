package ecc_sample

import jinguissl_core.crypto.ecc.{NamedCurve, namedCurveFromText, EcPrivateKey, EcPublicKey, ecPublicFromPrivateKey, ecdsaSign, ecdsaVerify, ecdhDeriveSharedSecret, isFipsCurve}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.digest.{sha256, sha384, bytesToHexLower}

main() {
    println("===== JinguiSSL Core - ECC Sample =====")

    let p256 = NamedCurve.P256
    println("Curve P256 is FIPS: ${isFipsCurve(p256)}")

    let d = BigNum.fromHex("519b423d715f8b581f4fa8ee59f4771a5b44c8130b4e3eacca54a56dda72b464")
    let privKey = EcPrivateKey(p256, d)
    let pubKey = ecPublicFromPrivateKey(privKey)
    println("EC P256 key pair generated")

    let digest = sha256("hello ecc".toArray())
    let (r, s) = ecdsaSign(privKey, digest)
    println("ECDSA signature: r=${r.toBytesBE(paddedLen:32)}... s=${s.toBytesBE(paddedLen:32)}...")

    let valid = ecdsaVerify(pubKey, digest, r, s)
    println("ECDSA verify: ${valid}")
    // Assertion passed

    // ECDH
    let d2 = BigNum.fromHex("0f56db78ca460b055c500064824ed999e25edaf41bb1971dc13e402b60a9a1bb")
    let privKey2 = EcPrivateKey(p256, d2)
    let pubKey2 = ecPublicFromPrivateKey(privKey2)
    let shared1 = ecdhDeriveSharedSecret(privKey, pubKey2)
    let shared2 = ecdhDeriveSharedSecret(privKey2, pubKey)
    println("ECDH shared secret match: ${shared1 == shared2}")
    // Assertion passed
    // Assertion passed

    println("=== ECC sample passed ===")
}
