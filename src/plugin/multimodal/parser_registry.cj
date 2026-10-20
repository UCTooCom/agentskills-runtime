/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import magic.log.LogUtils

/**
 * 单个解析器的健康统计（IF-04d 回写）。
 */
class ParserHealth {
    public var successCount: Int64 = 0
    public var failCount: Int64 = 0
    public var totalCostMs: Int64 = 0
    public var lastError: String = ""
    public init() {}
}

/**
 * 解析器可观测快照（契约 IF-04f / T-HAC-12）。
 *
 * 供运维查「已注册解析器 / 命中率 / 失败 TopN / 平均耗时」。`failRate` 升序即健康度升序，
 * 故 `stats()` 按失败率降序返回，取前 N 个就是失败 TopN。
 * 注意：本类是 public —— `stats()` 是 public，返回值类型不能是包内私有类型。
 */
public class ParserStat {
    public let parserId: String
    public let version: String
    public let track: String
    public let successCount: Int64
    public let failCount: Int64
    public let totalCostMs: Int64
    /** 平均耗时（仅统计成功调用；无成功调用时为 0）。 */
    public let avgCostMs: Int64
    /** 失败率 = failCount / (successCount + failCount)，无调用记录时为 0.0。 */
    public let failRate: Float64
    public init(parserId: String, version: String, track: String, successCount: Int64,
                failCount: Int64, totalCostMs: Int64, avgCostMs: Int64, failRate: Float64) {
        this.parserId = parserId
        this.version = version
        this.track = track
        this.successCount = successCount
        this.failCount = failCount
        this.totalCostMs = totalCostMs
        this.avgCostMs = avgCostMs
        this.failRate = failRate
    }
}

/**
 * 注册表条目：描述符 + 可调用引用 + 健康度。
 */
class RegisteredParser {
    public let descriptor: ParserDescriptor
    public let parser: DocumentParser
    public let health: ParserHealth
    public init(descriptor: ParserDescriptor, parser: DocumentParser) {
        this.descriptor = descriptor
        this.parser = parser
        this.health = ParserHealth()
    }
}

/**
 * 命中排序用的打分载体：优先级降序、失败率升序。
 */
class ScoredParser {
    public var priority: Int64 = 0
    public var failRate: Float64 = 0.0
    public var parser: DocumentParser
    public init(priority: Int64, failRate: Float64, parser: DocumentParser) {
        this.priority = priority
        this.failRate = failRate
        this.parser = parser
    }
}

/**
 * 解析器注册表（契约 IF-04a~e）。
 *
 * 不持有任何格式解析实现，只持有可调用引用；按 MIME→扩展名→优先级→健康度命中。
 * 重复 `parserId` 注册按版本覆盖，不报错（IF-04a 幂等）。
 */
public class ParserRegistry {
    private static let INSTANCE = ParserRegistry()
    private let mutex: Mutex = Mutex()
    private let entries: HashMap<String, RegisteredParser> = HashMap<String, RegisteredParser>()

    public static func shared(): ParserRegistry {
        INSTANCE
    }

    public func register(parser: DocumentParser): Unit {
        let d = parser.descriptor()
        synchronized(this.mutex) {
            this.entries[d.parserId] = RegisteredParser(d, parser)
            LogUtils.info("[ParserRegistry] registered parser ${d.parserId} v${d.version} " +
                "(track=${d.track}, priority=${d.priority})")
        }
    }

    public func unregister(parserId: String): Bool {
        synchronized(this.mutex) {
            if (this.entries.contains(parserId)) {
                this.entries.remove(parserId)
                LogUtils.info("[ParserRegistry] unregistered parser ${parserId}")
                return true
            }
            return false
        }
    }

    /**
     * 按格式命中，返回按「优先级降序、失败率升序」排序的有序候选列表（IF-04c）。
     * 无候选返回空数组，不抛。
     */
    public func resolve(filename: String, mimeType: String): ArrayList<DocumentParser> {
        let lowerName = filename.toAsciiLower()
        let lowerMime = mimeType.toAsciiLower()
        let scored = ArrayList<ScoredParser>()
        synchronized(this.mutex) {
            for ((_, rp) in this.entries) {
                if (formatMatches(rp.descriptor.formats, lowerName, lowerMime)) {
                    let total = rp.health.successCount + rp.health.failCount
                    let rate = if (total > 0) { Float64(rp.health.failCount) / Float64(total) } else { 0.0 }
                    scored.add(ScoredParser(rp.descriptor.priority, rate, rp.parser))
                }
            }
        }
        // 手动选择排序：每次取最优剩余项，避免依赖 ArrayList.sort 的签名差异
        let sorted = ArrayList<DocumentParser>()
        let remaining = scored
        while (remaining.size > 0) {
            var bestIdx = 0
            for (k in 1..remaining.size) {
                let a = remaining[k]
                let b = remaining[bestIdx]
                if (a.priority > b.priority || (a.priority == b.priority && a.failRate < b.failRate)) {
                    bestIdx = k
                }
            }
            sorted.add(remaining[bestIdx].parser)
            remaining.remove(at: bestIdx)
        }
        sorted
    }

    /**
     * 回写健康度（IF-04d）。未知 ID 记 warn 不抛。
     */
    public func report(parserId: String, ok: Bool, costMs: Int64): Unit {
        synchronized(this.mutex) {
            match (this.entries.get(parserId)) {
                case Some(rp) =>
                    if (ok) {
                        rp.health.successCount = rp.health.successCount + 1
                        rp.health.totalCostMs = rp.health.totalCostMs + costMs
                    } else {
                        rp.health.failCount = rp.health.failCount + 1
                    }
                case None => LogUtils.warn("[ParserRegistry] report for unknown parser ${parserId}")
            }
        }
    }

    public func list(): ArrayList<ParserDescriptor> {
        let out = ArrayList<ParserDescriptor>()
        synchronized(this.mutex) {
            for ((_, rp) in this.entries) {
                out.add(rp.descriptor)
            }
        }
        out
    }

    /**
     * 可观测快照（IF-04f / T-HAC-12）：每个已注册解析器一条统计，按「失败率降序 → 失败数降序」排序。
     * 无调用记录时 failRate 记 0.0（不区分健康与未使用），避免把从未调用的解析器误判为最差。
     */
    public func stats(): ArrayList<ParserStat> {
        let out = ArrayList<ParserStat>()
        synchronized(this.mutex) {
            for ((_, rp) in this.entries) {
                let h = rp.health
                let avg = if (h.successCount > 0) { h.totalCostMs / h.successCount } else { 0 }
                let total = h.successCount + h.failCount
                let rate = if (total > 0) { Float64(h.failCount) / Float64(total) } else { 0.0 }
                out.add(ParserStat(rp.descriptor.parserId, rp.descriptor.version,
                    rp.descriptor.track, h.successCount, h.failCount, h.totalCostMs, avg, rate))
            }
        }
        // 手动选择排序：每次取最优剩余项，避免依赖 ArrayList.sort 的签名差异（同 resolve 的写法）
        let sorted = ArrayList<ParserStat>()
        let remaining = out
        while (remaining.size > 0) {
            var bestIdx = 0
            for (k in 1..remaining.size) {
                let a = remaining[k]
                let b = remaining[bestIdx]
                if (a.failRate > b.failRate ||
                    (a.failRate == b.failRate && a.failCount > b.failCount)) {
                    bestIdx = k
                }
            }
            sorted.add(remaining[bestIdx])
            remaining.remove(at: bestIdx)
        }
        sorted
    }

    public func size(): Int64 {
        synchronized(this.mutex) { this.entries.size }
    }

    private func formatMatches(f: ParserFormats, name: String, mime: String): Bool {
        for (m in f.mimeTypes) {
            let lm = m.toAsciiLower()
            if (lm == mime) {
                return true
            }
            if (lm.endsWith("/*")) {
                let prefix = lm[0..lm.size - 1]
                if (mime.startsWith(prefix)) {
                    return true
                }
            }
        }
        for (ext in f.extensions) {
            if (name.endsWith(ext.toAsciiLower())) {
                return true
            }
        }
        false
    }
}
