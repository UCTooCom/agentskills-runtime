package sample_hmac_hkdf
/** hmac-hkdf — HMAC 认证与 HKDF 密钥派生 */
import jinguissl.contract.*

main() {
    println("=== HMAC / HKDF Sample ===")

    // HMAC-SHA256
    let key: Array<Byte> = [0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                             0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
                             0x0b, 0x0b, 0x0b, 0x0b]
    let data = "Hi There".toArray()
    let hmac256 = contractHmac(HashAlgorithm.SHA256, key, data)
    println("HMAC-SHA256: ${contractBytesToHexLower(hmac256)} (${hmac256.size} bytes)")

    // HMAC-SHA512
    let hmac512 = contractHmac(HashAlgorithm.SHA512, key, data)
    println("HMAC-SHA512: ${contractBytesToHexLower(hmac512)} (${hmac512.size} bytes)")

    // HKDF extract-then-expand
    let ikm = "hkdf test input material".toArray()
    let salt = Array<Byte>(32, repeat: 0x01)
    let info = "hkdf context info".toArray()

    let prk = contractHkdfExtract(HashAlgorithm.SHA256, salt, ikm)
    println("HKDF extract PRK: ${contractBytesToHexLower(prk)} (${prk.size} bytes)")

    let okm = contractHkdfExpand(HashAlgorithm.SHA256, prk, info, Int64(48))
    println("HKDF expand OKM:  ${contractBytesToHexLower(okm)} (${okm.size} bytes)")

    // One-shot HKDF
    let fullOkm = contractHkdf(HashAlgorithm.SHA256, ikm, info, Int64(32), salt: salt)
    println("HKDF one-shot:    ${contractBytesToHexLower(fullOkm)} (${fullOkm.size} bytes)")

    println("HMAC/HKDF operations completed.")
}
