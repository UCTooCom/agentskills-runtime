package jinguissl_contract_application_smoke

import jinguissl.contract.*

private let SHA256_ABC: String =
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

main(): Int64 {
    let payload: Array<Byte> = [0x61, 0x62, 0x63]
    let digest = contractBytesToHexLower(contractSha256(payload))

    if (digest != SHA256_ABC) {
        println("fatal=JinguiSSLContract SHA-256 application smoke mismatch")
        println("actual=${digest}")
        return 1
    }

    let quicKey: Array<Byte> = [
        0x1f, 0x36, 0x96, 0x13, 0xdd, 0x76, 0xd5, 0x46,
        0x77, 0x30, 0xef, 0xcb, 0xe3, 0xb1, 0xa2, 0x2d
    ]
    let quicIv: Array<Byte> = [
        0xfa, 0x04, 0x4b, 0x2f, 0x42, 0xa3,
        0xfd, 0x3b, 0x46, 0xfb, 0x25, 0x5c
    ]
    let quicPlaintext = "contract quic consumer".toArray()
    let quicAad = "consumer aad".toArray()
    let sealed = contractQuicAeadEncrypt(
        quicKey, quicIv, 9, quicPlaintext, quicAad,
        ContractQuicAeadAlgorithm.Aes128Gcm
    )
    let recovered = contractQuicAeadDecrypt(
        quicKey, quicIv, 9, sealed, quicAad,
        ContractQuicAeadAlgorithm.Aes128Gcm
    )
    if (recovered != quicPlaintext) {
        println("fatal=JinguiSSLContract QUIC application smoke mismatch")
        return 1
    }

    try {
        _ = contractQuicAeadEncrypt(
            Array<Byte>(32, repeat: 0), quicIv, 9, quicPlaintext, quicAad,
            ContractQuicAeadAlgorithm.Aes128Gcm
        )
        println("fatal=JinguiSSLContract QUIC mismatch was not rejected")
        return 1
    } catch (e: ContractException) {
        if (e.code != ContractErrorCode.BadInput) {
            println("fatal=JinguiSSLContract QUIC mismatch error mapping is wrong")
            return 1
        }
    }

    println("jinguissl_contract_application_smoke=pass")
    println("sha256_abc=${digest}")
    println("quic_aead=${ContractQuicAeadAlgorithm.Aes128Gcm}")
    0
}
