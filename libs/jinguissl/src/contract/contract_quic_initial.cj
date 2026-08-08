package jinguissl.contract

import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.quic.{
    QUIC_SALT_V1 as Core_QUIC_SALT_V1,
    QUIC_SALT_V2 as Core_QUIC_SALT_V2,
    quicInitialSecrets as Core_quicInitialSecrets,
    quicInitialKeyIv as Core_quicInitialKeyIv,
    quicInitialHpKey as Core_quicInitialHpKey,
    quicInitialKeyDerive as Core_quicInitialKeyDerive
}

/**
 * contractQuicSaltV1 — QUIC v1 initial salt (RFC 9001 §5.2), 20 bytes.
 *
 * Returns a fresh copy each call to prevent shared-mutable-array corruption.
 */
public func contractQuicSaltV1(): Array<Byte> {
    Core_QUIC_SALT_V1.clone()
}

/**
 * contractQuicSaltV2 — QUIC v2 initial salt (RFC 9369 §5.2), 20 bytes.
 *
 * Returns a fresh copy each call to prevent shared-mutable-array corruption.
 */
public func contractQuicSaltV2(): Array<Byte> {
    Core_QUIC_SALT_V2.clone()
}

/**
 * contractQuicInitialSecrets — derive initial secrets for client and server.
 *
 * initial_secret = HKDF-Extract(salt, conn_id)
 * client_secret  = HKDF-Expand-Label(initial_secret, "client in",  32)
 * server_secret  = HKDF-Expand-Label(initial_secret, "server in",  32)
 *
 * @param connId QUIC connection ID
 * @param isV2 true for QUIC v2, false for QUIC v1
 * @returns (client_secret, server_secret) each 32 bytes
 * @throws ContractException when derivation fails
 */
public func contractQuicInitialSecrets(
    connId: Array<Byte>, isV2: Bool
): (Array<Byte>, Array<Byte>) {
    try {
        Core_quicInitialSecrets(connId, isV2)
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC initial secret derivation", e, false)
    }
}

/**
 * contractQuicInitialKeyIv — derive initial key and IV from a traffic secret.
 *
 * key = HKDF-Expand-Label(secret, "quic key" / "quicv2 key",  16)
 * iv  = HKDF-Expand-Label(secret, "quic iv"  / "quicv2 iv",   12)
 *
 * @param secret 32-byte traffic secret (client or server)
 * @param isV2 true for QUIC v2
 * @returns (key, iv)
 * @throws ContractException when the traffic secret is invalid or derivation fails
 */
public func contractQuicInitialKeyIv(
    secret: Array<Byte>, isV2: Bool
): (Array<Byte>, Array<Byte>) {
    contractQuicRequireInitialSecret(secret)
    try {
        Core_quicInitialKeyIv(secret, isV2)
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC initial key and IV derivation", e, false)
    }
}

/**
 * contractQuicInitialHpKey — derive initial header protection key.
 *
 * hp = HKDF-Expand-Label(secret, "quic hp" / "quicv2 hp", 16)
 *
 * @param secret 32-byte traffic secret
 * @param isV2 true for QUIC v2
 * @returns 16-byte header protection key
 * @throws ContractException when the traffic secret is invalid or derivation fails
 */
public func contractQuicInitialHpKey(
    secret: Array<Byte>, isV2: Bool
): Array<Byte> {
    contractQuicRequireInitialSecret(secret)
    try {
        Core_quicInitialHpKey(secret, isV2)
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC initial header protection key derivation", e, false)
    }
}

/**
 * contractQuicInitialKeyDerive — one-shot client-side initial key material.
 *
 * Derives (key, iv, hp_key) from connection ID in a single call.
 *
 * @param connId QUIC connection ID
 * @param isV2 true for QUIC v2
 * @returns (key, iv, hpKey)
 * @throws ContractException when derivation fails
 */
public func contractQuicInitialKeyDerive(
    connId: Array<Byte>, isV2: Bool
): (Array<Byte>, Array<Byte>, Array<Byte>) {
    try {
        Core_quicInitialKeyDerive(connId, isV2)
    } catch (e: CryptoException) {
        throw contractQuicException("QUIC initial key material derivation", e, false)
    }
}

private func contractQuicRequireInitialSecret(secret: Array<Byte>): Unit {
    if (secret.size != 32) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "QUIC initial traffic secret must be 32 bytes"
        )
    }
}
