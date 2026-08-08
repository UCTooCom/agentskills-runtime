package quic_cj.wire

import quic_cj.protocol.{MAX_CONN_ID_LEN, MIN_CONN_ID_LEN_INITIAL, VERSION_1, VERSION_2, VERSION_UNKNOWN}

/// Header 表示解析后的 QUIC 包头。
public class Header {
    public var isLongHeader: Bool = false
    public var destConnId: Array<Byte> = []
    public var srcConnId: Array<Byte> = []
    public var version: UInt32 = 0u32
    public var typeByte: UInt8 = 0u8
    public var packetType: UInt8 = 0u8
}

/// 检查首字节是否指示长包头包。
public func isLongHeaderPacket(firstByte: UInt8): Bool {
    (firstByte & 0x80u8) != 0u8
}

/// 从长包头包中提取版本。
public func parseVersion(data: Array<Byte>): UInt32 {
    if (data.size < 5) { return VERSION_UNKNOWN }
    UInt32(UInt8(data[1])) << 24 | UInt32(UInt8(data[2])) << 16 |
    UInt32(UInt8(data[3])) << 8 | UInt32(UInt8(data[4]))
}

/// 从首字节提取长包头包类型。
public func parseLongPacketType(firstByte: UInt8): UInt8 {
    (firstByte >> 4) & 0x03u8
}

/// 对数据是否可能是 QUIC 包进行基本检查。
public func isPotentialQUICPacket(firstByte: UInt8): Bool {
    (firstByte & 0x40u8) != 0u8
}

/// 解析 QUIC 包头的公共字段。
/// 返回 (Header, bytes_consumed)，出错时返回空 Header。
public func parseHeader(data: Array<Byte>): (Header, Int64) {
    if (data.size < 1) { return (Header(), 0) }
    let firstByte = UInt8(data[0])
    let longHdr = isLongHeaderPacket(firstByte)

    if (!longHdr) {
        // 短包头：仅目标连接 ID（需要外部知道长度）
        let hdr = Header()
        hdr.isLongHeader = false
        hdr.typeByte = firstByte
        return (hdr, 1)
    }

    // 长包头：类型、版本、目标/源连接 ID
    if (data.size < 6) { return (Header(), 0) }
    let pktType = parseLongPacketType(firstByte)
    let version = parseVersion(data)
    let destLen = Int64(UInt8(data[5]))
    if (destLen > MAX_CONN_ID_LEN || data.size < 6 + destLen + 1) {
        return (Header(), 0)
    }
    let srcLen = Int64(UInt8(data[6 + destLen]))
    if (data.size < 6 + destLen + 1 + srcLen) {
        return (Header(), 0)
    }
    let headerLen = 6 + destLen + 1 + srcLen
    let hdr = Header()
    hdr.isLongHeader = true
    hdr.typeByte = firstByte
    hdr.packetType = pktType
    hdr.version = version
    hdr.destConnId = data[6..(6 + destLen)]
    hdr.srcConnId = data[(6 + destLen + 1)..headerLen]
    (hdr, Int64(headerLen))
}

/// 短包头的默认连接 ID 长度。
public let SHORT_HEADER_CONN_ID_LEN: Int64 = 4
