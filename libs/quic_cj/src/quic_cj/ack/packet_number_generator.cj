package quic_cj.ack

import quic_cj.protocol.PacketNumber
import std.random.Random

/// PacketNumberGenerator 生成包编号。
open public class PacketNumberGenerator {
    /// 返回下一个包编号但不消费它。
    open public func peek(): PacketNumber { 0 }
    /// 消费并返回下一个包编号。
    /// 返回 (was_skipped, packet_number)。
    open public func pop(): (Bool, PacketNumber) { (false, 0) }
}

/// 顺序生成包编号。
public class SequentialPacketNumberGenerator <: PacketNumberGenerator {
    private var next: PacketNumber = 0

    public init(initial: PacketNumber) {
        this.next = initial
    }

    public func peek(): PacketNumber { next }
    public func pop(): (Bool, PacketNumber) {
        let n = next
        next += 1
        (false, n)
    }
}

/// SkippingPacketNumberGenerator 偶尔跳过 PN 以增强 PN 加密。
public class SkippingPacketNumberGenerator <: PacketNumberGenerator {
    private var next: PacketNumber = 0
    private var nextToSkip: PacketNumber = 0
    private var period: PacketNumber = 0
    private var maxPeriod: PacketNumber = 0
    private var rng: Random = Random()

    public init(initial: PacketNumber, initialPeriod: PacketNumber, maxPeriodParam: PacketNumber) {
        this.next = initial
        this.period = initialPeriod
        this.maxPeriod = maxPeriodParam
        generateNewSkip()
    }

    public func peek(): PacketNumber {
        if (next == nextToSkip) { return next + 1 }
        next
    }

    public func pop(): (Bool, PacketNumber) {
        let n = next
        if (next == nextToSkip) {
            next += 2
            generateNewSkip()
            (true, n + 1)
        } else {
            next += 1
            (false, n)
        }
    }

    private func generateNewSkip(): Unit {
        let offset = 3 + (rng.nextInt64() % (2 * period))
        nextToSkip = next + offset
        period = if (2 * period < maxPeriod) { 2 * period } else { maxPeriod }
    }
}

/// 创建从 0 开始的顺序包编号生成器。
public func newSequentialGenerator(): PacketNumberGenerator {
    SequentialPacketNumberGenerator(0)
}

/// 创建跳过式包编号生成器。
public func newSkippingGenerator(initialPeriod: PacketNumber, maxPeriod: PacketNumber): PacketNumberGenerator {
    SkippingPacketNumberGenerator(0, initialPeriod, maxPeriod)
}
