package sample_provider_gate

/** provider-gate — 提供商门禁（错误映射、降级决策） */
import jinguissl.contract.*

main() {
    println("=== Provider Gate Sample ===")

    // Provider capability record
    let cap = contractProviderCapabilityRecord()
    println("Provider: ${cap.providerId} v${cap.providerVersion}")
    println("  supports client TLS: ${cap.supportsClientTls}")
    println("  supports server attach: ${cap.supportsServerTlsAttach}")
    println("  default eligible: ${cap.defaultEligible}")

    // Provider attach contract info
    let info = contractProviderAttachContractInfo()
    println("Attach contract info:")
    println("  supports TLS precheck: ${info.supportsTlsPrecheck}")
    println("  precheck inputs: ${info.tlsPrecheckInputs}")

    // Error mapping
    let mapped = contractMapToIgniteCryptoErrorCode(ContractErrorCode.VerifyFailed)
    println("Error mapping: VerifyFailed -> ${mapped.toString()}")

    // Describe a provider error
    let desc = contractDescribeProviderErrorCode(
        ContractErrorCode.CryptoUnavailable,
        phase: ContractProviderErrorPhase.TlsHandshake,
        detail: "AES-NI not available on this CPU"
    )
    println("Error descriptor:")
    println("  family: ${desc.family.toString()}")
    println("  phase: ${desc.phase.toString()}")
    println("  retryable: ${desc.retryable}")
    println("  fallbackSuggested: ${desc.fallbackSuggested}")

    // Fallback decision (pass the descriptor)
    let decision = contractRecommendProviderFallback(desc)
    println("Fallback decision: suggested=${decision.fallbackSuggested}, target=${decision.fallbackTarget}")
    println("  retryable=${decision.retryable}, mustSurface=${decision.mustSurface}")

    println("Provider gate sample completed.")
}
