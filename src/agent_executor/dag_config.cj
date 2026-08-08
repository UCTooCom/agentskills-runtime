/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_executor

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull}

public enum DagStepType {
    | Skill
    | Agent
    | Condition
    | Subplan
}

public class StepConfig {
    public var name: String = ""
    public var stepType: DagStepType = DagStepType.Skill
    public var targetRef: String = ""
    public var dependsOn: ArrayList<String> = ArrayList<String>()
    public var condition: Option<String> = None<String>
    public var inputMapping: HashMap<String, String> = HashMap<String, String>()
    public var retryCount: Int64 = 0
    public var timeout: Option<Int64> = None<Int64>

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", JsonString(this.name))
        map.add("step_type", JsonString(stepTypeToString(this.stepType)))
        map.add("target_ref", JsonString(this.targetRef))
        let depsArr = JsonArray()
        for (d in this.dependsOn) {
            depsArr.add(JsonString(d))
        }
        map.add("depends_on", depsArr)
        if (let Some(c) <- this.condition) {
            map.add("condition", JsonString(c))
        }
        var mappingMap = HashMap<String, JsonValue>()
        for ((k, v) in this.inputMapping) {
            mappingMap.add(k, JsonString(v))
        }
        map.add("input_mapping", JsonObject(mappingMap))
        map.add("retry_count", JsonInt(this.retryCount))
        if (let Some(t) <- this.timeout) {
            map.add("timeout", JsonInt(t))
        }
        return JsonObject(map)
    }

    public static func stepTypeToString(st: DagStepType): String {
        match (st) {
            case DagStepType.Skill => "skill"
            case DagStepType.Agent => "agent"
            case DagStepType.Condition => "condition"
            case DagStepType.Subplan => "subplan"
        }
    }

    public static func parseStepType(s: String): DagStepType {
        match (s) {
            case "agent" => DagStepType.Agent
            case "condition" => DagStepType.Condition
            case "subplan" => DagStepType.Subplan
            case _ => DagStepType.Skill
        }
    }
}

public class DagConfig {
    public var name: String = ""
    public var description: String = ""
    public var version: String = "1.0.0"
    public var steps: ArrayList<StepConfig> = ArrayList<StepConfig>()
    public var inputs: HashMap<String, String> = HashMap<String, String>()
    public var outputs: HashMap<String, String> = HashMap<String, String>()
    public var teamId: Option<String> = None<String>

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", JsonString(this.name))
        map.add("description", JsonString(this.description))
        map.add("version", JsonString(this.version))
        let stepsArr = JsonArray()
        for (s in this.steps) {
            stepsArr.add(s.toJsonValue())
        }
        map.add("steps", stepsArr)
        var inputsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.inputs) {
            inputsMap.add(k, JsonString(v))
        }
        map.add("inputs", JsonObject(inputsMap))
        var outputsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.outputs) {
            outputsMap.add(k, JsonString(v))
        }
        map.add("outputs", JsonObject(outputsMap))
        if (let Some(tid) <- this.teamId) {
            map.add("team_id", JsonString(tid))
        }
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }

    public static func fromJsonValue(json: JsonValue): Option<DagConfig> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let config = DagConfig()
        if (let Some(v) <- fields.get("name")) {
            config.name = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("description")) {
            config.description = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("version")) {
            config.version = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("steps")) {
            if (v is JsonArray) {
                let arr = (v as JsonArray).getOrThrow()
                for (i in 0..arr.size()) {
                    let stepOpt = parseStepConfig(arr[i])
                    if (stepOpt.isSome()) {
                        config.steps.add(stepOpt.getOrThrow())
                    }
                }
            }
        }
        if (let Some(v) <- fields.get("inputs")) {
            config.inputs = jsonStringMap(v)
        }
        if (let Some(v) <- fields.get("outputs")) {
            config.outputs = jsonStringMap(v)
        }
        if (let Some(v) <- fields.get("team_id")) {
            config.teamId = Some(jsonStringValue(v))
        }
        return Some(config)
    }

    private static func parseStepConfig(json: JsonValue): Option<StepConfig> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let step = StepConfig()
        if (let Some(v) <- fields.get("name")) {
            step.name = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("step_type")) {
            step.stepType = StepConfig.parseStepType(jsonStringValue(v))
        }
        if (let Some(v) <- fields.get("target_ref")) {
            step.targetRef = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("skill")) {
            step.targetRef = jsonStringValue(v)
            step.stepType = DagStepType.Skill
        }
        if (let Some(v) <- fields.get("agent_type")) {
            step.targetRef = jsonStringValue(v)
            step.stepType = DagStepType.Agent
        }
        if (let Some(v) <- fields.get("depends_on")) {
            step.dependsOn = jsonStringArray(v)
        }
        if (let Some(v) <- fields.get("condition")) {
            step.condition = Some(jsonStringValue(v))
        }
        if (let Some(v) <- fields.get("input_mapping")) {
            step.inputMapping = jsonStringMap(v)
        }
        if (let Some(v) <- fields.get("input")) {
            step.inputMapping = jsonStringMap(v)
        }
        if (let Some(v) <- fields.get("retry_count")) {
            if (v is JsonInt) {
                step.retryCount = (v as JsonInt).getOrThrow().getValue()
            }
        }
        if (let Some(v) <- fields.get("timeout")) {
            if (v is JsonInt) {
                step.timeout = Some((v as JsonInt).getOrThrow().getValue())
            }
        }
        return Some(step)
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

    private static func jsonStringMap(v: JsonValue): HashMap<String, String> {
        let result = HashMap<String, String>()
        if (v is JsonObject) {
            let obj = (v as JsonObject).getOrThrow()
            let fields = obj.getFields()
            for ((k, val) in fields) {
                result.add(k, jsonStringValue(val))
            }
        }
        return result
    }
}