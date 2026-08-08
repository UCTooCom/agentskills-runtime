package jinguissl.contract

import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.quic.{
    quicRetryIntegrityTag as Core_quicRetryIntegrityTag,
    quicVerifyRetryIntegrity as Core_quicVerifyRetryIntegrity
}

/**
 * contractQuicRetryIntegrityTag — compute Retry Integrity Tag (RFC 9001 §5.8 / RFC 9369 §5.8).
 *
 * aad = concat(len(origDestConnId), origDestConnId, retryPacket)
 * tag = AES-128-GCM(RetryIntegrityKey, RetryIntegrityNonce, nil, aad)[0..16]
 *
 * @param retryPacket the Retry packet bytes WITHOUT the trailing 16-byte tag
 * @param origDestConnId the Original Destination Connection ID from the client's Initial
 * @param isV2 true for QUIC v2, false for QUIC v1
 * @returns 16-byte integrity tag
 * @throws ContractException when inputs are invalid or tag generation fails
 */
public func contractQuicRetryIntegrityTag(
    retryPacket: Array<Byte>,
    origDestConnId: Array<Byte>,
    isV2: Bool
): Array<Byte> {
    contractQuicRequireOrigDestConnId(origDestConnId)
    try {
        Core_quicRetryIntegrityTag(retryPacket, origDestConnId, isV2)
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC Retry integrity tag generation", e, false)
    }
}

/**
 * contractQuicVerifyRetryIntegrity — verify Retry Integrity Tag.
 *
 * @param retryPacketWithTag the full Retry packet INCLUDING the 16-byte tag
 * @param origDestConnId the Original Destination Connection ID
 * @param isV2 true for QUIC v2
 * @returns true if tag is valid, false otherwise
 * @throws ContractException when inputs are invalid or verification cannot be completed
 */
public func contractQuicVerifyRetryIntegrity(
    retryPacketWithTag: Array<Byte>,
    origDestConnId: Array<Byte>,
    isV2: Bool
): Bool {
    contractQuicRequireOrigDestConnId(origDestConnId)
    try {
        Core_quicVerifyRetryIntegrity(retryPacketWithTag, origDestConnId, isV2)
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC Retry integrity verification", e, true)
    }
}

private func contractQuicRequireOrigDestConnId(origDestConnId: Array<Byte>): Unit {
    if (origDestConnId.size > 20) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "QUIC original destination connection ID must not exceed 20 bytes"
        )
    }
}
