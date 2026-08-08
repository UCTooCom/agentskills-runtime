package sample_tls_client

/** tls-client — TLS 1.3 客户端验证会话 (RFC 8446) */
import std.fs.File
import jinguissl.live.*

private let TEST_HOST_WWW: String = "www." + "example.com"

private func hexToBytes(hex: String): Array<Byte> {
    let clean = hex.trimAscii()
    let out = Array<Byte>(clean.size / 2, repeat: 0)
    var i = 0
    while (i < clean.size) {
        let hi = hexNibble(clean[i])
        let lo = hexNibble(clean[i + 1])
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}


private func privateBytesToHex(bytes: Array<Byte>): String {
    let hex = "0123456789abcdef"
    var out = ""
    for (b in bytes) {
        out = "${out}${hex[Int64(b) >> 4 & 0xf]}${hex[Int64(b) & 0xf]}"
    }
    out
}
private func hexNibble(ch: Byte): Int64 {
    if (ch >= b'0' && ch <= b'9') { return Int64(ch - b'0') }
    let lower = if (ch >= b'A' && ch <= b'F') { ch + 32 } else { ch }
    if (lower >= b'a' && lower <= b'f') { return Int64(lower - b'a' + 10) }
    throw Exception("invalid hex char")
}

main() {
    println("=== TLS 1.3 Client Sample ===")

    let serverName = TEST_HOST_WWW
    let leafPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_leaf.pem"))
    let intermediatePem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_intermediate.pem"))
    let rootPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_root.pem"))
    let chainPem = "${leafPem}\n${intermediatePem}"

    // Verify certificate chain
    let verifyResult = contractVerifyServerCertificateChainPem(
        chainPem, rootPem, hostname: serverName
    )
    println("Chain verified: length=${verifyResult.chainLength}")
    println("Leaf subject: ${verifyResult.leafSubjectCommonName}")
    println("Trust anchor: ${verifyResult.trustAnchorCommonName}")

    // Build TLS negotiation policy
    let policy = ContractTlsHttpNegotiationPolicy(
        requireServerName: true,
        allowedServerNames: [serverName],
        alpnPreference: ["h2", "http/1.1"]
    )

    // Build client hello
    let clientKey = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
    let clientHello = contractTls13BuildHttpClientHelloX25519(
        serverName,
        alpnProtocols: ["h2", "http/1.1"],
        clientPrivateKey: Some(clientKey)
    )
    println("Client hello: ${clientHello.encodedClientHello.size} bytes")
    println("Client public key derived: ${privateBytesToHex(clientHello.clientPublicKey)}")

    // Compute leaf pins
    let (derSha256, spkiSha256) = contractComputeLeafPinsFromPem(leafPem)
    println("Leaf DER SHA256: ${privateBytesToHex(derSha256)}")
    println("Leaf SPKI SHA256: ${privateBytesToHex(spkiSha256)}")

    println("TLS client sample completed.")
}
