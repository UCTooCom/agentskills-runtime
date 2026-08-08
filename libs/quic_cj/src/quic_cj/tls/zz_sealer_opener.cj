package quic_cj.tls

import quic_cj.protocol.PacketNumber

/// 包装 UpdatableAEAD 以实现 Sealer 接口（RFC 9001 §5.1）。
public class AeadSealer <: Sealer {
    private var aead: UpdatableAEAD

    public init(aead: UpdatableAEAD) {
        this.aead = aead
    }

    public func encrypt(pn: PacketNumber, plaintext: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        aead.encrypt(pn, plaintext, aad)
    }

    public func overhead(): Int64 { 16 }
}

/// 包装 UpdatableAEAD 以实现 Opener 接口（RFC 9001 §5.1）。
public class AeadOpener <: Opener {
    private var aead: UpdatableAEAD

    public init(aead: UpdatableAEAD) {
        this.aead = aead
    }

    public func decrypt(pn: PacketNumber, ciphertextWithTag: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        aead.decrypt(pn, ciphertextWithTag, aad)
    }
}
