package quic_cj.tls

import jinguissl_core.crypto.quic.{quicHpAesEncrypt as coreHpAes, quicHpChaChaEncrypt as coreHpChaCha}

/// 实现基于 AES 的 QUIC 包头保护（RFC 9001 §5.4.1）。
public class AesHeaderProtector <: HeaderProtector {
    private var key: Array<Byte>

    public init(key: Array<Byte>) {
        this.key = key
    }

    public func encryptHeader(sample: Array<Byte>): (UInt8, Array<Byte>) {
        coreHpAes(sample, key)
    }
}

/// 实现基于 ChaCha20 的 QUIC 包头保护（RFC 9001 §5.4.2）。
public class ChaChaHeaderProtector <: HeaderProtector {
    private var key: Array<Byte>

    public init(key: Array<Byte>) {
        this.key = key
    }

    public func encryptHeader(sample: Array<Byte>): (UInt8, Array<Byte>) {
        coreHpChaCha(sample, key)
    }
}
