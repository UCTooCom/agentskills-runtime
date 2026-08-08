package sample_ed25519
/** ed25519 — Ed25519 签名能力探测 */
import jinguissl.contract.*

main() {
    println("=== Ed25519 Signing Capability Sample ===")

    // 1. Query Ed25519 signing capability
    let ed = contractEd25519SigningCapability()
    println("Ed25519 available: ${ed.available}")
    println("Detail:            ${ed.detail}")
    println()

    // 2. Key material sizes
    println("Seed length:        ${ed.seedLen} bytes")
    println("Public key length:  ${ed.pubKeyLen} bytes")
    println("Signature length:   ${ed.sigLen} bytes")
    println()

    // 3. Try-outcome pattern
    let outcome = contractTryEd25519SigningCapability()
    if (outcome.ok) {
        match (outcome.result) {
            case Some(result) =>
                println("Try-outcome: OK (seed=${result.seedLen}, pub=${result.pubKeyLen}, sig=${result.sigLen})")
            case None =>
                println("Try-outcome: OK (no result — unexpected)")
        }
    } else {
        println("Try-outcome: FAILED — ${outcome.message}")
    }
    println()

    // 4. Require (should succeed)
    try {
        let required = contractRequireEd25519SigningCapability()
        println("Require: PASS (${required.seedLen}-byte seed, ${required.pubKeyLen}-byte pub key)")
    } catch (e: ContractException) {
        println("Require: FAILED — ${e.code.toString()}: ${e.message}")
    }

    println()
    println("Ed25519 capability sample completed.")
}
