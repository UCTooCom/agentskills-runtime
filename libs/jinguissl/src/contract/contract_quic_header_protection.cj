package jinguissl.contract

import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.quic.{
    quicHpAesEncrypt as Core_quicHpAesEncrypt,
    quicHpChaChaEncrypt as Core_quicHpChaChaEncrypt
}

/**
 * contractQuicHpAesEncrypt — QUIC AES-based header protection mask (RFC 9001 §5.4.1).
 *
 * mask = AES-ECB(hp_key, sample); returns (first_byte_mask, pn_mask)
 *
 * @param sample 16-byte sample from the protected ciphertext
 * @param key 16-byte or 32-byte header protection key
 * @returns (first_byte_mask, pn_mask_bytes) where pn_mask is 15 bytes
 * @throws ContractException when the sample or key is invalid
 */
public func contractQuicHpAesEncrypt(
    sample: Array<Byte>, key: Array<Byte>
): (Byte, Array<Byte>) {
    contractQuicRequireHpSample(sample)
    if (key.size != 16 && key.size != 32) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "QUIC AES header protection key must be 16 or 32 bytes"
        )
    }
    try {
        Core_quicHpAesEncrypt(sample, key)
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC AES header protection", e, false)
    }
}

/**
 * contractQuicHpChaChaEncrypt — QUIC ChaCha20-based header protection mask (RFC 9001 §5.4.2).
 *
 * mask = ChaCha20(hp_key, counter, nonce); returns (first_byte_mask, pn_mask)
 *
 * @param sample 16-byte sample where sample[0..4]=counter (LE), sample[4..16]=nonce
 * @param key 32-byte header protection key
 * @returns (first_byte_mask, pn_mask_bytes) where pn_mask is 4 bytes
 * @throws ContractException when the sample or key is invalid
 */
public func contractQuicHpChaChaEncrypt(
    sample: Array<Byte>, key: Array<Byte>
): (Byte, Array<Byte>) {
    contractQuicRequireHpSample(sample)
    if (key.size != 32) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "QUIC ChaCha20 header protection key must be 32 bytes"
        )
    }
    try {
        Core_quicHpChaChaEncrypt(sample, key)
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC ChaCha20 header protection", e, false)
    }
}

private func contractQuicRequireHpSample(sample: Array<Byte>): Unit {
    if (sample.size != 16) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "QUIC header protection sample must be 16 bytes"
        )
    }
}
