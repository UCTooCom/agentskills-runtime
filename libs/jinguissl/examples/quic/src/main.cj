package sample_quic

/** quic — QUIC 初始密钥派生与 Header Protection */
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
    throw Exception("invalid hex char: ${ch}")
}

main() {
    println("=== QUIC Sample ===")

    // Salt constants
    println("QUIC v1 salt: ${contractBytesToHexLower(QUIC_SALT_V1)}")
    println("QUIC v2 salt: ${contractBytesToHexLower(QUIC_SALT_V2)}")

    // Derive initial secrets from connection ID
    let connId = hexToBytes("8394c8f03e515708")
    let (clientSecret, serverSecret) = contractQuicInitialSecrets(connId, false)
    println("Client initial secret: ${contractBytesToHexLower(clientSecret)}")
    println("Server initial secret: ${contractBytesToHexLower(serverSecret)}")

    // Derive key and IV from traffic secret
    let (key, iv) = contractQuicInitialKeyIv(clientSecret, false)
    println("Client key: ${contractBytesToHexLower(key)}")
    println("Client IV:  ${contractBytesToHexLower(iv)}")

    // Derive header protection key
    let hpKey = contractQuicInitialHpKey(clientSecret, false)
    println("Client HP key: ${contractBytesToHexLower(hpKey)}")

    // One-shot derivation returns (key, iv, hpKey)
    let (derivedKey, derivedIv, derivedHp) = contractQuicInitialKeyDerive(connId, false)
    println(
        "One-shot key derived: key_ok=${derivedKey == key}, " +
        "iv_ok=${derivedIv == iv}, hp_ok=${derivedHp == hpKey}"
    )

    // QUIC AEAD encrypt/decrypt
    let testKey: Array<Byte> = [0x1f, 0x36, 0x96, 0x13, 0xdd, 0x76, 0xd5, 0x46, 0x77, 0x30, 0xef, 0xcb, 0xe3, 0xb1, 0xa2, 0x2d]
    let testIv: Array<Byte> = [0xfa, 0x04, 0x4b, 0x2f, 0x42, 0xa3, 0xfd, 0x3b, 0x46, 0xfb, 0x25, 0x5c]
    let pt = "hello quic".toArray()
    let aad = "aad".toArray()
    let sealed = contractQuicAeadEncrypt(
        testKey, testIv, 42, pt, aad,
        ContractQuicAeadAlgorithm.Aes128Gcm
    )
    let recovered = contractQuicAeadDecrypt(
        testKey, testIv, 42, sealed, aad,
        ContractQuicAeadAlgorithm.Aes128Gcm
    )
    println("AEAD round-trip: ${String.fromUtf8(recovered)}")

    println("QUIC sample completed.")
}
