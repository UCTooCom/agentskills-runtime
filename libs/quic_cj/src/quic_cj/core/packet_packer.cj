package quic_cj.core

import quic_cj.protocol.{PacketNumber, PacketNumberLen, EncryptionLevel, Version, VERSION_1, MAX_PACKET_BUFFER_SIZE}
import quic_cj.wire.{Frame, appendByte, appendVarint, appendBytes, appendFrame, frameWireSize, writeFrameAt, writeByteAt, writeBytesAt, writeVarintAt, writeVarintLen, writeSliceAt}
import quic_cj.tls.{LongHeaderOpener, LongHeaderSealer, Sealer, HeaderProtector}

/// PacketNumberSpace 跟踪某个加密级别的包编号。
public class PacketNumberSpace {
    private var largestSent: PacketNumber = -1
    private var largestAcked: PacketNumber = -1

    public func nextPacketNumber(): PacketNumber {
        largestSent += 1
        largestSent
    }

    public func getLargestAcked(): PacketNumber { largestAcked }
    public func getCurrentPn(): PacketNumber { largestSent }
}

/// PacketPacker 从帧组装 QUIC 包并处理包头编码。
public class PacketPacker {
    private var version: Version = VERSION_1
    private var srcConnId: Array<Byte> = []
    private var destConnId: Array<Byte> = []
    private var initialPn: PacketNumberSpace = PacketNumberSpace()
    private var handshakePn: PacketNumberSpace = PacketNumberSpace()
    private var zeroRttPn: PacketNumberSpace = PacketNumberSpace()
    private var oneRttPn: PacketNumberSpace = PacketNumberSpace()
    public var sealerActive: Bool = false
    private var lastPnOffset: Int64 = 0

    public init(version: Version, srcConnId: Array<Byte>, destConnId: Array<Byte>) {
        this.version = version
        this.srcConnId = srcConnId
        this.destConnId = destConnId
    }

    /// 组装带帧的长包头包（预计算大小 + 一次分配 + 位置写入）。
    public func packLongHeaderPacket(
        pktType: UInt8,
        encLevel: EncryptionLevel,
        frames: Array<Frame>,
        pnLen: PacketNumberLen
    ): Array<Byte> {
        packLongHeaderPacketWithToken(pktType, encLevel, frames, pnLen, [])
    }

    public func packLongHeaderPacketWithToken(
        pktType: UInt8,
        encLevel: EncryptionLevel,
        frames: Array<Frame>,
        pnLen: PacketNumberLen,
        token: Array<Byte>
    ): Array<Byte> {
        let pn = getPnSpace(encLevel).nextPacketNumber()

        // 1. 计算 payload 大小：PN + 所有帧
        var payloadSize: Int64 = Int64(pnLen)
        var i: Int64 = 0
        while (i < frames.size) {
            payloadSize += frameWireSize(frames[i])
            i += 1
        }

        // 2. 计算包头基础大小
        var headerSize: Int64 = 1 + 4  // 首字节 + 版本号
        headerSize += 1 + destConnId.size  // 目标连接 ID 长度 + 值
        headerSize += 1 + srcConnId.size   // 源连接 ID 长度 + 值
        if (pktType == 0u8) {
            headerSize += writeVarintLen(token.size) + token.size
        }
        headerSize += writeVarintLen(payloadSize)  // 负载长度字段

        // 3. 一次性分配完整缓冲区
        let totalSize = headerSize + payloadSize
        var buf = Array<Byte>(totalSize, repeat: 0u8)
        var pos: Int64 = 0

        // 4. 写入包头
        let firstByte = 0x80u8 | ((pktType & 0x07u8) << 4) | (pnLen - 1u8)
        pos = writeByteAt(buf, pos, firstByte)
        pos = writeByteAt(buf, pos, UInt8((version >> 24) & 0xffu32))
        pos = writeByteAt(buf, pos, UInt8((version >> 16) & 0xffu32))
        pos = writeByteAt(buf, pos, UInt8((version >> 8) & 0xffu32))
        pos = writeByteAt(buf, pos, UInt8(version & 0xffu32))
        pos = writeByteAt(buf, pos, UInt8(destConnId.size))
        pos = writeBytesAt(buf, pos, destConnId)
        pos = writeByteAt(buf, pos, UInt8(srcConnId.size))
        pos = writeBytesAt(buf, pos, srcConnId)
        if (pktType == 0u8) {
            pos = writeVarintAt(buf, pos, token.size)
            pos = writeBytesAt(buf, pos, token)
        }
        lastPnOffset = pos  // 保存 PN 偏移（AAD 长度）
        pos = writeVarintAt(buf, pos, payloadSize)

        // 5. 写入 payload：PN + 帧
        pos = writePacketNumberAt(buf, pos, pn, pnLen)
        i = 0
        while (i < frames.size) {
            pos = writeFrameAt(buf, pos, frames[i])
            i += 1
        }
        buf
    }

    /// 组装短包头包（预计算大小 + 一次分配 + 位置写入）。
    public func packShortHeaderPacket(
        frames: Array<Frame>,
        pnLen: PacketNumberLen
    ): Array<Byte> {
        packShortHeaderPacketWithOptions(frames, pnLen, false, false)
    }

    public func packShortHeaderPacketWithOptions(
        frames: Array<Frame>,
        pnLen: PacketNumberLen,
        keyPhase: Bool,
        spinBit: Bool
    ): Array<Byte> {
        let pn = oneRttPn.nextPacketNumber()

        // 1. 计算帧总大小
        var payloadSize: Int64 = 0
        var i: Int64 = 0
        while (i < frames.size) {
            payloadSize += frameWireSize(frames[i])
            i += 1
        }

        // 2. 一次性分配：首字节(1) + 目标ID + PN + 帧
        let totalSize = 1 + destConnId.size + Int64(pnLen) + payloadSize
        var buf = Array<Byte>(totalSize, repeat: 0u8)
        var pos: Int64 = 0

        // 3. 写入短包头
        let firstByte = 0x40u8 | (pnLen - 1u8) | (if (keyPhase) { 0x10u8 } else { 0u8 }) | (if (spinBit) { 0x20u8 } else { 0u8 })
        pos = writeByteAt(buf, pos, firstByte)
        pos = writeBytesAt(buf, pos, destConnId)
        lastPnOffset = pos  // 保存 PN 偏移（AAD 长度）

        // 4. 写入 PN + 帧
        pos = writePacketNumberAt(buf, pos, pn, pnLen)
        i = 0
        while (i < frames.size) {
            pos = writeFrameAt(buf, pos, frames[i])
            i += 1
        }
        buf
    }

    public func getPn(encLevel: EncryptionLevel): PacketNumber {
        getPnSpace(encLevel).getCurrentPn()
    }

    public func getLastPnOffset(): Int64 { lastPnOffset }

    public func getLargestAckedPn(encLevel: EncryptionLevel): PacketNumber {
        getPnSpace(encLevel).getLargestAcked()
    }

    private func getPnSpace(encLevel: EncryptionLevel): PacketNumberSpace {
        match (encLevel) {
            case EncryptionLevel.Initial => initialPn
            case EncryptionLevel.Handshake => handshakePn
            case EncryptionLevel.ZeroRTT => zeroRttPn
            case _ => oneRttPn
        }
    }
}

/// 对 QUIC 包应用 AEAD 加密和包头保护（预分配 + 一次写入）。
/// buf：未加密的包（AAD + PN + 明文帧）
/// pn：用于 AEAD nonce 的完整包编号
/// pnOffset：buf 中截断 PN 起始的字节位置（= AAD 长度）
/// pnLen：截断 PN 的字节长度
/// sealer：AEAD 密封器
/// hdrProtector：包头保护器
/// 返回应用了包头保护的加密包。
public func sealPacket(
    buf: Array<Byte>,
    pn: PacketNumber,
    pnOffset: Int64,
    pnLen: Int64,
    sealer: Sealer,
    hdrProtector: HeaderProtector
): Array<Byte> {
    let aadLen = pnOffset
    if (aadLen <= 0 || aadLen + pnLen > buf.size) { return buf }
    let framesStart = aadLen + pnLen
    let aad = buf[..aadLen]
    let plaintextFrames = buf[framesStart..]

    // AEAD 加密
    let ciphertext = sealer.encrypt(pn, plaintextFrames, aad)

    // 预分配完整输出缓冲区：AAD + PN + 密文
    let totalSize = aad.size + pnLen + ciphertext.size
    var out = Array<Byte>(totalSize, repeat: 0u8)
    // 一次写入：AAD + PN + 密文
    var pos = writeSliceAt(out, 0, buf, 0, aadLen)
    pos = writeSliceAt(out, pos, buf, aadLen, aadLen + pnLen)
    pos = writeBytesAt(out, pos, ciphertext)

    // 使用密文的样本（RFC 9001 §5.4 规定的字节 4-19）应用包头保护
    if (ciphertext.size >= 20) {
        let sample = ciphertext[4..20]
        let (maskByte, maskPn) = hdrProtector.encryptHeader(sample)
        let isLong = (out[0] & 0x80u8) != 0u8
        let protectMask = if (isLong) { 0x0fu8 } else { 0x1fu8 }
        out[0] = out[0] ^ (maskByte & protectMask)
        var i: Int64 = 0
        while (i < pnLen && i < maskPn.size) {
            out[aadLen + i] = out[aadLen + i] ^ maskPn[i]
            i += 1
        }
    }
    out
}

// ── 包编号写入（位置模式） ──

/// 在 buf 的 pos 位置写入指定长度的编码包编号，返回新位置。
internal func writePacketNumberAt(buf: Array<Byte>, pos: Int64, pn: PacketNumber, pnLen: PacketNumberLen): Int64 {
    if (pnLen == 1u8) {
        writeByteAt(buf, pos, UInt8(pn & 0xff))
    } else if (pnLen == 2u8) {
        var p = writeByteAt(buf, pos, UInt8((pn >> 8) & 0xff))
        writeByteAt(buf, p, UInt8(pn & 0xff))
    } else if (pnLen == 3u8) {
        var p = writeByteAt(buf, pos, UInt8((pn >> 16) & 0xff))
        p = writeByteAt(buf, p, UInt8((pn >> 8) & 0xff))
        writeByteAt(buf, p, UInt8(pn & 0xff))
    } else {
        var p = writeByteAt(buf, pos, UInt8((pn >> 24) & 0xff))
        p = writeByteAt(buf, p, UInt8((pn >> 16) & 0xff))
        p = writeByteAt(buf, p, UInt8((pn >> 8) & 0xff))
        writeByteAt(buf, p, UInt8(pn & 0xff))
    }
}

// ── 包编号追加（旧兼容，保留使用） ──

/// 用指定长度编码包编号（旧接口，保留兼容）。
internal func appendPacketNumber(buf: Array<Byte>, pn: PacketNumber, pnLen: PacketNumberLen): Array<Byte> {
    if (pnLen == 1u8) {
        appendByte(buf, UInt8(pn & 0xff))
    } else if (pnLen == 2u8) {
        var out = appendByte(buf, UInt8((pn >> 8) & 0xff))
        out = appendByte(out, UInt8(pn & 0xff))
        out
    } else if (pnLen == 3u8) {
        var out = appendByte(buf, UInt8((pn >> 16) & 0xff))
        out = appendByte(out, UInt8((pn >> 8) & 0xff))
        out = appendByte(out, UInt8(pn & 0xff))
        out
    } else {
        var out = appendByte(buf, UInt8((pn >> 24) & 0xff))
        out = appendByte(out, UInt8((pn >> 16) & 0xff))
        out = appendByte(out, UInt8((pn >> 8) & 0xff))
        out = appendByte(out, UInt8(pn & 0xff))
        out
    }
}
