/**
 * QPACK：HTTP/3 头部压缩完整实现（RFC 9204）。
 *
 * QPACK 是 HPACK 的 QUIC 适配变体，用于 HTTP/3 头部压缩。
 * 与 HPACK 的主要区别包括：
 * - 编码器/解码器状态通过专用的单向流（编码器流/解码器流）同步
 * - 使用相对索引（Post-Base / Base），而非 HPACK 的绝对索引
 * - 头部块前缀中含有 Required Insert Count 和 Base（带符号）
 * - 流取消（Stream Cancellation）指令允许解码器通知编码器
 *   已丢弃未解码的流
 *
 * @see https://www.rfc-editor.org/rfc/rfc9204
 */
package http_lib.http3

import std.collection.ArrayList
import std.collection.HashMap
import http_lib.core.{HttpHeaders, ProtocolException}
import http_lib.http2.{encodeQuicVarint, decodeQuicVarint}

// ======== QPACK 常量 ========

public let QPACK_MAX_TABLE_CAPACITY_DEFAULT: Int64 = 0
public let QPACK_BLOCKED_STREAMS_DEFAULT: Int64 = 0

// QPACK 流类型（用于编码器/解码器流的首字节）
public let QPACK_ENCODER_STREAM_TYPE: UInt8 = 0x02
public let QPACK_DECODER_STREAM_TYPE: UInt8 = 0x03

// ======== 静态表（RFC 9204 §2.1）========
// QPACK 静态表与 HPACK 静态表相同，共 99 条。
// 索引范围：0-98（RFC 9204 的表 2 从 HPACK 的表 1 继承）
// 注意：与 HPACK 不同，QPACK 静态表的第一条索引为 0。

public class QpackStaticEntry {
    public let name: String
    public let value: String
    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

internal let QPACK_STATIC_TABLE = 61

internal let qpackStaticTable: Array<QpackStaticEntry> = [
    QpackStaticEntry(":authority", ""),
    QpackStaticEntry(":method", "GET"),
    QpackStaticEntry(":method", "POST"),
    QpackStaticEntry(":path", "/"),
    QpackStaticEntry(":path", "/index.html"),
    QpackStaticEntry(":scheme", "http"),
    QpackStaticEntry(":scheme", "https"),
    QpackStaticEntry(":status", "200"),
    QpackStaticEntry(":status", "204"),
    QpackStaticEntry(":status", "206"),
    QpackStaticEntry(":status", "304"),
    QpackStaticEntry(":status", "400"),
    QpackStaticEntry(":status", "404"),
    QpackStaticEntry(":status", "500"),
    QpackStaticEntry("accept-charset", ""),
    QpackStaticEntry("accept-encoding", "gzip, deflate"),
    QpackStaticEntry("accept-language", ""),
    QpackStaticEntry("accept-ranges", ""),
    QpackStaticEntry("accept", ""),
    QpackStaticEntry("access-control-allow-origin", ""),
    QpackStaticEntry("age", ""),
    QpackStaticEntry("allow", ""),
    QpackStaticEntry("authorization", ""),
    QpackStaticEntry("cache-control", ""),
    QpackStaticEntry("content-disposition", ""),
    QpackStaticEntry("content-encoding", ""),
    QpackStaticEntry("content-language", ""),
    QpackStaticEntry("content-length", ""),
    QpackStaticEntry("content-location", ""),
    QpackStaticEntry("content-range", ""),
    QpackStaticEntry("content-type", ""),
    QpackStaticEntry("cookie", ""),
    QpackStaticEntry("date", ""),
    QpackStaticEntry("etag", ""),
    QpackStaticEntry("expect", ""),
    QpackStaticEntry("expires", ""),
    QpackStaticEntry("from", ""),
    QpackStaticEntry("host", ""),
    QpackStaticEntry("if-match", ""),
    QpackStaticEntry("if-modified-since", ""),
    QpackStaticEntry("if-none-match", ""),
    QpackStaticEntry("if-range", ""),
    QpackStaticEntry("if-unmodified-since", ""),
    QpackStaticEntry("last-modified", ""),
    QpackStaticEntry("link", ""),
    QpackStaticEntry("location", ""),
    QpackStaticEntry("max-forwards", ""),
    QpackStaticEntry("proxy-authenticate", ""),
    QpackStaticEntry("proxy-authorization", ""),
    QpackStaticEntry("range", ""),
    QpackStaticEntry("referer", ""),
    QpackStaticEntry("refresh", ""),
    QpackStaticEntry("retry-after", ""),
    QpackStaticEntry("server", ""),
    QpackStaticEntry("set-cookie", ""),
    QpackStaticEntry("strict-transport-security", ""),
    QpackStaticEntry("transfer-encoding", ""),
    QpackStaticEntry("user-agent", ""),
    QpackStaticEntry("vary", ""),
    QpackStaticEntry("via", ""),
    QpackStaticEntry("www-authenticate", ""),
]

// ======== 动态表条目 ========

internal class QpackDynamicEntry {
    public let name: String
    public let lowerName: String
    public let value: String
    public let size: Int64
    public var absoluteIndex: Int64  // 在动态表中的绝对索引（从 0 开始递增）

    public init(name: String, value: String, absoluteIndex: Int64) {
        this.name = name
        this.lowerName = toLower(name)
        this.value = value
        this.size = name.size + value.size + 32
        this.absoluteIndex = absoluteIndex
    }
}

// ======== 动态表管理 ========

/**
 * QPACK 动态表。
 * 维护按插入顺序排列的动态条目，支持容量控制
 * 和基于绝对索引的查找（供编码器使用）。
 */
internal class QpackDynamicTable {
    private var entries: ArrayList<QpackDynamicEntry> = ArrayList<QpackDynamicEntry>()
    private var maxCapacity: Int64 = 0
    private var currentSize: Int64 = 0
    private var nextAbsoluteIndex: Int64 = 0  // 下一个插入条目的绝对索引
    private var nameIndex: HashMap<String, ArrayList<Int64>> = HashMap<String, ArrayList<Int64>>()

    public init() {}

    public func setCapacity(newCapacity: Int64): Unit {
        maxCapacity = newCapacity
        evictToFit(0)
    }

    public func getMaxCapacity(): Int64 { maxCapacity }
    public func getSize(): Int64 { currentSize }
    public func getNumEntries(): Int64 { entries.size }
    public func getInsertCount(): Int64 { nextAbsoluteIndex }  // 已插入条目总数

    /**
     * 在绝对索引值处插入条目（来自编码器流）。
     * 返回实际插入时的绝对索引值（= nextAbsoluteIndex）。
     */
    public func insert(name: String, value: String): Int64 {
        let entry = QpackDynamicEntry(name, value, nextAbsoluteIndex)
        evictToFit(entry.size)
        entries.add(entry)  // 最近插入的在最前
        currentSize += entry.size
        // 更新名称索引
        match (nameIndex.get(entry.lowerName)) {
            case Some(indices) =>
                indices.add(entries.size - 1)
            case None =>
                let newIndices = ArrayList<Int64>()
                newIndices.add(entries.size - 1)
                nameIndex[entry.lowerName] = newIndices
        }
        let idx = nextAbsoluteIndex
        nextAbsoluteIndex += 1
        idx
    }

    /**
     * 复制已有条目（Duplicate 指令）。
     */
    public func duplicate(absoluteIndex: Int64): Int64 {
        let entry = getByAbsoluteIndex(absoluteIndex)
        match (entry) {
            case Some(e) => return insert(e.name, e.value)
            case None => throw ProtocolException("QPACK duplicate: absolute index ${absoluteIndex} not found")
        }
    }

    /**
     * 按绝对索引获取条目（编码器端查找）。
     */
    public func getByAbsoluteIndex(index: Int64): ?QpackDynamicEntry {
        if (index < 0) { return None }
        for (e in entries) {
            if (e.absoluteIndex == index) { return Some(e) }
        }
        None
    }

    /**
     * 按相对索引获取条目（解码器端查找）。
     * 相对索引 0 = 最新插入的条目。
     */
    public func getByRelativeIndex(relativeIndex: Int64, base: Int64): ?QpackDynamicEntry {
        let targetAbs = base - 1 - relativeIndex
        if (targetAbs < 0) { return None }
        getByAbsoluteIndex(targetAbs)
    }

    /**
     * 按 Post-Base 相对索引获取条目。
     * Post-Base 相对索引 0 = base 指向的条目。
     */
    public func getByPostBaseIndex(postBaseIndex: Int64, base: Int64): ?QpackDynamicEntry {
        let targetAbs = base + postBaseIndex
        if (targetAbs >= nextAbsoluteIndex) { return None }
        getByAbsoluteIndex(targetAbs)
    }

    /**
     * 查找包含指定名称（及可选值）的条目索引。
     * 先搜索动态表（最近插入的最先匹配），再搜索静态表。
     *
     * @param name 字段名称
     * @param value 字段值（非空时要求完全匹配）
     * @return (在静态表中的绝对索引（可能为负=>仅名称匹配），是否值完全匹配)
     */
    public func findEntry(name: String, value: String): (Int64, Bool) {
        let lowerName = toLower(name)
        // 先查静态表全匹配（通过 HashMap 索引 O(1)）
        match (getQpackStaticTableFullIndex().get("${name}\u{0}${value}")) {
            case Some(idx) => return (idx, true)
            case None => ()
        }
        // 再查动态表全匹配（通过 nameIndex 索引, 范围缩小）
        match (nameIndex.get(lowerName)) {
            case Some(indices) =>
                var ii = indices.size - 1
                while (ii >= 0) {
                    let aidx = indices[ii]
                    if (aidx >= 0 && aidx < entries.size) {
                        let e = entries[aidx]
                        if (e.value == value) {
                            return (QPACK_STATIC_TABLE + e.absoluteIndex, true)
                        }
                    }
                    ii -= 1
                }
            case None => ()
        }
        // 静态表名称匹配（通过索引 HashMap O(1)）
        match (getQpackStaticTableNameIndex().get(lowerName)) {
            case Some(indices) =>
                if (indices.size > 0) { return (indices[0], false) }
            case None => ()
        }
        // 动态表名称匹配（通过 nameIndex）
        match (nameIndex.get(lowerName)) {
            case Some(indices) =>
                if (indices.size > 0) {
                    let aidx = indices[indices.size - 1]
                    if (aidx >= 0 && aidx < entries.size) {
                        let e = entries[aidx]
                        return (QPACK_STATIC_TABLE + e.absoluteIndex, false)
                    }
                }
            case None => ()
        }
        (-1, false)  // 未找到
    }
    private func evictToFit(requiredSize: Int64): Unit {
        while (currentSize + requiredSize > maxCapacity && entries.size > 0) {
            let lastIdx = entries.size - 1
            let lastEntry = entries[lastIdx]
            currentSize -= lastEntry.size
            // 从名称索引中移除
            match (nameIndex.get(lastEntry.lowerName)) {
                case Some(indices) =>
                    var j: Int64 = 0
                    while (j < indices.size) {
                        if (indices[j] == lastIdx) {
                            indices.remove(j..j+1)
                            break
                        }
                        j += 1
                    }
                    if (indices.size == 0) {
                        nameIndex.remove(lastEntry.lowerName)
                    }
                case None => ()
            }
            entries.remove(lastIdx..lastIdx + 1)
        }
    }

    public func clear(): Unit {
        entries = ArrayList<QpackDynamicEntry>()
        nameIndex = HashMap<String, ArrayList<Int64>>()
        currentSize = 0
    }
}


private func toLower(s: String): String {
    let raw = unsafe { s.rawData() }
    // 快速路径：检查是否需要转小写（常见 HTTP 头已全小写，可避免分配）
    var needsLower = false
    var i: Int64 = 0
    while (i < raw.size) {
        let b = raw[i]
        if (b >= b'A' && b <= b'Z') {
            needsLower = true
            break
        }
        i += 1
    }
    if (!needsLower) { return s }
    let size = raw.size
    let bytes = Array<UInt8>(size, repeat: 0)
    i = 0
    while (i < size) {
        let b = raw[i]
        bytes[i] = if (b >= b'A' && b <= b'Z') { b + 32 } else { b }
        i += 1
    }
    unsafe { String.withRawData(bytes) }
}

// ======== 静态表索引（延迟初始化，与 HPACK 相同模式）========

private var qpackStaticTableNameIndex: ?HashMap<String, ArrayList<Int64>> = None
private var qpackStaticTableFullIndex: ?HashMap<String, Int64> = None

private func getQpackStaticTableNameIndex(): HashMap<String, ArrayList<Int64>> {
    match (qpackStaticTableNameIndex) {
        case Some(t) => return t
        case None => ()
    }
    let index = HashMap<String, ArrayList<Int64>>()
    for (i in 0..QPACK_STATIC_TABLE) {
        let name = qpackStaticTable[i].name
        let lowerName = toLower(name)
        match (index.get(lowerName)) {
            case Some(indices) => indices.add(i)
            case None =>
                let newIndices = ArrayList<Int64>()
                newIndices.add(i)
                index[lowerName] = newIndices
        }
    }
    qpackStaticTableNameIndex = Some(index)
    index
}

private func getQpackStaticTableFullIndex(): HashMap<String, Int64> {
    match (qpackStaticTableFullIndex) {
        case Some(t) => return t
        case None => ()
    }
    let index = HashMap<String, Int64>()
    for (i in 0..QPACK_STATIC_TABLE) {
        let entry = qpackStaticTable[i]
        index["${entry.name}\u{0}${entry.value}"] = i
    }
    qpackStaticTableFullIndex = Some(index)
    index
}

// ======== 辅助函数 ========

/**
 * RFC 9204 §4.5.1：将头部字段编码为 QPACK 字符串字面量。
 * 字符串使用 Huffman 编码（可选）后跟字节数据。
 *
 * @param data 原始字符串字节
 * @return 编码后的字符串字面量（前缀 + 数据）
 */
internal func encodeQpackString(data: Array<UInt8>): Array<UInt8> {
    let lenEnc = encodeQuicVarint(UInt64(data.size))
    let totalSize = lenEnc.size + data.size
    var result = Array<UInt8>(totalSize, repeat: 0u8)
    if (lenEnc.size > 0) {
        lenEnc.copyTo(result, 0, 0, lenEnc.size)
    }
    data.copyTo(result, 0, lenEnc.size, data.size)
    result
}

/**
 * 解码 QPACK 字符串字面量。
 * 格式：H（1bit）+ 字符串长度（varint）+ 字符串数据（或 Huffman 编码数据）
 *
 * @param data 完整帧数据
 * @param offset 读取偏移
 * @return (解码的字符串, 消耗的字节数)
 */
internal func decodeQpackString(data: Array<UInt8>, offset: Int64): (String, Int64) {
    if (offset >= data.size) {
        throw ProtocolException("QPACK: unexpected end of string data")
    }
    let (rawLen, lenLen) = decodeQuicVarint(data, offset)
    let strLen = Int64(rawLen)
    let strStart = offset + lenLen
    if (strStart + strLen > data.size) {
        throw ProtocolException("QPACK: string truncated: need ${strLen} bytes at ${strStart}, have ${data.size}")
    }
    let strBytes = data[strStart..strStart + strLen]
    let result = String.fromUtf8(strBytes)
    (result, lenLen + strLen)
}

// ======== 编码器流指令 ========

/**
 * 构建 QPACK 编码器流指令：Insert With Name Reference（RFC 9204 §4.2.1）。
 * 格式：1|N|T|NameIndex(varint)|ValueLength(varint)|Value
 */
internal func buildInsertWithNameRef(isStatic: Bool, nameIndex: UInt64, value: Array<UInt8>): ArrayList<UInt8> {
    let idxEnc = encodeQuicVarint(nameIndex)
    let valEnc = encodeQpackString(value)
    let result = ArrayList<UInt8>(1 + idxEnc.size + valEnc.size)
    result.add(0x80u8 | (if (isStatic) { 0x40u8 } else { 0u8 }))
    for (b in idxEnc) { result.add(b) }
    for (b in valEnc) { result.add(b) }
    result
}

/**
 * 构建 QPACK 编码器流指令：Insert Without Name Reference（RFC 9204 §4.2.2）。
 * 格式：0|1|N|NameLength(3bit)|Name|ValueLength(varint)|Value
 */
internal func buildInsertWithoutNameRef(name: Array<UInt8>, value: Array<UInt8>): ArrayList<UInt8> {
    let nameEnc = encodeQpackString(name)
    let valEnc = encodeQpackString(value)
    let result = ArrayList<UInt8>(1 + nameEnc.size + valEnc.size)
    result.add(0x40u8)  // 0|1|N prefix
    for (b in nameEnc) { result.add(b) }
    for (b in valEnc) { result.add(b) }
    result
}

/**
 * 构建 QPACK 编码器流指令：Duplicate（RFC 9204 §4.2.3）。
 * 格式：000|1|Index(varint)
 */
internal func buildDuplicate(absoluteIndex: UInt64): ArrayList<UInt8> {
    let idxEnc = encodeQuicVarint(absoluteIndex)
    let result = ArrayList<UInt8>(1 + idxEnc.size)
    result.add(0x08u8)  // 00001 前缀
    for (b in idxEnc) { result.add(b) }
    result
}

/**
 * 构建 QPACK 编码器流指令：Dynamic Table Size Update（RFC 9204 §4.2.4）。
 * 格式：001|Capacity(varint)
 */
internal func buildTableSizeUpdate(capacity: UInt64): ArrayList<UInt8> {
    let result = ArrayList<UInt8>()
    result.add(0x20u8)  // 001 前缀
    let capEnc = encodeQuicVarint(capacity)
    for (b in capEnc) { result.add(b) }
    result
}

/**
 * 构建 QPACK 解码器流指令：Header Acknowledgement（RFC 9204 §4.4.1）。
 * 格式：1|StreamId(varint)
 */
internal func buildHeaderAck2(streamId: UInt64): Array<UInt8> {
    let sidEnc = encodeQuicVarint(streamId)
    if (sidEnc.size == 0) { return [0x80u8] }
    let result = ArrayList<UInt8>()
    result.add(0x80u8 | sidEnc[0])
    for (i in 1..sidEnc.size) {
        result.add(sidEnc[i])
    }
    result.toArray()
}

/**
 * 构建 QPACK 解码器流指令：Stream Cancellation（RFC 9204 §4.4.2）。
 * 格式：01|StreamId(varint)
 */
internal func buildStreamCancellation(streamId: UInt64): Array<UInt8> {
    let sidEnc = encodeQuicVarint(streamId)
    if (sidEnc.size == 0) { return [0x40u8] }
    let result = ArrayList<UInt8>()
    result.add(0x40u8 | sidEnc[0])
    for (i in 1..sidEnc.size) {
        result.add(sidEnc[i])
    }
    result.toArray()
}

/**
 * 构建 QPACK 解码器流指令：Insert Count Increment（RFC 9204 §4.4.3）。
 * 格式：00|Increment(varint)
 */
internal func buildInsertCountIncrement(increment: UInt64): Array<UInt8> {
    let result = ArrayList<UInt8>()
    result.add(0x00u8)  // 00 前缀
    let incEnc = encodeQuicVarint(increment)
    for (b in incEnc) { result.add(b) }
    result.toArray()
}

// ======== 头部块前缀编解码（RFC 9204 §4.3.1）========

/**
 * 编码头部块前缀。
 * 格式：Required Insert Count (varint) + S(1bit) + Delta Base (sign varint)
 *
 * @param requiredInsertCount 编码器中已知的插入计数（至少包含当前流引用的最新条目）
 * @param base 用于计算相对索引的基数
 * @return 编码后的前缀字节
 */
internal func encodeHeaderBlockPrefix(requiredInsertCount: UInt64, base: UInt64): Array<UInt8> {
    let result = ArrayList<UInt8>()
    let ricEnc = encodeQuicVarint(requiredInsertCount)
    for (b in ricEnc) { result.add(b) }
    let deltaBase = Int64(base) - Int64(requiredInsertCount)
    let sBit: UInt8 = if (deltaBase >= 0) { 0u8 } else { 0x80u8 }
    let absDelta = if (deltaBase >= 0) { UInt64(deltaBase) } else { UInt64(-deltaBase) }
    let dbEnc = encodeQuicVarint(absDelta)
    if (dbEnc.size > 0) {
        result.add(dbEnc[0] | sBit)
        var i: Int64 = 1
        while (i < dbEnc.size) { result.add(dbEnc[i]); i += 1 }
    } else {
        result.add(0x80u8)  // 空 delta = 0，S=0
    }
    result.toArray()
}

/**
 * 解码头部块前缀。
 * @return (requiredInsertCount, base, consumedBytes)
 */
internal func decodeHeaderBlockPrefix(data: Array<UInt8>, offset: Int64): (UInt64, UInt64, Int64) {
    var off = offset
    let (ric, ricLen) = decodeQuicVarint(data, off)
    off += ricLen
    if (off >= data.size) {
        throw ProtocolException("QPACK: header block prefix truncated (need more bytes)")
    }
    let firstByte = data[off]
    let sBit: Bool = (firstByte & 0x80u8) != 0u8
    let modifiedData = data.clone()
    modifiedData[off] = firstByte & 0x7fu8
    let (absDelta, dbLen) = decodeQuicVarint(modifiedData, off)
    off += dbLen
    let base: UInt64 = if (!sBit) {
        ric + absDelta
    } else {
        if (absDelta > ric) { 0u64 } else { ric - absDelta }
    }
    (ric, base, off - offset)
}

// ======== 字段行编解码 ========

/**
 * 将头部字段按 QPACK 编码格式写入字节流。
 *
 * 支持的编码格式（RFC 9204 §4.3）：
 *   Indexed（绝对索引）：1|Index(varint)
 *   Indexed Post-Base：0001|Index(varint)
 *   Literal With Name Reference：01|N|NameIdx|Val
 *   Literal Without Name Reference：001|N|NameLen|Name|Val
 */
internal func encodeFieldLine(name: String, value: String, dynamicTable: QpackDynamicTable, base: UInt64): ArrayList<UInt8> {
    let result = ArrayList<UInt8>()
    let nameBytes = unsafe { name.rawData() }
    let valueBytes = unsafe { value.rawData() }

    // 预分配容量以减少动态扩容
    result.reserve(32 + nameBytes.size + valueBytes.size)

    let (tableIndex, exactMatch) = dynamicTable.findEntry(name, value)

    if (exactMatch && tableIndex >= 0) {
        if (tableIndex < QPACK_STATIC_TABLE) {
            let idxEnc = encodeQuicVarint(UInt64(tableIndex))
            result.add(0x80u8)  // 1 前缀
            for (b in idxEnc) { result.add(b) }
        } else {
            let dynIdx = tableIndex - QPACK_STATIC_TABLE
            if (UInt64(dynIdx) < base) {
                let relIdx = base - UInt64(1) - UInt64(dynIdx)
                let idxEnc2 = encodeQuicVarint(relIdx)
                result.add(0x80u8)
                for (b in idxEnc2) { result.add(b) }
            } else {
                let postBaseIdx = UInt64(dynIdx) - base
                let pbEnc = encodeQuicVarint(postBaseIdx)
                result.add(0x10u8)  // 0001 prefix
                for (b in pbEnc) { result.add(b) }
            }
        }
        return result
    }
    // Fallback: Literal Without Name Reference
    result.add(0x20u8)  // 001|N prefix
    for (b in encodeQpackString(nameBytes)) { result.add(b) }
    for (b in encodeQpackString(valueBytes)) { result.add(b) }
    result
}

// ======== QPACK 完整编码器 ========

/**
 * QPACK 编码器。
 * 管理动态表的状态，将 HTTP 头部块编码为 QPACK 编码数据。
 * 同时管理编码器流的输出（动态表更新指令）和解码器流输入（确认指令）。
 */
public class QpackEncoder {
    private var dynamicTable: QpackDynamicTable
    private var maxTableCapacity: Int64 = 4096
    private var blockedStreams: Int64 = 100
    private var encoderStreamBuffer: ArrayList<UInt8>
    private var pendingAckStreams: HashMap<UInt64, Int64>
    /// 解码器已确认的插入计数（来自 Insert Count Increment / Header Ack）。
    public var decoderKnownInsertCount: Int64 = 0

    public init(maxTableCapacity!: Int64 = QPACK_MAX_TABLE_CAPACITY_DEFAULT, blockedStreams!: Int64 = QPACK_BLOCKED_STREAMS_DEFAULT) {
        this.dynamicTable = QpackDynamicTable()
        this.maxTableCapacity = maxTableCapacity
        this.blockedStreams = blockedStreams
        this.encoderStreamBuffer = ArrayList<UInt8>()
        this.pendingAckStreams = HashMap<UInt64, Int64>()
    }

    /**
     * 将 HTTP 头编码为 QPACK 头部块（RFC 9204 §4.3）。
     * 返回编码后的头部块字节（包含前缀）。
     *
     * 如果动态表有可用容量，常见条目会被添加以加速后续压缩。
     */
    public func encode(headers: HttpHeaders): Array<UInt8> {
        // 预分配 ArrayList 容量，减少扩容次数
        let result = ArrayList<UInt8>(512)
        let ric: UInt64 = UInt64(dynamicTable.getInsertCount())
        let base: UInt64 = ric
        let prefix = encodeHeaderBlockPrefix(ric, base)
        for (b in prefix) { result.add(b) }
        for ((name, value) in headers.entries()) {
            let fieldLine = encodeFieldLine(name, value, dynamicTable, base)
            for (b in fieldLine) { result.add(b) }
            let entrySize = name.size + value.size + 32
            if (entrySize <= maxTableCapacity && maxTableCapacity > 0) {
                let absIdx = dynamicTable.insert(name, value)
                let insBytes = buildInsertWithoutNameRef(
                    unsafe { name.rawData() },
                    unsafe { value.rawData() }
                )
                for (b in insBytes) { encoderStreamBuffer.add(b) }
            }
        }
        result.toArray()
    }

    /**
     * 取回待发送的编码器流数据。
     */
    public func getEncoderStreamData(): Array<UInt8> {
        let result = encoderStreamBuffer.toArray()
        encoderStreamBuffer = ArrayList<UInt8>()
        result
    }

    /**
     * 注册已编码的流 ID，用于追踪待确认的 QPACK Header Ack。
     * 每次使用 encode() 编码头部后调用，便于编码器在收到
     * Header Acknowledgement 或 Stream Cancellation 时验证流状态。
     *
     * @param streamId 编码头部所属的 QUIC 流 ID
     */
    public func registerEncodedStream(streamId: UInt64): Unit {
        pendingAckStreams[streamId] = dynamicTable.getInsertCount()
    }

    /**
     * 检查指定流是否已注册且等待 ACK。
     * 用于 Stream Cancellation 验证。
     */
    public func hasPendingAckStream(streamId: UInt64): Bool {
        pendingAckStreams.get(streamId) != None
    }

    /**
     * 获取等待 ACK 的流数量。
     */
    public func getPendingAckStreamCount(): Int64 {
        pendingAckStreams.size
    }

    /**
     * 获取所有等待 ACK 的流 ID 列表。
     */
    public func getPendingAckStreamIds(): ArrayList<UInt64> {
        let result = ArrayList<UInt64>()
        for (sid in pendingAckStreams.keys()) {
            result.add(sid)
        }
        result
    }

    /**
     * 处理解码器流确认指令。
     * 处理 Header Acknowledgement、Insert Count Increment、Stream Cancellation。
     */
    public func processDecoderInstruction(data: Array<UInt8>): Unit {
        if (data.size == 0) { return }
        let firstByte = data[0]
        if ((firstByte & 0x80u8) != 0u8) {
            let cleanData = data.clone()
            cleanData[0] = firstByte & 0x7fu8
            let (sid, _) = decodeQuicVarint(cleanData, 0)
            pendingAckStreams.remove(sid)
            let insertCount = dynamicTable.getInsertCount()
            if (insertCount > decoderKnownInsertCount) {
                decoderKnownInsertCount = insertCount
            }
        } else if ((firstByte & 0x40u8) != 0u8) {
            // Stream Cancellation: 01|StreamId(varint)
            // 对端放弃了一个流的头部解码，编码器应释放对该流的引用追踪
            let cleanData = data.clone()
            cleanData[0] = firstByte & 0x3fu8
            let (sid, _) = decodeQuicVarint(cleanData, 0)
            pendingAckStreams.remove(sid)
        } else {
            // Insert Count Increment: 00|Increment(varint)
            let (increment, _) = decodeQuicVarint(data, 0)
            decoderKnownInsertCount += Int64(increment)
            if (decoderKnownInsertCount > dynamicTable.getInsertCount()) {
                decoderKnownInsertCount = dynamicTable.getInsertCount()
            }
        }
    }

    /// 获取解码器已知的插入计数。
    public func getDecoderKnownInsertCount(): Int64 { decoderKnownInsertCount }

    public func getMaxTableCapacity(): Int64 { maxTableCapacity }
    public func getBlockedStreams(): Int64 { blockedStreams }
}

// ======== QPACK 完整解码器 ========

/**
 * QPACK 解码器。
 * 管理动态表的状态，将 QPACK 编码的头部块解码为 HTTP 头部。
 */
public class QpackDecoder {
    private var dynamicTable: QpackDynamicTable
    private var maxTableCapacity: Int64 = 4096
    private var blockedStreams: HashMap<UInt64, Array<UInt8>> = HashMap<UInt64, Array<UInt8>>()
    private var knownInsertCount: Int64 = 0

    public init(maxTableCapacity!: Int64 = QPACK_MAX_TABLE_CAPACITY_DEFAULT) {
        this.dynamicTable = QpackDynamicTable()
        this.maxTableCapacity = maxTableCapacity
    }

    /**
     * 解码 QPACK 编码的头部块（RFC 9204 §4.3）。
     * 返回解码后的 HttpHeaders。
     */
    public func decode(data: Array<UInt8>): HttpHeaders {
        let headers = HttpHeaders()
        if (data.size == 0) { return headers }
        var offset: Int64 = 0
        let (ric, base, prefixLen) = decodeHeaderBlockPrefix(data, offset)
        offset += prefixLen

        while (offset < data.size) {
            let firstByte = data[offset]
            if ((firstByte & 0x80u8) != 0u8) {
                let (rawIdx, idxLen) = decodeQuicVarint(data, offset)
                offset += idxLen
                let name: String
                let value: String
                if (rawIdx < UInt64(QPACK_STATIC_TABLE)) {
                    let entry = qpackStaticTable[Int64(rawIdx)]
                    name = entry.name
                    value = entry.value
                } else {
                    match (dynamicTable.getByRelativeIndex(Int64(rawIdx), Int64(base))) {
                        case Some(e) =>
                            name = e.name
                            value = e.value
                        case None =>
                            throw ProtocolException("QPACK: relative index ${rawIdx} out of range (base=${base})")
                    }
                }
                headers.add(name, value)
            } else if ((firstByte & 0x40u8) != 0u8) {
                let (nameIdx, nameIdxLen) = decodeQuicVarint(data, offset)
                offset += nameIdxLen
                let (val, valLen) = decodeQpackString(data, offset)
                offset += valLen
                let name = if (Int64(nameIdx) < QPACK_STATIC_TABLE) {
                    qpackStaticTable[Int64(nameIdx)].name
                } else {
                    match (dynamicTable.getByRelativeIndex(Int64(nameIdx) - QPACK_STATIC_TABLE, Int64(base))) {
                        case Some(e) => e.name
                        case None => throw ProtocolException("QPACK: name index ${nameIdx} out of range")
                    }
                }
                headers.add(name, val)
            } else if ((firstByte & 0x20u8) != 0u8) {
                offset += 1
                let (name, nameLen) = decodeQpackString(data, offset)
                offset += nameLen
                let (val, valLen) = decodeQpackString(data, offset)
                offset += valLen
                headers.add(name, val)
            } else if ((firstByte & 0x10u8) != 0u8) {
                offset += 1
                let (pbIdx, pbIdxLen) = decodeQuicVarint(data, offset)
                offset += pbIdxLen
                match (dynamicTable.getByPostBaseIndex(Int64(pbIdx), Int64(base))) {
                    case Some(e) => headers.add(e.name, e.value)
                    case None => throw ProtocolException("QPACK: post-base index ${pbIdx} out of range (base=${base})")
                }
            } else {
                offset += 1
                let (nameIdx, nameIdxLen) = decodeQuicVarint(data, offset)
                offset += nameIdxLen
                let (val, valLen) = decodeQpackString(data, offset)
                offset += valLen
                match (dynamicTable.getByPostBaseIndex(Int64(nameIdx), Int64(base))) {
                    case Some(e) => headers.add(e.name, val)
                    case None => throw ProtocolException("QPACK: post-base name index ${nameIdx} out of range")
                }
            }
        }
        headers
    }

    /**
     * 处理编码器流数据（动态表更新指令）。
     */
    public func processEncoderStream(data: Array<UInt8>): Unit {
        var offset: Int64 = 0
        while (offset < data.size) {
            let firstByte = data[offset]
            if ((firstByte & 0x80u8) != 0u8) {
                let tBit = (firstByte & 0x40u8) != 0u8
                offset += 1
                let (nameIdx, nameIdxLen) = decodeQuicVarint(data, offset)
                offset += nameIdxLen
                let (val, valLen) = decodeQpackString(data, offset)
                offset += valLen
                let name = if (tBit) {
                    qpackStaticTable[Int64(nameIdx)].name
                } else {
                    match (dynamicTable.getByAbsoluteIndex(Int64(nameIdx))) {
                        case Some(e) => e.name
                        case None => throw ProtocolException("QPACK: encoder stream name index ${nameIdx} out of range")
                    }
                }
                dynamicTable.insert(name, val)
            } else if ((firstByte & 0x40u8) != 0u8) {
                offset += 1
                let (name, nameLen) = decodeQpackString(data, offset)
                offset += nameLen
                let (val, valLen) = decodeQpackString(data, offset)
                offset += valLen
                dynamicTable.insert(name, val)
            } else if ((firstByte & 0x08u8) != 0u8) {
                offset += 1
                let (dupIdx, dupIdxLen) = decodeQuicVarint(data, offset)
                offset += dupIdxLen
                dynamicTable.duplicate(Int64(dupIdx))
            } else if ((firstByte & 0x20u8) != 0u8) {
                offset += 1
                let (cap, capLen) = decodeQuicVarint(data, offset)
                offset += capLen
                dynamicTable.setCapacity(Int64(cap))
            } else {
                offset += 1
            }
        }
    }

    public func getMaxTableCapacity(): Int64 { maxTableCapacity }
    public func getKnownInsertCount(): Int64 { knownInsertCount }

    /**
     * 尝试解码头部块：若不满足条件则加入阻塞队列。
     * RFC 9204 §2.2.2：当解码器引用的动态表条目尚未到达时，流进入阻塞状态。
     * @return 成功返回 HttpHeaders，阻塞返回 None
     */
    public func decodeBlocked(data: Array<UInt8>, streamId: UInt64): ?HttpHeaders {
        try {
            return decode(data)
        } catch (_: ProtocolException) {
            blockedStreams[streamId] = data
            return None
        }
    }

    /**
     * 尝试解除指定流的 QPACK 阻塞状态。
     */
    public func tryUnblockStream(streamId: UInt64): ?HttpHeaders {
        match (blockedStreams.get(streamId)) {
            case Some(data) =>
                try {
                    let headers = decode(data)
                    blockedStreams.remove(streamId)
                    return Some(headers)
                } catch (_: ProtocolException) {
                    None
                }
            case None => None
        }
    }

    /**
     * 尝试解除所有阻塞流。在编码器流数据到达后调用。
     * @return 成功解除阻塞的流 (streamId -> headers) 映射
     */
    public func tryUnblockAll(): HashMap<UInt64, HttpHeaders> {
        let result = HashMap<UInt64, HttpHeaders>()
        let keys = ArrayList<UInt64>()
        for (key in blockedStreams.keys()) {
            keys.add(key)
        }
        for (sid in keys) {
            let data = blockedStreams.get(sid)
            match (data) {
                case Some(d) =>
                    try {
                        let headers = decode(d)
                        result[sid] = headers
                        blockedStreams.remove(sid)
                    } catch (_: ProtocolException) {}
                case None => ()
            }
        }
        result
    }

    /**
     * 是否有阻塞的流。
     */
    public func hasBlockedStreams(): Bool { blockedStreams.size > 0 }

    /**
     * 获取阻塞流数量。
     */
    public func getBlockedStreamCount(): Int64 { blockedStreams.size }

}

// ======== 导出函数（兼容原接口）========

public func buildHeaderAck(streamId: UInt64): Array<UInt8> {
    buildHeaderAck2(streamId)
}

public func decodeEncoderStream(data: Array<UInt8>): Unit {
    let decoder = QpackDecoder()
    decoder.processEncoderStream(data)
}

public func buildInsertCountIncrementFrame(increment: UInt64): Array<UInt8> {
    buildInsertCountIncrement(increment)
}

public func buildStreamCancellationFrame(streamId: UInt64): Array<UInt8> {
    buildStreamCancellation(streamId)
}

// QPACK 流类型
public let QPACK_STREAM_TYPE_ENCODER: UInt8 = 0x02
public let QPACK_STREAM_TYPE_DECODER: UInt8 = 0x03
