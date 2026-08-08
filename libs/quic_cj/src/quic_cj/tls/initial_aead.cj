package quic_cj.tls

import jinguissl_core.crypto.quic.{
    quicInitialKeyDerive as coreKeyDerive,
    quicAeadEncrypt as coreAeadEncrypt,
    quicAeadDecrypt as coreAeadDecrypt,
    QUIC_SALT_V1, QUIC_SALT_V2,
    QuicAeadAlgorithm
}

/// 为初始包提供加密/解密。
public class InitialAEAD {
    private var key: Array<Byte>
    private var iv: Array<Byte>
    private var hpKey: Array<Byte>
    private var isV2: Bool

    public init(connId: Array<Byte>, isV2: Bool) {
        let (k, i, h) = coreKeyDerive(connId, isV2)
        this.key = k
        this.iv = i
        this.hpKey = h
        this.isV2 = isV2
    }

    public func encrypt(pn: Int64, plaintext: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        coreAeadEncrypt(key, iv, pn, plaintext, aad, QuicAeadAlgorithm.Aes128Gcm)
    }

    public func decrypt(pn: Int64, ciphertextWithTag: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        coreAeadDecrypt(key, iv, pn, ciphertextWithTag, aad, QuicAeadAlgorithm.Aes128Gcm)
    }

    public func getHpKey(): Array<Byte> { hpKey }
    public func getKey(): Array<Byte> { key }
    public func getIv(): Array<Byte> { iv }
}

/// 创建 QUIC v1 的 InitialAEAD。
public func newInitialAEAD(connId: Array<Byte>): InitialAEAD {
    InitialAEAD(connId, false)
}

/// 创建 QUIC v2 的 InitialAEAD。
public func newInitialAEADV2(connId: Array<Byte>): InitialAEAD {
    InitialAEAD(connId, true)
}
