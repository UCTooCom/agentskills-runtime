/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray}
import magic.log.LogUtils

public class CuratorScope {
    public var onlyAgentCreated: Bool = true
    public var excludePinned: Bool = true
    public var targetStates: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("only_agent_created", JsonBool(this.onlyAgentCreated))
        map.add("exclude_pinned", JsonBool(this.excludePinned))
        var statesArr = ArrayList<JsonValue>()
        for (s in this.targetStates) { statesArr.add(JsonString(s)) }
        map.add("target_states", JsonArray(statesArr))
        JsonObject(map)
    }
}

public class CuratorRule {
    public var name: String = ""
    public var ruleType: String = ""
    public var condition: String = ""
    public var action: String = ""
    public var enabled: Bool = true
    public var params: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", JsonString(this.name))
        map.add("rule_type", JsonString(this.ruleType))
        map.add("condition", JsonString(this.condition))
        map.add("action", JsonString(this.action))
        map.add("enabled", JsonBool(this.enabled))
        var paramsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.params) { paramsMap.add(k, JsonString(v)) }
        map.add("params", JsonObject(paramsMap))
        JsonObject(map)
    }
}

public class CuratorRuleSet {
    public var schedule: String = "0 2 * * *"
    public var rules: ArrayList<CuratorRule> = ArrayList<CuratorRule>()
    public var scope: CuratorScope = CuratorScope()

    public init() {}

    public func initDefaultRules(): Unit {
        if (rules.size > 0) { return }

        let r1 = CuratorRule()
        r1.name = "stale_check"
        r1.ruleType = "state_transition"
        r1.condition = "last_activity_at > 30d"
        r1.action = "transition_to_stale"
        rules.add(r1)

        let r2 = CuratorRule()
        r2.name = "archived_check"
        r2.ruleType = "state_transition"
        r2.condition = "last_activity_at > 90d"
        r2.action = "transition_to_archived"
        rules.add(r2)

        let r3 = CuratorRule()
        r3.name = "low_usage_check"
        r3.ruleType = "usage_check"
        r3.condition = "use_count < 3 AND last_activity_at > 14d"
        r3.action = "flag_low_usage"
        rules.add(r3)

        let r4 = CuratorRule()
        r4.name = "scripts_check"
        r4.ruleType = "scripts_check"
        r4.condition = "scripts_declared AND NOT scripts_generated"
        r4.action = "trigger_script_generation"
        rules.add(r4)
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("schedule", JsonString(this.schedule))
        var rulesArr = ArrayList<JsonValue>()
        for (r in this.rules) { rulesArr.add(r.toJsonValue()) }
        map.add("rules", JsonArray(rulesArr))
        map.add("scope", this.scope.toJsonValue())
        JsonObject(map)
    }
}

public class CuratorReport {
    public var timestamp: String = ""
    public var totalScanned: Int64 = 0
    public var stateTransitions: ArrayList<String> = ArrayList<String>()
    public var lowUsageFlags: ArrayList<String> = ArrayList<String>()
    public var scriptGenerations: ArrayList<String> = ArrayList<String>()
    public var errors: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("timestamp", JsonString(this.timestamp))
        map.add("total_scanned", JsonInt(this.totalScanned))
        var transArr = ArrayList<JsonValue>()
        for (t in this.stateTransitions) { transArr.add(JsonString(t)) }
        map.add("state_transitions", JsonArray(transArr))
        var lowArr = ArrayList<JsonValue>()
        for (l in this.lowUsageFlags) { lowArr.add(JsonString(l)) }
        map.add("low_usage_flags", JsonArray(lowArr))
        var scriptArr = ArrayList<JsonValue>()
        for (s in this.scriptGenerations) { scriptArr.add(JsonString(s)) }
        map.add("script_generations", JsonArray(scriptArr))
        var errArr = ArrayList<JsonValue>()
        for (e in this.errors) { errArr.add(JsonString(e)) }
        map.add("errors", JsonArray(errArr))
        JsonObject(map)
    }
}

public class SkillCuratorHandler {
    private let _ruleSet: CuratorRuleSet
    private let _getAllSkillStats: () -> ArrayList<SkillUsageRecord>
    private let _updateSkillEvolutionState: (String, String) -> Bool
    private let _isPinned: (String) -> Bool
    private let _isAgentCreated: (String) -> Bool

    public init(ruleSet!: CuratorRuleSet, getAllSkillStats!: () -> ArrayList<SkillUsageRecord>, updateSkillEvolutionState!: (String, String) -> Bool, isPinned!: (String) -> Bool, isAgentCreated!: (String) -> Bool) {
        _ruleSet = ruleSet
        _getAllSkillStats = getAllSkillStats
        _updateSkillEvolutionState = updateSkillEvolutionState
        _isPinned = isPinned
        _isAgentCreated = isAgentCreated
    }

    public func execute(): CuratorReport {
        LogUtils.info("[SkillCurator] Starting curator execution")
        let report = CuratorReport()
        report.timestamp = DateTime.now().toString()

        let allStats = _getAllSkillStats()
        report.totalScanned = Int64(allStats.size)

        for (record in allStats) {
            if (_ruleSet.scope.onlyAgentCreated && !_isAgentCreated(record.skillName)) {
                continue
            }
            if (_ruleSet.scope.excludePinned && _isPinned(record.skillName)) {
                continue
            }

            for (rule in _ruleSet.rules) {
                if (!rule.enabled) { continue }

                if (rule.ruleType == "state_transition") {
                    handleStateTransition(rule, record, report)
                } else if (rule.ruleType == "usage_check") {
                    handleUsageCheck(rule, record, report)
                } else if (rule.ruleType == "scripts_check") {
                    handleScriptsCheck(rule, record, report)
                }
            }
        }

        LogUtils.info("[SkillCurator] Curator execution complete: scanned=${report.totalScanned.toString()}, transitions=${report.stateTransitions.size.toString()}, flags=${report.lowUsageFlags.size.toString()}")
        report
    }

    private func handleStateTransition(rule: CuratorRule, record: SkillUsageRecord, report: CuratorReport): Unit {
        if (rule.action == "transition_to_stale") {
            if (isSameSkillEvolutionState(record.state, SkillEvolutionState.Stable) || isSameSkillEvolutionState(record.state, SkillEvolutionState.Experimental)) {
                if (record.useCount < 3) {
                    let success = _updateSkillEvolutionState(record.skillName, "deprecated")
                    if (success) {
                        report.stateTransitions.add("${record.skillName}: → deprecated (low usage)")
                        LogUtils.info("[SkillCurator] ${record.skillName}: transitioned to deprecated")
                    }
                }
            }
        } else if (rule.action == "transition_to_archived") {
            if (isSameSkillEvolutionState(record.state, SkillEvolutionState.Deprecated)) {
                if (record.useCount == 0) {
                    let success = _updateSkillEvolutionState(record.skillName, "retired")
                    if (success) {
                        report.stateTransitions.add("${record.skillName}: → retired (no usage)")
                        LogUtils.info("[SkillCurator] ${record.skillName}: transitioned to retired")
                    }
                }
            }
        }
    }

    private func handleUsageCheck(rule: CuratorRule, record: SkillUsageRecord, report: CuratorReport): Unit {
        if (record.useCount < 3 && record.successRate() < 0.5) {
            report.lowUsageFlags.add("${record.skillName}: use_count=${record.useCount.toString()}, success_rate=${record.successRate().toString()}")
            LogUtils.info("[SkillCurator] ${record.skillName}: flagged as low usage")
        }
    }

    private func handleScriptsCheck(rule: CuratorRule, record: SkillUsageRecord, report: CuratorReport): Unit {
        if (record.useCount >= 1 && record.successRate() > 0.3) {
            LogUtils.info("[SkillCurator] Scripts check for ${record.skillName}: first successful use detected, script generation eligible")
            report.scriptGenerations.add("${record.skillName}: eligible for script generation (use_count=${record.useCount.toString()}, success_rate=${record.successRate().toString()})")
        } else {
            LogUtils.info("[SkillCurator] Scripts check for ${record.skillName}: skipped (use_count=${record.useCount.toString()}, success_rate=${record.successRate().toString()})")
        }
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
}

public class SkillCuratorYamlParser {
    public static func parseFromJson(json: JsonValue): Option<CuratorRuleSet> {
        if (!(json is JsonObject)) { return None<CuratorRuleSet> }
        let obj = json.asObject()
        let ruleSet = CuratorRuleSet()

        if (let Some(val) <- obj.get("schedule")) {
            if (val is JsonString) { ruleSet.schedule = val.asString().getValue() }
        }

        if (let Some(val) <- obj.get("rules")) {
            if (val is JsonArray) {
                for (item in val.asArray().getItems()) {
                    let rule = parseRule(item)
                    ruleSet.rules.add(rule)
                }
            }
        }

        if (ruleSet.rules.size == 0) {
            ruleSet.initDefaultRules()
        }

        if (let Some(val) <- obj.get("scope")) {
            ruleSet.scope = parseScope(val)
        }

        Some(ruleSet)
    }

    private static func parseRule(obj: JsonValue): CuratorRule {
        let rule = CuratorRule()
        if (!(obj is JsonObject)) { return rule }
        let o = obj.asObject()
        if (let Some(val) <- o.get("name")) {
            if (val is JsonString) { rule.name = val.asString().getValue() }
        }
        if (let Some(val) <- o.get("rule_type")) {
            if (val is JsonString) { rule.ruleType = val.asString().getValue() }
        }
        if (let Some(val) <- o.get("type")) {
            if (val is JsonString) { rule.ruleType = val.asString().getValue() }
        }
        if (let Some(val) <- o.get("condition")) {
            if (val is JsonString) { rule.condition = val.asString().getValue() }
        }
        if (let Some(val) <- o.get("action")) {
            if (val is JsonString) { rule.action = val.asString().getValue() }
        }
        if (let Some(val) <- o.get("enabled")) {
            if (val is JsonBool) { rule.enabled = val.asBool().getValue() }
        }
        rule
    }

    private static func parseScope(obj: JsonValue): CuratorScope {
        let scope = CuratorScope()
        if (!(obj is JsonObject)) { return scope }
        let o = obj.asObject()
        if (let Some(val) <- o.get("only_agent_created")) {
            if (val is JsonBool) { scope.onlyAgentCreated = val.asBool().getValue() }
        }
        if (let Some(val) <- o.get("exclude_pinned")) {
            if (val is JsonBool) { scope.excludePinned = val.asBool().getValue() }
        }
        if (let Some(val) <- o.get("target_states")) {
            if (val is JsonArray) {
                for (item in val.asArray().getItems()) {
                    if (item is JsonString) { scope.targetStates.add(item.asString().getValue()) }
                }
            }
        }
        scope
    }
}
