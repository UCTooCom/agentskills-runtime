package quic_cj.tls

import quic_cj.protocol.{PacketNumber, EncryptionLevel}
import quic_cj.wire.appendByte

/// 解密 QUIC 包。
open public class Opener {
    /// 解密密文（带标签）并返回明文。
    open public func decrypt(pn: PacketNumber, ciphertextWithTag: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        throw Exception("Opener.decrypt: not implemented")
    }
}

/// 加密 QUIC 包。
open public class Sealer {
    /// 加密明文并返回带标签的密文。
    open public func encrypt(pn: PacketNumber, plaintext: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        throw Exception("Sealer.encrypt: not implemented")
    }
    /// 返回加密增加的字节数（标签长度）。
    open public func overhead(): Int64 { 16 }
}

/// 加密/解密 QUIC 包头。
open public class HeaderProtector {
    /// 应用包头保护掩码。
    open public func encryptHeader(sample: Array<Byte>): (UInt8, Array<Byte>) {
        throw Exception("HeaderProtector.encryptHeader: not implemented")
    }
    /// 应用包头保护掩码（相同操作）。
    open public func decryptHeader(sample: Array<Byte>): (UInt8, Array<Byte>) {
        encryptHeader(sample)
    }
}

/// 在指定加密级别解密长包头包。
public class LongHeaderOpener <: Opener {
    public var level: EncryptionLevel
    public init(level: EncryptionLevel) {
        this.level = level
    }
}

/// 在指定加密级别加密长包头包。
public class LongHeaderSealer <: Sealer {
    public var level: EncryptionLevel
    public init(level: EncryptionLevel) {
        this.level = level
    }
}
