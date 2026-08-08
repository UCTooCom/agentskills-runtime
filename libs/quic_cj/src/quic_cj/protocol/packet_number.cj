package quic_cj.protocol

public type PacketNumber = Int64
public type PacketNumberLen = UInt8

public let INVALID_PACKET_NUMBER: PacketNumber = -1

public let PACKET_NUMBER_LEN_1: PacketNumberLen = 1u8
public let PACKET_NUMBER_LEN_2: PacketNumberLen = 2u8
public let PACKET_NUMBER_LEN_3: PacketNumberLen = 3u8
public let PACKET_NUMBER_LEN_4: PacketNumberLen = 4u8

/// 实现 RFC 9000 附录 A.3 截断包编号解码。
public func decodePacketNumber(
    length: PacketNumberLen,
    largest: PacketNumber,
    truncated: PacketNumber
): PacketNumber {
    let expected = largest + 1
    let shift = Int64(length) * 8
    let win = Int64(1) << shift
    let hwin = win / 2
    let mask = win - 1
    let base = (expected / win) * win
    var candidate = base | truncated
    if (candidate <= expected - hwin && candidate < (Int64(1) << 62) - win) {
        candidate + win
    } else if (candidate > expected + hwin && candidate >= win) {
        candidate - win
    } else {
        candidate
    }
}

/// 选择能够表示该差值的最短编码。
public func packetNumberLengthForHeader(pn: PacketNumber, largestAcked: PacketNumber): PacketNumberLen {
    let numUnacked = if (largestAcked == INVALID_PACKET_NUMBER) {
        pn + 1
    } else {
        pn - largestAcked
    }
    if (numUnacked < (Int64(1) << (8 - 1))) { PACKET_NUMBER_LEN_1 }
    else if (numUnacked < (Int64(1) << (16 - 1))) { PACKET_NUMBER_LEN_2 }
    else if (numUnacked < (Int64(1) << (24 - 1))) { PACKET_NUMBER_LEN_3 }
    else { PACKET_NUMBER_LEN_4 }
}
