package quic_cj.core

import quic_cj.protocol.{MAX_BYTE_COUNT}

/// 字节区间：[Start, End)
internal class ByteInterval {
    public var start: Int64 = 0
    public var end: Int64 = 0

    public init(start: Int64, end: Int64) {
        this.start = start
        this.end = end
    }
}

/// FrameSorterEntry 保存已排序队列中一个帧的数据。
internal class FrameSorterEntry {
    public var data: Array<Byte> = []
    public init(data: Array<Byte>) {
        this.data = data
    }
}

/// FrameSorter 使用 gap 算法对乱序到达的 CRYPTO/STREAM 帧数据进行排序。
/// 跟踪已接收数据的间隙，并仅插入填充这些间隙的数据。
public class FrameSorter {
    private var gaps: Array<ByteInterval> = []
    private var keys: Array<Int64> = []      // 并行数组：偏移量键
    private var values: Array<FrameSorterEntry> = []  // 并行数组：条目
    private var readPos: Int64 = 0

    public init() {
        gaps = [ByteInterval(0, MAX_BYTE_COUNT)]
    }

    /// 在指定偏移量推入数据。
    /// 返回 true 表示数据被接受，false 表示重复数据。
    public func push(data: Array<Byte>, offset: Int64): Bool {
        if (data.size == 0) { return false }
        let start: Int64 = offset
        let end: Int64 = offset + Int64(data.size)
        if (gaps.size == 0) { return false }
        if (end <= gaps[0].start) { return false }

        let (startGapIdx, startsInGap) = findStartGap(start)
        if (startGapIdx < 0) { return false }
        let (endGapIdx, endsInGap) = findEndGap(startGapIdx, end)
        if (endGapIdx < 0) { return false }

        let startGapEqEndGap: Bool = startGapIdx == endGapIdx

        if (startGapEqEndGap && end <= gaps[startGapIdx].start) { return false }
        if (!startGapEqEndGap && gaps[startGapIdx].end >= gaps[endGapIdx].start && end <= gaps[startGapIdx].start) { return false }

        let startGapEnd: Int64 = gaps[startGapIdx].end
        let endGapEnd: Int64 = gaps[endGapIdx].end

        var pos: Int64 = start
        var replacedAny: Bool = false
        var actualData: Array<Byte> = data
        var actualEnd: Int64 = end
        var wasCut: Bool = false

        while (true) {
            if (let Some(entry) <- findEntry(pos)) {
                let entryLen = Int64(entry.data.size)
                if (actualEnd - pos > entryLen || (replacedAny && actualEnd - pos == entryLen)) {
                    deleteEntry(pos)
                    pos += entryLen
                    replacedAny = true
                } else {
                    if (!replacedAny) { return false }
                    actualData = actualData[..Int64(pos - start)]
                    actualEnd = pos
                    wasCut = true
                    break
                }
            } else { break }
        }

        var adjStart: Int64 = start
        if (!startsInGap && !replacedAny) {
            let cutFront = Int64(gaps[startGapIdx].start - adjStart)
            actualData = actualData[cutFront..]
            adjStart = gaps[startGapIdx].start
            wasCut = true
        }

        if (adjStart <= gaps[startGapIdx].start) {
            if (actualEnd >= gaps[startGapIdx].end) {
                removeGap(startGapIdx)
            } else {
                gaps[startGapIdx].start = actualEnd
            }
        } else if (!replacedAny) {
            let oldEnd = gaps[startGapIdx].end
            gaps[startGapIdx].end = adjStart
            insertGap(startGapIdx + 1, ByteInterval(actualEnd, oldEnd))
        }

        deleteConsecutive(startGapEnd)
        if (!startGapEqEndGap) {
            if (end >= endGapEnd) {
                removeGap(endGapIdx)
            } else {
                gaps[endGapIdx].start = end
            }
        }

        addEntry(adjStart, FrameSorterEntry(actualData))
        true
    }

    /// 弹出下一个连续的数据块。如果没有连续数据，返回空数组。
    public func pop(): (Int64, Array<Byte>) {
        if (let Some(entry) <- findEntry(readPos)) {
            deleteEntry(readPos)
            let offset: Int64 = readPos
            readPos += Int64(entry.data.size)
            (offset, entry.data)
        } else { return (readPos, []) }
    }

    public func hasMoreData(): Bool { keys.size > 0 }

    private func findStartGap(offset: Int64): (Int64, Bool) {
        var i: Int64 = 0
        while (i < gaps.size) {
            if (offset >= gaps[i].start && offset <= gaps[i].end) { return (i, true) }
            if (offset < gaps[i].start) { return (i, false) }
            i += 1
        }
        (-1, false)
    }

    private func findEndGap(startIdx: Int64, offset: Int64): (Int64, Bool) {
        var i: Int64 = startIdx
        while (i < gaps.size) {
            if (offset >= gaps[i].start && offset < gaps[i].end) { return (i, true) }
            if (offset < gaps[i].start) { return (i - 1, false) }
            i += 1
        }
        (gaps.size - 1, false)
    }

    private func findEntry(offset: Int64): Option<FrameSorterEntry> {
        var i: Int64 = 0
        while (i < keys.size) {
            if (keys[i] == offset) { return Some(values[i]) }
            i += 1
        }
        None
    }

    private func addEntry(offset: Int64, entry: FrameSorterEntry): Unit {
        let n = keys.size
        var newKeys = Array<Int64>(n + 1, repeat: 0)
        var newVals = Array<FrameSorterEntry>(n + 1, repeat: FrameSorterEntry([]))
        var i: Int64 = 0
        while (i < n) { newKeys[i] = keys[i]; newVals[i] = values[i]; i += 1 }
        newKeys[n] = offset
        newVals[n] = entry
        keys = newKeys
        values = newVals
    }

    private func deleteEntry(offset: Int64): Unit {
        let n = keys.size
        var j: Int64 = 0
        var i: Int64 = 0
        while (i < n) {
            if (keys[i] != offset) {
                keys[j] = keys[i]
                values[j] = values[i]
                j += 1
            }
            i += 1
        }
        if (j < n) {
            var newKeys = Array<Int64>(j, repeat: 0)
            var newVals = Array<FrameSorterEntry>(j, repeat: FrameSorterEntry([]))
            i = 0
            while (i < j) { newKeys[i] = keys[i]; newVals[i] = values[i]; i += 1 }
            keys = newKeys
            values = newVals
        }
    }

    private func deleteConsecutive(pos: Int64): Unit {
        var p: Int64 = pos
        while (true) {
            if (let Some(entry) <- findEntry(p)) {
                deleteEntry(p)
                p += Int64(entry.data.size)
            } else { break }
        }
    }

    private func insertGap(idx: Int64, gap: ByteInterval): Unit {
        let n = gaps.size
        var out = Array<ByteInterval>(n + 1, repeat: ByteInterval(0, 0))
        var i: Int64 = 0
        while (i < idx) { out[i] = gaps[i]; i += 1 }
        out[idx] = gap
        i = idx
        while (i < n) { out[i + 1] = gaps[i]; i += 1 }
        gaps = out
    }

    private func removeGap(idx: Int64): Unit {
        let n = gaps.size
        var out = Array<ByteInterval>(n - 1, repeat: ByteInterval(0, 0))
        var i: Int64 = 0
        var j: Int64 = 0
        while (i < n) {
            if (i != idx) { out[j] = gaps[i]; j += 1 }
            i += 1
        }
        gaps = out
    }
}

/// 创建新的 FrameSorter 实例。
public func newFrameSorter(): FrameSorter { FrameSorter() }
