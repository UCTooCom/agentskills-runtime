package sample_tls_server

/** tls-server — TLS 1.3 服务端 Accepted Transport (RFC 8446) */
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

private func hexNibble(ch: Byte): Int64 {
    if (ch >= b'0' && ch <= b'9') { return Int64(ch - b'0') }
    let lower = if (ch >= b'A' && ch <= b'F') { ch + 32 } else { ch }
    if (lower >= b'a' && lower <= b'f') { return Int64(lower - b'a' + 10) }
    throw Exception("invalid hex char")
}

main() {
    println("=== TLS 1.3 Server (Accepted Transport) Sample ===")

    let serverName = TEST_HOST_WWW
    let leafPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_leaf.pem"))
    let intermediatePem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_intermediate.pem"))
    let certChainPem = "${leafPem}\n${intermediatePem}"
    let leafKeyPem = String.fromUtf8(File.readFrom("../../testdata/x509/policy_leaf_key_pkcs8.pem"))

    // Plan server attach
    let plan = contractPlanHttpServerAttachRequest(
        ContractHttpServerLibraryStartupRequest(
            ContractHttpServerTlsConfigRequest(
                certChainPem,
                leafKeyPem,
                alpnProtocols: ["h2", "http/1.1"],
                requireHttp2Alpn: true
            ),
            aesBackendHint: "shim"
        )
    )
    println("Server attach plan ready: ${plan.stableAttachGate.readyNow}")
    if (plan.stableAttachGate.readyNow) {
        println("  attach surface: ${plan.attachSurface}")
        println("  expected TLS version: ${plan.expectedTlsVersion.toString()}")
        println("  expected ALPN: ${plan.expectedAlpnProtocols}")
    }

    // Build client hello
    let clientKey = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
    let clientHello = contractTls13BuildHttpClientHelloX25519(
        serverName,
        alpnProtocols: ["h2", "http/1.1"],
        clientPrivateKey: Some(clientKey)
    )

    // Server key exchange private (separate key)
    let serverKeyPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")

    // Describe accepted transport
    let policy = ContractTlsHttpNegotiationPolicy(
        requireServerName: true,
        allowedServerNames: [serverName],
        alpnPreference: ["h2", "http/1.1"]
    )

    let transport = ContractAcceptedTransportDescriptor(
        "tls13-x25519-demo",
        transportKind: "demo",
        localEndpoint: "127.0.0.1:443",
        remoteEndpoint: "127.0.0.1:34567"
    )
    println("Transport ID: ${transport.transportId}")
    println("  peer: ${transport.remoteEndpoint}")

    // Attach accepted transport with TLS 1.3 X25519
    let session = contractAttachAcceptedTransportTls13X25519(
        transport,
        plan,
        clientHello.encodedClientHello,
        serverKeyPrivate,
        policy: policy
    )
    println("Session ready: ${session.secureSessionReady}")
    println("  cipher suite: ${session.result.cipherSuite}")
    println("  negotiated ALPN: ${session.result.negotiatedAlpn}")
    println("  attach surface: ${session.result.attachSurface}")

    // Initial handshake facade
    let facade = contractBuildHttpServerInitialHandshakeFacade(session)
    println("  handshake records: ${facade.recordCount}")
    println("  wire bytes: ${facade.wireBytes}")

    // Close the session
    let closed = contractCloseAcceptedTransportSession(session)
    println("Session closed: ${!closed.secureSessionReady}")

    println("TLS server sample completed.")
}
