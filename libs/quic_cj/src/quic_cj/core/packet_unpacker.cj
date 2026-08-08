package quic_cj.core

import quic_cj.protocol.{PacketNumber, PacketNumberLen, EncryptionLevel, decodePacketNumber, INVALID_PACKET_NUMBER}
import quic_cj.wire.{Frame, parseFrame, parseFrameAt, parseHeader, Header, readVarint, readVarintAt, appendByte}
import quic_cj.tls.{Opener, HeaderProtector}

/// ParsedPacket 保存解析并解密 QUIC 包的结果。
public class ParsedPacket {
    public var header: Header = Header()
    public var packetNumber: PacketNumber = INVALID_PACKET_NUMBER
    public var frames: Array<Frame> = []
    public var payload: Array<Byte> = []
    public var consumed: Int64 = 0
    public var encryptionLevel: EncryptionLevel = EncryptionLevel.Initial
}

/// PacketUnpacker 解析 QUIC 包并提取帧。
public class PacketUnpacker {
   private var largestReceived: PacketNumber = INVALID_PACKET_NUMBER

    public func getLargestReceived(): PacketNumber { largestReceived }
    public func setLargestReceived(pn: PacketNumber): Unit { largestReceived = pn }

    public init() {}

    /// 处理长包头包。返回解析后的帧 + 包编号。
    /// 此版本处理包头解析和帧提取，不进行解密。
    public func unpackLongHeader(data: Array<Byte>): ParsedPacket {
        let result = ParsedPacket()
        let (hdr, hdrLen) = parseHeader(data)
        if (hdrLen <= 0) { return result }
        result.header = hdr
        result.encryptionLevel = encLevelFromPacketType(hdr.packetType)

        // 从首字节获取包编号长度
        let pnLen: PacketNumberLen = (hdr.typeByte & 0x03u8) + 1u8

    // 对于初始包：跳过令牌长度 + 令牌（RFC 9000 §17.2.1）
    var pnOffset = hdrLen
    var payloadLen: Int64 = 0
    if (hdr.packetType == 0u8) {
        if (pnOffset < data.size) {
            let (tokenLen, tl) = readVarintAt(data, pnOffset)
            pnOffset += tl + tokenLen
        }
    }
    // 读取长度字段（RFC 9000 §17.2）
    if (pnOffset < data.size) {
        let (pl, n) = readVarintAt(data, pnOffset)
        payloadLen = pl
        pnOffset += n
    }

        if (pnOffset + Int64(pnLen) > data.size) { return result }

        // 读取原始包编号
        let (rawPn, _) = readPacketNumberRaw(data, pnOffset, pnLen)
        result.packetNumber = decodePacketNumber(pnLen, largestReceived, rawPn)
        largestReceived = result.packetNumber

        // 加密负载
        let payloadOffset = pnOffset + Int64(pnLen)
        let payloadEnd = if (payloadLen > 0 && payloadOffset + payloadLen <= data.size) { payloadOffset + payloadLen } else { data.size }
        if (payloadOffset < data.size && payloadEnd > payloadOffset) {
            result.payload = data[payloadOffset..payloadEnd]
        }

        // 尝试从原始负载解析帧（应首先解密）
        // 目前，尝试对原始数据进行帧解析（用于测试）
        result.consumed = payloadOffset
        result
    }

    /// 处理短包头包。
    public func unpackShortHeader(data: Array<Byte>): ParsedPacket {
        return unpackShortHeaderWithConnId(data, 0)
    }

    public func unpackShortHeaderWithConnId(data: Array<Byte>, connIdLen: Int64): ParsedPacket {
        let result = ParsedPacket()
        let (hdr, hdrLen) = parseHeader(data)
        if (hdrLen <= 0) { return result }
        result.header = hdr
        result.encryptionLevel = EncryptionLevel.OneRTT

        // 从首字节获取包编号长度
        let pnLen: PacketNumberLen = (hdr.typeByte & 0x03u8) + 1u8

        // 短包头：目标连接 ID + PN（connIdLen 来自参数）
        let destIdLen = connIdLen
        let pnOffset = 1 + destIdLen
        if (pnOffset + Int64(pnLen) > data.size) { return result }

        let (rawPn, _) = readPacketNumberRaw(data, pnOffset, pnLen)
        result.packetNumber = decodePacketNumber(pnLen, largestReceived, rawPn)
        largestReceived = result.packetNumber

        let payloadOffset = pnOffset + Int64(pnLen)
        if (payloadOffset < data.size) {
            result.payload = data[payloadOffset..]
        }

        result.consumed = payloadOffset
        result
    }

    /// 从解密后的负载中提取帧。
    public func parseFramesFromPayload(payload: Array<Byte>): Array<Frame> {
        // 预分配容量 8，覆盖典型多帧包，避免 O(n²) 逐次追加
        var frames: Array<Frame> = Array<Frame>(8, repeat: Frame())
        var count: Int64 = 0
        var offset: Int64 = 0
        while (offset < payload.size) {
            let (frame, consumed) = parseFrameAt(payload, offset)
            if (consumed <= 0) { break }
            if (count >= frames.size) {
                let newCap = frames.size * 2
                let newArr = Array<Frame>(newCap, repeat: Frame())
                var i: Int64 = 0
                while (i < count) { newArr[i] = frames[i]; i += 1 }
                frames = newArr
            }
            frames[count] = frame
            count += 1
            offset += consumed
        }
        // 修剪到实际数量
        if (count == 0) { return Array<Frame>(0, repeat: Frame()) }
        if (count < frames.size) {
            let result = Array<Frame>(count, repeat: Frame())
            var i: Int64 = 0
            while (i < count) { result[i] = frames[i]; i += 1 }
            result
        } else {
            frames
        }
    }
}

private func encLevelFromPacketType(pktType: UInt8): EncryptionLevel {
    // 包类型：0=初始，1=0-RTT，2=握手，3=重试（无加密负载）
    if (pktType == 0u8) { EncryptionLevel.Initial }
    else if (pktType == 1u8) { EncryptionLevel.ZeroRTT }
    else if (pktType == 2u8) { EncryptionLevel.Handshake }
    else { EncryptionLevel.Initial }  // type 3 (Retry) 无加密，映射为 Initial 级别
}

private func readPacketNumberRaw(data: Array<Byte>, offset: Int64, pnLen: PacketNumberLen): (PacketNumber, Int64) {
    var pn: PacketNumber = 0
    var i: Int64 = 0
    while (i < Int64(pnLen)) {
        pn = (pn << 8) | Int64(UInt8(data[offset + i]))
        i += 1
    }
   (pn, Int64(pnLen))
}

/// 对已移除包头保护的 QUIC 包进行 AEAD 解密。
/// data：已移除包头保护的包（AAD 和 PN 字节均已还原）
/// pn：用于 AEAD nonce 的完整包编号（由 removeHeaderProtectionAndDecodePn 返回）
/// pnOffset：data 中截断 PN 起始的字节位置（= AAD 长度）
/// pnLen：截断 PN 的字节长度
/// opener：AEAD 开启器
/// hdrProtector：包头保护器（已由调用方应用，此函数不再处理）
/// 返回解密后的负载帧，失败时返回空数组。
public func unsealPacket(
    data: Array<Byte>,
    pn: PacketNumber,
    pnOffset: Int64,
    pnLen: Int64,
    opener: Opener,
    hdrProtector: HeaderProtector
): Array<Byte> {
    let aadLen = pnOffset
    if (aadLen <= 0 || aadLen + pnLen >= data.size) { return [] }
    let aad = data[..aadLen]
    let ciphertext = data[aadLen + pnLen..]
    opener.decrypt(pn, ciphertext, aad)
}

/// 移除包头保护并解码截断的包编号。
/// 在 data 中原地移除包头保护（首字节和 PN 字节），
/// 返回校正后的完整包编号。
/// 调用方后续可以将 data（已移除保护）传给 unsealPacket 进行 AEAD 解密。
public func removeHeaderProtectionAndDecodePn(
    data: Array<Byte>,
    pnOffset: Int64,
    pnLen: Int64,
    largestReceived: PacketNumber,
    hdrProtector: HeaderProtector
): PacketNumber {
    let aadLen = pnOffset
    if (aadLen + pnLen >= data.size) {
        let (rawPn, _) = readPacketNumberRaw(data, pnOffset, UInt8(pnLen))
        return decodePacketNumber(UInt8(pnLen), largestReceived, rawPn)
    }
    let ciphertext = data[aadLen + pnLen..]
    if (ciphertext.size < 20) {
        // 密文不足以提供采样 — 直接解码截断 PN
        let (rawPn, _) = readPacketNumberRaw(data, pnOffset, UInt8(pnLen))
        return decodePacketNumber(UInt8(pnLen), largestReceived, rawPn)
    }
    let sample = ciphertext[4..20]
    let (maskByte, maskPn) = hdrProtector.decryptHeader(sample)
    let isLong = (data[0] & 0x80u8) != 0u8
    let protectMask = if (isLong) { 0x0fu8 } else { 0x1fu8 }
    // 原地移除首字节的包头保护
    data[0] = data[0] ^ (maskByte & protectMask)
    // 原地移除 PN 字节的包头保护
    var i: Int64 = 0
    while (i < pnLen && i < maskPn.size) {
        data[pnOffset + i] = data[pnOffset + i] ^ maskPn[i]
        i += 1
    }
    // 从已移除保护的字节中读取截断包编号
    let (rawPn, _) = readPacketNumberRaw(data, pnOffset, UInt8(pnLen))
    decodePacketNumber(UInt8(pnLen), largestReceived, rawPn)
}
