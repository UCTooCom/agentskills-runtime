package sample_x509
/** x509 — X.509 证书链验证与指纹计算 */
import std.fs.File
import jinguissl.contract.*

main() {
    println("=== X.509 Certificate Verification Sample ===")

    // Read test certificates
    let leafPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_leaf.pem"))
    let intermediatePem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_intermediate.pem"))
    let rootPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_root.pem"))
    let chainPem = "${leafPem}\n${intermediatePem}"

    // Compute leaf certificate pins
    let (derSha256, spkiSha256) = contractComputeLeafPinsFromPem(leafPem)
    println("Leaf DER SHA-256:  ${contractBytesToHexLower(derSha256)}")
    println("Leaf SPKI SHA-256: ${contractBytesToHexLower(spkiSha256)}")

    // Verify certificate chain
    let verifyResult = contractVerifyServerCertificatePem(
        leafPem,
        rootPem,
        intermediatesPemBundle: intermediatePem,
        hostname: "www.example.com"
    )
    println("Chain length: ${verifyResult.chainLength}")
    println("Leaf subject: ${verifyResult.leafSubjectCommonName}")
    println("Trust anchor: ${verifyResult.trustAnchorCommonName}")

    if (verifyResult.chainLength >= 2) {
        println("SUCCESS: Certificate chain verified.")
    } else {
        println("FAIL: Chain verification failed.")
    }
}
