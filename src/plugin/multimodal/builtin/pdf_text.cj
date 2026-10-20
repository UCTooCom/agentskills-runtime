/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal.builtin

import compress4cj.zlib.Zlib
import compress4cj.zlib.ZlibType

import std.collection.ArrayList
import std.core.StringBuilder

/**
 * PDF 正文抽取（best-effort，工程 `specs/multimodal-native-chat`，T-MC-013 的后半段）。
 *
 * 【做法】PDF 没有「纯文本」这回事：正文是画在页面上的字形，靠内容流里的
 * Tj / TJ 运算符摆放。本实现走最小可用路径：
 *   1. 顺序扫出 stream ... endstream 数据段，尝试 inflate（FlateDecode）；
 *   2. 只保留含有 Tj / TJ 的段（其余是字体、图片等资源流）；
 *   3. 从这些段里取出被 Tj / TJ 使用的字符串，解 PDF 转义后按字节解码成文本。
 *
 * 【能力边界（必须如实告知）】
 * - 只覆盖 FlateDecode 与未压缩的内容流；LZW、JPEG2000 等编码跳过。
 * - 使用 CID / 自定义编码的 CJK 字体（很多中文 PDF 就是）没有 ToUnicode 映射时，
 *   解出来是乱码 —— 本实现不做 CMap 解析，这类文件会产出低质量文本。
 * - 不做版面还原：不分栏、不保表格，按运算符出现顺序拼接。
 * 这是刻意的取舍：先保证「简单 PDF 能读到内容」，而不是为了完美而引入完整 PDF 引擎。
 */
public class PdfTextExtractor {
    /** 最多解析的页数（内容流段数） */
    private static let MAX_PAGES: Int64 = 300
    /** 单个流解压上限（32MB），防御解压炸弹 */
    private static let MAX_STREAM_BYTES: Int64 = 33554432
    /** TJ 数组中负位移超过此阈值（单位：1/1000 文本空间）时补一个空格 */
    private static let TJ_SPACE_THRESHOLD: Int64 = 100

    /**
     * 返回每个内容流抽出的文本，顺序即流在文件中的顺序（近似页序）。
     * 任何情况下都不抛异常；读不出内容就返回空列表。
     */
    public static func extractPages(bytes: Array<Byte>): ArrayList<String> {
        let result = ArrayList<String>()
        let total = Int64(bytes.size)
        if (total == 0) {
            return result
        }
        var pos: Int64 = 0
        while (pos < total && result.size < MAX_PAGES) {
            let streamAt = indexOfAscii(bytes, "stream", pos)
            if (streamAt < 0) {
                break
            }
            // stream 关键字后允许 CRLF 或 LF（PDF 规范要求换行，实测也有直接跟数据的）
            var dataStart = streamAt + 6
            if (dataStart < total && Int64(bytes[dataStart]) == 0x0D) {
                dataStart++
            }
            if (dataStart < total && Int64(bytes[dataStart]) == 0x0A) {
                dataStart++
            }
            let endAt = indexOfAscii(bytes, "endstream", dataStart)
            if (endAt < 0) {
                break
            }
            pos = endAt + 9
            let raw = subBytes(bytes, dataStart, endAt)
            if (raw.size == 0) {
                continue
            }
            let content = inflateOrRaw(raw)
            if (content.size == 0) {
                continue
            }
            // 只有真正画字的流才是内容流；字体 / 图片流没有 Tj、TJ。
            if (indexOfAscii(content, "Tj", 0) < 0 && indexOfAscii(content, "TJ", 0) < 0) {
                continue
            }
            let text = extractTextFromContent(content)
            if (!text.trimAscii().isEmpty()) {
                result.add(text)
            }
        }
        result
    }

    // ==================== 内容流解析 ====================

    private static func extractTextFromContent(c: Array<Byte>): String {
        let n = Int64(c.size)
        let out = StringBuilder()
        var i: Int64 = 0
        while (i < n) {
            let v = Int64(c[i])
            if (v == 0x28) {
                // 左括号：PDF 字面字符串
                let end = findLiteralEnd(c, i)
                if (end < 0) {
                    i++
                    continue
                }
                let after = skipSpace(c, end + 1)
                if (isOperator(c, after, "Tj")) {
                    out.append(decodeLiteral(subBytes(c, i + 1, end)))
                    i = after + 2
                    continue
                }
                i = end + 1
                continue
            }
            if (v == 0x5B) {
                // 左方括号：TJ 数组
                let end = findArrayEnd(c, i)
                if (end < 0) {
                    i++
                    continue
                }
                let after = skipSpace(c, end + 1)
                if (isOperator(c, after, "TJ")) {
                    out.append(decodeTjArray(subBytes(c, i + 1, end)))
                    i = after + 2
                    continue
                }
                i = end + 1
                continue
            }
            i++
        }
        out.toString()
    }

    /**
     * TJ 数组：字符串直接拼接，负位移超过阈值补空格（这就是 PDF 里的词间空格）。
     */
    private static func decodeTjArray(arr: Array<Byte>): String {
        let out = StringBuilder()
        let n = Int64(arr.size)
        var i: Int64 = 0
        while (i < n) {
            let v = Int64(arr[i])
            if (v == 0x28) {
                let end = findLiteralEnd(arr, i)
                if (end < 0) {
                    break
                }
                out.append(decodeLiteral(subBytes(arr, i + 1, end)))
                i = end + 1
                continue
            }
            if (v == 0x3C) {
                let end = indexByte(arr, 0x3E, i + 1)
                if (end < 0) {
                    break
                }
                out.append(decodeHex(subBytes(arr, i + 1, end)))
                i = end + 1
                continue
            }
            if (v == 0x2D || (v >= 0x30 && v <= 0x39)) {
                var j = i
                var negative = false
                if (Int64(arr[j]) == 0x2D) {
                    negative = true
                    j++
                }
                var value: Int64 = 0
                var got = false
                while (j < n && Int64(arr[j]) >= 0x30 && Int64(arr[j]) <= 0x39) {
                    value = value * 10 + (Int64(arr[j]) - 0x30)
                    got = true
                    j++
                }
                if (got && negative && value >= TJ_SPACE_THRESHOLD) {
                    out.append(" ")
                }
                i = if (j > i) { j } else { i + 1 }
                continue
            }
            i++
        }
        out.toString()
    }

    /**
     * 解 PDF 字面字符串的反斜杠转义。注意八进制 \ddd 是字节级转义，
     * 所以结果是字节序列，最后统一交给 bytesToText 按编码解。
     */
    private static func decodeLiteral(raw: Array<Byte>): String {
        let out = ArrayList<Byte>()
        let n = Int64(raw.size)
        var i: Int64 = 0
        while (i < n) {
            let v = Int64(raw[i])
            if (v == 0x5C && i + 1 < n) {
                let nx = Int64(raw[i + 1])
                if (nx >= 0x30 && nx <= 0x37) {
                    var oct = nx - 0x30
                    var j = i + 2
                    var digits: Int64 = 1
                    while (j < n && digits < 3 && Int64(raw[j]) >= 0x30 && Int64(raw[j]) <= 0x37) {
                        oct = oct * 8 + (Int64(raw[j]) - 0x30)
                        j++
                        digits++
                    }
                    out.add(UInt8(oct & 0xFF))
                    i = j
                    continue
                }
                if (nx == 0x6E) {
                    out.add(UInt8(0x0A))
                } else if (nx == 0x72) {
                    out.add(UInt8(0x0D))
                } else if (nx == 0x74) {
                    out.add(UInt8(0x09))
                } else if (nx == 0x62) {
                    out.add(UInt8(0x08))
                } else if (nx == 0x66) {
                    out.add(UInt8(0x0C))
                } else if (nx == 0x28) {
                    out.add(UInt8(0x28))
                } else if (nx == 0x29) {
                    out.add(UInt8(0x29))
                } else if (nx == 0x5C) {
                    out.add(UInt8(0x5C))
                } else if (nx == 0x0A) {
                    () // 行续接，忽略
                } else if (nx == 0x0D) {
                    () // 行续接，忽略
                } else {
                    out.add(raw[i + 1])
                }
                i = i + 2
                continue
            }
            out.add(raw[i])
            i++
        }
        bytesToText(out.toArray())
    }

    /**
     * 解十六进制字符串 <48656C6C6F>。奇数个数字时末尾补 0（PDF 规范约定）。
     */
    private static func decodeHex(raw: Array<Byte>): String {
        let out = ArrayList<Byte>()
        let n = Int64(raw.size)
        var i: Int64 = 0
        var high: Int64 = -1
        while (i < n) {
            let d = hexVal(Int64(raw[i]))
            if (d >= 0) {
                if (high < 0) {
                    high = d
                } else {
                    out.add(UInt8(high * 16 + d))
                    high = -1
                }
            }
            i++
        }
        if (high >= 0) {
            out.add(UInt8(high * 16))
        }
        bytesToText(out.toArray())
    }

    // ==================== 编码 ====================

    /**
     * 字节序列转文本：先认 UTF-16 BOM（PDF 的 Unicode 字符串几乎都带），
     * 再按 UTF-8；都不是就无损兜底展开，绝不因为编码问题丢掉整段内容。
     */
    private static func bytesToText(bytes: Array<Byte>): String {
        if (bytes.size == 0) {
            return ""
        }
        if (bytes.size >= 2) {
            let b0 = Int64(bytes[0])
            let b1 = Int64(bytes[1])
            if (b0 == 0xFE && b1 == 0xFF) {
                return decodeUtf16(bytes, bigEndian: true)
            }
            if (b0 == 0xFF && b1 == 0xFE) {
                return decodeUtf16(bytes, bigEndian: false)
            }
        }
        try {
            String.fromUtf8(bytes)
        } catch (_: Exception) {
            unsafe { String.fromUtf8Unchecked(bytes) }
        }
    }

    private static func decodeUtf16(bytes: Array<Byte>, bigEndian!: Bool = true): String {
        let out = ArrayList<Byte>()
        let n = Int64(bytes.size)
        var i: Int64 = 2
        while (i + 1 < n) {
            let code = if (bigEndian) {
                (Int64(bytes[i]) << 8) | Int64(bytes[i + 1])
            } else {
                (Int64(bytes[i + 1]) << 8) | Int64(bytes[i])
            }
            appendUtf8(out, code)
            i = i + 2
        }
        try {
            String.fromUtf8(out.toArray())
        } catch (_: Exception) {
            ""
        }
    }

    private static func appendUtf8(out: ArrayList<Byte>, code: Int64): Unit {
        if (code < 0x80) {
            out.add(UInt8(code))
        } else if (code < 0x800) {
            out.add(UInt8(0xC0 | (code >> 6)))
            out.add(UInt8(0x80 | (code & 0x3F)))
        } else {
            out.add(UInt8(0xE0 | (code >> 12)))
            out.add(UInt8(0x80 | ((code >> 6) & 0x3F)))
            out.add(UInt8(0x80 | (code & 0x3F)))
        }
    }

    // ==================== 字节工具 ====================

    private static func inflateOrRaw(raw: Array<Byte>): Array<Byte> {
        try {
            let out = Zlib.uncompress(raw, wrap: ZlibType.DEFLATE, bufferSize: 65536,
                maxOutputSize: MAX_STREAM_BYTES)
            if (out.size > 0) {
                return out
            }
        } catch (_: Exception) {
            ()
        }
        raw
    }

    private static func indexOfAscii(data: Array<Byte>, needle: String, from: Int64): Int64 {
        let nb = needle.toArray()
        let n = Int64(data.size)
        let m = Int64(nb.size)
        if (m == 0 || n < m) {
            return -1
        }
        var i = from
        if (i < 0) {
            i = 0
        }
        while (i + m <= n) {
            var ok = true
            var k: Int64 = 0
            while (k < m) {
                if (Int64(data[i + k]) != Int64(nb[k])) {
                    ok = false
                    break
                }
                k++
            }
            if (ok) {
                return i
            }
            i++
        }
        -1
    }

    private static func indexByte(data: Array<Byte>, target: Int64, from: Int64): Int64 {
        let n = Int64(data.size)
        var i = from
        if (i < 0) {
            i = 0
        }
        while (i < n) {
            if (Int64(data[i]) == target) {
                return i
            }
            i++
        }
        -1
    }

    private static func subBytes(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
        let len = end - start
        if (len <= 0 || start < 0 || end > Int64(data.size)) {
            return Array<Byte>()
        }
        Array<Byte>(len, { k => data[start + k] })
    }

    private static func skipSpace(c: Array<Byte>, from: Int64): Int64 {
        let n = Int64(c.size)
        var i = from
        while (i < n) {
            let v = Int64(c[i])
            if (v == 0x20 || v == 0x09 || v == 0x0A || v == 0x0D || v == 0x0C || v == 0x00) {
                i++
            } else {
                break
            }
        }
        i
    }

    private static func isOperator(c: Array<Byte>, at: Int64, op: String): Bool {
        let n = Int64(c.size)
        let ob = op.toArray()
        let m = Int64(ob.size)
        if (at < 0 || at + m > n) {
            return false
        }
        var k: Int64 = 0
        while (k < m) {
            if (Int64(c[at + k]) != Int64(ob[k])) {
                return false
            }
            k++
        }
        true
    }

    /** 找与 start 处左括号配对的右括号（考虑嵌套与反斜杠转义）。 */
    private static func findLiteralEnd(c: Array<Byte>, start: Int64): Int64 {
        let n = Int64(c.size)
        var i = start
        var depth: Int64 = 0
        while (i < n) {
            let v = Int64(c[i])
            if (v == 0x5C) {
                i = i + 2
                continue
            }
            if (v == 0x28) {
                depth++
            } else if (v == 0x29) {
                depth--
                if (depth <= 0) {
                    return i
                }
            }
            i++
        }
        -1
    }

    /** 找与 start 处左方括号配对的右方括号（括号内的字符串要整体跳过）。 */
    private static func findArrayEnd(c: Array<Byte>, start: Int64): Int64 {
        let n = Int64(c.size)
        var i = start
        var depth: Int64 = 0
        var inString = false
        while (i < n) {
            let v = Int64(c[i])
            if (inString && v == 0x5C) {
                i = i + 2
                continue
            }
            if (v == 0x28) {
                inString = true
            } else if (v == 0x29) {
                inString = false
            } else if (!inString && v == 0x5B) {
                depth++
            } else if (!inString && v == 0x5D) {
                depth--
                if (depth <= 0) {
                    return i
                }
            }
            i++
        }
        -1
    }

    private static func hexVal(v: Int64): Int64 {
        if (v >= 0x30 && v <= 0x39) {
            return v - 0x30
        }
        if (v >= 0x41 && v <= 0x46) {
            return v - 0x41 + 10
        }
        if (v >= 0x61 && v <= 0x66) {
            return v - 0x61 + 10
        }
        -1
    }
}
