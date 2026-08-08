/**
 * QUIC 变长整数编码（RFC 9000 §16）。
 *
 * 前两位编码长度：
 *   00 → 1 字节（6 位值）
 *   01 → 2 字节（14 位值）
 *   10 → 4 字节（30 位值）
 *   11 → 8 字节（62 位值）
 */
package http_lib.http2

import http_lib.core.ProtocolException

/**
 * 编码 QUIC 变长整数（RFC 9000 §16）。
 *
 * @param value 要编码的无符号整数
 * @return 编码后的字节数组（1/2/4/8 字节）
 * @throws ProtocolException 若值超出可用范围
 */
public func encodeQuicVarint(value: UInt64): Array<UInt8> {
    if (value <= 63) {
        [UInt8(value)]
    } else if (value <= 16383) {
        let v = UInt16(value) | 0x4000u16
        let b0 = UInt8((v >> 8) & 0xff)
        let b1 = UInt8(v & 0xff)
        [b0, b1]
    } else if (value <= 1073741823) {
        let v = UInt32(value) | 0x80000000u32
        let b0 = UInt8((v >> 24) & 0xff)
        let b1 = UInt8((v >> 16) & 0xff)
        let b2 = UInt8((v >> 8) & 0xff)
        let b3 = UInt8(v & 0xff)
        [b0, b1, b2, b3]
    } else if (value <= 4611686018427387903) {
        let v = value | 0xC000000000000000u64
        let b0 = UInt8((v >> 56) & 0xff)
        let b1 = UInt8((v >> 48) & 0xff)
        let b2 = UInt8((v >> 40) & 0xff)
        let b3 = UInt8((v >> 32) & 0xff)
        let b4 = UInt8((v >> 24) & 0xff)
        let b5 = UInt8((v >> 16) & 0xff)
        let b6 = UInt8((v >> 8) & 0xff)
        let b7 = UInt8(v & 0xff)
        [b0, b1, b2, b3, b4, b5, b6, b7]
    } else {
        throw ProtocolException("QUIC varint value out of range: ${value}")
    }
}

/**
 * 解码 QUIC 变长整数（RFC 9000 §16）。
 *
 * @param data 包含变长整数的字节数组
 * @param offset 起始偏移
 * @return (解码后的值, 编码长度字节数)
 * @throws ProtocolException 若数据不足或值无效
 */
public func decodeQuicVarint(data: Array<UInt8>, offset: Int64): (UInt64, Int64) {
    if (offset >= data.size) {
        throw ProtocolException("QUIC varint: unexpected end of data")
    }
    let prefix = data[offset] >> 6
    match (prefix) {
        case 0u8 =>
            let value = UInt64(data[offset] & 0x3f)
            (value, 1)
        case 1u8 =>
            if (offset + 2 > data.size) {
                throw ProtocolException("QUIC varint: unexpected end of data for 2-byte varint")
            }
            let value = UInt64((UInt16(data[offset] & 0x3f) << 8) | UInt16(data[offset + 1]))
            (value, 2)
        case 2u8 =>
            if (offset + 4 > data.size) {
                throw ProtocolException("QUIC varint: unexpected end of data for 4-byte varint")
            }
            let value = UInt64((UInt32(data[offset] & 0x3f) << 24) |
                (UInt32(data[offset + 1]) << 16) |
                (UInt32(data[offset + 2]) << 8) |
                UInt32(data[offset + 3]))
            (value, 4)
        case 3u8 =>
            if (offset + 8 > data.size) {
                throw ProtocolException("QUIC varint: unexpected end of data for 8-byte varint")
            }
            let value = (UInt64(data[offset] & 0x3f) << 56) |
                (UInt64(data[offset + 1]) << 48) |
                (UInt64(data[offset + 2]) << 40) |
                (UInt64(data[offset + 3]) << 32) |
                (UInt64(data[offset + 4]) << 24) |
                (UInt64(data[offset + 5]) << 16) |
                (UInt64(data[offset + 6]) << 8) |
                UInt64(data[offset + 7])
            (value, 8)
        case _ =>
            throw ProtocolException("QUIC varint: invalid prefix")
    }
}
