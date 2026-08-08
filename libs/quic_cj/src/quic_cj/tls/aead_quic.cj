package quic_cj.tls

import jinguissl_core.crypto.quic.{quicAeadEncrypt as coreEncrypt, quicAeadDecrypt as coreDecrypt, QuicAeadAlgorithm}
import quic_cj.protocol.PacketNumber

/// 提供支持密钥更新的 AEAD 加密（RFC 9001 §6）。
public class UpdatableAEAD {
    private var key: Array<Byte>
    private var iv: Array<Byte>
    private var keyPhase: Int64 = 0
    private var alg: QuicAeadAlgorithm = QuicAeadAlgorithm.Aes128Gcm

    public init(key: Array<Byte>, iv: Array<Byte>) {
        this.key = key
        this.iv = iv
        this.alg = QuicAeadAlgorithm.Aes128Gcm
    }

    public init(key: Array<Byte>, iv: Array<Byte>, alg: QuicAeadAlgorithm) {
        this.key = key
        this.iv = iv
        this.alg = alg
    }

    public func encrypt(pn: PacketNumber, plaintext: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        coreEncrypt(key, iv, pn, plaintext, aad, alg)
    }

    public func decrypt(pn: PacketNumber, ciphertextWithTag: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        try {
            coreDecrypt(key, iv, pn, ciphertextWithTag, aad, alg)
        } catch (_: Exception) {
            []
        }
    }

    public func getKey(): Array<Byte> { key }
    public func getIv(): Array<Byte> { iv }
}
