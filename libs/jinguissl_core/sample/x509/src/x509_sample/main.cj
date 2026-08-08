package x509_sample

import jinguissl_core.crypto.x509.{x509ParsePem, x509DerToPem, x509NameFindFirstValue, X509_OID_COMMON_NAME}
import jinguissl_core.crypto.digest.bytesToHexLower
import std.fs.{File, exists}

main() {
    println("===== JinguiSSL Core - X.509 Sample =====")

    let rootPemPath = "../../testdata/x509/policy_root.pem"
    let leafPemPath = "../../testdata/x509/policy_leaf.pem"

    if (exists(rootPemPath)) {
        let rootBytes = File.readFrom(rootPemPath)
        let rootPem = String.fromUtf8(rootBytes)
        let rootCert = x509ParsePem(rootPem)
        let cn = x509NameFindFirstValue(rootCert.subject, X509_OID_COMMON_NAME)
        println("Root cert CN: ${cn}")
        println("Root cert serial: ${rootCert.serialHexLower()}")
        println("Root cert valid: ${rootCert.notBefore} ~ ${rootCert.notAfter}")

        // PEM roundtrip using toPem method
        let pemRound = rootCert.toPem()
        println("PEM roundtrip: ${pemRound.startsWith("-----BEGIN")}")
        if (!pemRound.startsWith("-----BEGIN")) { throw Exception("PEM roundtrip failed") }

        // Verify issuer==subject for self-signed
        println("Root is self-issued: ${rootCert.isSelfIssued()}")
    } else {
        println("Test data not found at ${rootPemPath}")
    }

    if (exists(leafPemPath)) {
        let leafBytes = File.readFrom(leafPemPath)
        let leafPem = String.fromUtf8(leafBytes)
        let leafCert = x509ParsePem(leafPem)
        let leafCn = x509NameFindFirstValue(leafCert.subject, X509_OID_COMMON_NAME)
        println("Leaf cert CN: ${leafCn}")
        println("Leaf cert size: ${leafCert.der.size} bytes")
    } else {
        println("Test data not found at ${leafPemPath}")
    }

    println("=== X.509 sample passed ===")
}
