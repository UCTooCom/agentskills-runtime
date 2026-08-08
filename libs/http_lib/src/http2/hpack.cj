package http_lib.http2

import std.collection.ArrayList
import std.collection.HashMap
import http_lib.core.HttpHeaders

// ---- 模块级类型和常量 ----

class DynamicEntry {
    public let name: String
    public let lowerName: String
    public let value: String
    public let size: Int64

    public init(name: String, lowerName: String, value: String) {
        this.name = name
        this.lowerName = lowerName
        this.value = value
        this.size = name.size + value.size + 32
    }
}

class StaticEntry {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

let STATIC_TABLE_SIZE: Int64 = 61



let staticTable: Array<StaticEntry> = [
    StaticEntry(":authority", ""),
    StaticEntry(":method", "GET"),
    StaticEntry(":method", "POST"),
    StaticEntry(":path", "/"),
    StaticEntry(":path", "/index.html"),
    StaticEntry(":scheme", "http"),
    StaticEntry(":scheme", "https"),
    StaticEntry(":status", "200"),
    StaticEntry(":status", "204"),
    StaticEntry(":status", "206"),
    StaticEntry(":status", "304"),
    StaticEntry(":status", "400"),
    StaticEntry(":status", "404"),
    StaticEntry(":status", "500"),
    StaticEntry("accept-charset", ""),
    StaticEntry("accept-encoding", "gzip, deflate"),
    StaticEntry("accept-language", ""),
    StaticEntry("accept-ranges", ""),
    StaticEntry("accept", ""),
    StaticEntry("access-control-allow-origin", ""),
    StaticEntry("age", ""),
    StaticEntry("allow", ""),
    StaticEntry("authorization", ""),
    StaticEntry("cache-control", ""),
    StaticEntry("content-disposition", ""),
    StaticEntry("content-encoding", ""),
    StaticEntry("content-language", ""),
    StaticEntry("content-length", ""),
    StaticEntry("content-location", ""),
    StaticEntry("content-range", ""),
    StaticEntry("content-type", ""),
    StaticEntry("cookie", ""),
    StaticEntry("date", ""),
    StaticEntry("etag", ""),
    StaticEntry("expect", ""),
    StaticEntry("expires", ""),
    StaticEntry("from", ""),
    StaticEntry("host", ""),
    StaticEntry("if-match", ""),
    StaticEntry("if-modified-since", ""),
    StaticEntry("if-none-match", ""),
    StaticEntry("if-range", ""),
    StaticEntry("if-unmodified-since", ""),
    StaticEntry("last-modified", ""),
    StaticEntry("link", ""),
    StaticEntry("location", ""),
    StaticEntry("max-forwards", ""),
    StaticEntry("proxy-authenticate", ""),
    StaticEntry("proxy-authorization", ""),
    StaticEntry("range", ""),
    StaticEntry("referer", ""),
    StaticEntry("refresh", ""),
    StaticEntry("retry-after", ""),
    StaticEntry("server", ""),
    StaticEntry("set-cookie", ""),
    StaticEntry("strict-transport-security", ""),
    StaticEntry("transfer-encoding", ""),
    StaticEntry("user-agent", ""),
    StaticEntry("vary", ""),
    StaticEntry("via", ""),
    StaticEntry("www-authenticate", ""),
]

// ---- 哈夫曼编码表（RFC 7541 Appendix B） ----

let HUFFMAN_CODES: Array<UInt32> = [
    0x1ff8, 0x7fffd8, 0xfffffe2, 0xfffffe3, 0xfffffe4, 0xfffffe5, 0xfffffe6, 0xfffffe7,
    0xfffffe8, 0xffffea, 0x3ffffffc, 0xfffffe9, 0xfffffea, 0x3ffffffd, 0xfffffeb, 0xfffffec,
    0xfffffed, 0xfffffee, 0xfffffef, 0xffffff0, 0xffffff1, 0xffffff2, 0x3ffffffe, 0xffffff3,
    0xffffff4, 0xffffff5, 0xffffff6, 0xffffff7, 0xffffff8, 0xffffff9, 0xffffffa, 0xffffffb,
    0x14, 0x3f8, 0x3f9, 0xffa, 0x1ff9, 0x15, 0xf8, 0x7fa, 0x3fa, 0x3fb, 0xf9, 0x7fb,
    0xfa, 0x16, 0x17, 0x18, 0x0, 0x1, 0x2, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
    0x5c, 0xfb, 0x7ffc, 0x20, 0xffb, 0x3fc, 0x1ffa, 0x21, 0x5d, 0x5e, 0x5f, 0x60, 0x61,
    0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f,
    0x70, 0x71, 0x72, 0xfc, 0x73, 0xfd, 0x1ffb, 0x7fff0, 0x1ffc, 0x3ffc, 0x22, 0x7ffd,
    0x3, 0x23, 0x4, 0x24, 0x5, 0x25, 0x26, 0x27, 0x6, 0x74, 0x75, 0x28, 0x29, 0x2a, 0x7,
    0x2b, 0x76, 0x2c, 0x8, 0x9, 0x2d, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7ffe, 0x7fc, 0x3ffd,
    0x1ffd, 0xffffffc, 0xfffe6, 0x3fffd2, 0xfffe7, 0xfffe8, 0x3fffd3, 0x3fffd4, 0x3fffd5,
    0x7fffd9, 0x3fffd6, 0x7fffda, 0x7fffdb, 0x7fffdc, 0x7fffdd, 0x7fffde, 0xffffeb, 0x7fffdf,
    0xffffec, 0xffffed, 0x3fffd7, 0x7fffe0, 0xffffee, 0x7fffe1, 0x7fffe2, 0x7fffe3, 0x7fffe4,
    0x1fffdc, 0x3fffd8, 0x7fffe5, 0x3fffd9, 0x7fffe6, 0x7fffe7, 0xffffef, 0x3fffda, 0x1fffdd,
    0xfffe9, 0x3fffdb, 0x3fffdc, 0x7fffe8, 0x7fffe9, 0x1fffde, 0x7fffea, 0x3fffdd, 0x3fffde,
    0xfffff0, 0x1fffdf, 0x3fffdf, 0x7fffeb, 0x7fffec, 0x1fffe0, 0x1fffe1, 0x3fffe0, 0x1fffe2,
    0x7fffed, 0x3fffe1, 0x7fffee, 0x7fffef, 0xfffea, 0x3fffe2, 0x3fffe3, 0x3fffe4, 0x7ffff0,
    0x3fffe5, 0x3fffe6, 0x7ffff1, 0x3ffffe0, 0x3ffffe1, 0xfffeb, 0x7fff1, 0x3fffe7, 0x7ffff2,
    0x3fffe8, 0x1ffffec, 0x3ffffe2, 0x3ffffe3, 0x3ffffe4, 0x7ffffde, 0x7ffffdf, 0x3ffffe5,
    0xfffff1, 0x1ffffed, 0x7fff2, 0x1fffe3, 0x3ffffe6, 0x7ffffe0, 0x7ffffe1, 0x3ffffe7,
    0x7ffffe2, 0xfffff2, 0x1fffe4, 0x1fffe5, 0x3ffffe8, 0x3ffffe9, 0xffffffd, 0x7ffffe3,
    0x7ffffe4, 0x7ffffe5, 0xfffec, 0xfffff3, 0xfffed, 0x1fffe6, 0x3fffe9, 0x1fffe7, 0x1fffe8,
    0x7ffff3, 0x3fffea, 0x3fffeb, 0x1ffffee, 0x1ffffef, 0xfffff4, 0xfffff5, 0x3ffffea,
    0x7ffff4, 0x3ffffeb, 0x7ffffe6, 0x3ffffec, 0x3ffffed, 0x7ffffe7, 0x7ffffe8, 0x7ffffe9,
    0x7ffffea, 0x7ffffeb, 0xffffffe, 0x7ffffec, 0x7ffffed, 0x7ffffee, 0x7ffffef, 0x7fffff0,
    0x3ffffee, 0x3fffffff
]

let HUFFMAN_CODE_LENS: Array<Int64> = [
    13, 23, 28, 28, 28, 28, 28, 28, 28, 24, 30, 28, 28, 30, 28, 28,
    28, 28, 28, 28, 28, 28, 30, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    6, 10, 10, 12, 13, 6, 8, 11, 10, 10, 8, 11, 8, 6, 6, 6,
    5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 7, 8, 15, 6, 12, 10,
    13, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 8, 7, 8, 13, 19, 13, 14, 6,
    15, 5, 6, 5, 6, 5, 6, 6, 6, 5, 7, 7, 6, 6, 6, 5,
    6, 7, 6, 5, 5, 6, 7, 7, 7, 7, 7, 15, 11, 14, 13, 28,
    20, 22, 20, 20, 22, 22, 22, 23, 22, 23, 23, 23, 23, 23, 24, 23,
    24, 24, 22, 23, 24, 23, 23, 23, 23, 21, 22, 23, 22, 23, 23, 24,
    22, 21, 20, 22, 22, 23, 23, 21, 22, 23, 24, 22, 22, 23, 23, 22,
    22, 23, 21, 23, 22, 22, 24, 23, 23, 22, 22, 22, 23, 23, 22, 23,
    23, 22, 21, 22, 22, 21, 22, 23, 23, 22, 23, 23, 22, 22, 22, 22,
    22, 21, 22, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22,
    22, 22, 22, 21, 22, 22, 22, 21, 22, 22, 22, 21, 24, 22, 22, 22,
    22, 21, 22, 22, 21, 20, 22, 22, 22, 22, 23, 21, 21, 21, 23, 22,
    22, 26, 26, 20, 22, 22, 22, 22, 22, 22, 22, 22, 30, 28, 20, 30,
    22, 22, 22, 22, 22, 22, 22, 22, 22, 24, 22, 22, 22, 22, 22, 22,
    22, 22, 21, 22, 21, 30, 21, 22, 22, 21, 22, 21, 22, 22, 22, 23,
    26, 26, 26, 27, 27, 26, 26, 26, 27, 26, 27, 27, 27, 27, 28, 27,
    28, 28, 27, 30, 27, 28, 28, 28, 28, 27, 27, 27, 28, 27, 27, 27,
    27, 27, 27, 27, 28, 30, 28, 30, 30, 30, 28, 30, 28, 28, 28, 28,
    30, 30, 28, 30, 28, 28, 28, 28, 28, 28, 30, 28, 28, 28, 28, 30,
    28, 30, 30, 28, 28, 28, 30, 28, 30, 28, 28, 28, 28, 30, 28, 30,
    30, 28, 30, 28, 30, 30, 30, 28, 30, 30, 30, 28, 30, 28, 28, 28,
    30, 28, 30, 28, 28, 30, 30, 30, 30, 28, 28, 30, 28, 28, 28, 28,
    28, 30, 30, 28, 30, 28, 28, 28, 30, 28, 28, 30, 28, 30, 30, 28,
    30, 28, 28, 28, 28, 28, 30, 30, 28, 30, 28, 28, 28, 28, 28, 28,
    28, 28, 28, 30, 30, 28, 28, 28, 30, 30, 30, 28, 28, 28, 28, 28,
    30, 30, 28, 28, 30, 30, 28, 28, 28, 28, 30, 28, 28, 28, 28, 28,
    30, 30, 30, 30, 30, 30, 28, 30, 30, 30, 30, 28, 28, 28, 28, 30,
    30, 30, 30, 30, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 30,
    28, 30, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
    30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
    30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
    30
]

// ---- 模块级哈夫曼辅助函数 ----

/**
 * Huffman 编码：将字节数组编码为 HPACK Huffman 格式。
 * 使用 RFC 7541 Appendix B 定义的 Huffman 码表进行编码，
 * 用 EOS（全 1）填充到字节边界。
 * 用于 HPACK 头部压缩的字符串字面量编码。
 *
 * @param data 待编码的原始字节数组
 * @return Huffman 编码后的字节数组
 */
public func huffmanEncode(data: Array<UInt8>): Array<UInt8> {
    // 计算总比特长度
    var totalBits: Int64 = 0
    var i: Int64 = 0
    while (i < data.size) {
        let sym = Int64(data[i])
        totalBits += HUFFMAN_CODE_LENS[sym]
        i += 1
    }
    // 用 EOS（全 1）填充到字节边界
    let paddedBits = ((totalBits + 7) / 8) * 8
    let outputLen = paddedBits / 8
    let result = Array<UInt8>(outputLen, repeat: 0)
    var bitBuf: UInt64 = 0
    var bitsInBuf: Int64 = 0
    var pos: Int64 = 0
    i = 0
    while (i < data.size) {
        let sym = Int64(data[i])
        let code = UInt64(HUFFMAN_CODES[sym])
        let codeLen = HUFFMAN_CODE_LENS[sym]
        bitBuf = (bitBuf << codeLen) | code
        bitsInBuf += codeLen
        while (bitsInBuf >= 8) {
            bitsInBuf -= 8
            result[pos] = UInt8((bitBuf >> bitsInBuf) & 0xFF)
            pos += 1
        }
        bitBuf = bitBuf & ((UInt64(1) << bitsInBuf) - 1)
        i += 1
    }
    // 用 EOS（全 1）填充剩余比特
    if (bitsInBuf > 0) {
        let shift = 8 - bitsInBuf
        bitBuf = (bitBuf << shift) | ((UInt64(1) << shift) - 1)
        result[pos] = UInt8(bitBuf & 0xFF)
    }
    result
}

func huffmanDecode(data: Array<UInt8>, offset: Int64, bitLength: Int64): (Array<UInt8>, Int64) {
    let estSize = Int64(bitLength / 4) + 1
    let output = ArrayList<UInt8>(estSize)
    var bitPos: Int64 = offset * 8
    let endBit = bitPos + bitLength
    var currentCode: UInt32 = 0
    var currentLen: Int64 = 0

    while (bitPos < endBit) {
        let byteIdx = bitPos / 8
        let bitIdx = 7 - (bitPos % 8)
        let bit = (Int64(data[byteIdx]) >> bitIdx) & 1
        currentCode = (currentCode << 1) | UInt32(bit)
        currentLen += 1
        bitPos += 1

        let found = matchHuffmanCode(currentCode, currentLen)
        match (found) {
            case Some(sym) =>
                if (sym == 256) {
                    // 按 RFC 7541 §5.2：在流中间发现 EOS 符号必须
                    // 作为 COMPRESSION_ERROR 处理，而非数据结束。
                    throw Http2Exception(Http2ErrorCode.COMPRESSION_ERROR, "Huffman EOS symbol found mid-stream")
                }
                output.add(UInt8(sym))
                currentCode = 0
                currentLen = 0
            case None =>
                if (currentLen >= 30) {
                    throw Http2Exception(Http2ErrorCode.COMPRESSION_ERROR, "Huffman decode: invalid code")
                }
        }
    }
    let bytesConsumed = (bitPos + 7) / 8 - offset
    (output.toArray(), bytesConsumed)
}

/**
 * 构建 Huffman 解码查找表。
 * 使用 Huffman 码表构建 (code, length) -> symbol 的反向映射，
 * 用于 O(1) 解码查找。
 * @return code -> symbol 的映射表
 */
/**
 * 哈夫曼解码查找表：(code << 8) | codeLen → symbol。
 * 每比特 O(1) 查找，而非 O(log N) 二分搜索。
 * 键格式：高位 = code，低 8 位 = code length（最大 30）。
 * 哈夫曼码为前缀无关，因此 (code, codeLen) 始终唯一。
 */
private var huffmanLookup: ?HashMap<UInt64, Int64> = None

private func getHuffmanLookup(): HashMap<UInt64, Int64> {
    match (huffmanLookup) {
        case Some(t) => return t
        case None => ()
    }
    let table = HashMap<UInt64, Int64>()
    var i: Int64 = 0
    while (i < 257) {
        let key = (UInt64(HUFFMAN_CODES[i]) << 8) | UInt64(HUFFMAN_CODE_LENS[i])
        table[key] = i
        i += 1
    }
    huffmanLookup = Some(table)
    table
}

func matchHuffmanCode(code: UInt32, codeLen: Int64): ?Int64 {
    let table = getHuffmanLookup()
    let key = (UInt64(code) << 8) | UInt64(codeLen)
    table.get(key)
}

func writeBits(output: Array<UInt8>, bitOffset: Int64, value: UInt32, bitCount: Int64): Unit {
    var remaining = bitCount
    var v = value
    var pos = bitOffset
    while (remaining > 0) {
        let byteIdx = pos / 8
        let bitIdx = 7 - (pos % 8)
        let bitsThisByte = if (remaining > bitIdx + 1) { bitIdx + 1 } else { remaining }
        let shift = remaining - bitsThisByte
        let bits = (v >> shift) & ((UInt32(1) << bitsThisByte) - 1)
        output[byteIdx] = output[byteIdx] | UInt8(bits << (bitIdx - bitsThisByte + 1))
        pos += bitsThisByte
        remaining -= bitsThisByte
    }
}

func shouldUseHuffman(data: Array<UInt8>): Bool {
    data.size >= 4
}

// ---- 整数编码辅助函数 ----

func encodeInteger(value: Int64, prefixBits: Int64, prefixMask: Int64, output: ArrayList<UInt8>): Unit {
    let maxPrefixValue = (1 << prefixBits) - 1
    if (value < maxPrefixValue) {
        output.add(UInt8(value | prefixMask))
    } else {
        output.add(UInt8(maxPrefixValue | prefixMask))
        var remaining = value - maxPrefixValue
        while (remaining >= 128) {
            output.add(UInt8((remaining % 128) + 128))
            remaining = remaining / 128
        }
        output.add(UInt8(remaining))
    }
}

func decodeInteger(data: Array<UInt8>, offset: Int64, prefixBits: Int64): (Int64, Int64) {
    let prefixMask = (1 << prefixBits) - 1
    var value = Int64(data[offset] & UInt8(prefixMask))
    if (value < prefixMask) {
        return (value, 1)
    }
    var advanced: Int64 = 1
    var m: Int64 = 0
    while (true) {
        let b = Int64(data[offset + advanced])
        value += (b & 127) << m
        advanced += 1
        if ((b & 128) == 0) { break }
        m += 7
    }
    (value, advanced)
}

// ---- 字符串字面量编码/解码 ----

func encodeStringLiteral(s: String, output: ArrayList<UInt8>): Unit {
    let bytes = unsafe { s.rawData() }
    if (shouldUseHuffman(bytes)) {
        let encoded = huffmanEncode(bytes)
        encodeInteger(encoded.size, 7, 0x80, output)
        var i: Int64 = 0
        while (i < encoded.size) { output.add(encoded[i]); i += 1 }
    } else {
        encodeInteger(bytes.size, 7, 0x00, output)
        var i: Int64 = 0
        while (i < bytes.size) { output.add(bytes[i]); i += 1 }
    }
}

func decodeStringLiteral(data: Array<UInt8>, offset: Int64): (String, Int64) {
    let (length, advanced) = decodeInteger(data, offset, 7)
    let isHuffman = (data[offset] & 0x80) != 0
    let strLen = Int64(length)
    if (offset + advanced + strLen > data.size) {
        throw Http2Exception(Http2ErrorCode.COMPRESSION_ERROR, "HPACK string literal overflow")
    }
    if (isHuffman) {
        let (decoded, consumed) = huffmanDecode(data, offset + advanced, strLen * 8)
        // 使用 fromUtf8 而非 withRawData，确保正确处理非 UTF-8 字节
        (String.fromUtf8(decoded), advanced + strLen)
    } else {
        let bytes = Array<UInt8>(strLen, repeat: 0)
        var i: Int64 = 0
        while (i < strLen) { bytes[i] = data[offset + advanced + i]; i += 1 }
        (String.fromUtf8(bytes), advanced + strLen)
    }
}

// ---- 大小写工具 ----

func toLower(s: String): String {
    let raw = unsafe { s.rawData() }
    let size = raw.size
    let bytes = Array<UInt8>(size, repeat: 0)
    var i: Int64 = 0
    while (i < size) {
        let b = raw[i]
        bytes[i] = if (b >= b'A' && b <= b'Z') { b + 32 } else { b }
        i += 1
    }
    unsafe { String.withRawData(bytes) }
}
// ---- 静态表索引（按需惰性初始化，遵循 huffmanLookup 模式） ----
private var staticTableNameIndex: ?HashMap<String, ArrayList<Int64>> = None
private var staticTableFullIndex: ?HashMap<String, Int64> = None

private func getStaticTableNameIndex(): HashMap<String, ArrayList<Int64>> {
    match (staticTableNameIndex) {
        case Some(t) => return t
        case None => ()
    }
    let index = HashMap<String, ArrayList<Int64>>()
    var i: Int64 = 0
    while (i < STATIC_TABLE_SIZE) {
        let entry = staticTable[i]
        match (index.get(entry.name)) {
            case Some(list) => list.add(i + 1)
            case None =>
                let list = ArrayList<Int64>()
                list.add(i + 1)
                index[entry.name] = list
        }
        i += 1
    }
    staticTableNameIndex = Some(index)
    index
}

private func getStaticTableFullIndex(): HashMap<String, Int64> {
    match (staticTableFullIndex) {
        case Some(t) => return t
        case None => ()
    }
    let index = HashMap<String, Int64>()
    var i: Int64 = 0
    while (i < STATIC_TABLE_SIZE) {
        let entry = staticTable[i]
        let key = "${entry.name}\u{0}${entry.value}"
        index[key] = i + 1
        i += 1
    }
    staticTableFullIndex = Some(index)
    index
}



/**
 * HPACK 头部压缩 for HTTP/2 (RFC 7541).
 *
 * Full implementation with Huffman encoding, 静态表, and 动态表.
 */
public class HPACK {
    private var maxTableSize: Int64 = 4096
    private var dynamicTable: ArrayList<DynamicEntry>
    private var currentTableSize: Int64 = 0
    private var maxHeaderListSize: Int64 = 65536  // 默认 64 KB
    private var nameIndex: HashMap<String, ArrayList<Int64>>
    private var pendingTableSizeUpdate: Bool = false

    /**
     * 编码 HTTP 头部为 HPACK 格式字节流。
     * 使用静态表、动态表和 Huffman 编码实现头部压缩。
     * 按索引优先、字符串字面量后备的策略编码每个头部。
     * 敏感头部（如 authorization 和 cookie）始终以字符串字面量编码。
     *
     * @param headers 待编码的 HTTP 头部
     * @return HPACK 编码后的字节数组
     */
    public init() {
        dynamicTable = ArrayList<DynamicEntry>()
        this.nameIndex = HashMap<String, ArrayList<Int64>>()
    }

    public init(maxTableSize: Int64) {
        this.maxTableSize = maxTableSize
        dynamicTable = ArrayList<DynamicEntry>()
        this.nameIndex = HashMap<String, ArrayList<Int64>>()
    }

    /**
     * 将 HttpHeaders 编码为 HPACK 压缩字节。
     */
    public func encode(headers: HttpHeaders): Array<UInt8> {
        // 预分配 ArrayList 容量，减少扩容次数
        let result = ArrayList<UInt8>(256)
        // 若表已调整大小则发出动态表大小更新信号
    /**
     * 解码 HPACK 格式字节流为 HTTP 头部。
     * 处理索引引用、动态表新增和字符串字面量解码。
     * 使用动态表维护解码状态以实现增量解码。
     *
     * @param data HPACK 编码的字节数组
     * @return 解码后的 HttpHeaders
     */
        // 自上次 encode() 调用以来的变化（RFC 7541 Section 6.3）。
        if (pendingTableSizeUpdate) {
            // 动态表大小更新：带 5 位前缀的 0x20 掩码
            encodeInteger(maxTableSize, 5, 0x20, result)
            pendingTableSizeUpdate = false
        }
        let names = headers.names()
        for (name in names) {
            let values = headers.getAll(name)
            for (value in values) {
                let lowerName = toLower(name)
                // 按 RFC 7541：头部名称大小写不敏感（必须小写），
                // 但头部值保留原始大小写以用于静态表匹配
                encodeHeader(name, value, lowerName, value, result)
            }
        }
        result.toArray()
    }

    /**
     * 将 HPACK 压缩字节解码为 HttpHeaders。
     * 若设置了 MAX_HEADER_LIST_SIZE 则强制执行。
     */
    public func decode(data: Array<UInt8>): HttpHeaders {
        let headers = HttpHeaders()
    /**
     * 设置编码器动态表最大大小。超过大小限制的条目将被淘汰。
     */
        var offset: Int64 = 0
        var totalDecodedSize: Int64 = 0
        while (offset < data.size) {
            let (name, value, advanced) = decodeHeader(data, offset)
            if (name.size > 0) {
                headers.add(name, value)
                totalDecodedSize += name.size + value.size + 32
    /**
     * 设置解码器最大头部列表大小。超过此大小的头部将被拒绝。
     */
                if (totalDecodedSize > maxHeaderListSize) {
                    throw Http2Exception(Http2ErrorCode.ENHANCE_YOUR_CALM, "Header list size exceeded (max: ${maxHeaderListSize})")
                }
            }
            offset += advanced
        }
        headers
    }

    /**
     * 设置最大头部列表大小（来自 SETTINGS_MAX_HEADER_LIST_SIZE）。
     */
    public func setMaxHeaderListSize(size: Int64): Unit {
    /**
     * 检查头部名称是否为敏感头部（应始终以字符串字面量编码）。
     * 敏感头部包括：authorization、cookie、set-cookie、proxy-authorization 等。
     */
        maxHeaderListSize = size
    }

    /**
     * Set the maximum 动态表 size (from SETTINGS_HEADER_TABLE_SIZE).
     * 按 RFC 7541 Section 4.2，若新最大表大小小于当前表大小，
     * current 动态表 size, entries at the end of the 动态表
    /**
     * 以字符串字面量编码敏感头部，不引用动态表。
     * 避免凭证泄露（CRIME/BREACH 攻击防护）。
     */
     * 被淘汰。编码器必须在编码后续任何头部之前发出动态表大小更新信号
     * （第 6.3 节）在编码任何后续头部之前。
     */
    public func setMaxTableSize(size: Int64): Unit {
        maxTableSize = size
        evictToFit(0)
        // 在下次 encode() 调用期间发出动态表大小更新信号
        // 根据 RFC 7541 第 6.3 节。
        pendingTableSizeUpdate = true
    }

    // ---- 内部编码 ----

    /**
     * 检查头部名称是否敏感且不应被索引。
     * 根据 RFC 7541 第 7.1 节，这些头部必须使用 Literal Never Indexed
     * to avoid being added to the 动态表 by intermediaries.
     */
    private func isSensitiveHeader(lowerName: String): Bool {
        lowerName == "authorization" ||
        lowerName == "set-cookie" ||
        lowerName == "cookie" ||
        lowerName == "proxy-authorization"
    }

    /**
     * 使用 Literal Never Indexed 编码敏感头部（RFC 7541 第 6.2.3 节）。
     * Sensitive headers MUST NOT be added to the 动态表.
     */
    private func encodeSensitiveHeader(name: String, value: String, lowerName: String, lowerValue: String, output: ArrayList<UInt8>): Unit {
        // 1. Look for full match in 动态表 (use indexed — already in table)
        let dynFullIdx = findInDynamicTable(lowerName, lowerValue)
        match (dynFullIdx) {
            case Some(idx) =>
                let tableIdx = STATIC_TABLE_SIZE + idx + 1
                encodeInteger(tableIdx, 7, 0x80, output)
                return
            case None => ()
        }

        // 2. Look for full match in 静态表 (use Literal Never Indexed with name reference)
        let staticFullIdx = findInStaticTable(lowerName, lowerValue)
        match (staticFullIdx) {
            case Some(idx) =>
    /**
     * 编码单个头部。先尝试静态表索引引用（RFC 7541 §6.1-6.2），
     * 再尝试动态表索引引用（§6.3-6.4），最后以字面量编码并加入动态表（§6.5-6.6）。
     */
                encodeInteger(idx, 4, 0x00, output)
                encodeStringLiteral(value, output)
                return
            case None => ()
        }

        // 3. Look for name match in 动态表 (use Literal Never Indexed with name reference)
        let dynNameIdx = findDynamicNameIndex(lowerName)
        match (dynNameIdx) {
            case Some(idx) =>
                let tableIdx = STATIC_TABLE_SIZE + idx + 1
                encodeInteger(tableIdx, 4, 0x00, output)
                encodeStringLiteral(value, output)
                return
            case None => ()
        }

        // 4. Look for name match in 静态表 (use Literal Never Indexed with name reference)
        let staticNameIdx = findStaticNameIndex(lowerName)
        match (staticNameIdx) {
            case Some(idx) =>
                encodeInteger(idx, 4, 0x00, output)
                encodeStringLiteral(value, output)
                return
            case None => ()
        }

        // 5. 新名称 — 使用带新名称的 Literal Never Indexed（0x10 前缀）
        output.add(0x10)
        encodeStringLiteral(name, output)
        encodeStringLiteral(value, output)
    }

    private func encodeHeader(name: String, value: String, lowerName: String, lowerValue: String, output: ArrayList<UInt8>): Unit {
        // 根据 RFC 7541 第 7.1 节：敏感头部必须使用 Literal Never Indexed
        if (isSensitiveHeader(lowerName)) {
            encodeSensitiveHeader(name, value, lowerName, lowerValue, output)
            return
        }

        // 1. Look for full match in 动态表
        let dynFullIdx = findInDynamicTable(lowerName, lowerValue)
        match (dynFullIdx) {
            case Some(idx) =>
                let tableIdx = STATIC_TABLE_SIZE + idx + 1
                encodeInteger(tableIdx, 7, 0x80, output)
                return
            case None => ()
        }

        // 2. Look for full match in 静态表
        let staticFullIdx = findInStaticTable(lowerName, lowerValue)
    /**
     * 解码单个头部条目。从指定偏移量读取第一个字节确定编码类型，
     * 然后解析索引引用或字符串字面量。返回 (名称, 值, 消耗字节数)。
     */
        match (staticFullIdx) {
            case Some(idx) =>
                encodeInteger(idx, 7, 0x80, output)
                return
            case None => ()
        }

        // 3. Look for name match in 动态表
        let dynNameIdx = findDynamicNameIndex(lowerName)
        match (dynNameIdx) {
            case Some(idx) =>
                let tableIdx = STATIC_TABLE_SIZE + idx + 1
                encodeInteger(tableIdx, 6, 0x40, output)
                encodeStringLiteral(value, output)
                addToDynamicTable(name, lowerName, value)
                return
            case None => ()
        }

        // 4. Look for name match in 静态表
        let staticNameIdx = findStaticNameIndex(lowerName)
        match (staticNameIdx) {
            case Some(idx) =>
                encodeInteger(idx, 6, 0x40, output)
                encodeStringLiteral(value, output)
                addToDynamicTable(name, lowerName, value)
                return
            case None => ()
        }

        // 5. 新名称
        output.add(0x40)
        encodeStringLiteral(name, output)
        encodeStringLiteral(value, output)
        addToDynamicTable(name, lowerName, value)
    }

    private func decodeHeader(data: Array<UInt8>, offset: Int64): (String, String, Int64) {
        if (offset >= data.size) {
            throw Http2Exception(Http2ErrorCode.COMPRESSION_ERROR, "HPACK decode overflow")
        }
        let firstByte = data[offset]

        if ((firstByte & 0x80) != 0) {
            let (index, advanced) = decodeInteger(data, offset, 7)
            let (name, value) = lookupEntry(index)
            (name, value, advanced)
        } else if ((firstByte & 0x40) != 0) {
            let (nameIndex, nameAdvanced) = decodeInteger(data, offset, 6)
    /**
     * 在静态表中查找完全匹配（名称 + 值）的条目标引。
     * 用于索引编码模式（RFC 7541 §6.1）。
     * @return 条目标引（1-based），未找到时返回 None
     */
            var pos = offset + nameAdvanced
            var nameStr = ""
            if (nameIndex > 0) {
                let (n, _) = lookupEntry(nameIndex)
                nameStr = n
            } else {
                let (decoded, adv) = decodeStringLiteral(data, pos)
                nameStr = decoded
                pos += adv
            }
            let (valueStr, vAdvanced) = decodeStringLiteral(data, pos)
            let totalAdvanced = (pos + vAdvanced) - offset
            if (nameStr.size > 0 && valueStr.size > 0) {
    /**
     * 在静态表中按名称查找条目标引（不匹配值）。
     * 用于字面量编码中名称的索引引用（RFC 7541 §6.2）。
     */
                let lowerName = toLower(nameStr)
                addToDynamicTable(nameStr, lowerName, valueStr)
            }
            (nameStr, valueStr, totalAdvanced)
        } else if ((firstByte & 0x20) != 0) {
            let (newSize, advanced) = decodeInteger(data, offset, 5)
            maxTableSize = newSize
            evictToFit(0)
    /**
     * 在动态表中查找完全匹配（名称 + 值）的条目标引。
     * 动态表索引从静态表之后开始计数。
     */
            ("", "", advanced)
        } else {
            // 字面量不索引（Literal without Indexing，0x00 或 0x10 前缀，均为 4 位前缀）
            let prefixBits: Int64 = 4
            let (nameIndex, nameAdvanced) = decodeInteger(data, offset, prefixBits)
            var pos = offset + nameAdvanced
            var nameStr = ""
            if (nameIndex > 0) {
                let (n, _) = lookupEntry(nameIndex)
                nameStr = n
            } else {
                let (decoded, adv) = decodeStringLiteral(data, pos)
                nameStr = decoded
                pos += adv
            }
            let (valueStr, vAdvanced) = decodeStringLiteral(data, pos)
            let totalAdvanced = (pos + vAdvanced) - offset
            (nameStr, valueStr, totalAdvanced)
        }
    }

    // ---- 表查找 ----

    private func findInStaticTable(name: String, value: String): ?Int64 {
        let key = "${name}\u{0}${value}"
        getStaticTableFullIndex().get(key)
    }

    /**
     * Find a 静态表 index by header name.
     * Assumes `name` is already lowercased (静态表 names are lowercase).
     */
    private func findStaticNameIndex(name: String): ?Int64 {
        match (getStaticTableNameIndex().get(name)) {
            case Some(indices) =>
                if (indices.size > 0) { Some(indices[0]) } else { None }
            case None => None
        }
    }

    private func findInDynamicTable(name: String, value: String): ?Int64 {
        // 索引查找：条目按添加顺序自然有序，无需排序
        match (nameIndex.get(name)) {
            case Some(indices) =>
                // 条目按追加顺序自然升序（越新索引越大），从末尾直接遍历
                var i: Int64 = indices.size - 1
                while (i >= 0) {
                    let arrayIdx = indices[i]
                    if (arrayIdx >= 0 && arrayIdx < dynamicTable.size) {
                        let entry = dynamicTable[arrayIdx]
                        if (entry.value == value) {
                            return Some(dynamicTable.size - 1 - arrayIdx)
                        }
                    }
                    i -= 1
                }
            case None => ()
        }

        // 回退：线性扫描（仅当 nameIndex 缺失时触发）
        var i: Int64 = dynamicTable.size - 1
        while (i >= 0) {
            let entry = dynamicTable[i]
            if (entry.lowerName == name && entry.value == value) {
                // 返回 HPACK 索引：从 1 开始，最近 = 1
                return Some(dynamicTable.size - 1 - i)
            }
            i -= 1
        }
        None
    }

    private func findDynamicNameIndex(name: String): ?Int64 {
        // 先尝试基于索引的查找（平均 O(1)）
        match (nameIndex.get(name)) {
    /**
     * 淘汰动态表中最早的条目，直到腾出指定空间。
     * 从表头（最旧条目）开始逐条淘汰。
     */
            case Some(indices) =>
                // 找到最大的数组索引（最新条目）
                var maxIdx: Int64 = -1
                for (idx in indices) {
                    if (idx > maxIdx) {
                        maxIdx = idx
                    }
                }
                if (maxIdx >= 0 && maxIdx < dynamicTable.size) {
                    return Some(dynamicTable.size - 1 - maxIdx)
                }
            case None => ()
        }

        // 回退：线性扫描
        var i: Int64 = dynamicTable.size - 1
        while (i >= 0) {
            if (dynamicTable[i].lowerName == name) {
                // 返回 HPACK 索引：从 1 开始，最近 = 1
                return Some(dynamicTable.size - 1 - i)
            }
            i -= 1
        }
        None
    }

    private func lookupEntry(index: Int64): (String, String) {
        if (index <= STATIC_TABLE_SIZE) {
            let entry = staticTable[index - 1]
            (entry.name, entry.value)
        } else {
            // HPACK 索引 -> 数组索引：最新（HPACK 1）= 数组中的最后一个
            let hpackIdx = index - STATIC_TABLE_SIZE - 1
            let dynIdx = dynamicTable.size - 1 - hpackIdx
            if (dynIdx >= 0 && dynIdx < dynamicTable.size) {
                let entry = dynamicTable[dynIdx]
                (entry.name, entry.value)
            } else {
                ("", "")
            }
        }
    }

    // ---- 动态表管理 ----

    private func addToDynamicTable(name: String, lowerName: String, value: String): Unit {
        let entrySize = name.size + value.size + 32
        if (entrySize > maxTableSize) {
            return
        }
        evictToFit(entrySize)
        let entry = DynamicEntry(name, lowerName, value)
        // 将最新条目存储在末尾以避免每次插入 O(n)。
        // 索引映射：dynamicTable[size - 1 - i] = 索引 i+1 处的 HPACK 条目
        dynamicTable.add(entry)
        currentTableSize += entry.size

        // 更新名称索引以实现 O(1) 查找
        match (nameIndex.get(lowerName)) {
            case Some(indices) =>
                indices.add(dynamicTable.size - 1)
            case None =>
                let newIndices = ArrayList<Int64>()
                newIndices.add(dynamicTable.size - 1)
                nameIndex[lowerName] = newIndices
        }
    }

    private func evictToFit(neededSpace: Int64): Unit {
        // 最旧条目在前端（索引 0），因为最新条目在末尾
        while (currentTableSize + neededSpace > maxTableSize && dynamicTable.size > 0) {
            let entry = dynamicTable[0]
            currentTableSize -= entry.size

            // 更新名称索引：移除被淘汰的条目并递减剩余索引
            let lowerName = entry.lowerName
            match (nameIndex.get(lowerName)) {
                case Some(indices) =>
                    // 查找并移除数组索引 0（正在被淘汰）
                    var j: Int64 = 0
                    while (j < indices.size) {
                        if (indices[j] == 0) {
                            indices.remove(j..j + 1)
                            break
                        }
                        j += 1
                    }
                    // 将所有剩余数组索引减 1（所有内容左移）
                    var k: Int64 = 0
                    while (k < indices.size) {
                        indices[k] = indices[k] - 1
                        k += 1
                    }
                    if (indices.size == 0) {
                        nameIndex.remove(lowerName)
                    }
                case None => ()
            }

            dynamicTable.remove(0..1)
        }
    }
}
