package sample_kem
/** kem — KEM（密钥封装机制）能力探测 */
import jinguissl.contract.*

main() {
    println("=== KEM Profile Probe Sample ===")
    println("(KEM is a post-quantum reserve — no active product roadmap)")
    println()

    // 1. Query KEM profile
    let kem = contractKemProfile()
    println("KEM available: ${kem.available}")
    println("Algorithm:     ${kem.algoHint}")
    println("Detail:        ${kem.detail}")
    println()

    // 2. Try-outcome pattern
    let outcome = contractTryKemProfile()
    if (outcome.ok) {
        match (outcome.result) {
            case Some(result) =>
                println("Try-outcome: OK (algo=${result.algoHint}, available=${result.available})")
            case None =>
                println("Try-outcome: OK (no result — unexpected)")
        }
    } else {
        println("Try-outcome: FAILED — ${outcome.message}")
        match (outcome.code) {
            case Some(code) =>
                println("  code:       ${code.toString()}")
            case None => ()
        }
    }

    println()
    println("KEM profile sample completed.")
}
