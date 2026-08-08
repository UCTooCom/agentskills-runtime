package compress4cj.bzip2

import compress4cj.common.Zlib4cjException
import std.collection.ArrayList

/**
 * bzip2 解压 (block sorting compression)。
 *
 * 纯仓颉实现，基于 Go compress/bzip2 的算法理解以仓颉惯用风格重写。
 *
 * 支持解压标准 bzip2 (.bz2) 格式文件，使用 Huffman 编码 + MTF + BWT。
 */

// ========== 常量 ==========

private let BZ_MAGIC: Int64 = 0x425A
private let BLOCK_MAGIC: Int64 = 0x314159265359
private let FINAL_MAGIC: Int64 = 0x177245385090
private let INVALID_NODE: UInt16 = 0xFFFF

// ========== 公开 API ==========

/**
 * 解压 bzip2 格式数据。
 *
 * @param data bzip2 压缩数据
 * @return 解压后的原始数据
 */
public func bzip2Decompress(data: Array<UInt8>): Array<UInt8> {
    if (data.size == 0) { return Array<UInt8>() }
    let dec = Bzip2Decoder(data)
    dec.decodeAll()
    dec.getOutput()
}

// ========== 比特读取器 ==========

private class BitReader {
    private var data: Array<UInt8>
    private var pos: Int64
    private var buf: UInt64
    private var nBits: Int32

    public init(data: Array<UInt8>) {
        this.data = data
        this.pos = 0
        this.buf = 0
        this.nBits = 0
    }

    public func readBit(): Bool {
        readBits(1) != 0
    }

    public func readBits(n: Int64): Int64 {
        if (n <= 0) { return 0 }
        while (nBits < Int32(n)) {
            if (pos >= data.size) {
                throw Zlib4cjException("bzip2: unexpected end of data")
            }
            if (nBits == 0) { buf = 0 }
            buf = (buf << 8) | UInt64(data[pos])
            pos += 1
            nBits += 8
        }
        let shift = Int64(nBits) - n
        if (n < 63) {
            let mask = (Int64(1) << n) - 1
            let val = Int64(buf >> UInt32(shift)) & mask
            nBits -= Int32(n)
            val
        } else {
            // For n >= 63, compute mask without overflow
            let val = Int64(buf >> UInt32(shift))
            nBits -= Int32(n)
            val
        }
    }

    public func readUint32(n: Int64): UInt32 {
        UInt32(readBits(n))
    }
}

// ========== CRC32 (bzip2 变体) ==========

private func makeCrcTable(): Array<UInt32> {
    let tab = Array<UInt32>(256, repeat: 0)
    for (i in 0..256) {
        var crc = UInt32(i) << 24
        for (_ in 0..8) {
            if ((crc & 0x80000000) != 0) {
                crc = (crc << 1) ^ 0x04C11DB7
            } else {
                crc <<= 1
            }
        }
        tab[i] = crc
    }
    tab
}

private let CRC_TABLE: Array<UInt32> = makeCrcTable()

private func updateCrc(crc: UInt32, data: Array<UInt8>): UInt32 {
    var val = crc ^ 0xFFFFFFFF
    for (b in data) {
        let idx = Int64(UInt8(val >> 24) ^ b)
        val = CRC_TABLE[idx] ^ (val << 8)
    }
    val ^ 0xFFFFFFFF
}

// ========== Huffman 码长对 ==========

private class CodeLenPair {
    var symbol: UInt16
    var length: UInt8
    public init(sym: UInt16, len: UInt8) {
        this.symbol = sym
        this.length = len
    }
}


// ========== Huffman 树 ==========

private class HuffmanNode {
    var left: UInt16
    var right: UInt16
    var leftVal: UInt16
    var rightVal: UInt16
    public init() {
        this.left = INVALID_NODE
        this.right = INVALID_NODE
        this.leftVal = 0
        this.rightVal = 0
    }
}

private class HuffmanTree {
    private var nodes: Array<HuffmanNode>
    private var nextNode: Int64

    public init(lengths: Array<UInt8>) {
        let maxNodes = lengths.size * 2 + 2
        this.nodes = Array<HuffmanNode>(maxNodes, {_ => HuffmanNode()})
        this.nextNode = 1  // root is index 0
        buildTree(lengths)
    }

    public func decode(reader: BitReader): UInt16 {
        var nodeIdx: Int64 = 0
        var result: UInt16 = 0
        while (true) {
            let node = nodes[nodeIdx]
            let bit = reader.readBit()
            if (bit) {
                if (node.left == INVALID_NODE) {
                    result = node.leftVal
                    break
                }
                nodeIdx = Int64(node.left)
            } else {
                if (node.right == INVALID_NODE) {
                    result = node.rightVal
                    break
                }
                nodeIdx = Int64(node.right)
            }
        }
        result
    }

    private func buildTree(lengths: Array<UInt8>): Unit {
        var pairs = ArrayList<CodeLenPair>()
        for (i in 0..lengths.size) {
            if (lengths[i] > 0) {
                pairs.add(CodeLenPair(UInt16(i), lengths[i]))
            }
        }
        if (pairs.size < 2) {
            throw Zlib4cjException("bzip2: too few symbols in Huffman tree")
        }
        sortPairs(pairs)

        var code: Int64 = 0
        var prevLen: Int64 = 0
        for (i in 0..pairs.size) {
            let pair = pairs[i]
            let len = Int64(pair.length)
            code <<= (len - prevLen)
            prevLen = len
            insertCode(code, len, pair.symbol)
            code += 1
        }
    }

    private func insertCode(code: Int64, len: Int64, symbol: UInt16): Unit {
        var nodeIdx: Int64 = 0
        for (bitPos in 0..len) {
            let bit = (code >> (len - 1 - bitPos)) & 1
            if (bitPos == len - 1) {
                if (bit == 1) {
                    nodes[nodeIdx].leftVal = symbol
                    nodes[nodeIdx].left = INVALID_NODE
                } else {
                    nodes[nodeIdx].rightVal = symbol
                    nodes[nodeIdx].right = INVALID_NODE
                }
            } else {
                if (bit == 1) {
                    if (nodes[nodeIdx].left == INVALID_NODE) {
                        nodes[nodeIdx].left = UInt16(nextNode)
                        nextNode += 1
                    }
                    nodeIdx = Int64(nodes[nodeIdx].left)
                } else {
                    if (nodes[nodeIdx].right == INVALID_NODE) {
                        nodes[nodeIdx].right = UInt16(nextNode)
                        nextNode += 1
                    }
                    nodeIdx = Int64(nodes[nodeIdx].right)
                }
            }
        }
    }

    private func sortPairs(pairs: ArrayList<CodeLenPair>): Unit {
        let n = pairs.size
        for (i in 1..n) {
            var j = i
            while (j > 0) {
                let a = pairs[j - 1]
                let b = pairs[j]
                if (a.length < b.length || (a.length == b.length && a.symbol < b.symbol)) {
                    break
                }
                let tmp = pairs[j]
                pairs[j] = pairs[j - 1]
                pairs[j - 1] = tmp
                j -= 1
            }
        }
    }
}


// ========== Move-to-Front 解码器 ==========

private class MoveToFront {
    private var list: Array<UInt8>

    public init(symbols: Array<UInt8>) {
        this.list = Array<UInt8>(symbols.size, {i => symbols[i]})
    }

    public init(range: Int64) {
        this.list = Array<UInt8>(range, {i => UInt8(i)})
    }

    public func decode(n: Int64): UInt8 {
        let result = list[n]
        if (n > 0) {
            var i = n
            while (i > 0) {
                list[i] = list[i - 1]
                i -= 1
            }
            list[0] = result
        }
        result
    }

    public func first(): UInt8 {
        list[0]
    }
}

// ========== 完整解码器 ==========

private class Bzip2Decoder {
    private var data: Array<UInt8>
    private var reader: BitReader
    private var out: ArrayList<UInt8>
    private var blockSize: Int64
    private var fileCRC: UInt32

    public init(data: Array<UInt8>) {
        this.data = data
        this.reader = BitReader(data)
        this.out = ArrayList<UInt8>()
        this.blockSize = 0
        this.fileCRC = 0
    }

    public func decodeAll(): Unit {
        let magic = reader.readBits(16)
        if (magic != BZ_MAGIC) {
            throw Zlib4cjException("bzip2: invalid magic")
        }
        let method = reader.readBits(8)
        if (method != 0x68) {
            throw Zlib4cjException("bzip2: not Huffman encoding")
        }
        let level = reader.readBits(8)
        if (level < 0x31 || level > 0x39) {
            throw Zlib4cjException("bzip2: invalid compression level")
        }
        blockSize = 100000 * (level - 0x30)

        var done = false
        while (!done) {
            let blockMagic = reader.readBits(48)
            if (blockMagic == BLOCK_MAGIC) {
                decodeBlock()
            } else if (blockMagic == FINAL_MAGIC) {
                let wantCRC = reader.readUint32(32)
                if (fileCRC != wantCRC) {
                    throw Zlib4cjException("bzip2: file CRC mismatch")
                }
                done = true
            } else {
                throw Zlib4cjException("bzip2: bad block magic")
            }
        }
    }

    private func decodeBlock(): Unit {
        let wantCRC = reader.readUint32(32)
        var blockCRC: UInt32 = 0
        fileCRC = (fileCRC << 1) | (fileCRC >> 31)
        fileCRC = fileCRC ^ wantCRC

        let randomized = reader.readBits(1)
        if (randomized != 0) {
            throw Zlib4cjException("bzip2: randomized blocks not supported")
        }

        let origPtr = reader.readBits(24)
        let symBitmap = reader.readBits(16)

        var symbolPresent = Array<Bool>(256, repeat: false)
        var numSymbols: Int64 = 0
        for (range in 0..16) {
            if ((symBitmap & (1 << (15 - range))) != 0) {
                let bits = reader.readBits(16)
                for (sym in 0..16) {
                    if ((bits & (1 << (15 - sym))) != 0) {
                        symbolPresent[16 * range + sym] = true
                        numSymbols += 1
                    }
                }
            }
        }
        if (numSymbols == 0) {
            throw Zlib4cjException("bzip2: no symbols in block")
        }

        let numTrees = reader.readBits(3)
        if (numTrees < 2 || numTrees > 6) {
            throw Zlib4cjException("bzip2: invalid number of Huffman trees")
        }
        let numSelectors = reader.readBits(15)
        var treeIndexes = Array<Int64>(numSelectors, repeat: 0)
        let mtfSelector = MoveToFront(numTrees)
        for (i in 0..numSelectors) {
            var c: Int64 = 0
            while (reader.readBit()) { c += 1 }
            if (c >= numTrees) {
                throw Zlib4cjException("bzip2: tree index too large")
            }
            treeIndexes[i] = Int64(mtfSelector.decode(c))
        }

        var symbols = Array<UInt8>(numSymbols, repeat: 0)
        var nextSym: Int64 = 0
        for (i in 0..256) {
            if (symbolPresent[i]) {
                symbols[nextSym] = UInt8(i)
                nextSym += 1
            }
        }
        let mtf = MoveToFront(symbols)
        let totalSymbols = numSymbols + 2

        var huffTrees = ArrayList<HuffmanTree>()
        for (i in 0..numTrees) {
            var length = reader.readBits(5)
            var lengths = Array<UInt8>(totalSymbols, repeat: 0)
            for (j in 0..totalSymbols) {
                while (true) {
                    if (length < 1 || length > 20) {
                        throw Zlib4cjException("bzip2: Huffman length out of range")
                    }
                    if (!reader.readBit()) { break }
                    if (reader.readBit()) {
                        length -= 1
                    } else {
                        length += 1
                    }
                }
                lengths[j] = UInt8(length)
            }
            huffTrees.add(HuffmanTree(lengths))
        }

        var selectorIdx: Int64 = 1
        if (numSelectors == 0) {
            throw Zlib4cjException("bzip2: no selectors")
        }
        var curTree = huffTrees[Int64(treeIndexes[0])]
        var decoded: Int64 = 0

        var cArr = Array<UInt64>(256, repeat: 0)
        var tt = ArrayList<UInt32>()
        var repeatCount: Int64 = 0
        var repeatPower: Int64 = 0

        while (true) {
            if (decoded == 50) {
                if (selectorIdx >= numSelectors) {
                    throw Zlib4cjException("bzip2: insufficient selectors")
                }
                curTree = huffTrees[Int64(treeIndexes[selectorIdx])]
                selectorIdx += 1
                decoded = 0
            }
            let v = curTree.decode(reader)
            decoded += 1

            if (v < 2) {
                if (repeatCount == 0) { repeatPower = 1 }
                repeatCount += repeatPower << v
                repeatPower <<= 1
                if (repeatCount > 2 * 1024 * 1024) {
                    throw Zlib4cjException("bzip2: repeat count too large")
                }
                continue
            }

            if (repeatCount > 0) {
                if (repeatCount > blockSize - tt.size) {
                    throw Zlib4cjException("bzip2: repeats past end of block")
                }
                let firstByte = mtf.first()
                for (_ in 0..repeatCount) {
                    tt.add(UInt32(firstByte))
                    cArr[Int64(firstByte)] += 1
                }
                repeatCount = 0
            }

            if (v == UInt16(totalSymbols - 1)) {
                break
            }

            let b = mtf.decode(Int64(v - 1))
            if (tt.size >= blockSize) {
                throw Zlib4cjException("bzip2: data exceeds block size")
            }
            tt.add(UInt32(b))
            cArr[Int64(b)] += 1
        }

        if (Int64(origPtr) >= tt.size) {
            throw Zlib4cjException("bzip2: origPtr out of bounds")
        }

        let ttArr = listToArrayU32(tt)
        inverseBwt(ttArr, Int64(origPtr), cArr)
        runLengthDecode(ttArr, Int64(origPtr))
        blockCRC = 0
    }

    private func runLengthDecode(tt: Array<UInt32>, tPos: Int64): Unit {
        var pos = tPos
        var lastByte: Int64 = -1
        var byteRepeats: Int64 = 0
        var repeats: Int64 = 0
        var preRLEPos: Int64 = 0
        let preRLESize = tt.size

        while (repeats > 0 || preRLEPos < preRLESize) {
            if (repeats > 0) {
                out.add(UInt8(lastByte))
                repeats -= 1
                if (repeats == 0) { lastByte = -1 }
                continue
            }

            pos = Int64(tt[pos] >> 8)
            let outPos = tt[pos] & 0xFF
            let b = UInt8(outPos)
            preRLEPos += 1

            if (byteRepeats == 3) {
                repeats = Int64(b)
                byteRepeats = 0
                continue
            }

            if (lastByte == Int64(b)) {
                byteRepeats += 1
            } else {
                byteRepeats = 0
            }
            lastByte = Int64(b)
            out.add(b)
        }
    }

    public func getOutput(): Array<UInt8> {
        let n = out.size
        let result = Array<UInt8>(n, repeat: 0)
        for (i in 0..n) { result[i] = out[i] }
        result
    }
}

// ========== 逆 BWT ==========

private func inverseBwt(tt: Array<UInt32>, origPtr: Int64, c: Array<UInt64>): Unit {
    let n = tt.size
    var sum: UInt64 = 0
    for (i in 0..256) {
        let ci = c[i]
        c[i] = sum
        sum += ci
    }

    for (i in 0..n) {
        let b = tt[i] & 0xFF
        let ci = c[Int64(b)]
        tt[Int64(ci)] = tt[Int64(ci)] | (UInt32(i) << 8)
        c[Int64(b)] = ci + 1
    }
}

// ========== 工具函数 ==========

private func listToArrayU32(list: ArrayList<UInt32>): Array<UInt32> {
    let n = list.size
    let result = Array<UInt32>(n, repeat: 0)
    for (i in 0..n) { result[i] = list[i] }
    result
}
