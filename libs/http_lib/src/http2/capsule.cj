/**
 * RFC 9298 Capsule Protocol（胶囊协议）与 HTTP Datagrams 支持。
 *
 * Capsule Protocol 用于在 HTTP 流上传输非 HTTP 数据，如 UDP 数据报。
 * 在 HTTP/2 中，胶囊帧通过 DATA 帧的 0x00 类型胶囊传输。
 * 胶囊格式：Capsule Type（变长整型）+ Capsule Length（变长整型）+ Capsule Data。
 */
package http_lib.http2

import std.collection.ArrayList
import http_lib.core.ProtocolException

/**
 * RFC 9298 Capsule Protocol（胶囊协议）与 HTTP Datagrams 支持。
 *
 * Capsule Protocol 用于在 HTTP 流上传输非 HTTP 数据，如 UDP 数据报。
 * 在 HTTP/2 中，胶囊帧通过 DATA 帧的 0x00 类型胶囊传输。
 * Capsule 格式：Capsule Type（变长整型）| Capsule Length（变长整型）| Capsule Data。
    /**
     * 将胶囊类型转换为 UInt64 编码。
     */
 */

/**
 * 胶囊类型（RFC 9298 §5.2）。
 */
public enum CapsuleType <: ToString & Equatable<CapsuleType> {
    | DATA          // 0x00（数据流）
    | DATAGRAM      // 0x01（HTTP 数据报）
    | DATAGRAM_WITH_CONTEXT  // 0x02（带上下文的 HTTP 数据报）
    | CLOSE         // 0x03（关闭流）

    /**
     * 从 UInt64 值解析胶囊类型。
     */
    public func toUInt64(): UInt64 {
        match (this) {
            case DATA => 0x00u64
            case DATAGRAM => 0x01u64
            case DATAGRAM_WITH_CONTEXT => 0x02u64
            case CLOSE => 0x03u64
        }
    }

    public static func fromUInt64(v: UInt64): ?CapsuleType {
        match (v) {
            case 0x00 => Some(DATA)
            case 0x01 => Some(DATAGRAM)
            case 0x02 => Some(DATAGRAM_WITH_CONTEXT)
            case 0x03 => Some(CLOSE)
            case _ => None
        }
    }

    public func toString(): String {
        match (this) {
            case DATA => "DATA"
            case DATAGRAM => "DATAGRAM"
            case DATAGRAM_WITH_CONTEXT => "DATAGRAM_WITH_CONTEXT"
            case CLOSE => "CLOSE"
        }
    }

    public operator func ==(that: CapsuleType): Bool {
        match ((this, that)) {
            case (DATA, DATA) => true
            case (DATAGRAM, DATAGRAM) => true
            case (DATAGRAM_WITH_CONTEXT, DATAGRAM_WITH_CONTEXT) => true
            case (CLOSE, CLOSE) => true
            case _ => false
        }
    }

    public operator func !=(that: CapsuleType): Bool { !(this == that) }
}
/**
 * 编码胶囊帧（类型 + 长度 + 载荷）。
 * 使用固定 2 字节类型和 2 字节长度编码（简化实现）。
 * 完整实现应使用 QUIC 变长整数编码。
 */

/**
 * 单个胶囊帧，包含类型 + 长度 + 有效载荷。
 */
public class Capsule {
    public let capsuleType: CapsuleType
    public let payload: Array<UInt8>

    public init(capsuleType: CapsuleType, payload: Array<UInt8>) {
        this.capsuleType = capsuleType
        this.payload = payload
    }
}

/**
 * 编码胶囊帧（类型 + 长度 + 载荷，使用 QUIC 变长整数编码）。
 * 简化实现，使用固定 2 字节类型/长度。
 *
 * 格式：
/**
 * 解码胶囊帧。
 * 解析类型和长度字段，提取载荷数据。
 */
 *   capsule_type (varint, 2 bytes)
 *   capsule_length (varint, 2 bytes)
 *   capsule_payload (variable)
 */
public func encodeCapsule(capsule: Capsule): Array<UInt8> {
    let payload = capsule.payload
    let payloadLen = payload.size
    let result = ArrayList<UInt8>()
    // 使用 QUIC 变长整数编码（RFC 9298 §3 / RFC 9000 §16）
    let typeVal = capsule.capsuleType.toUInt64()
    let typeBytes = encodeQuicVarint(typeVal)
    for (b in typeBytes) { result.add(b) }
    let lenBytes = encodeQuicVarint(UInt64(payloadLen))
    for (b in lenBytes) { result.add(b) }
    var i: Int64 = 0
    while (i < payloadLen) {
        result.add(payload[i])
        i += 1
    }
    result.toArray()
}

/**
 * 解码胶囊帧。
 */
public func decodeCapsule(data: Array<UInt8>): Capsule {
    var offset: Int64 = 0
    // 使用 QUIC 变长整数解码（RFC 9298 §3 / RFC 9000 §16）
    let (typeVal, typeLen) = decodeQuicVarint(data, offset)
    offset += typeLen
    if (offset >= data.size) {
        throw ProtocolException("capsule too short: missing length field")
    }
    let (payloadLen, lenLen) = decodeQuicVarint(data, offset)
    offset += lenLen
    if (offset + Int64(payloadLen) > data.size) {
        throw ProtocolException("capsule payload truncated")
    }
    let capsuleType = match (CapsuleType.fromUInt64(typeVal)) {
        case Some(ct) => ct
        case None => throw ProtocolException("unknown capsule type: ${typeVal}")
    }
    let payloadEnd = offset + Int64(payloadLen)
    let payload = data[offset..payloadEnd]
    Capsule(capsuleType, payload)
}

/**
 * 创建 HTTP Datagram 胶囊。
 * RFC 9298 §5：DATAGRAM 胶囊包含一个完整的 UDP 数据报。
 */
public func buildDatagramCapsule(datagramData: Array<UInt8>): Capsule {
    Capsule(CapsuleType.DATAGRAM, datagramData)
}

/**
 * 创建带上下文的 HTTP Datagram 胶囊。
 * DATAGRAM_WITH_CONTEXT 包含上下文 ID + 数据报。
 */
public func buildDatagramWithContextCapsule(contextId: UInt64, datagramData: Array<UInt8>): Capsule {
    let contextBytes = ArrayList<UInt8>()
    contextBytes.add(UInt8(contextId >> 8))
    contextBytes.add(UInt8(contextId & 0xff))
    var i: Int64 = 0
    while (i < datagramData.size) {
        contextBytes.add(datagramData[i])
        i += 1
    }
    Capsule(CapsuleType.DATAGRAM_WITH_CONTEXT, contextBytes.toArray())
}

/**
 * 创建 CLOSE 胶囊（流关闭通知）。
 */
public func buildCloseCapsule(): Capsule {
    Capsule(CapsuleType.CLOSE, [])
}
