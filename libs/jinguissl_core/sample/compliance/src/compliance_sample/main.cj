package compliance_sample

import jinguissl_core.crypto.compliance.{FipsProfile, TlsVersion, TLS_VERSION_1_2, TLS_VERSION_1_3}

main() {
    println("===== JinguiSSL Core - Compliance Sample =====")

    let defaultProfile = FipsProfile.phase1Default()
    println("FIPS phase1 default profile created")

    // Check that allowed algorithms pass
    try {
        defaultProfile.requireAllowed("SHA-256")
        println("SHA-256 allowed by default profile: true")
    } catch (_: Exception) {
        println("SHA-256 allowed by default profile: false (unexpected)")
    }

    // TLS versions
    println("TLS 1.2: ${TLS_VERSION_1_2}")
    println("TLS 1.3: ${TLS_VERSION_1_3}")

    // Custom profile from text
    let customText = "SHA-256\nAES-GCM\n# comment\nTLS1.3"
    let customProfile = FipsProfile.fromText(customText)
    println("Custom profile from text created")

    try {
        customProfile.requireAllowed("SHA-256")
        println("SHA-256 allowed by custom profile: true")
    } catch (_: Exception) {
        println("SHA-256 allowed by custom profile: false (unexpected)")
    }

    try {
        customProfile.requireAllowed("MD5")
        println("MD5 allowed by custom profile: true (unexpected)")
    } catch (_: Exception) {
        println("MD5 rejected by custom profile: true (expected)")
    }

    println("=== Compliance sample passed ===")
}
