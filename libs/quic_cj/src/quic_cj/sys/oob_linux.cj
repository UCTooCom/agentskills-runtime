package quic_cj.sys

import quic_cj.protocol.{ECN, MAX_PACKET_BUFFER_SIZE}

// ── Linux OOB (Out-of-Band) 数据常量 ──

// IPPROTO_IP / IPPROTO_IPV6
private let IPPROTO_IP: Int64 = 0
private let IPPROTO_IPV6: Int64 = 41
private let SOL_SOCKET: Int64 = 1

// 套接字选项
private let IP_TOS: Int64 = 1
private let IPV6_TCLASS: Int64 = 67
private let IP_RECVTOS: Int64 = 13           // 接收 IPv4 TOS
private let IPV6_RECVTCLASS: Int64 = 56      // 接收 IPv6 流量类别
private let IP_PKTINFO: Int64 = 8
private let IPV6_RECVPKTINFO: Int64 = 61
private let UDP_SEGMENT: Int64 = 103
private let IP_MTU_DISCOVER: Int64 = 10
private let IP_PMTUDISC_PROBE: Int64 = 3
private let IPV6_MTU_DISCOVER: Int64 = 71
private let IPV6_PMTUDISC_PROBE: Int64 = 3

// CMSG 层级与类型
private let SOL_IP: Int64 = 0
private let IP_TOS_TYPE: Int64 = 1
private let IP_PKTINFO_TYPE: Int64 = 8
private let IPV6_TCLASS_TYPE: Int64 = 67
private let IPV6_PKTINFO_TYPE: Int64 = 61

private let CMSG_ALIGN: Int64 = 8
private let CMSG_LEN_HEADER: Int64 = 16  // sizeof(struct cmsghdr) on 64-bit

/// OobCapabilities 描述 Linux OOB 连接的能力。
public class OobCapabilities {
    public var df: Bool = false
    public var gso: Bool = false
    public var ecn: Bool = false

    public init(df: Bool, gso: Bool, ecn: Bool) {
        this.df = df
        this.gso = gso
        this.ecn = ecn
    }
}

// ── OOB 数据辅助函数 ──

/// 将 ECN 值编码为 IPv4 TOS 控制消息（1 字节数据）。
/// 返回 OOB 控制消息字节数组。
internal func appendIPV4EcnMsg(oob: Array<Byte>, ecn: ECN): Array<Byte> {
    var buf = oob
    let dataLen: Int64 = 1
    let totalLen = CMSG_LEN_HEADER + dataLen
    let alignedLen = (totalLen + CMSG_ALIGN - 1) / CMSG_ALIGN * CMSG_ALIGN

    let startIdx = buf.size
    var i: Int64 = 0
    while (i < alignedLen) { buf = appendByteOob(buf, 0u8); i += 1 }

    // cmsg_len = 对齐后的长度（CMSG_LEN_HEADER + dataLen）
    let cmsgLen = CMSG_LEN_HEADER + dataLen
    buf[startIdx + 0] = UInt8(cmsgLen & 0xff)
    buf[startIdx + 1] = UInt8((cmsgLen >> 8) & 0xff)
    buf[startIdx + 2] = UInt8((cmsgLen >> 16) & 0xff)
    buf[startIdx + 3] = UInt8((cmsgLen >> 24) & 0xff)
    // cmsg_level = IPPROTO_IP
    buf[startIdx + 4] = UInt8(IPPROTO_IP & 0xff)
    buf[startIdx + 5] = UInt8((IPPROTO_IP >> 8) & 0xff)
    buf[startIdx + 6] = UInt8((IPPROTO_IP >> 16) & 0xff)
    buf[startIdx + 7] = UInt8((IPPROTO_IP >> 24) & 0xff)
    // cmsg_type = IP_TOS
    buf[startIdx + 8] = UInt8(IP_TOS_TYPE & 0xff)
    buf[startIdx + 9] = UInt8((IP_TOS_TYPE >> 8) & 0xff)
    buf[startIdx + 10] = UInt8((IP_TOS_TYPE >> 16) & 0xff)
    buf[startIdx + 11] = UInt8((IP_TOS_TYPE >> 24) & 0xff)
    // data: ECN 位（对齐到 12 字节 + 数据在字节 12）
    let bits = ecnToHeaderBits(ecn)
    buf[startIdx + CMSG_LEN_HEADER] = bits

    buf
}

/// 将 ECN 值编码为 IPv6 TCLASS 控制消息（4 字节数据）。
internal func appendIPV6EcnMsg(oob: Array<Byte>, ecn: ECN): Array<Byte> {
    var buf = oob
    let dataLen: Int64 = 4
    let totalLen = CMSG_LEN_HEADER + dataLen
    let alignedLen = (totalLen + CMSG_ALIGN - 1) / CMSG_ALIGN * CMSG_ALIGN

    let startIdx = buf.size
    var i: Int64 = 0
    while (i < alignedLen) { buf = appendByteOob(buf, 0u8); i += 1 }

    // CMSG 头部（64 位系统上 16 字节）
    let cmsgLen = CMSG_LEN_HEADER + dataLen
    buf[startIdx + 0] = UInt8(cmsgLen & 0xff)
    buf[startIdx + 1] = UInt8((cmsgLen >> 8) & 0xff)
    buf[startIdx + 2] = UInt8((cmsgLen >> 16) & 0xff)
    buf[startIdx + 3] = UInt8((cmsgLen >> 24) & 0xff)
    buf[startIdx + 4] = UInt8(IPPROTO_IPV6 & 0xff)
    buf[startIdx + 5] = UInt8((IPPROTO_IPV6 >> 8) & 0xff)
    buf[startIdx + 6] = UInt8((IPPROTO_IPV6 >> 16) & 0xff)
    buf[startIdx + 7] = UInt8((IPPROTO_IPV6 >> 24) & 0xff)
    buf[startIdx + 8] = UInt8(IPV6_TCLASS_TYPE & 0xff)
    buf[startIdx + 9] = UInt8((IPV6_TCLASS_TYPE >> 8) & 0xff)
    buf[startIdx + 10] = UInt8((IPV6_TCLASS_TYPE >> 16) & 0xff)
    buf[startIdx + 11] = UInt8((IPV6_TCLASS_TYPE >> 24) & 0xff)
    // data: 作为 uint32 的 ECN 位（本机字节序）
    let bits: UInt32 = UInt32(ecnToHeaderBits(ecn))
    buf[startIdx + CMSG_LEN_HEADER + 0] = UInt8(bits & 0xff)
    buf[startIdx + CMSG_LEN_HEADER + 1] = UInt8((bits >> 8) & 0xff)
    buf[startIdx + CMSG_LEN_HEADER + 2] = UInt8((bits >> 16) & 0xff)
    buf[startIdx + CMSG_LEN_HEADER + 3] = UInt8((bits >> 24) & 0xff)

    buf
}

/// 为 GSO 添加 UDP_SEGMENT 控制消息（2 字节数据）。
internal func appendUdpSegmentMsg(oob: Array<Byte>, gsoSize: UInt16): Array<Byte> {
    var buf = oob
    let dataLen: Int64 = 2
    let totalLen = CMSG_LEN_HEADER + dataLen
    let alignedLen = (totalLen + CMSG_ALIGN - 1) / CMSG_ALIGN * CMSG_ALIGN

    let startIdx = buf.size
    var i: Int64 = 0
    while (i < alignedLen) { buf = appendByteOob(buf, 0u8); i += 1 }

    let cmsgLen = CMSG_LEN_HEADER + dataLen
    buf[startIdx + 0] = UInt8(cmsgLen & 0xff)
    buf[startIdx + 1] = UInt8((cmsgLen >> 8) & 0xff)
    buf[startIdx + 2] = UInt8((cmsgLen >> 16) & 0xff)
    buf[startIdx + 3] = UInt8((cmsgLen >> 24) & 0xff)
    buf[startIdx + 4] = UInt8(IPPROTO_IP & 0xff)
    buf[startIdx + 5] = UInt8((IPPROTO_IP >> 8) & 0xff)
    buf[startIdx + 6] = UInt8((IPPROTO_IP >> 16) & 0xff)
    buf[startIdx + 7] = UInt8((IPPROTO_IP >> 24) & 0xff)
    buf[startIdx + 8] = UInt8(UDP_SEGMENT & 0xff)
    buf[startIdx + 9] = UInt8((UDP_SEGMENT >> 8) & 0xff)
    buf[startIdx + 10] = UInt8((UDP_SEGMENT >> 16) & 0xff)
    buf[startIdx + 11] = UInt8((UDP_SEGMENT >> 24) & 0xff)
    // data: GSO 大小（2 字节）
    buf[startIdx + CMSG_LEN_HEADER + 0] = UInt8(gsoSize & 0xffu16)
    buf[startIdx + CMSG_LEN_HEADER + 1] = UInt8((gsoSize >> 8) & 0xffu16)

    buf
}

/// 从 OOB 数据中提取 ECN 值。
/// 解析 IP_TOS (IPv4) 和 IPV6_TCLASS (IPv6) 控制消息。
internal func parseOobEcn(oob: Array<Byte>): ECN {
    var offset: Int64 = 0
    while (offset + CMSG_LEN_HEADER <= oob.size) {
        let cmsgLenU32 = readUint32LE(oob, offset)
        if (Int64(cmsgLenU32) < CMSG_LEN_HEADER) { break }
        let cmsgLevel = readInt32LE(oob, offset + 4)
        let cmsgType = readInt32LE(oob, offset + 8)
        let dataOffset = offset + CMSG_LEN_HEADER

        if (cmsgLevel == IPPROTO_IP && cmsgType == IP_TOS_TYPE) {
            // IPv4 TOS：1 字节
            if (dataOffset < oob.size) {
                let ecnBits = oob[dataOffset] & 0x03u8
                return ecnFromBits(ecnBits)
            }
        }
        if (cmsgLevel == IPPROTO_IPV6 && cmsgType == IPV6_TCLASS_TYPE) {
            // IPv6 TCLASS：4 字节，ECN 在最低 2 位
            if (dataOffset + 3 < oob.size) {
                let tclass = readUint32LE(oob, dataOffset)
                let ecnBits = UInt8(tclass & 0x03)
                return ecnFromBits(ecnBits)
            }
        }
        offset += Int64(cmsgLenU32)
        // 对齐到 CMSG_ALIGN
        offset = (offset + CMSG_ALIGN - 1) / CMSG_ALIGN * CMSG_ALIGN
    }
    ECN.Unsupported
}

/// 从 IPv4 控制消息中解析 PKTINFO（12 字节）。
internal func parseOobPktInfo(oob: Array<Byte>): Option<Array<Byte>> {
    var offset: Int64 = 0
    while (offset + CMSG_LEN_HEADER <= oob.size) {
        let cmsgLenU32 = readUint32LE(oob, offset)
        if (Int64(cmsgLenU32) < CMSG_LEN_HEADER) { break }
        let cmsgLevel = readInt32LE(oob, offset + 4)
        let cmsgType = readInt32LE(oob, offset + 8)
        let dataOffset = offset + CMSG_LEN_HEADER

        if (cmsgLevel == SOL_IP && cmsgType == IP_PKTINFO_TYPE) {
            // struct in_pktinfo { unsigned int ifindex; struct in_addr spec_dst; struct in_addr addr; } = 12 字节
            if (dataOffset + 12 <= oob.size) {
                let pktInfo = oob[dataOffset..dataOffset+12]
                return Some(pktInfo)
            }
        }
        offset += Int64(cmsgLenU32)
        offset = (offset + CMSG_ALIGN - 1) / CMSG_ALIGN * CMSG_ALIGN
    }
    None
}

// ── 辅助函数 ──

private func ecnToHeaderBits(ecn: ECN): UInt8 {
    match (ecn) {
        case ECN.ECT0 => 0x02u8
        case ECN.ECT1 => 0x01u8
        case ECN.CE => 0x03u8
        case _ => 0x00u8
    }
}

private func ecnFromBits(bits: UInt8): ECN {
    if (bits == 0x01u8) { ECN.ECT1 }
    else if (bits == 0x02u8) { ECN.ECT0 }
    else if (bits == 0x03u8) { ECN.CE }
    else { ECN.Non }
}

private func readUint32LE(buf: Array<Byte>, offset: Int64): UInt32 {
    if (offset + 3 >= buf.size) { return 0u32 }
    UInt32(buf[offset]) | (UInt32(buf[offset + 1]) << 8) | (UInt32(buf[offset + 2]) << 16) | (UInt32(buf[offset + 3]) << 24)
}

private func readInt32LE(buf: Array<Byte>, offset: Int64): Int64 {
    Int64(readUint32LE(buf, offset))
}

internal func appendByteOob(arr: Array<Byte>, b: UInt8): Array<Byte> {
    let n = arr.size
    var out = Array<Byte>(n + 1, repeat: 0u8)
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = b
    out
}
