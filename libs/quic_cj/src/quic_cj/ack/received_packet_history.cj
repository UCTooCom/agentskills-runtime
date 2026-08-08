package quic_cj.ack

import quic_cj.protocol.{PacketNumber, INVALID_PACKET_NUMBER, MAX_NUM_ACK_RANGES}

/// Interval 表示接收到的包编号的连续范围 [开始, 结束]。
public class Interval {
    public var start: PacketNumber = 0
    public var end: PacketNumber = 0
    public init() {}
    public init(start: PacketNumber, end: PacketNumber) {
        this.start = start
        this.end = end
    }
}

/// 跟踪收到的包编号并生成 ACK 范围。
public class ReceivedPacketHistory {
    private var ranges: Array<Interval> = Array<Interval>(MAX_NUM_ACK_RANGES, repeat: Interval())
    private var rangeCount: Int64 = 0
    private var deletedBelow: PacketNumber = INVALID_PACKET_NUMBER

    /// 注册收到的包编号。
    /// 如果是新包（不是重复/延迟的），返回 true。
    public func receivedPacket(pn: PacketNumber): Bool {
        if (pn < deletedBelow) { return false }
        let isNew = addToRanges(pn)
        if (rangeCount > MAX_NUM_ACK_RANGES) {
            deleteFrontRanges(rangeCount - MAX_NUM_ACK_RANGES)
        }
        isNew
    }

    /// 删除 pn 以下（不包括 pn）的所有范围。
    public func deleteBelow(pn: PacketNumber): Unit {
        if (pn < deletedBelow) { return }
        deletedBelow = pn
        if (rangeCount == 0) { return }
        var deleteIdx: Int64 = -1
        var i: Int64 = 0
        while (i < rangeCount) {
            let r = ranges[i]
            if (r.end < pn) {
                deleteIdx = i
            } else if (pn > r.start && pn <= r.end) {
                ranges[i].start = pn
                break
            } else {
                break
            }
            i += 1
        }
        if (deleteIdx >= 0) {
            deleteFrontRanges(deleteIdx + 1)
        }
    }

    /// 反向返回范围（用于 ACK 帧构建）。
    /// 从最大到最小的包编号返回区间。
    /// 将反向范围直接写入 target（预分配数组），返回写入的区间数。
    public func fillBackwardRanges(target: Array<(Int64, Int64)>): Int64 {
        var i: Int64 = 0
        while (i < rangeCount) {
            target[i] = (ranges[rangeCount - 1 - i].start, ranges[rangeCount - 1 - i].end)
            i += 1
        }
        rangeCount
    }

    /// 返回最大已确认包编号（避免 backwardGetRanges 的数组分配）。
    public func getLargestAcked(): PacketNumber {
        if (rangeCount > 0) { ranges[rangeCount - 1].end } else { 0 }
    }

    /// 返回到 p 为止的最高丢失包编号。
    public func highestMissingUpTo(p: PacketNumber): PacketNumber {
        if (rangeCount == 0) { return INVALID_PACKET_NUMBER }
        let lastEnd = ranges[rangeCount - 1].end
        let limit = if (p < lastEnd) { p } else { lastEnd }
        var i: Int64 = rangeCount - 1
        while (i >= 0) {
            let r = ranges[i]
            if (limit >= r.start && limit <= r.end) {
                let highest = r.start - 1
                if (deletedBelow != INVALID_PACKET_NUMBER && highest < deletedBelow) {
                    return INVALID_PACKET_NUMBER
                }
                return highest
            }
            if (i >= 1) {
                let prevEnd = ranges[i - 1].end
                if (limit > prevEnd && limit <= r.start) {
                    return limit
                }
            }
            i -= 1
        }
        limit
    }

    /// 检查包编号是否可能是重复的。
    public func isPotentiallyDuplicate(pn: PacketNumber): Bool {
        if (pn < deletedBelow) { return true }
        var i: Int64 = rangeCount - 1
        while (i >= 0) {
            let r = ranges[i]
            if (pn > r.end) { return false }
            if (pn >= r.start && pn <= r.end) { return true }
            i -= 1
        }
        false
    }

    /// 将包编号添加到范围中。
    private func addToRanges(pn: PacketNumber): Bool {
        if (rangeCount == 0) {
            ranges[0] = Interval(pn, pn)
            rangeCount = 1
            return true
        }
        var i: Int64 = rangeCount - 1
        while (i >= 0) {
            let r = ranges[i]
            if (pn >= r.start && pn <= r.end) { return false }
            if (r.end == pn - 1) {
                ranges[i].end = pn
                return true
            }
            if (r.start == pn + 1) {
                ranges[i].start = pn
                if (i > 0 && ranges[i - 1].end + 1 == ranges[i].start) {
                    ranges[i - 1].end = ranges[i].end
                    deleteRangeAt(i)
                }
                return true
            }
            if (pn > r.end) {
                insertRangeAt(i + 1, Interval(pn, pn))
                return true
            }
            i -= 1
        }
        insertRangeAt(0, Interval(pn, pn))
        true
    }

    private func insertRangeAt(idx: Int64, interval: Interval): Unit {
        var i: Int64 = rangeCount
        while (i > idx) {
            ranges[i] = ranges[i - 1]
            i -= 1
        }
        ranges[idx] = interval
        rangeCount += 1
    }

    private func deleteRangeAt(idx: Int64): Unit {
        var i: Int64 = idx
        while (i < rangeCount - 1) {
            ranges[i] = ranges[i + 1]
            i += 1
        }
        rangeCount -= 1
    }

    private func deleteFrontRanges(count: Int64): Unit {
        let shift = if (count > rangeCount) { rangeCount } else { count }
        var i: Int64 = 0
        while (i < rangeCount - shift) {
            ranges[i] = ranges[i + shift]
            i += 1
        }
        rangeCount -= shift
    }

    /// 保留旧接口（测试兼容）
    public func backwardGetRanges(): Array<Interval> {
        let count = rangeCount
        var out = Array<Interval>(count, repeat: Interval())
        var i: Int64 = 0
        while (i < count) {
            out[i] = ranges[count - 1 - i]
            i += 1
        }
        out
    }
}
