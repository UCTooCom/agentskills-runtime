package quic_cj.tls

import jinguissl_core.crypto.quic.{quicRetryIntegrityTag, quicVerifyRetryIntegrity}
import quic_cj.protocol.{VERSION_1, VERSION_2, Version}

/// 计算重试完整性标签（RFC 9001 §5.8）。
public func getRetryIntegrityTag(
    retryPacket: Array<Byte>,
    origDestConnId: Array<Byte>,
    version: Version
): Array<Byte> {
    let isV2 = (version == VERSION_2)
    quicRetryIntegrityTag(retryPacket, origDestConnId, isV2)
}

/// 验证重试完整性标签。
public func verifyRetryIntegrity(
    retryPacket: Array<Byte>,
    origDestConnId: Array<Byte>,
    version: Version
): Bool {
    let isV2 = (version == VERSION_2)
    quicVerifyRetryIntegrity(retryPacket, origDestConnId, isV2)
}
