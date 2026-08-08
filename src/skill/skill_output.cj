/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull}

public class SkillOutput {
    public var files: ArrayList<String> = ArrayList<String>()
    public var data: HashMap<String, JsonValue> = HashMap<String, JsonValue>()
    public var metrics: HashMap<String, Int64> = HashMap<String, Int64>()
    public var errors: ArrayList<String> = ArrayList<String>()
    public var rawOutput: String = ""

    public init() {}

    public static func fromRaw(output: String): SkillOutput {
        let result = SkillOutput()
        result.rawOutput = output
        return result
    }

    public static func fromError(error: String): SkillOutput {
        let result = SkillOutput()
        result.errors.add(error)
        return result
    }

    public func hasErrors(): Bool {
        return !errors.isEmpty()
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        let filesArr = JsonArray()
        for (f in this.files) {
            filesArr.add(JsonString(f))
        }
        map.add("files", filesArr)
        map.add("data", JsonObject(this.data))
        var metricsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.metrics) {
            metricsMap.add(k, JsonInt(v))
        }
        map.add("metrics", JsonObject(metricsMap))
        let errorsArr = JsonArray()
        for (e in this.errors) {
            errorsArr.add(JsonString(e))
        }
        map.add("errors", errorsArr)
        map.add("raw_output", JsonString(this.rawOutput))
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }
}

public class SkillInput {
    public var data: HashMap<String, JsonValue> = HashMap<String, JsonValue>()
    public var files: ArrayList<String> = ArrayList<String>()
    public var context: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    public func get(key: String): Option<JsonValue> {
        data.get(key)
    }

    public func getString(key: String): String {
        if (let Some(v) <- data.get(key)) {
            if (v is JsonString) {
                return (v as JsonString).getOrThrow().getValue()
            }
            return v.toString()
        }
        return ""
    }

    public func put(key: String, value: JsonValue): Unit {
        data.add(key, value)
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("data", JsonObject(this.data))
        let filesArr = JsonArray()
        for (f in this.files) {
            filesArr.add(JsonString(f))
        }
        map.add("files", filesArr)
        var ctxMap = HashMap<String, JsonValue>()
        for ((k, v) in this.context) {
            ctxMap.add(k, JsonString(v))
        }
        map.add("context", JsonObject(ctxMap))
        return JsonObject(map)
    }
}
