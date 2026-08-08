package sample_digest
/** digest — SHA-256/384/512 摘要、HMAC、HKDF */
import jinguissl.contract.*

main() {
    println("=== Digest / HMAC / HKDF Sample ===")

    // SHA-256 digest
    let data = "hello jingui".toArray()
    let sha256Digest = contractSha256(data)
    println("SHA-256: ${contractBytesToHexLower(sha256Digest)}")

    // SHA-384 digest
    let sha384Digest = contractSha384(data)
    println("SHA-384: ${contractBytesToHexLower(sha384Digest)}")

    // SHA-512 digest
    let sha512Digest = contractSha512(data)
    println("SHA-512: ${contractBytesToHexLower(sha512Digest)}")

    // HMAC-SHA256
    let key: Array<Byte> = [0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                             0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b]
    let hmacResult = contractHmac(HashAlgorithm.SHA256, key, data)
    println("HMAC-SHA256: ${contractBytesToHexLower(hmacResult)}")

    // HKDF derive
    let ikm = Array<Byte>(22, repeat: 0x0b)
    let salt = Array<Byte>(32, repeat: 0x01)
    let info = Array<Byte>(10, repeat: 0xf0)
    let okm = contractHkdf(HashAlgorithm.SHA256, ikm, info, 32, salt: salt)
    println("HKDF-SHA256 OKM(32): ${contractBytesToHexLower(okm)}")

    println("All digest operations completed.")
}
