/*
 * crypto.cj —— 驱动自带的密码学原语。
 *
 * 仓颉标准库 std.crypto.digest 仅提供 `Digest` 抽象接口，并未随包发布 SHA-256、
 * HMAC 等具体算法实现，因此为了让本驱动在仅依赖 std 的前提下完成 PostgreSQL 的
 * SCRAM-SHA-256 / MD5 认证，这里用纯仓颉实现所需的全部原语：
 *   - Base64 编解码（SCRAM 的 salt、proof 传输）
 *   - SHA-256 摘要（RFC 6234）
 *   - MD5 摘要（RFC 1321，用于 AuthenticationMD5Password）
 *   - HMAC-SHA-256（RFC 2104）
 *   - PBKDF2-HMAC-SHA-256（RFC 8018，即 SCRAM 的 Hi 函数）
 *   - 十六进制编码
 */

package pgsql

import std.collection.*

// Base64 标准字母表（RFC 4648），下标即编码后的 6bit 值。
private const BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

/**
 * 将字节数组编码为标准 Base64 字符串（带 `=` 填充）。
 *
 * @param data 待编码的原始字节。
 * @return Base64 文本。
 */
public func base64Encode(data: Array<Byte>): String {
    // 预先按 4/3 比例估算输出容量，避免反复扩容。
    let sb = StringBuilder()
    let table = BASE64_ALPHABET.toArray()
    var i = 0
    // 每次处理 3 字节（24bit），输出 4 个 Base64 字符。
    while (i + 3 <= data.size) {
        let n = (UInt32(data[i]) << 16) | (UInt32(data[i + 1]) << 8) | UInt32(data[i + 2])
        sb.append(Rune(table[Int64((n >> 18) & 0x3F)]))
        sb.append(Rune(table[Int64((n >> 12) & 0x3F)]))
        sb.append(Rune(table[Int64((n >> 6) & 0x3F)]))
        sb.append(Rune(table[Int64(n & 0x3F)]))
        i += 3
    }
    // 处理尾部剩余的 1 或 2 字节，并以 '=' 补齐到 4 字符。
    let rem = data.size - i
    if (rem == 1) {
        let n = UInt32(data[i]) << 16
        sb.append(Rune(table[Int64((n >> 18) & 0x3F)]))
        sb.append(Rune(table[Int64((n >> 12) & 0x3F)]))
        sb.append(r'=')
        sb.append(r'=')
    } else if (rem == 2) {
        let n = (UInt32(data[i]) << 16) | (UInt32(data[i + 1]) << 8)
        sb.append(Rune(table[Int64((n >> 18) & 0x3F)]))
        sb.append(Rune(table[Int64((n >> 12) & 0x3F)]))
        sb.append(Rune(table[Int64((n >> 6) & 0x3F)]))
        sb.append(r'=')
    }
    return sb.toString()
}

// 将单个 Base64 字符还原为对应的 6bit 数值，非法字符返回 -1。
private func base64DecodeChar(c: Byte): Int64 {
    if (c >= b'A' && c <= b'Z') {
        return Int64(c - b'A')
    } else if (c >= b'a' && c <= b'z') {
        return Int64(c - b'a') + 26
    } else if (c >= b'0' && c <= b'9') {
        return Int64(c - b'0') + 52
    } else if (c == b'+') {
        return 62
    } else if (c == b'/') {
        return 63
    }
    return -1
}

/**
 * 解码标准 Base64 字符串为字节数组，忽略空白字符，容忍缺省填充。
 *
 * @param s Base64 文本。
 * @return 解码后的原始字节。
 */
public func base64Decode(s: String): Array<Byte> {
    let out = ArrayList<Byte>()
    var acc: UInt32 = 0
    var bits = 0
    for (c in s.toArray()) {
        // 跳过 '='、换行、空格等非数据字符。
        if (c == b'=' || c == b'\n' || c == b'\r' || c == b' ' || c == b'\t') {
            continue
        }
        let v = base64DecodeChar(c)
        if (v < 0) {
            continue
        }
        // 把新的 6bit 拼到累加器尾部，凑满 8bit 即输出一个字节。
        acc = (acc << 6) | UInt32(v)
        bits += 6
        if (bits >= 8) {
            bits -= 8
            out.add(UInt8((acc >> UInt32(bits)) & 0xFF))
        }
    }
    return out.toArray()
}

/**
 * 将字节数组编码为小写十六进制字符串。
 *
 * @param data 原始字节。
 * @return 十六进制文本，长度为 `data.size * 2`。
 */
public func toHex(data: Array<Byte>): String {
    let digits = "0123456789abcdef".toArray()
    let sb = StringBuilder()
    for (b in data) {
        sb.append(Rune(digits[Int64(b >> 4)]))
        sb.append(Rune(digits[Int64(b & 0x0F)]))
    }
    return sb.toString()
}

// ===== SHA-256（RFC 6234）=====

// SHA-256 的 64 个轮常量（前 64 个素数立方根小数部分的前 32bit）。
private let SHA256_K: Array<UInt32> = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
]

// 32 位循环右移。
@OverflowWrapping
private func rotr32(x: UInt32, n: UInt32): UInt32 {
    return (x >> n) | (x << (32 - n))
}

/**
 * 计算输入数据的 SHA-256 摘要。
 *
 * @param data 原始字节。
 * @return 32 字节摘要。
 */
@OverflowWrapping
public func sha256(data: Array<Byte>): Array<Byte> {
    // 初始哈希值 H0..H7（前 8 个素数平方根小数部分前 32bit）。
    var h0: UInt32 = 0x6a09e667
    var h1: UInt32 = 0xbb67ae85
    var h2: UInt32 = 0x3c6ef372
    var h3: UInt32 = 0xa54ff53a
    var h4: UInt32 = 0x510e527f
    var h5: UInt32 = 0x9b05688c
    var h6: UInt32 = 0x1f83d9ab
    var h7: UInt32 = 0x5be0cd19

    // 预处理：追加 0x80、若干 0x00，再补 64bit 的位长度，使总长度为 64 字节的整数倍。
    let msgLen = data.size
    let bitLen = UInt64(msgLen) * 8
    var padded = ArrayList<Byte>(data)
    padded.add(0x80)
    while (padded.size % 64 != 56) {
        padded.add(0x00)
    }
    // 以大端序写入 64bit 消息位长度。
    var lenIdx = 7
    while (lenIdx >= 0) {
        padded.add(UInt8((bitLen >> UInt64(lenIdx * 8)) & 0xFF))
        lenIdx -= 1
    }

    let blocks = padded.toArray()
    let w = Array<UInt32>(64, repeat: 0)
    var blockStart = 0
    // 逐个 512bit 分块处理。
    while (blockStart < blocks.size) {
        // 1) 将 16 个大端 32bit 字读入消息调度数组的前 16 项。
        var t = 0
        while (t < 16) {
            let off = blockStart + t * 4
            w[t] = (UInt32(blocks[off]) << 24) | (UInt32(blocks[off + 1]) << 16) |
                (UInt32(blocks[off + 2]) << 8) | UInt32(blocks[off + 3])
            t += 1
        }
        // 2) 扩展生成剩余 48 个字。
        t = 16
        while (t < 64) {
            let s0 = rotr32(w[t - 15], 7) ^ rotr32(w[t - 15], 18) ^ (w[t - 15] >> 3)
            let s1 = rotr32(w[t - 2], 17) ^ rotr32(w[t - 2], 19) ^ (w[t - 2] >> 10)
            w[t] = w[t - 16] + s0 + w[t - 7] + s1
            t += 1
        }
        // 3) 压缩函数：8 个工作变量迭代 64 轮。
        var a = h0
        var b = h1
        var c = h2
        var d = h3
        var e = h4
        var f = h5
        var g = h6
        var hh = h7
        t = 0
        while (t < 64) {
            let bigS1 = rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25)
            let ch = (e & f) ^ ((!e) & g)
            let temp1 = hh + bigS1 + ch + SHA256_K[t] + w[t]
            let bigS0 = rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = bigS0 + maj
            hh = g
            g = f
            f = e
            e = d + temp1
            d = c
            c = b
            b = a
            a = temp1 + temp2
            t += 1
        }
        // 4) 累加回链接变量。
        h0 += a
        h1 += b
        h2 += c
        h3 += d
        h4 += e
        h5 += f
        h6 += g
        h7 += hh
        blockStart += 64
    }

    // 以大端序拼接 8 个哈希字得到 32 字节摘要。
    return u32sToBytesBE([h0, h1, h2, h3, h4, h5, h6, h7])
}

// 将一组 UInt32 以大端序展开为字节数组。
private func u32sToBytesBE(words: Array<UInt32>): Array<Byte> {
    let out = Array<Byte>(words.size * 4, repeat: 0)
    for (i in 0..words.size) {
        out[i * 4] = UInt8((words[i] >> 24) & 0xFF)
        out[i * 4 + 1] = UInt8((words[i] >> 16) & 0xFF)
        out[i * 4 + 2] = UInt8((words[i] >> 8) & 0xFF)
        out[i * 4 + 3] = UInt8(words[i] & 0xFF)
    }
    return out
}

// ===== MD5（RFC 1321，用于 AuthenticationMD5Password）=====

// MD5 每轮左移位数表。
private let MD5_S: Array<UInt32> = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
]

// MD5 轮常量 K[i] = floor(2^32 * abs(sin(i+1)))。
private let MD5_K: Array<UInt32> = [
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
]

// 32 位循环左移。
@OverflowWrapping
private func rotl32(x: UInt32, n: UInt32): UInt32 {
    return (x << n) | (x >> (32 - n))
}

/**
 * 计算输入数据的 MD5 摘要。
 *
 * @param data 原始字节。
 * @return 16 字节摘要。
 */
@OverflowWrapping
public func md5(data: Array<Byte>): Array<Byte> {
    var a0: UInt32 = 0x67452301
    var b0: UInt32 = 0xefcdab89
    var c0: UInt32 = 0x98badcfe
    var d0: UInt32 = 0x10325476

    // 预处理：追加 0x80 与 0x00，使长度对 64 取模为 56，再补 64bit 小端位长度。
    let bitLen = UInt64(data.size) * 8
    var padded = ArrayList<Byte>(data)
    padded.add(0x80)
    while (padded.size % 64 != 56) {
        padded.add(0x00)
    }
    var i = 0
    while (i < 8) {
        padded.add(UInt8((bitLen >> UInt64(i * 8)) & 0xFF))
        i += 1
    }

    let blocks = padded.toArray()
    let m = Array<UInt32>(16, repeat: 0)
    var blockStart = 0
    while (blockStart < blocks.size) {
        // 以小端序读入 16 个 32bit 字。
        var j = 0
        while (j < 16) {
            let off = blockStart + j * 4
            m[j] = UInt32(blocks[off]) | (UInt32(blocks[off + 1]) << 8) |
                (UInt32(blocks[off + 2]) << 16) | (UInt32(blocks[off + 3]) << 24)
            j += 1
        }
        var a = a0
        var b = b0
        var c = c0
        var d = d0
        var t = 0
        while (t < 64) {
            var f: UInt32 = 0
            var g = 0
            // 四个阶段使用不同的非线性函数 F/G/H/I 与不同的消息字索引。
            if (t < 16) {
                f = (b & c) | ((!b) & d)
                g = t
            } else if (t < 32) {
                f = (d & b) | ((!d) & c)
                g = (5 * t + 1) % 16
            } else if (t < 48) {
                f = b ^ c ^ d
                g = (3 * t + 5) % 16
            } else {
                f = c ^ (b | (!d))
                g = (7 * t) % 16
            }
            f = f + a + MD5_K[t] + m[g]
            a = d
            d = c
            c = b
            b = b + rotl32(f, MD5_S[t])
            t += 1
        }
        a0 += a
        b0 += b
        c0 += c
        d0 += d
        blockStart += 64
    }

    // 以小端序输出 4 个链接变量，得到 16 字节摘要。
    return u32sToBytesLE([a0, b0, c0, d0])
}

// 将一组 UInt32 以小端序展开为字节数组。
private func u32sToBytesLE(words: Array<UInt32>): Array<Byte> {
    let out = Array<Byte>(words.size * 4, repeat: 0)
    for (i in 0..words.size) {
        out[i * 4] = UInt8(words[i] & 0xFF)
        out[i * 4 + 1] = UInt8((words[i] >> 8) & 0xFF)
        out[i * 4 + 2] = UInt8((words[i] >> 16) & 0xFF)
        out[i * 4 + 3] = UInt8((words[i] >> 24) & 0xFF)
    }
    return out
}

// ===== HMAC-SHA-256（RFC 2104）=====

// SHA-256 的分组长度（字节）。
private const SHA256_BLOCK_SIZE = 64

/**
 * 计算 HMAC-SHA-256。
 *
 * @param key 密钥；超过分组长度时先做 SHA-256，再零填充到分组长度。
 * @param msg 待认证的消息。
 * @return 32 字节 MAC。
 */
public func hmacSha256(key: Array<Byte>, msg: Array<Byte>): Array<Byte> {
    // 规整密钥：过长则先哈希，随后零填充到 64 字节。
    var k = key
    if (k.size > SHA256_BLOCK_SIZE) {
        k = sha256(k)
    }
    let block = Array<Byte>(SHA256_BLOCK_SIZE, repeat: 0)
    for (i in 0..k.size) {
        block[i] = k[i]
    }
    // 构造内外填充：ipad = 0x36、opad = 0x5c 与密钥逐字节异或。
    let ipad = Array<Byte>(SHA256_BLOCK_SIZE, repeat: 0)
    let opad = Array<Byte>(SHA256_BLOCK_SIZE, repeat: 0)
    for (i in 0..SHA256_BLOCK_SIZE) {
        ipad[i] = block[i] ^ 0x36
        opad[i] = block[i] ^ 0x5c
    }
    // inner = H(ipad || msg)
    let innerInput = ArrayList<Byte>(ipad)
    innerInput.add(all: msg)
    let innerHash = sha256(innerInput.toArray())
    // HMAC = H(opad || inner)
    let outerInput = ArrayList<Byte>(opad)
    outerInput.add(all: innerHash)
    return sha256(outerInput.toArray())
}

/**
 * PBKDF2-HMAC-SHA-256（RFC 8018），即 SCRAM 的 Hi 函数。
 *
 * 由于 SCRAM 的派生密钥长度固定为 32 字节（与 HMAC-SHA-256 输出等长），
 * 这里只需计算单个数据块 T1 即可。
 *
 * @param password 口令字节。
 * @param salt 盐值。
 * @param iterations 迭代次数。
 * @param dkLen 期望派生密钥长度（字节）。
 * @return 长度为 `dkLen` 的派生密钥。
 */
public func pbkdf2HmacSha256(password: Array<Byte>, salt: Array<Byte>, iterations: Int64, dkLen: Int64): Array<Byte> {
    let hLen = 32
    // 计算需要的数据块数量，向上取整。
    let blockCount = (dkLen + hLen - 1) / hLen
    let result = ArrayList<Byte>()
    var blockIndex = 1
    while (blockIndex <= blockCount) {
        // U1 = HMAC(password, salt || INT_BE(blockIndex))
        let salted = ArrayList<Byte>(salt)
        salted.add(UInt8((blockIndex >> 24) & 0xFF))
        salted.add(UInt8((blockIndex >> 16) & 0xFF))
        salted.add(UInt8((blockIndex >> 8) & 0xFF))
        salted.add(UInt8(blockIndex & 0xFF))
        var u = hmacSha256(password, salted.toArray())
        let t = Array<Byte>(hLen, repeat: 0)
        for (i in 0..hLen) {
            t[i] = u[i]
        }
        // 迭代：U(c) = HMAC(password, U(c-1))，并把每次结果异或进 T。
        var iter = 1
        while (iter < iterations) {
            u = hmacSha256(password, u)
            for (i in 0..hLen) {
                t[i] ^= u[i]
            }
            iter += 1
        }
        result.add(all: t)
        blockIndex += 1
    }
    // 截断到期望长度。
    let out = Array<Byte>(dkLen, repeat: 0)
    let full = result.toArray()
    for (i in 0..dkLen) {
        out[i] = full[i]
    }
    return out
}
