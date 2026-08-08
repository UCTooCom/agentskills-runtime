/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull}

public enum StepType {
    | Sequential
    | Parallel
    | Conditional
}

public class CompositionStep {
    public var name: String = ""
    public var skillName: String = ""
    public var stepType: StepType = StepType.Sequential
    public var dependsOn: ArrayList<String> = ArrayList<String>()
    public var inputMapping: HashMap<String, String> = HashMap<String, String>()
    public var condition: Option<String> = None<String>
    public var retryCount: Int64 = 0
    public var timeout: Option<Int64> = None<Int64>

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", JsonString(this.name))
        map.add("skill_name", JsonString(this.skillName))
        map.add("step_type", JsonString(stepTypeToString(this.stepType)))
        let depsArr = JsonArray()
        for (d in this.dependsOn) {
            depsArr.add(JsonString(d))
        }
        map.add("depends_on", depsArr)
        var mappingMap = HashMap<String, JsonValue>()
        for ((k, v) in this.inputMapping) {
            mappingMap.add(k, JsonString(v))
        }
        map.add("input_mapping", JsonObject(mappingMap))
        if (let Some(c) <- this.condition) {
            map.add("condition", JsonString(c))
        }
        map.add("retry_count", JsonInt(this.retryCount))
        if (let Some(t) <- this.timeout) {
            map.add("timeout", JsonInt(t))
        }
        return JsonObject(map)
    }

    private static func stepTypeToString(st: StepType): String {
        match (st) {
            case StepType.Sequential => "sequential"
            case StepType.Parallel => "parallel"
            case StepType.Conditional => "conditional"
        }
    }
}

public class CompositionDefinition {
    public var name: String = ""
    public var description: String = ""
    public var version: String = "1.0.0"
    public var steps: ArrayList<CompositionStep> = ArrayList<CompositionStep>()
    public var inputs: HashMap<String, String> = HashMap<String, String>()
    public var outputs: HashMap<String, String> = HashMap<String, String>()
    public var templateRef: Option<String> = None<String>

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
        if (let Some(tr) <- this.templateRef) {
            map.add("template_ref", JsonString(tr))
        }
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }

    public static func fromJsonValue(json: JsonValue): Option<CompositionDefinition> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let def = CompositionDefinition()
        if (let Some(v) <- fields.get("name")) {
            def.name = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("description")) {
            def.description = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("version")) {
            def.version = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("steps")) {
            if (v is JsonArray) {
                let arr = (v as JsonArray).getOrThrow()
                for (i in 0..arr.size()) {
                    let stepOpt = parseCompositionStep(arr[i])
                    if (stepOpt.isSome()) {
                        def.steps.add(stepOpt.getOrThrow())
                    }
                }
            }
        }
        if (let Some(v) <- fields.get("inputs")) {
            def.inputs = jsonStringMap(v)
        }
        if (let Some(v) <- fields.get("outputs")) {
            def.outputs = jsonStringMap(v)
        }
        if (let Some(v) <- fields.get("template_ref")) {
            def.templateRef = Some(jsonStringValue(v))
        }
        return Some(def)
    }

    private static func parseCompositionStep(json: JsonValue): Option<CompositionStep> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let step = CompositionStep()
        if (let Some(v) <- fields.get("name")) {
            step.name = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("skill_name")) {
            step.skillName = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("step_type")) {
            step.stepType = parseStepType(jsonStringValue(v))
        }
        if (let Some(v) <- fields.get("depends_on")) {
            step.dependsOn = jsonStringArray(v)
        }
        if (let Some(v) <- fields.get("input_mapping")) {
            step.inputMapping = jsonStringMap(v)
        }
        if (let Some(v) <- fields.get("condition")) {
            step.condition = Some(jsonStringValue(v))
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

    private static func parseStepType(s: String): StepType {
        match (s) {
            case "parallel" => StepType.Parallel
            case "conditional" => StepType.Conditional
            case _ => StepType.Sequential
        }
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
