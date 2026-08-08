package sample_ecc
/** ecc — ECC 能力探测（椭圆曲线密码学） */
import jinguissl.contract.*

main() {
    println("=== ECC Capability Probe Sample ===")

    // 1. Query ECC capability
    let ecc = contractEccCapability()
    println("ECC available: ${ecc.available}")
    println("Detail:        ${ecc.detail}")
    println()

    // 2. Supported curves
    println("Supported curves:")
    for (curve in ecc.supportedCurves) {
        println("  - ${curve}")
    }
    println()

    // 3. FIPS curves
    println("FIPS-approved curves:")
    for (curve in ecc.fipsCurves) {
        println("  - ${curve}")
    }
    println()

    // 4. ECDSA / ECDH status
    println("ECDSA allowed:  ${ecc.ecdsaAllowed}")
    println("ECDH allowed:   ${ecc.ecdhAllowed}")
    println()

    // 5. Try-outcome pattern
    let outcome = contractTryEccCapability()
    if (outcome.ok) {
        println("Try-outcome: OK (result available)")
    } else {
        println("Try-outcome: FAILED — ${outcome.message}")
    }
    println()

    // 6. Require (should succeed)
    try {
        let required = contractRequireEccCapability()
        println("Require: PASS (${required.supportedCurves.size} curves available)")
    } catch (e: ContractException) {
        println("Require: FAILED — ${e.code.toString()}: ${e.message}")
    }

    println()
    println("ECC capability sample completed.")
}
