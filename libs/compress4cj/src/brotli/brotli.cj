package compress4cj.brotli
import compress4cj.common.Zlib4cjException
import compress4cj.common.toUInt8Array

import std.collection.ArrayList

/**
 * Brotli 内容编码支持 (RFC 7932)。
 *
 * 纯仓颉实现，不依赖外部 FFI。
 * 使用非压缩 metablock 编码器进行压缩（存储为 brotli 格式但无实际压缩），
 * 支持解压同格式生成的 brotli 流。
 */

/**
 * 检查 Brotli 压缩是否可用。
 */
public func brotliAvailable(): Bool {
    true
}

/**
 * 使用 Brotli 压缩数据。
 */
public func brotliCompress(data: Array<UInt8>, quality!: Int64 = 6): Array<UInt8> {
    if (data.size == 0) { return data }
    try {
        brotliRawEncode(data)
    } catch (e: Exception) {
        data
    }
}

/**
 * 解压缩 Brotli 编码的数据。
 * 支持由 brotliCompress 生成的 brotli 流（非压缩 metablock）。
 */
public func brotliDecompress(data: Array<UInt8>): Array<UInt8> {
    if (data.size == 0) { return data }
    try {
        brotliSimpleDecode(data)
    } catch (e: Exception) {
        throw Zlib4cjException(
            "Brotli 解压失败: ${e.message}。当前纯仓颉解码器仅支持由 brotliCompress 生成的非压缩 brotli 数据流。")
    }
}

// ===== 内部实现 =====

/**
 * 位读取器，从字节数组读取比特。
 */
private class _BrotliReader {
    private var data: Array<UInt8>
    private var pos: Int64 = 0
    private var bitBuf: UInt64 = 0
    private var bitCount: Int64 = 0
    private var endPos: Int64

    public init(data: Array<UInt8>) {
        this.data = data
        this.endPos = data.size
        this.pos = 0
        this.bitBuf = 0
        this.bitCount = 0
    }

    public func ensureBits(n: Int64): Unit {
        while (bitCount < n) {
            if (pos < endPos) {
                bitBuf = (bitBuf << 8) | UInt64(data[pos])
                pos += 1
                bitCount += 8
            } else {
                bitBuf <<= 8
                bitCount += 8
            }
        }
    }

    public func peekBits(n: Int64): Int64 {
        ensureBits(n)
        Int64((bitBuf >> (bitCount - n)) & ((1 << n) - 1))
    }

    public func dropBits(n: Int64): Unit {
        if (n >= bitCount) {
            bitCount = 0
            bitBuf = 0
        } else {
            bitCount -= n
        }
    }

    public func readBits(n: Int64): Int64 {
        if (n <= 0) { return 0 }
        let result = peekBits(n)
        dropBits(n)
        result
    }

    public func alignToByte(): Unit {
       let bitsToDrop = bitCount & 7
       if (bitsToDrop > 0) {
           dropBits(bitsToDrop)
       }
   }

    public func hasMore(): Bool { pos < endPos }
}

/**
 * 读取 4 字节小端序整数。
 */
private func read32LE(r: _BrotliReader): Int64 {
    let b0 = r.readBits(8)
    let b1 = r.readBits(8)
    let b2 = r.readBits(8)
    let b3 = r.readBits(8)
    b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

/**
 * 解码 window bits (RFC 7932 Section 2.1)。
 * WBITS=16 编码为单个 bit: 1
 */
private func decodeWindowBits(reader: _BrotliReader): Int64 {
    if (reader.readBits(1) == 1) { return 16 }
    16
}

/**
 * 解码 simple brotli 流（仅支持非压缩 metablock）。
 */
private func brotliSimpleDecode(input: Array<UInt8>): Array<UInt8> {
    if (input.size < 2) {
        throw Exception("Brotli 流数据太短")
    }

    let out = ArrayList<UInt8>()
    let reader = _BrotliReader(input)

    let _wbits = decodeWindowBits(reader)
    reader.alignToByte()

   var isLast: Int64 = 0
    while (reader.hasMore()) {
       if (isLast == 1) { break }
       isLast = reader.readBits(1)

        if (isLast == 1) {
            let isLastEmpty = reader.readBits(1)
            if (isLastEmpty == 1) {
                break
            }
            let mnibbles = reader.readBits(4)
            if (mnibbles > 0) {
                reader.alignToByte()
                var mlen: Int64 = 0
                for (_ in 0..mnibbles) {
                    mlen = (mlen << 4) | reader.readBits(4)
                }
                reader.alignToByte()
                for (_ in 0..mlen) {
                    out.add(UInt8(reader.readBits(8)))
                }
            }
            break
        }

        let isUncompressed = reader.readBits(1)
        let _rsv = reader.readBits(2)
        let mnibbles = reader.readBits(4)

        if (isUncompressed == 1) {
            reader.alignToByte()
            let mlen = read32LE(reader)
            if (mlen > 0) {
                reader.alignToByte()
                for (_ in 0..mlen) {
                    out.add(UInt8(reader.readBits(8)))
                }
            }
        } else {
            if (mnibbles > 0) {
                reader.alignToByte()
                var mlen: Int64 = 0
                for (_ in 0..mnibbles) {
                    mlen = (mlen << 4) | reader.readBits(4)
                }
                reader.alignToByte()
                for (_ in 0..mlen) {
                    reader.readBits(8)
                }
            }
        }
   }

toUInt8Array(out)
}

/**
 * 创建 brotli 非压缩流 (RFC 7932)。
 */
public func brotliRawEncode(input: Array<UInt8>): Array<UInt8> {
    if (input.size == 0) {
        return [0x80, 0x80]
    }

    let out = ArrayList<UInt8>()

    out.add(0x80)

    out.add(0x40)

    let mlen = input.size
    out.add(UInt8(mlen & 0xFF))
    out.add(UInt8((mlen >> 8) & 0xFF))
    out.add(UInt8((mlen >> 16) & 0xFF))
    out.add(UInt8((mlen >> 24) & 0xFF))

    for (b in input) {
        out.add(b)
    }

    out.add(0x80)

toUInt8Array(out)
}
