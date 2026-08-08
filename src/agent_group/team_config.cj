/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_group

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull}

public enum AgentRole {
    | Manager
    | TeamLeader
    | Worker
}

public class AgentRoleConfig {
    public var agentType: String = ""
    public var skills: ArrayList<String> = ArrayList<String>()
    public var model: Option<String> = None<String>
    public var maxTurns: Option<Int64> = None<Int64>
    public var permissions: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("agent_type", JsonString(this.agentType))
        let skillsArr = JsonArray()
        for (s in this.skills) {
            skillsArr.add(JsonString(s))
        }
        map.add("skills", skillsArr)
        if (let Some(m) <- this.model) {
            map.add("model", JsonString(m))
        }
        if (let Some(mt) <- this.maxTurns) {
            map.add("max_turns", JsonInt(mt))
        }
        let permsArr = JsonArray()
        for (p in this.permissions) {
            permsArr.add(JsonString(p))
        }
        map.add("permissions", permsArr)
        return JsonObject(map)
    }
}

public class LeaderConfig {
    public var agentType: String = ""
    public var skills: ArrayList<String> = ArrayList<String>()
    public var model: Option<String> = None<String>
    public var workers: ArrayList<AgentRoleConfig> = ArrayList<AgentRoleConfig>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("agent_type", JsonString(this.agentType))
        let skillsArr = JsonArray()
        for (s in this.skills) {
            skillsArr.add(JsonString(s))
        }
        map.add("skills", skillsArr)
        if (let Some(m) <- this.model) {
            map.add("model", JsonString(m))
        }
        let workersArr = JsonArray()
        for (w in this.workers) {
            workersArr.add(w.toJsonValue())
        }
        map.add("workers", workersArr)
        return JsonObject(map)
    }
}

public class TeamConfig {
    public var name: String = ""
    public var description: String = ""
    public var manager: AgentRoleConfig = AgentRoleConfig()
    public var leaders: ArrayList<LeaderConfig> = ArrayList<LeaderConfig>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", JsonString(this.name))
        map.add("description", JsonString(this.description))
        map.add("manager", this.manager.toJsonValue())
        let leadersArr = JsonArray()
        for (l in this.leaders) {
            leadersArr.add(l.toJsonValue())
        }
        map.add("leaders", leadersArr)
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }

    public static func fromJsonValue(json: JsonValue): Option<TeamConfig> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let config = TeamConfig()
        if (let Some(nameVal) <- fields.get("name")) {
            config.name = jsonStringValue(nameVal)
        }
        if (let Some(descVal) <- fields.get("description")) {
            config.description = jsonStringValue(descVal)
        }
        if (let Some(managerVal) <- fields.get("manager")) {
            if (let Some(mc) <- parseAgentRoleConfig(managerVal)) {
                config.manager = mc
            }
        }
        if (let Some(leadersVal) <- fields.get("leaders")) {
            if (leadersVal is JsonArray) {
                let arr = (leadersVal as JsonArray).getOrThrow()
                for (i in 0..arr.size()) {
                    let lcOpt = parseLeaderConfig(arr[i])
                    if (lcOpt.isSome()) {
                        config.leaders.add(lcOpt.getOrThrow())
                    }
                }
            }
        }
        return Some(config)
    }

    private static func parseAgentRoleConfig(json: JsonValue): Option<AgentRoleConfig> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let cfg = AgentRoleConfig()
        if (let Some(v) <- fields.get("agent_type")) {
            cfg.agentType = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("skills")) {
            cfg.skills = jsonStringArray(v)
        }
        if (let Some(v) <- fields.get("model")) {
            cfg.model = Some(jsonStringValue(v))
        }
        if (let Some(v) <- fields.get("max_turns")) {
            if (v is JsonInt) {
                cfg.maxTurns = Some((v as JsonInt).getOrThrow().getValue())
            }
        }
        if (let Some(v) <- fields.get("permissions")) {
            cfg.permissions = jsonStringArray(v)
        }
        return Some(cfg)
    }

    private static func parseLeaderConfig(json: JsonValue): Option<LeaderConfig> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let cfg = LeaderConfig()
        if (let Some(v) <- fields.get("agent_type")) {
            cfg.agentType = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("skills")) {
            cfg.skills = jsonStringArray(v)
        }
        if (let Some(v) <- fields.get("model")) {
            cfg.model = Some(jsonStringValue(v))
        }
        if (let Some(v) <- fields.get("workers")) {
            if (v is JsonArray) {
                let arr = (v as JsonArray).getOrThrow()
                for (i in 0..arr.size()) {
                    let wcOpt = parseAgentRoleConfig(arr[i])
                    if (wcOpt.isSome()) {
                        cfg.workers.add(wcOpt.getOrThrow())
                    }
                }
            }
        }
        return Some(cfg)
    }

    private static func jsonStringValue(v: JsonValue): String {
        if (v is JsonString) {
            return (v as JsonString).getOrThrow().getValue()
        }
        return v.toString()
    }

    private static func jsonStringArray(v: JsonValue): ArrayList<String> {
        let result = ArrayList<String>()
        if (v is JsonArray) {
            let arr = (v as JsonArray).getOrThrow()
            for (i in 0..arr.size()) {
                result.add(jsonStringValue(arr[i]))
            }
        }
        return result
    }
}

public class TeamConfigValidationResult {
    public var valid: Bool = true
    public var errors: ArrayList<String> = ArrayList<String>()
    public var warnings: ArrayList<String> = ArrayList<String>()

    public init() {}
}
