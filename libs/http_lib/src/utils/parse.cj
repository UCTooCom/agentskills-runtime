package http_lib.utils

import std.collection.{ArrayList, HashMap}

/**
 * 端口字符串解析工具函数。
 *
 * 将字符串形式的端口号解析为 UInt16。使用 UInt64 中间值
 * 防止乘法溢出。值超出 0-65535 范围时抛出异常。
 */

/**
 * 将端口字符串解析为 UInt16。
 *
 * @param portStr 端口号字符串（如 "80"、"443"）
 * @return 解析后的端口号
 * @throws Exception 端口格式无效或超出范围时抛出
 */
public func parsePortString(portStr: String): UInt16 {
    let bytes = portStr.toArray()
    var p: UInt64 = 0
    for (b in bytes) {
        if (b >= b'0' && b <= b'9') {
            p = p * 10 + UInt64(b - b'0')
            if (p > 65535) {
                throw Exception("端口超出范围: '${portStr}'")
            }
        } else {
            throw Exception("invalid port: '${portStr}'")
        }
    }
    UInt16(p)
}

// ---------- URL 解码 ----------

/**
 * 对 application/x-www-form-urlencoded 格式的字符串进行百分号解码。
 * 将 %XX 转换为对应字节，将 + 转换为空格。
 *
 * @param s URL 编码的字符串
 * @return 解码后的字符串
 */
public func formUrlDecode(s: String): String {
    let bytes = s.toArray()
    let result = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i < bytes.size) {
        if (bytes[i] == b'+') {
            result.add(b' ')
            i++
        } else if (bytes[i] == b'%' && i + 2 < bytes.size) {
            let hi = _hexVal(bytes[i + 1])
            let lo = _hexVal(bytes[i + 2])
            if (hi >= 0 && lo >= 0) {
                result.add(UInt8((hi << 4) | lo))
                i += 3
            } else {
                result.add(bytes[i])
                i++
            }
        } else {
            result.add(bytes[i])
            i++
        }
    }
    String.fromUtf8(result.toArray())
}

/**
 * 将十六进制字符转换为数值（0-15）。
 */
private func _hexVal(b: UInt8): Int64 {
    if (b >= b'0' && b <= b'9') { Int64(b - b'0') }
    else if (b >= b'A' && b <= b'F') { Int64(b - b'A' + 10) }
    else if (b >= b'a' && b <= b'f') { Int64(b - b'a' + 10) }
    else { -1 }
}

// ---------- Cookie 解析 ----------

/**
 * 解析 Cookie HTTP 头，返回所有 cookie 名称到值的映射。
 *
 * 支持 RFC 6265 定义的 Cookie 头格式：
 *   Cookie: name1=value1; name2=value2
 *
 * 对 cookie 名称和值进行 URL 解码（%XX 和 + → 空格）。
 * 重复的 cookie 名称以后出现的值为准。
 *
 * 用法（服务端处理器）：
 *   let cookies = parseCookies(req.headers.get("cookie").getOrElse(""))
 *   let sessionId = cookies.get("session_id")
 *
 * @param cookieHeader Cookie 头的值（如 "name1=value1; name2=value2"）
 * @return 解析后的 cookie 键值对映射
 */
public func parseCookies(cookieHeader: String): HashMap<String, String> {
    let result = HashMap<String, String>()
    if (cookieHeader.size == 0) { return result }

    // 按 ; 分割，每个 cookie-pair
    let bytes = cookieHeader.toArray()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i <= bytes.size) {
        if (i == bytes.size || bytes[i] == b';') {
            // 解析 start..i 范围内的一个 cookie-pair
            if (i > start) {
                _parseSingleCookie(bytes[start..i], result)
            }
            start = i + 1
        }
        i++
    }
    result
}

/**
 * 解析单个 cookie-pair（name=value），可能包含前导/尾部空白。
 */
private func _parseSingleCookie(data: Array<UInt8>, result: HashMap<String, String>): Unit {
    // 去除前导空白
    var nameStart: Int64 = 0
    while (nameStart < data.size && (data[nameStart] == b' ' || data[nameStart] == b'\t')) {
        nameStart++
    }
    if (nameStart >= data.size) { return }

    // 找到第一个 =
    var eqPos: Int64 = nameStart
    while (eqPos < data.size && data[eqPos] != b'=') {
        eqPos++
    }
    if (eqPos >= data.size) { return }

    // 提取名称（去除尾部空白）
    var nameEnd: Int64 = eqPos
    while (nameEnd > nameStart && (data[nameEnd - 1] == b' ' || data[nameEnd - 1] == b'\t')) {
        nameEnd--
    }
    let nameBytes = data[nameStart..nameEnd]
    let name = String.fromUtf8(nameBytes)

    // 提取值（去除前导/尾部空白）
    var valStart: Int64 = eqPos + 1
    while (valStart < data.size && (data[valStart] == b' ' || data[valStart] == b'\t')) {
        valStart++
    }
    var valEnd: Int64 = data.size
    while (valEnd > valStart && (data[valEnd - 1] == b' ' || data[valEnd - 1] == b'\t')) {
        valEnd--
    }
    let valueBytes = data[valStart..valEnd]
    let value = String.fromUtf8(valueBytes)

    // URL 解码后存储
    if (name.size > 0) {
        result[formUrlDecode(name)] = formUrlDecode(value)
    }
}
