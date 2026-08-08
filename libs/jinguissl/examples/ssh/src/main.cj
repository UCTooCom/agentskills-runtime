package sample_ssh

/** ssh — SSH 启动捆绑包（KEX 握手） */
import std.fs.File
import jinguissl_core.crypto.ssh.{sshBuildDefaultKexInit, sshBuildKexEcdhInitX25519, sshEncodeKexInit, sshEncodeNewKeys}
import jinguissl.contract.*

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
    println("=== SSH Startup Bundle Sample ===")

    let clientPrivate = hexToBytes("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
    let serverPrivate = hexToBytes("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
    let rsaPkcs8Pem = String.fromUtf8(File.readFrom("../../testdata/x509/rsa_2048_pkcs8.pem"))

    // Transcript uses SSH_MSG_KEXINIT (algorithm negotiation)
    let clientKexInit = sshEncodeKexInit(sshBuildDefaultKexInit())
    let serverKexInit = sshEncodeKexInit(sshBuildDefaultKexInit())
    let transcript = ContractSshKexExchangeTranscript(
        "SSH-2.0-sample-client\r\n".toArray(),
        "SSH-2.0-sample-server\r\n".toArray(),
        clientKexInit,
        serverKexInit
    )

    let negotiated = ContractSshNegotiatedAlgorithms(
        "curve25519-sha256",
        "rsa-sha2-256",
        "aes128-ctr",
        "aes128-ctr",
        "hmac-sha2-256",
        "hmac-sha2-256",
        compressionAlgorithmClientToServer: "none",
        compressionAlgorithmServerToClient: "none"
    )

    // The server request needs KEX ECDH INIT (key exchange)
    let (encodedClientInit, _) = sshBuildKexEcdhInitX25519(clientPrivate)
    let encodedNewKeys = sshEncodeNewKeys()

    // Prepare server startup bundle (RSA PKCS#8 host key)
    let serverBundle = contractPrepareSshServerLibraryStartupX25519RsaPkcs8Request(
        ContractSshServerLibraryStartupX25519RsaPkcs8Request(
            transcript,
            serverPrivate,
            encodedClientInit,
            rsaPkcs8Pem,
            negotiated,
            encodedNewKeys,
            encodedNewKeys
        )
    )
    println("Server bundle: template=${serverBundle.template.label}")
    println("  readiness: http=${serverBundle.readiness.httpTlsReady}, ssh=${serverBundle.readiness.sshReady}")

    // SSH profile catalog
    let profiles = contractListHttpSshStartupProfiles()
    println("SSH startup profiles (${profiles.size}):")
    for (p in profiles) {
        println("  - ${p.label}")
    }

    println("SSH sample completed.")
}
