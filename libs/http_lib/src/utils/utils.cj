package http_lib.utils

import std.collection.ArrayList
import std.convert.Parsable

// 关于 unsafe { str.rawData() } 的说明：
// 仓颉 String 值是不可变的 UTF-8 字节序列，即使在 unsafe 块中，
// rawData() 访问对于只读操作也是安全的。返回的字节数组是字符串
// 内部存储的直接视图。由于字符串永远不会被修改，该指针/长度在引用的
// 整个生命周期内保持稳定，不会导致释放后使用或数据竞争。
// 对于新代码，建议使用安全替代方案 String.toArray()，
// 它返回堆分配的 UTF-8 字节副本，无需 unsafe 块。
// 本文件中的 stringToBytes() 辅助函数提供了对 toArray() 的安全封装。

// ---------- 字节数组辅助函数 ----------

/**
 * 将字节从源数组复制到目标数组。
 * 封装 Array<UInt8>.copyTo() 以确保一致的复制语义。
 */
public func copyBytes(
    source: Array<UInt8>,
    sourceOffset: Int64,
    destination: Array<UInt8>,
    destinationOffset: Int64,
    length: Int64
): Unit {
    if (length > 0) {
        source.copyTo(destination, sourceOffset, destinationOffset, length)
    }
}

/// 返回两个 Int64 中的较大值（编译时常量版本）。
public const func maxInt64(a: Int64, b: Int64): Int64 {
    if (a > b) { a } else { b }
}

/// 返回两个 Int64 中的较小值（编译时常量版本）。
public const func minInt64(a: Int64, b: Int64): Int64 {
    if (a < b) { a } else { b }
}

// ---------- 字符串/数字转换 ----------

// ---------- Base64 编码 ----------

private let BASE64_TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
private let BASE64_RUNES: Array<Rune> = BASE64_TABLE.toRuneArray()

/**
 * 将字节数组编码为 Base64 字符串（RFC 4648 标准字母表）。
 *
 * 每 3 个字节编码为 4 个 Base64 字符，不足 3 字节时以 '=' 填充。
 * 用于 HTTP Basic 认证和 TLS 诊断数据的编码。
 */
public func base64EncodeBytes(data: Array<UInt8>): String {
    var result = ArrayList<Rune>(((data.size + 2) / 3) * 4)
    var i: Int64 = 0
    while (i < data.size) {
        let b0 = UInt32(data[i])
        let remaining = data.size - i
        let b1 = if (remaining > 1) { UInt32(data[i + 1]) } else { UInt32(0) }
        let b2 = if (remaining > 2) { UInt32(data[i + 2]) } else { UInt32(0) }

        let triple = (b0 << 16) | (b1 << 8) | b2
        result.add(BASE64_RUNES[Int64((triple >> 18) & 0x3f)])
        result.add(BASE64_RUNES[Int64((triple >> 12) & 0x3f)])

        if (remaining > 1) {
            result.add(BASE64_RUNES[Int64((triple >> 6) & 0x3f)])
        } else {
            result.add(r'=')
        }

        if (remaining > 2) {
            result.add(BASE64_RUNES[Int64(triple & 0x3f)])
        } else {
            result.add(r'=')
        }

        i += 3
    }
    String(result.toArray())
}

/**
 * 将字符串编码为 Base64 字符串（RFC 4648 标准字母表）。
 * 等价于 base64EncodeBytes(stringToBytes(s))。
 */
public func base64EncodeString(s: String): String {
    base64EncodeBytes(unsafe { s.rawData() })
}
/**
 * Base64 解码表（RFC 4648 标准字母表反向映射）。
 * 将 Base64 字符映射回 6 位值（-1 表示非法字符）。
 */
private let BASE64_DECODE_TABLE: Array<Int64> = buildBase64DecodeTable()

private func buildBase64DecodeTable(): Array<Int64> {
    let table = Array<Int64>(256, repeat: -1)
    var i: Int64 = 0
    let alphabet = BASE64_RUNES
    while (i < alphabet.size) {
        table[Int64(UInt32(alphabet[i]))] = i
        i += 1
    }
    table
}

/**
 * 将 Base64 字符串解码为字节数组（RFC 4648 标准字母表）。
 * 支持标准的 Base64（带 '=' 填充）。
 *
 * @param s Base64 编码的字符串
 * @return 解码后的字节数组
 */
public func base64DecodeBytes(s: String): Array<UInt8> {
    let runes = s.toRuneArray()
    var result = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i + 3 < runes.size + 1) {
        var values = Array<Int64>(4, repeat: -1)
        var validCount: Int64 = 0
        while (validCount < 4 && i < runes.size) {
            let r = runes[i]
            i += 1
            if (r == r'=') {
                break
            }
            let code = Int64(UInt32(r))
            if (code >= 256) { continue }
            let v = BASE64_DECODE_TABLE[code]
            if (v >= 0) {
                values[validCount] = v
                validCount += 1
            }
        }
        if (validCount < 2) { break }

        let b0 = UInt8((values[0] << 2 | values[1] >> 4) & 0xFF)
        result.add(b0)

        if (validCount > 2) {
            let b1 = UInt8((values[1] << 4 | values[2] >> 2) & 0xFF)
            result.add(b1)
        }

        if (validCount > 3) {
            let b2 = UInt8((values[2] << 6 | values[3]) & 0xFF)
            result.add(b2)
        }
    }
    result.toArray()
}

/**
 * 将 Base64 字符串解码为字符串（RFC 4648 标准字母表）。
 *
 * @param s Base64 编码的字符串
 * @return 解码后的字符串
 */
public func base64DecodeString(s: String): String {
    String.fromUtf8(base64DecodeBytes(s))
}


// ---------- 大小写不敏感字节比较 ----------

/**
 * 比较两个字节数组是否相等。
 * 逐字节比较，大小写敏感。用于 HTTP 中需要精确匹配的场景。
 */
public func arraysEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
    if (a.size != b.size) { return false }
    var i: Int64 = 0
    while (i < a.size) {
        if (a[i] != b[i]) { return false }
        i += 1
    }
    true
}

/**
 * 大小写不敏感相等检查：比较 ASCII 字节数组与 Rune 数组。
 * 将大写 ASCII 字母映射到小写后逐元素比较。
 * 用于 HTTP 头部值比较（如 "Content-Type" 与 "content-type" 视为相等）。
 */
public func equalsIgnoreCaseBytesRunes(a: Array<UInt8>, b: Array<Rune>): Bool {
    if (a.size != b.size) { return false }
    var i: Int64 = 0
    while (i < a.size) {
        let ab = if (a[i] >= b'A' && a[i] <= b'Z') { a[i] + 32 } else { a[i] }
        let bbVal = UInt32(b[i])
        let bb = if (bbVal >= 65 && bbVal <= 90) { UInt8(bbVal + 32) } else { UInt8(bbVal) }
        if (ab != bb) { return false }
        i += 1
    }
    true
}

/**
 * 大小写不敏感相等检查：比较两个字节数组。
 */
public func equalsIgnoreCaseBytes(a: Array<UInt8>, b: Array<UInt8>): Bool {
    if (a.size != b.size) { return false }
    var i: Int64 = 0
    while (i < a.size) {
        let ab = if (a[i] >= b'A' && a[i] <= b'Z') { a[i] + 32 } else { a[i] }
        let bb = if (b[i] >= b'A' && b[i] <= b'Z') { b[i] + 32 } else { b[i] }
        if (ab != bb) { return false }
        i += 1
    }
    true
}

/**
 * 大小写不敏感子串搜索。
 *
 * 在 data 中查找 needle，两者均为字节数组。
 * 若在 data 的任意位置（不限于开头）找到 needle 则返回 true。
 * 用于 Connection、Content-Encoding 等头部值的匹配。
 */
public func containsIgnoreCaseBytes(data: Array<UInt8>, needle: Array<UInt8>): Bool {
    if (needle.size == 0) { return true }
    if (needle.size > data.size) { return false }
    var i: Int64 = 0
    while (i <= data.size - needle.size) {
        var isMatch = true
        var j: Int64 = 0
        while (j < needle.size) {
            let db = if (data[i + j] >= b'A' && data[i + j] <= b'Z') { data[i + j] + 32 } else { data[i + j] }
            let nb = if (needle[j] >= b'A' && needle[j] <= b'Z') { needle[j] + 32 } else { needle[j] }
            if (db != nb) { isMatch = false; break }
            j += 1
        }
        if (isMatch) { return true }
        i += 1
    }
    false
}

/**
 * 大小写不敏感子串搜索（字节数组 vs Rune 数组）。
 * 在字节数组中搜索 Rune 类型的 needle。当调用方已有 Rune 数组时
 * 避免一次 String.toRuneArray() 转换。
 */
public func containsIgnoreCase(data: Array<UInt8>, needle: Array<Rune>): Bool {
    if (needle.size == 0) { return true }
    if (needle.size > data.size) { return false }
    var i: Int64 = 0
    while (i <= data.size - needle.size) {
        var isMatch = true
        var j: Int64 = 0
        while (j < needle.size) {
            let db = if (data[i + j] >= b'A' && data[i + j] <= b'Z') { data[i + j] + 32 } else { data[i + j] }
            let nbVal = UInt32(needle[j])
            let nb = if (nbVal >= 65 && nbVal <= 90) { UInt8(nbVal + 32) } else { UInt8(nbVal) }
            if (db != nb) { isMatch = false; break }
            j += 1
        }
        if (isMatch) { return true }
        i += 1
    }
    false
}

/**
 * 检查字节数组是否以指定前缀开头，大小写不敏感。
 * 用于检查传输编码或连接选项的起始部分。
 */
public func startsWithIgnoreCase(data: Array<UInt8>, prefix: Array<UInt8>): Bool {
    if (prefix.size > data.size) { return false }
    var i: Int64 = 0
    while (i < prefix.size) {
        let db = if (data[i] >= b'A' && data[i] <= b'Z') { data[i] + 32 } else { data[i] }
        let pb = if (prefix[i] >= b'A' && prefix[i] <= b'Z') { prefix[i] + 32 } else { prefix[i] }
        if (db != pb) { return false }
        i += 1
    }
    true
}

// ---------- 字符串转换 ----------

/**
 * 将 ASCII 字符串转换为小写。
 * 仅影响 ASCII 字母（A-Z），其他字符保持不变。
 * 用于 HTTP 头部名和值的归一化。
 */
public func asciiToLower(s: String): String {
    let runes = s.toRuneArray()
    var result = ArrayList<Rune>(runes.size)
    for (r in runes) {
        let cp = UInt32(r)
        if (cp >= 65 && cp <= 90) {  // A-Z 转 a-z（ASCII 大写转小写）
            result.add(Rune(cp + 32))
        } else {
            result.add(r)
        }
    }
    String(result.toArray())
}

/**
 * 去除字符串两端的 ASCII 空白字符（空格和制表符）。
 */
public func asciiTrim(s: String): String {
    s.trimAscii()
}

/**
 * 将字符串转换为字节数组（UTF-8 编码）。
 * 使用 String.toArray() 直接返回底层 UTF-8 字节。
 * 这是 `unsafe { str.rawData() }` 的安全替代方案，
 * 在代码库中应统一使用以避免字符串转换时的 unsafe 块。
 */
public func stringToBytes(s: String): Array<UInt8> {
    s.toArray()
}

/**
 * 在两个字符串值上进行大小写不敏感子串搜索。
 * 这是对 `unsafe { haystack.rawData() }` + `containsIgnoreCase(runeArray)`
 * 模式的安全替代方案。两个字符串都通过安全的 stringToBytes 辅助函数
 * 转换为字节数组，然后使用已有的 containsIgnoreCaseBytes 函数。
 */
public func containsIgnoreCaseString(haystack: String, needle: String): Bool {
    let haystackBytes = stringToBytes(haystack)
    let needleBytes = stringToBytes(needle)
    containsIgnoreCaseBytes(haystackBytes, needleBytes)
}

/**
 * 将字节数组通过 UTF-8 转换为字符串。
 * 等价于 String.fromUtf8(data)。
 */
public func bytesToString(data: Array<UInt8>): String {
    String.fromUtf8(data)
}

// ---------- URL 编码 ----------

/**
 * 对字符串进行 application/x-www-form-urlencoded 的百分号编码。
 */
public func formUrlEncode(s: String): String {
    let hexUpper = unsafe { "0123456789ABCDEF".rawData() }
    let bytes = s.toArray()
    let result = ArrayList<UInt8>()
    for (b in bytes) {
        if ((b >= b'A' && b <= b'Z') || (b >= b'a' && b <= b'z') ||
            (b >= b'0' && b <= b'9') || b == b'-' || b == b'_' || b == b'.' || b == b'~') {
            result.add(b)
        } else if (b == b' ') {
            result.add(b'+')
        } else {
            result.add(b'%')
            result.add(hexUpper[Int64((b >> 4) & 0x0f)])
            result.add(hexUpper[Int64(b & 0x0f)])
        }
    }
    unsafe { String.withRawData(result.toArray()) }
}
