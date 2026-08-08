/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.crypto.PBKDF2

class BinTools {
    public static let hex = "0123456789ABCDEF".toArray()

    public static func bin2hex(b: Array<Byte>): String {
        var sb = StringBuilder(2 * b.size)
        for (i in 0..b.size) {
            var v = Int64(b[i]) % 256
            sb.append(hex[((v / 16) & 15)])
            sb.append(hex[((v % 16) & 15)])
        }
        return sb.toString()
    }

    public static func hex2bin(s: String): Array<Byte> {
        var m = s.toRuneArray()
        if (s.size % 2 != 0) {
            // Assume leading zero for odd string length
            m = "0${s}".toRuneArray()
        }
        var r = Array<Byte>(m.size / 2, repeat: 0)
        var i = 0
        for (n in 0..m.size) {
            var h = m[i]
            i++
            var l = m[i]
            i++
            r[n] = UInt8(hex2bin(h) * 16 + hex2bin(l))
        }
        return r
    }

    public static func hex2bin(i: Rune) {
        let c = UInt32(i)
        if (c >= UInt32(r'0') && c <= UInt32(r'9')) {
            return (c - UInt32(r'0'))
        }
        if (c >= UInt32(r'A') && c <= UInt32(r'F')) {
            return (c - UInt32(r'A') + 10)
        }
        if (c >= UInt32(r'a') && c <= UInt32(r'f')) {
            return (c - UInt32(r'a') + 10)
        }
        throw IllegalArgumentException("Input string may only contain hex digits, but found '${i}'")
    }
}
