/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal.builtin

import compress4cj.zlib.Zlib
import compress4cj.zlib.ZlibType

import std.collection.ArrayList

/**
 * 极简 ZIP 读取器（只读，无写入）。
 *
 * 【为什么自己写】DOCX / PPTX 本质都是 ZIP 容器，ingestion 需要按条目名取出里面的 XML
 * 再抽文本。vendored 的 zip4cj 只支持「磁盘文件 解到磁盘目录」，而附件是**内存中的
 * base64 字节**，用它需要落临时文件再解，凭空引入临时目录管理与清理负担；ZIP 容器解析
 * 本身只是「定长头部 + 小端整数」，几十行就能覆盖真实场景（无加密、deflate 或 store），
 * 解压仍然复用项目已接入的 compress4cj，不新增任何依赖。
 *
 * 【明确不支持】加密条目、ZIP64（>4GB）、分卷、除 deflate / store 之外的算法。
 * 遇到这些情况 `entries()` 只返回能安全解析的条目，调用方走兜底分支即可，绝不抛异常。
 */
public class ZipEntryLite {
    /** 条目名（ZIP 内部路径，如 word/document.xml） */
    public let name: String
    /** 压缩方法：0=store，8=deflate */
    public let method: Int64
    public let compSize: Int64
    public let uncompSize: Int64
    /** 条目数据在原字节数组中的起始下标；-1 表示本地头解析失败 */
    public let dataOffset: Int64

    public init(name: String, method: Int64, compSize: Int64, uncompSize: Int64, dataOffset: Int64) {
        this.name = name
        this.method = method
        this.compSize = compSize
        this.uncompSize = uncompSize
        this.dataOffset = dataOffset
    }
}

public class ZipLite {
    /** End Of Central Directory 签名 */
    private static let SIG_EOCD: Int64 = 0x06054B50
    /** Central Directory File Header 签名 */
    private static let SIG_CDH: Int64 = 0x02014B50
    /** Local File Header 签名 */
    private static let SIG_LFH: Int64 = 0x04034B50
    /** 条目数上限：防止 EOCD 被篡改导致巨量循环 */
    private static let MAX_ENTRIES: Int64 = 4096
    /** 单条目压缩数据读取上限（32MB）：防御畸形 compSize */
    private static let MAX_READ_BYTES: Int64 = 33554432

    /**
     * 解析中央目录，返回全部条目。任何异常都退化成空列表。
     */
    public static func entries(data: Array<Byte>): ArrayList<ZipEntryLite> {
        let result = ArrayList<ZipEntryLite>()
        let total = Int64(data.size)
        if (total < 22) {
            return result
        }
        // EOCD 位于文件尾部，最多带 65535 字节注释，从「倒数 22 字节」往前扫。
        let floor = if (total - 65558 > 0) { total - 65558 } else { 0 }
        var cursor = total - 22
        var eocd: Int64 = -1
        while (cursor >= floor) {
            if (u32(data, cursor) == SIG_EOCD) {
                eocd = cursor
                break
            }
            cursor--
        }
        if (eocd < 0) {
            return result
        }
        let count = u16(data, eocd + 10)
        let cdOffset = u32(data, eocd + 16)
        if (cdOffset <= 0 || cdOffset >= total) {
            return result
        }
        var pointer = cdOffset
        var seen: Int64 = 0
        while (seen < count && seen < MAX_ENTRIES) {
            if (pointer + 46 > total) {
                break
            }
            if (u32(data, pointer) != SIG_CDH) {
                break
            }
            let method = u16(data, pointer + 10)
            let compSize = u32(data, pointer + 20)
            let uncompSize = u32(data, pointer + 24)
            let nameLen = u16(data, pointer + 28)
            let extraLen = u16(data, pointer + 30)
            let commentLen = u16(data, pointer + 32)
            let localOffset = u32(data, pointer + 42)
            let name = utf8(data, pointer + 46, nameLen)
            result.add(ZipEntryLite(name, method, compSize, uncompSize, localDataOffset(data, localOffset)))
            pointer = pointer + 46 + nameLen + extraLen + commentLen
            seen++
        }
        result
    }

    /**
     * 按完整条目名查找（ZIP 内路径区分大小写，OOXML 的路径是固定小写）。
     */
    public static func find(entries: ArrayList<ZipEntryLite>, name: String): Option<ZipEntryLite> {
        for (entry in entries) {
            if (entry.name == name) {
                return Some(entry)
            }
        }
        None
    }

    /**
     * 读取并解压一个条目。失败返回空数组（不抛异常）。
     */
    public static func read(data: Array<Byte>, entry: ZipEntryLite, maxOutputSize!: Int64 = 0): Array<Byte> {
        let total = Int64(data.size)
        if (entry.dataOffset < 0 || entry.dataOffset >= total) {
            return Array<Byte>()
        }
        let avail = total - entry.dataOffset
        var take = entry.compSize
        if (take <= 0 || take > avail) {
            take = avail
        }
        if (take > MAX_READ_BYTES) {
            take = MAX_READ_BYTES
        }
        if (take <= 0) {
            return Array<Byte>()
        }
        let raw = Array<Byte>(take, { k => data[entry.dataOffset + k] })
        if (entry.method == 0) {
            return raw
        }
        if (entry.method != 8) {
            return Array<Byte>()
        }
        try {
            return Zlib.uncompress(raw, wrap: ZlibType.DEFLATE, bufferSize: 65536, maxOutputSize: maxOutputSize)
        } catch (_: Exception) {
            return Array<Byte>()
        }
    }

    // ==================== 内部工具 ====================

    private static func u16(data: Array<Byte>, off: Int64): Int64 {
        if (off < 0 || off + 2 > Int64(data.size)) {
            return 0
        }
        Int64(data[off]) | (Int64(data[off + 1]) << 8)
    }

    private static func u32(data: Array<Byte>, off: Int64): Int64 {
        if (off < 0 || off + 4 > Int64(data.size)) {
            return 0
        }
        Int64(data[off]) | (Int64(data[off + 1]) << 8) |
            (Int64(data[off + 2]) << 16) | (Int64(data[off + 3]) << 24)
    }

    /**
     * 由本地文件头算出真实数据起点：本地头的名字长度与额外字段长度可能和中央目录不一致，
     * 必须以本地头为准，否则会解出偏移错位的垃圾。
     */
    private static func localDataOffset(data: Array<Byte>, localOffset: Int64): Int64 {
        let total = Int64(data.size)
        if (localOffset < 0 || localOffset + 30 > total) {
            return -1
        }
        if (u32(data, localOffset) != SIG_LFH) {
            return -1
        }
        let nameLen = u16(data, localOffset + 26)
        let extraLen = u16(data, localOffset + 28)
        localOffset + 30 + nameLen + extraLen
    }

    private static func utf8(data: Array<Byte>, off: Int64, len: Int64): String {
        if (len <= 0 || off < 0 || off + len > Int64(data.size)) {
            return ""
        }
        let buf = Array<Byte>(len, { k => data[off + k] })
        try {
            String.fromUtf8(buf)
        } catch (_: Exception) {
            unsafe { String.fromUtf8Unchecked(buf) }
        }
    }
}
