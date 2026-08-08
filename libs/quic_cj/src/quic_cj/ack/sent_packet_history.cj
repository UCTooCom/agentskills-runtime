package quic_cj.ack

import quic_cj.protocol.{PacketNumber, INVALID_PACKET_NUMBER, EncryptionLevel}
import quic_cj.wire.Frame

/// 跟踪一个已发送的包及其帧数据的条目。
public class PacketEntry {
    public var packetNumber: PacketNumber = 0
    public var packet: SentPacket = SentPacket()
}

/// 跟踪所有已发送和未确认的包，支持按包编号查找和删除。
public class SentPacketHistory {
    private var entries: Array<PacketEntry> = []
    private var highestPacketNumber: PacketNumber = INVALID_PACKET_NUMBER

    /// 记录已发送的包。
    public func sentPacket(pn: PacketNumber, pkt: SentPacket): Unit {
        highestPacketNumber = pn
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packetNumber == pn) { return }
            i += 1
        }
        let entry = PacketEntry()
        entry.packetNumber = pn
        entry.packet = pkt
        entries = appendPacketEntry(entries, entry)
    }

    /// 删除指定包编号的条目。
    public func remove(pn: PacketNumber): Unit {
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packetNumber == pn) {
                entries = removePacketEntryAt(entries, i)
                return
            }
            i += 1
        }
    }

    /// 删除包编号范围 [start, end]（含）内的所有条目。
    public func removeRange(start: PacketNumber, end: PacketNumber): Unit {
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packetNumber >= start && entries[i].packetNumber <= end) {
                entries = removePacketEntryAt(entries, i)
            } else {
                i += 1
            }
        }
    }

    /// 返回所有 outstanding 的包条目。
    public func getOutstandingEntries(): Array<PacketEntry> {
        var result: Array<PacketEntry> = []
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packet.outstanding()) {
                result = appendPacketEntry(result, entries[i])
            }
            i += 1
        }
        result
    }

    /// 检查指定 PN 的包是否存在。
    public func has(pn: PacketNumber): Bool {
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packetNumber == pn) { return true }
            i += 1
        }
        false
    }

    /// 获取指定 PN 的包数据。
    public func get(pn: PacketNumber): Option<SentPacket> {
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packetNumber == pn) { return Some(entries[i].packet) }
            i += 1
        }
        None
    }

    /// 返回当前 tracked 的包数量。
    public func len(): Int64 { entries.size }

    /// 如果存在未确认的包，返回 true。
    public func hasOutstandingPackets(): Bool {
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packet.outstanding()) { return true }
            i += 1
        }
        false
    }

    /// 获取最低的未确认包编号。
    public func firstOutstanding(): (PacketNumber, SentPacket) {
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packet.outstanding()) {
                return (entries[i].packetNumber, entries[i].packet)
            }
            i += 1
        }
        (INVALID_PACKET_NUMBER, SentPacket())
    }

    /// 查找小于等于 pn 的第一个未确认包。
    public func firstOutstandingBelow(pn: PacketNumber): (PacketNumber, SentPacket) {
        var i: Int64 = 0
        var best: PacketNumber = INVALID_PACKET_NUMBER
        var bestPkt: SentPacket = SentPacket()
        while (i < entries.size) {
            let e = entries[i]
            if (e.packet.outstanding() && e.packetNumber <= pn) {
                if (best == INVALID_PACKET_NUMBER || e.packetNumber < best) {
                    best = e.packetNumber
                    bestPkt = e.packet
                }
            }
            i += 1
        }
        (best, bestPkt)
    }

    /// 清空所有条目。
    public func clear(): Unit {
        entries = []
        highestPacketNumber = INVALID_PACKET_NUMBER
    }

    /// 删除所有包编号小于 pn 的条目。
    public func deleteBelow(pn: PacketNumber): Unit {
        var i: Int64 = 0
        while (i < entries.size) {
            if (entries[i].packetNumber < pn) {
                entries = removePacketEntryAt(entries, i)
            } else {
                i += 1
            }
        }
        if (highestPacketNumber < pn) { highestPacketNumber = INVALID_PACKET_NUMBER }
    }

    /// 返回最小的跟踪包编号。
    public func lowestPacketNumber(): PacketNumber {
        if (entries.size == 0) { return INVALID_PACKET_NUMBER }
        var lowest: PacketNumber = entries[0].packetNumber
        var i: Int64 = 1
        while (i < entries.size) {
            if (entries[i].packetNumber < lowest) { lowest = entries[i].packetNumber }
            i += 1
        }
        lowest
    }

    /// 返回所有包编号。
    public func allPacketNumbers(): Array<PacketNumber> {
        var result: Array<PacketNumber> = Array<PacketNumber>(entries.size, repeat: 0)
        var i: Int64 = 0
        while (i < entries.size) {
            result[i] = entries[i].packetNumber
            i += 1
        }
        result
    }

    /// 返回最高跟踪的包编号。
    public func highestPN(): PacketNumber { highestPacketNumber }
}

// ── 辅助函数 ──

internal func appendPacketEntry(arr: Array<PacketEntry>, item: PacketEntry): Array<PacketEntry> {
    let n = arr.size
    var out = Array<PacketEntry>(n + 1, repeat: PacketEntry())
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = item
    out
}

internal func removePacketEntryAt(arr: Array<PacketEntry>, idx: Int64): Array<PacketEntry> {
    let n = arr.size
    if (idx < 0 || idx >= n) { return arr }
    var out = Array<PacketEntry>(n - 1, repeat: PacketEntry())
    var i: Int64 = 0
    var j: Int64 = 0
    while (i < n) {
        if (i != idx) { out[j] = arr[i]; j += 1 }
        i += 1
    }
    out
}
