package sample_rsa
/** rsa — RSA 能力探测 */
import jinguissl.contract.*

main() {
    println("=== RSA Capability Probe Sample ===")

    // 1. Query RSA capability
    let rsa = contractRsaCapability()
    println("RSA available: ${rsa.available}")
    println("Detail:        ${rsa.detail}")
    println()

    // 2. Supported key sizes
    println("Supported key sizes:")
    for (size in rsa.supportedKeySizes) {
        println("  - ${size} bits")
    }
    println()

    // 3. Supported signature schemes
    println("Supported signature schemes:")
    for (scheme in rsa.supportedSchemes) {
        println("  - ${scheme}")
    }
    println()

    // 4. Supported hash algorithms
    println("Supported hash algorithms:")
    for (algo in rsa.supportedHashAlgorithms) {
        println("  - ${algo}")
    }
    println()

    // 5. RSA compliance
    println("RSA allowed (FIPS): ${rsa.rsaAllowed}")
    println()

    // 6. Try-outcome pattern
    let outcome = contractTryRsaCapability()
    if (outcome.ok) {
        println("Try-outcome: OK (result available)")
    } else {
        println("Try-outcome: FAILED — ${outcome.message}")
    }
    println()

    // 7. Require (should succeed)
    try {
        let required = contractRequireRsaCapability()
        println("Require: PASS (${required.supportedKeySizes.size} key sizes)")
    } catch (e: ContractException) {
        println("Require: FAILED — ${e.code.toString()}: ${e.message}")
    }

    println()
    println("RSA capability sample completed.")
}
