package compress4cj.common

import std.collection.ArrayList

/**
 * 将 ArrayList<UInt8> 转换为 Array<UInt8>。
 */
public func toUInt8Array(list: ArrayList<UInt8>): Array<UInt8> {
    let n = list.size
    if (n == 0) { return [] }
    let result = Array<UInt8>(n, repeat: 0)
    for (i in 0..n) {
        result[i] = list[i]
    }
    result
}

/**
 * 将 ASCII 字符串转换为 UInt8 数组。
 */
public func strToBytes(s: String): Array<UInt8> {
    Array<UInt8>(s.size, {i => s[i]})
}

/**
 * 比较两个 UInt8 数组是否相等。
 */
public func bytesEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
    if (a.size != b.size) { return false }
    for (i in 0..a.size) {
        if (a[i] != b[i]) { return false }
    }
    true
}
