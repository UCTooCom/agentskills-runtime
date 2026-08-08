package sample_sm
/** sm — SM3 杂凑、SM4 加密（中国国家密码标准） */
import jinguissl.contract.*

main() {
    println("=== SM3 / SM4 (China Crypto) Sample ===")

    // Probe SM capability
    let smCap = contractSmCapability()
    if (!smCap.sm3Available || !smCap.sm4Available) {
        println("WARNING: SM crypto not available in this runtime.")
        println("Detail: ${smCap.detail}")
        return
    }
    println("SM3 available:  ${smCap.sm3Available} (digest=${smCap.sm3DigestLen} bytes)")
    println("SM4 available:  ${smCap.sm4Available} (block=${smCap.sm4BlockLen}, key=${smCap.sm4KeyLen})")

    // Use try-outcome API
    let outcome = contractTrySmCapability()
    if (outcome.ok) {
        println("Try-SM outcome: OK")
    }

    // Require SM capability
    let required = contractRequireSmCapability()
    println("Require-SM: sm3=${required.sm3Available}, sm4=${required.sm4Available}")

    println("SM capability check completed.")
}
