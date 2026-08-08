package digest_sample

import jinguissl_core.crypto.digest.{HashAlgorithm, md5, sha1, sha256, sha384, sha512, hash, hmac, hkdf, hkdfExtract, hkdfExpand, bytesToHexLower}

main() {
    println("===== JinguiSSL Core - Digest Sample =====")

    let data = "Hello JinguiSSL".toArray()

    let md5Hash = md5(data)
    println("MD5(${data.size} bytes): ${bytesToHexLower(md5Hash)} (len=${md5Hash.size})")
    if (md5Hash.size != 16) { throw Exception("MD5 output length wrong") }

    let sha256Hash = sha256(data)
    println("SHA-256: ${bytesToHexLower(sha256Hash)} (len=${sha256Hash.size})")
    if (sha256Hash.size != 32) { throw Exception("SHA-256 output length wrong") }

    let sha512Hash = sha512(data)
    println("SHA-512: ${bytesToHexLower(sha512Hash)} (len=${sha512Hash.size})")
    if (sha512Hash.size != 64) { throw Exception("SHA-512 output length wrong") }

    let generic = hash(HashAlgorithm.SHA256, data)
    if (generic != sha256Hash) { throw Exception("Generic hash mismatch") }
    println("Generic hash matches: true")

    // HMAC
    let hmacResult = hmac(HashAlgorithm.SHA256, "key".toArray(), data)
    println("HMAC-SHA256: ${bytesToHexLower(hmacResult)} (len=${hmacResult.size})")
    if (hmacResult.size != 32) { throw Exception("HMAC output length wrong") }

    // HKDF - salt is named, params: (algorithm, ikm, info, outputLen, salt!)
    let ikm = "ikm".toArray()
    let salt = "salt".toArray()
    let info = "info".toArray()
    let hkdfResult = hkdf(HashAlgorithm.SHA256, ikm, info, 16, salt: salt)
    println("HKDF-SHA256(16): ${bytesToHexLower(hkdfResult)} (len=${hkdfResult.size})")
    if (hkdfResult.size != 16) { throw Exception("HKDF output length wrong") }

    // HKDF extract: (algorithm, salt, ikm)
    let prk = hkdfExtract(HashAlgorithm.SHA256, salt, ikm)
    let expanded = hkdfExpand(HashAlgorithm.SHA256, prk, info, 32)
    println("HKDF expand(32): ${bytesToHexLower(expanded)} (len=${expanded.size})")
    if (expanded.size != 32) { throw Exception("HKDF expand length wrong") }

    println("=== Digest sample passed ===")
}
