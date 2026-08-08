package http_lib.utils

import std.collection.ArrayList

/**
 * 十六进制编解码工具函数。
 *
 * 提供字节数组与十六进制字符串之间的转换，以及单个字节/半字节的
 * 十六进制转换函数。用于 ETag 生成、摘要认证和 TLS 诊断数据格式化。
 */

/**
 * 小写十六进制字符查找表（0-9, a-f）。
 * 预分配以避免重复构造 Rune 数组。
 */
public let HEX_CHARS: Array<Rune> = "0123456789abcdef".toRuneArray()
/// 大写十六进制字节查找表（0-9, A-F），用于 URL 编码等场景。
public let HEX_CHARS_UPPER: Array<UInt8> = unsafe { "0123456789ABCDEF".rawData() }

/// 小写十六进制字节查找表，用于 byte-based hexEncode 构建。
public let HEX_CHARS_LOWER: Array<UInt8> = unsafe { "0123456789abcdef".rawData() }

/**
 * 将 4 位半字节（0-15）转换为小写十六进制字符。
 * @param v 低 4 位为有效值，高 4 位被忽略
 */
public func byteToHexChar(v: UInt8): Rune {
    HEX_CHARS[Int64(v & 0x0f)]
}

/**
 * 将 4 位半字节（0-15）转换为大写十六进制字节。
 * 用于 URL 百分号编码的字节级输出。
 */
public func byteToHexCharUpper(v: UInt8): UInt8 {
    HEX_CHARS_UPPER[Int64(v & 0x0f)]
}

/**
 * 将字节数组编码为小写十六进制字符串。
 *
 * 每个字节编码为两个十六进制字符，高位在前。
 * 用于调试输出和二进制数据的文本表示。
 */
public func hexEncode(data: Array<UInt8>): String {
    var bytes = Array<UInt8>(data.size * 2, repeat: 0)
    var i: Int64 = 0
    for (b in data) {
        bytes[i] = HEX_CHARS_LOWER[Int64((b >> 4) & 0x0f)]
        bytes[i + 1] = HEX_CHARS_LOWER[Int64(b & 0x0f)]
        i += 2
    }
    String.fromUtf8(bytes)
}

/**
 * 将十六进制字符串解码为字节数组。
 *
 * 输入长度必须为偶数，包含有效的小写或大写十六进制字符。
 * 解码失败时抛出异常。
 */
public func hexDecode(hex: String): Array<UInt8> {
    let runes = hex.toRuneArray()
    if (runes.size % 2 != 0) {
        throw Exception("hex string must have even length")
    }
    let result = ArrayList<UInt8>(runes.size / 2)
    var i: Int64 = 0
    while (i < runes.size) {
        let high = hexDigitVal(runes[i])
        let low = hexDigitVal(runes[i + 1])
        result.add(UInt8((high << 4) | low))
        i += 2
    }
    result.toArray()
}

/**
 * 将十六进制字符转换为其数值（0-15）。
 * 如果字符不是有效的十六进制数字则抛出异常。
 */
private func hexDigitVal(c: Rune): Int64 {
    if (c >= r'0' && c <= r'9') { Int64(UInt32(c)) - 48 }
    else if (c >= r'a' && c <= r'f') { Int64(UInt32(c)) - 87 }
    else if (c >= r'A' && c <= r'F') { Int64(UInt32(c)) - 55 }
    else { throw Exception("invalid hex character: ${c}") }
}

/**
 * 将 UInt32 值转换为小写十六进制字符串（8 字符，零填充）。
 * 用于 ETag 生成和摘要认证。
 */
public func toHex32(value: UInt32): String {
    let runes = ArrayList<Rune>()
    var v = value
    var i: Int64 = 0
    while (i < 8) {
        let idx = Int64(v & 0x0fu32)
        runes.add(HEX_CHARS[idx])
        v = v >> 4
        i += 1
    }
    // 反转
    let reversed = ArrayList<Rune>()
    i = runes.size - 1
    while (i >= 0) {
        reversed.add(runes[i])
        i -= 1
    }
    String(reversed.toArray())
}

/**
 * 将 Int64 值转换为小写十六进制字符串。
 * 用于分块传输编码和 TLS 诊断。
 */
public func toHex64(value: Int64): String {
    if (value == 0) { return "0" }
    let runes = ArrayList<Rune>()
    var v: UInt64 = UInt64(value)  // 按位重解释（补码表示）
    while (v > 0) {
        let idx = Int64(v & 0x0f)
        runes.add(HEX_CHARS[idx])
        v = v >> 4
    }
    // 反转
    let reversed = ArrayList<Rune>()
    var i = runes.size - 1
    while (i >= 0) {
        reversed.add(runes[i])
        i -= 1
    }
    String(reversed.toArray())
}
