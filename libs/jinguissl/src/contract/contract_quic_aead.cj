package jinguissl.contract

import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.quic.{
    QuicAeadAlgorithm,
    quicAeadEncrypt as Core_quicAeadEncrypt,
    quicAeadDecrypt as Core_quicAeadDecrypt
}

public enum ContractQuicAeadAlgorithm <: Equatable<ContractQuicAeadAlgorithm> & ToString {
    | Aes128Gcm
    | Aes256Gcm
    | ChaCha20Poly1305

    public operator func ==(right: ContractQuicAeadAlgorithm): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractQuicAeadAlgorithm): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Aes128Gcm => 0
            case Aes256Gcm => 1
            case ChaCha20Poly1305 => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Aes128Gcm => "AES-128-GCM"
            case Aes256Gcm => "AES-256-GCM"
            case ChaCha20Poly1305 => "ChaCha20-Poly1305"
        }
    }
}

/**
 * Encrypt a QUIC payload with an explicitly selected AEAD algorithm.
 *
 * @throws ContractException when inputs are invalid or encryption fails
 */
public func contractQuicAeadEncrypt(
    key: Array<Byte>, iv: Array<Byte>, pn: Int64,
    plaintext: Array<Byte>, aad: Array<Byte>,
    algorithm: ContractQuicAeadAlgorithm
): Array<Byte> {
    contractQuicRequireAeadInputs(key, iv, pn, algorithm)
    try {
        Core_quicAeadEncrypt(
            key, iv, pn, plaintext, aad,
            contractQuicToCoreAeadAlgorithm(algorithm)
        )
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC AEAD encryption", e, false)
    }
}

/**
 * Decrypt and authenticate a QUIC payload with an explicitly selected AEAD algorithm.
 *
 * @throws ContractException when inputs are invalid or authentication fails
 */
public func contractQuicAeadDecrypt(
    key: Array<Byte>, iv: Array<Byte>, pn: Int64,
    ciphertextWithTag: Array<Byte>, aad: Array<Byte>,
    algorithm: ContractQuicAeadAlgorithm
): Array<Byte> {
    contractQuicRequireAeadInputs(key, iv, pn, algorithm)
    if (ciphertextWithTag.size < 16) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "QUIC AEAD ciphertext and tag must contain at least 16 bytes"
        )
    }
    try {
        Core_quicAeadDecrypt(
            key, iv, pn, ciphertextWithTag, aad,
            contractQuicToCoreAeadAlgorithm(algorithm)
        )
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC AEAD decryption", e, true)
    }
}

private func contractQuicToCoreAeadAlgorithm(
    algorithm: ContractQuicAeadAlgorithm
): QuicAeadAlgorithm {
    match (algorithm) {
        case ContractQuicAeadAlgorithm.Aes128Gcm => QuicAeadAlgorithm.Aes128Gcm
        case ContractQuicAeadAlgorithm.Aes256Gcm => QuicAeadAlgorithm.Aes256Gcm
        case ContractQuicAeadAlgorithm.ChaCha20Poly1305 => QuicAeadAlgorithm.ChaCha20Poly1305
    }
}

private func contractQuicRequireAeadInputs(
    key: Array<Byte>,
    iv: Array<Byte>,
    pn: Int64,
    algorithm: ContractQuicAeadAlgorithm
): Unit {
    let expectedKeyLength: Int64 = match (algorithm) {
        case ContractQuicAeadAlgorithm.Aes128Gcm => 16
        case ContractQuicAeadAlgorithm.Aes256Gcm => 32
        case ContractQuicAeadAlgorithm.ChaCha20Poly1305 => 32
    }
    if (key.size != expectedKeyLength) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "QUIC ${algorithm} key must be ${expectedKeyLength} bytes"
        )
    }
    if (iv.size != 12) {
        throw ContractException(ContractErrorCode.BadInput, "QUIC AEAD IV must be 12 bytes")
    }
    if (pn < 0) {
        throw ContractException(ContractErrorCode.BadInput, "QUIC packet number must be non-negative")
    }
}
