package quic_cj.protocol

public enum PacketType {
    | Initial
    | Retry
    | Handshake
    | ZeroRTT

}

public func packetTypeToWire(pt: PacketType): UInt8 {
    match (pt) {
        case PacketType.Initial => 1u8
        case PacketType.Retry => 2u8
        case PacketType.Handshake => 3u8
        case PacketType.ZeroRTT => 4u8
    }
}

public func packetTypeFromWire(v: UInt8): PacketType {
    if (v == 1u8) { PacketType.Initial }
    else if (v == 2u8) { PacketType.Retry }
    else if (v == 3u8) { PacketType.Handshake }
    else if (v == 4u8) { PacketType.ZeroRTT }
    else { PacketType.Initial }
}
