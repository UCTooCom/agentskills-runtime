/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray, JsonFloat, JsonNull}
import magic.log.LogUtils

public enum SkillEvolutionState {
    | Experimental | Stable | Recommended | Deprecated | Retired
}

public class SkillUsageRecord {
    public var skillName: String = ""
    public var useCount: Int64 = 0
    public var viewCount: Int64 = 0
    public var modifyCount: Int64 = 0
    public var successCount: Int64 = 0
    public var failureCount: Int64 = 0
    public var state: SkillEvolutionState = SkillEvolutionState.Experimental
    public var lastUsedAt: Option<DateTime> = None<DateTime>
    public var avgExecutionTimeMs: Float64 = 0.0
    public var userRating: Float64 = 0.0

    public init() {}

    public func successRate(): Float64 {
        if (useCount == 0) { return 0.0 }
        Float64(successCount) / Float64(useCount)
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("skill_name", JsonString(this.skillName))
        map.add("use_count", JsonInt(this.useCount))
        map.add("view_count", JsonInt(this.viewCount))
        map.add("modify_count", JsonInt(this.modifyCount))
        map.add("success_count", JsonInt(this.successCount))
        map.add("failure_count", JsonInt(this.failureCount))
        map.add("state", JsonString(skillStateToString(this.state)))
        map.add("avg_execution_time_ms", JsonFloat(this.avgExecutionTimeMs))
        map.add("user_rating", JsonFloat(this.userRating))
        if (let Some(t) <- this.lastUsedAt) {
            map.add("last_used_at", JsonString(t.toString()))
        }
        JsonObject(map)
    }

    public static func skillStateToString(s: SkillEvolutionState): String {
        match (s) {
            case SkillEvolutionState.Experimental => "experimental"
            case SkillEvolutionState.Stable => "stable"
            case SkillEvolutionState.Recommended => "recommended"
            case SkillEvolutionState.Deprecated => "deprecated"
            case SkillEvolutionState.Retired => "retired"
        }
    }

    public static func parseSkillEvolutionState(s: String): SkillEvolutionState {
        match (s.toAsciiLower()) {
            case "experimental" => SkillEvolutionState.Experimental
            case "stable" => SkillEvolutionState.Stable
            case "recommended" => SkillEvolutionState.Recommended
            case "deprecated" => SkillEvolutionState.Deprecated
            case "retired" => SkillEvolutionState.Retired
            case _ => SkillEvolutionState.Experimental
        }
    }
}

public class SkillUsageTracker {
    private var _records: HashMap<String, SkillUsageRecord>
    private let _persistRecord: (SkillUsageRecord) -> Bool

    public init(persistRecord!: (SkillUsageRecord) -> Bool) {
        _records = HashMap<String, SkillUsageRecord>()
        _persistRecord = persistRecord
    }

    public func incrementUsage(skillName: String, success: Bool, executionTimeMs: Float64): Unit {
        let record = getOrCreateRecord(skillName)
        record.useCount = record.useCount + 1
        if (success) { record.successCount = record.successCount + 1 }
        else { record.failureCount = record.failureCount + 1 }
        record.lastUsedAt = Some(DateTime.now())
        updateAvgExecutionTime(record, executionTimeMs)
        _persistRecord(record)
    }

    public func incrementView(skillName: String): Unit {
        let record = getOrCreateRecord(skillName)
        record.viewCount = record.viewCount + 1
        _persistRecord(record)
    }

    public func incrementModify(skillName: String): Unit {
        let record = getOrCreateRecord(skillName)
        record.modifyCount = record.modifyCount + 1
        _persistRecord(record)
    }

    public func getRecord(skillName: String): Option<SkillUsageRecord> {
        _records.get(skillName)
    }

    public func getTopUsedSkills(limit: Int64): ArrayList<SkillUsageRecord> {
        let all = ArrayList<SkillUsageRecord>()
        for ((_, r) in _records) { all.add(r) }
        let result = ArrayList<SkillUsageRecord>()
        let count = if (limit < Int64(all.size)) { limit } else { Int64(all.size) }
        var remaining = all
        for (_ in 0..count) {
            var maxIdx = 0
            for (i in 1..remaining.size) {
                if (remaining[i].useCount > remaining[maxIdx].useCount) { maxIdx = i }
            }
            result.add(remaining[maxIdx])
            remaining.remove(at: maxIdx)
        }
        result
    }

    public func getAllRecords(): ArrayList<SkillUsageRecord> {
        let result = ArrayList<SkillUsageRecord>()
        for ((_, r) in _records) { result.add(r) }
        result
    }

    private func getOrCreateRecord(skillName: String): SkillUsageRecord {
        if (let Some(r) <- _records.get(skillName)) { return r }
        let record = SkillUsageRecord()
        record.skillName = skillName
        _records.add(skillName, record)
        record
    }

    private func updateAvgExecutionTime(record: SkillUsageRecord, newTime: Float64): Unit {
        if (record.useCount == 1) {
            record.avgExecutionTimeMs = newTime
        } else {
            record.avgExecutionTimeMs = record.avgExecutionTimeMs + (newTime - record.avgExecutionTimeMs) / Float64(record.useCount)
        }
    }
}

public class SkillEvolutionStateTransition {
    public var fromState: SkillEvolutionState = SkillEvolutionState.Experimental
    public var toState: SkillEvolutionState = SkillEvolutionState.Stable
    public var condition: String = ""
    public var threshold: Float64 = 0.0
    public var description: String = ""

    public init() {}
}

public class SkillEvolutionStateTransitionEngine {
    private let _transitions: ArrayList<SkillEvolutionStateTransition>
    private let _updateState: (String, String) -> Bool

    public init(updateState!: (String, String) -> Bool) {
        _updateState = updateState
        _transitions = ArrayList<SkillEvolutionStateTransition>()
        initDefaultTransitions()
    }

    private func initDefaultTransitions(): Unit {
        let t1 = SkillEvolutionStateTransition()
        t1.fromState = SkillEvolutionState.Experimental
        t1.toState = SkillEvolutionState.Stable
        t1.condition = "success_rate >= 0.8 AND use_count >= 10"
        t1.threshold = 0.8
        t1.description = "Experimental → Stable: success rate >= 80% with >= 10 uses"
        _transitions.add(t1)

        let t2 = SkillEvolutionStateTransition()
        t2.fromState = SkillEvolutionState.Stable
        t2.toState = SkillEvolutionState.Recommended
        t2.condition = "success_rate >= 0.95 AND use_count >= 50 AND user_rating >= 4.0"
        t2.threshold = 0.95
        t2.description = "Stable → Recommended: success rate >= 95%, >= 50 uses, rating >= 4.0"
        _transitions.add(t2)

        let t3 = SkillEvolutionStateTransition()
        t3.fromState = SkillEvolutionState.Stable
        t3.toState = SkillEvolutionState.Deprecated
        t3.condition = "success_rate < 0.5 OR failure_count > use_count * 0.5"
        t3.threshold = 0.5
        t3.description = "Stable → Deprecated: success rate < 50%"
        _transitions.add(t3)

        let t4 = SkillEvolutionStateTransition()
        t4.fromState = SkillEvolutionState.Deprecated
        t4.toState = SkillEvolutionState.Retired
        t4.condition = "use_count == 0 for 30 days"
        t4.threshold = 0.0
        t4.description = "Deprecated → Retired: no usage for 30 days"
        _transitions.add(t4)
    }

    public func evaluateTransition(record: SkillUsageRecord): Option<SkillEvolutionState> {
        if (isSameSkillEvolutionState(record.state, SkillEvolutionState.Experimental)) {
            if (record.successRate() >= 0.8 && record.useCount >= 10) {
                LogUtils.info("[SkillEvolutionStateTransition] ${record.skillName}: Experimental → Stable")
                return Some(SkillEvolutionState.Stable)
            }
        }
        if (isSameSkillEvolutionState(record.state, SkillEvolutionState.Stable)) {
            if (record.successRate() >= 0.95 && record.useCount >= 50 && record.userRating >= 4.0) {
                LogUtils.info("[SkillEvolutionStateTransition] ${record.skillName}: Stable → Recommended")
                return Some(SkillEvolutionState.Recommended)
            }
            if (record.successRate() < 0.5) {
                LogUtils.info("[SkillEvolutionStateTransition] ${record.skillName}: Stable → Deprecated")
                return Some(SkillEvolutionState.Deprecated)
            }
        }

        None<SkillEvolutionState>
    }

    public static func isSameSkillEvolutionState(a: SkillEvolutionState, b: SkillEvolutionState): Bool {
        match (a) {
            case SkillEvolutionState.Experimental => match (b) { case SkillEvolutionState.Experimental => true case _ => false }
            case SkillEvolutionState.Stable => match (b) { case SkillEvolutionState.Stable => true case _ => false }
            case SkillEvolutionState.Recommended => match (b) { case SkillEvolutionState.Recommended => true case _ => false }
            case SkillEvolutionState.Deprecated => match (b) { case SkillEvolutionState.Deprecated => true case _ => false }
            case SkillEvolutionState.Retired => match (b) { case SkillEvolutionState.Retired => true case _ => false }
        }
    }

    public func applyTransition(skillName: String, newState: SkillEvolutionState): Bool {
        let stateStr = SkillUsageRecord.skillStateToString(newState)
        _updateState(skillName, stateStr)
    }

    public func getTransitions(): ArrayList<SkillEvolutionStateTransition> {
        _transitions
    }
}