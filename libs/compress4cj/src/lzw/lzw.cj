package compress4cj.lzw

import compress4cj.common.Zlib4cjException
import std.collection.ArrayList

/**
 * LZW 压缩/解压 (Lempel-Ziv-Welch)。
 *
 * 适用于 GIF/PDF 格式的 LZW，使用可变宽度编码（9-12 位），
 * 包含 Clear 和 EOI 控制码。
 *
 * 基于 Go compress/lzw 的算法理解以仓颉惯用风格重写。
 */

/** 比特顺序 */
public enum LzwOrder { LSB | MSB }

private let MAX_WIDTH: Int64 = 12
private let MAX_TABLE: Int64 = 1 << 12
private let INVALID_CODE: Int64 = -1
private let ENC_TABLE_SIZE: Int64 = 4 * (1 << 12)
private let ENC_TABLE_MASK: Int64 = ENC_TABLE_SIZE - 1
private let MAX_ENC_CODE: Int64 = (1 << 12) - 1

private func isLsb(order: LzwOrder): Bool {
    match (order) {
        case LzwOrder.LSB => true
        case _ => false
    }
}

/**
 * LZW 压缩。
 *
 * @param data 原始数据
 * @param order 比特顺序，LSB=GIF, MSB=TIFF/PDF
 * @param litWidth 字面量位宽 (2-8, 通常 8)
 * @return 压缩数据
 */
public func lzwCompress(data: Array<UInt8>, order!: LzwOrder = LzwOrder.LSB, litWidth!: Int64 = 8): Array<UInt8> {
    if (data.size == 0) { return Array<UInt8>() }
    if (litWidth < 2 || litWidth > 8) {
        throw Zlib4cjException("lzw: litWidth out of range")
    }
    let maxLit = (1 << litWidth) - 1
    for (b in data) {
        if (b > UInt8(maxLit)) {
            throw Zlib4cjException("lzw: input byte too large for litWidth")
        }
    }
    let enc = LzwEncoder(data, order, litWidth)
    enc.encode()
    enc.flush()
    enc.getOutput()
}

/**
 * LZW 解压。
 *
 * @param data 压缩数据
 * @param order 比特顺序，LSB=GIF, MSB=TIFF/PDF
 * @param litWidth 字面量位宽 (2-8, 通常 8)
 * @return 解压后的数据
 */
public func lzwDecompress(data: Array<UInt8>, order!: LzwOrder = LzwOrder.LSB, litWidth!: Int64 = 8): Array<UInt8> {
    if (data.size == 0) { return Array<UInt8>() }
    if (litWidth < 2 || litWidth > 8) {
        throw Zlib4cjException("lzw: litWidth out of range")
    }
    let dec = LzwDecoder(data, order, litWidth)
    dec.decode()
    dec.getOutput()
}

// ========== 比特读取器 ==========

private class BitReader {
    private var data: Array<UInt8>
    private var pos: Int64
    private var buf: UInt32
    private var nBits: Int32
    private var lsb: Bool

    public init(data: Array<UInt8>, order: LzwOrder) {
        this.data = data
        this.pos = 0
        this.buf = 0
        this.nBits = 0
        this.lsb = isLsb(order)
    }

    @Frozen
    public func readCode(width: Int64): Int64 {
        if (width <= 0) { return 0 }
        if (lsb) {
            while (nBits < Int32(width)) {
                if (pos >= data.size) {
                    throw Zlib4cjException("lzw: unexpected end of data")
                }
                buf |= UInt32(data[pos]) << UInt32(nBits)
                pos += 1
                nBits += 8
            }
            let mask = (Int64(1) << width) - 1
            let code = Int64(buf) & mask
            buf >>= UInt32(width)
            nBits -= Int32(width)
            code
        } else {
            while (nBits < Int32(width)) {
                if (pos >= data.size) {
                    throw Zlib4cjException("lzw: unexpected end of data")
                }
                buf |= UInt32(data[pos]) << UInt32(24 - nBits)
                pos += 1
                nBits += 8
            }
            let shift = 32 - Int32(width)
            let code = Int64(buf) >> shift
            buf <<= UInt32(width)
            nBits -= Int32(width)
            code
        }
    }
}

// ========== 比特写入器 ==========

private class BitWriter {
    private var out: Array<UInt8>
    private var len: Int64
    private var buf: UInt32
    private var nBits: Int32
    private var lsb: Bool

    public init(order: LzwOrder, cap: Int64) {
        this.out = Array<UInt8>(cap + 64, repeat: 0)
        this.len = 0
        this.buf = 0
        this.nBits = 0
        this.lsb = isLsb(order)
    }

    private func grow(extra: Int64): Unit {
        if (len + extra >= out.size) {
            let ncap = out.size * 2 + extra
            let n = Array<UInt8>(ncap, repeat: 0)
            for (i in 0..len) { n[i] = out[i] }
            out = n
        }
    }

    @Frozen
    public func writeCode(code: Int64, width: Int64): Unit {
        if (lsb) {
            buf |= UInt32(code) << UInt32(nBits)
            nBits += Int32(width)
            while (nBits >= 8) {
                grow(1)
                out[len] = UInt8(buf & 0xFF)
                len += 1
                buf >>= 8
                nBits -= 8
            }
        } else {
            buf |= UInt32(code) << UInt32(32 - Int32(width) - nBits)
            nBits += Int32(width)
            while (nBits >= 8) {
                grow(1)
                out[len] = UInt8(buf >> 24)
                len += 1
                buf <<= 8
                nBits -= 8
            }
        }
    }

    public func flush(): Unit {
        if (nBits > 0) {
            grow(1)
            if (!lsb) { buf >>= 24 }
            out[len] = UInt8(buf & 0xFF)
            len += 1
        }
    }

    public func getOutput(): Array<UInt8> {
        let result = Array<UInt8>(len, repeat: 0)
        for (i in 0..len) { result[i] = out[i] }
        result
    }
}

// ========== 解码器 ==========

private class LzwDecoder {
    private var reader: BitReader
    private var litWidth: Int64
    private var clear: Int64
    private var eof: Int64
    private var hi: Int64
    private var overflow: Int64
    private var last: Int64
    private var width: Int64
    private var suffix: Array<UInt8>
    private var prefix: Array<Int64>
    private var out: ArrayList<UInt8>

    public init(data: Array<UInt8>, order: LzwOrder, litWidth: Int64) {
        this.reader = BitReader(data, order)
        this.litWidth = litWidth
        this.width = litWidth + 1
        this.clear = 1 << litWidth
        this.eof = clear + 1
        this.hi = eof
        this.overflow = 1 << width
        this.last = INVALID_CODE
        this.suffix = Array<UInt8>(MAX_TABLE, repeat: 0)
        this.prefix = Array<Int64>(MAX_TABLE, repeat: 0)
        this.out = ArrayList<UInt8>()
    }

    public func decode(): Unit {
        let temp = Array<UInt8>(MAX_TABLE, repeat: 0)
        while (true) {
            let code = reader.readCode(width)

            if (code < clear) {
                out.add(UInt8(code))
                if (last != INVALID_CODE) {
                    suffix[hi] = UInt8(code)
                    prefix[hi] = last
                }
            } else if (code == clear) {
                width = litWidth + 1
                hi = eof
                overflow = 1 << width
                last = INVALID_CODE
                continue
            } else if (code == eof) {
                break
            } else if (code <= hi) {
                var ptr: Int64 = temp.size
                var c = code

                if (code == hi && last != INVALID_CODE) {
                    var head = last
                    while (head >= clear) {
                        head = prefix[head]
                    }
                    ptr -= 1
                    temp[ptr] = UInt8(head)
                    c = last
                }

                while (c >= clear) {
                    ptr -= 1
                    temp[ptr] = suffix[c]
                    c = prefix[c]
                }
                ptr -= 1
                temp[ptr] = UInt8(c)

                let count = temp.size - ptr
                for (j in 0..count) {
                    out.add(temp[ptr + j])
                }

                if (last != INVALID_CODE) {
                    suffix[hi] = temp[ptr]
                    prefix[hi] = last
                }
            } else {
                throw Zlib4cjException("lzw: invalid code")
            }

            last = code
            hi += 1
            if (hi >= overflow) {
                if (width == MAX_WIDTH) {
                    last = INVALID_CODE
                    hi -= 1
                } else {
                    width += 1
                    overflow = 1 << width
                }
            }
        }
    }

    public func getOutput(): Array<UInt8> {
        let n = out.size
        let result = Array<UInt8>(n, repeat: 0)
        for (i in 0..n) { result[i] = out[i] }
        result
    }
}

// ========== 编码器 ==========

private class LzwEncoder {
    private var writer: BitWriter
    private var data: Array<UInt8>
    private var litWidth: Int64
    private var width: Int64
    private var hi: Int64
    private var overflow: Int64
    private var table: Array<Int64>

    public init(data: Array<UInt8>, order: LzwOrder, litWidth: Int64) {
        this.data = data
        this.litWidth = litWidth
        this.width = litWidth + 1
        this.hi = (1 << litWidth) + 1
        this.overflow = 1 << (litWidth + 1)
        this.table = Array<Int64>(ENC_TABLE_SIZE, repeat: 0)
        this.writer = BitWriter(order, data.size)
    }

    public func encode(): Unit {
        if (data.size == 0) { return }

        writer.writeCode(1 << litWidth, width)

        var code: Int64 = Int64(data[0])
        var i: Int64 = 1
        while (i < data.size) {
            let lit = Int64(data[i])
            let key = (code << 8) | lit
            let hash = ((key >> 12) ^ key) & ENC_TABLE_MASK

            var found = false
            var h = hash
            var t = table[h]
            while (t != 0) {
                if (key == (t >> 12)) {
                    code = t & MAX_ENC_CODE
                    found = true
                    break
                }
                h = (h + 1) & ENC_TABLE_MASK
                t = table[h]
            }

            if (found) {
                i += 1
                continue
            }

            writer.writeCode(code, width)
            code = lit
            incHi()

            h = hash
            while (table[h] != 0) {
                h = (h + 1) & ENC_TABLE_MASK
            }
            table[h] = (key << 12) | hi

            i += 1
        }

        writer.writeCode(code, width)
    }

    private func incHi(): Unit {
        hi += 1
        if (hi == overflow) {
            width += 1
            overflow <<= 1
        }
        if (hi == MAX_ENC_CODE) {
            writer.writeCode(1 << litWidth, width)
            width = litWidth + 1
            hi = (1 << litWidth) + 1
            overflow = 1 << (litWidth + 1)
            for (j in 0..ENC_TABLE_SIZE) { table[j] = 0 }
        }
    }

    public func flush(): Unit {
        writer.writeCode((1 << litWidth) + 1, width)
        writer.flush()
    }

    public func getOutput(): Array<UInt8> {
        writer.getOutput()
    }
}
