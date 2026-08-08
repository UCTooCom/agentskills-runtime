/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull}
import magic.log.LogUtils

public class InputMapper {
    public init() {}

    public func map(output: SkillOutput, mapping: HashMap<String, String>): JsonValue {
        var result = HashMap<String, JsonValue>()
        for ((targetKey, expression) in mapping) {
            if (let Some(value) <- resolveExpression(expression, output)) {
                result.add(targetKey, value)
            } else {
                LogUtils.warn("[InputMapper] Could not resolve expression: ${expression} for key: ${targetKey}")
            }
        }
        return JsonObject(result)
    }

    public func resolveExpression(expression: String, context: HashMap<String, SkillOutput>): Option<JsonValue> {
        let parts = expression.split(".")
        if (parts.size < 2) {
            return None
        }

        let stepName = parts[0]
        if (let Some(output) <- context.get(stepName)) {
            return resolveExpression(parts, output)
        }
        return None
    }

    public func resolveExpression(expression: String, output: SkillOutput): Option<JsonValue> {
        let parts = expression.split(".")
        if (parts.size < 1) {
            return None
        }
        return resolveExpression(parts, output)
    }

    private func resolveExpression(parts: Array<String>, output: SkillOutput): Option<JsonValue> {
        if (parts.size < 2) {
            return Some(output.toJsonValue())
        }

        let field = parts[1]
        if (field == "raw_output") {
            return Some(JsonString(output.rawOutput))
        }
        if (field == "files") {
            return Some(buildStringArray(output.files))
        }
        if (field == "data") {
            if (parts.size >= 3) {
                return output.data.get(parts[2])
            }
            return Some(JsonObject(output.data))
        }
        if (field == "metrics") {
            if (parts.size >= 3) {
                let metricKey = parts[2]
                let metricOpt = output.metrics.get(metricKey)
                if (metricOpt.isSome()) {
                    return Some(JsonInt(metricOpt.getOrThrow()))
                }
                return None
            }
            var metricsMap = HashMap<String, JsonValue>()
            for ((k, v) in output.metrics) {
                metricsMap.add(k, JsonInt(v))
            }
            return Some(JsonObject(metricsMap))
        }
        if (field == "errors") {
            return Some(buildStringArray(output.errors))
        }
        let dataOpt = output.data.get(field)
        if (dataOpt.isSome()) {
            return dataOpt
        }
        return None
    }

    private func buildStringArray(items: ArrayList<String>): JsonValue {
        let arr = JsonArray()
        for (item in items) {
            arr.add(JsonString(item))
        }
        return arr
    }

    public func mapStepOutputs(stepOutputs: HashMap<String, SkillOutput>, stepInputMapping: HashMap<String, String>): SkillInput {
        let input = SkillInput()
        for ((targetKey, expression) in stepInputMapping) {
            let parts = expression.split(".")
            if (parts.size >= 2) {
                let stepName = parts[0]
                if (let Some(output) <- stepOutputs.get(stepName)) {
                    if (let Some(value) <- resolveExpression(expression, output)) {
                        input.put(targetKey, value)
                    }
                }
            }
        }
        return input
    }
}
