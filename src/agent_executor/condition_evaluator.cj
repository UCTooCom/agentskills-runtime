/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_executor

import std.collection.HashMap
import std.convert.Parsable
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool}
import magic.log.LogUtils

public class ConditionEvaluator {
    private let _stepOutputs: HashMap<String, JsonValue>
    private let _stepStatuses: HashMap<String, String>

    public init() {
        _stepOutputs = HashMap<String, JsonValue>()
        _stepStatuses = HashMap<String, String>()
    }

    public func setStepOutputs(outputs: HashMap<String, JsonValue>): Unit {
        _stepOutputs.clear()
        for ((k, v) in outputs) {
            _stepOutputs.add(k, v)
        }
    }

    public func setStepStatuses(statuses: HashMap<String, String>): Unit {
        _stepStatuses.clear()
        for ((k, v) in statuses) {
            _stepStatuses.add(k, v)
        }
    }

    public func evaluate(expression: String): Bool {
        let trimmed = expression.trimAscii()
        if (trimmed.isEmpty()) {
            return true
        }

        let orParts = trimmed.split(" or ")
        for (orPart in orParts) {
            if (evaluateAnd(orPart.trimAscii())) {
                return true
            }
        }
        return false
    }

    private func evaluateAnd(expr: String): Bool {
        let andParts = expr.split(" and ")
        for (andPart in andParts) {
            if (!evaluateAtom(andPart.trimAscii())) {
                return false
            }
        }
        return true
    }

    private func evaluateAtom(expr: String): Bool {
        if (expr.startsWith("not ")) {
            return !evaluateAtom(expr[4..expr.size].trimAscii())
        }

        if (expr == "true") {
            return true
        }
        if (expr == "false") {
            return false
        }

        let comparisonOps = [" != ", " == ", " contains ", " > ", " < "]
        var opFound = false
        var op = ""
        var leftPart = ""
        var rightPart = ""

        for (candidate in comparisonOps) {
            let idxOpt = expr.indexOf(candidate)
            if (let Some(idx) <- idxOpt) {
                op = candidate.trimAscii()
                leftPart = expr[0..idx].trimAscii()
                rightPart = expr[idx + candidate.size..expr.size].trimAscii()
                opFound = true
                break
            }
        }

        if (opFound) {
            let leftValue = resolveValue(leftPart)
            let rightValue = resolveValue(rightPart)

            match (op) {
                case "==" => return compareEquals(leftValue, rightValue)
                case "!=" => return !compareEquals(leftValue, rightValue)
                case "contains" => return compareContains(leftValue, rightValue)
                case ">" => return compareGreaterThan(leftValue, rightValue)
                case "<" => return compareLessThan(leftValue, rightValue)
                case _ => return false
            }
        }

        let resolved = resolveValue(expr)
        if (resolved is JsonBool) {
            return (resolved as JsonBool).getOrThrow().getValue()
        }

        if (resolved is JsonString) {
            let strVal = (resolved as JsonString).getOrThrow().getValue()
            if (strVal == "completed" || strVal == "true") {
                return true
            }
            if (strVal == "failed" || strVal == "false" || strVal == "pending") {
                return false
            }
            return !strVal.isEmpty()
        }

        return true
    }

    private func resolveValue(expr: String): JsonValue {
        if (expr.startsWith("${") && expr.endsWith("}")) {
            let path = expr[2..expr.size - 1]
            return resolvePath(path)
        }

        if (expr.startsWith("\"") && expr.endsWith("\"")) {
            return JsonString(expr[1..expr.size - 1])
        }

        if (expr == "true") {
            return JsonBool(true)
        }
        if (expr == "false") {
            return JsonBool(false)
        }

        let intOpt = Int64.tryParse(expr)
        if (intOpt.isSome()) {
            return JsonInt(intOpt.getOrThrow())
        }

        return JsonString(expr)
    }

    private func resolvePath(path: String): JsonValue {
        let parts = path.split(".")
        if (parts.size < 2) {
            return JsonString(path)
        }

        let stepName = parts[0]
        if (parts.size == 2) {
            let field = parts[1]
            if (field == "status") {
                if (let Some(status) <- _stepStatuses.get(stepName)) {
                    return JsonString(status)
                }
                return JsonString("unknown")
            }
            if (let Some(output) <- _stepOutputs.get(stepName)) {
                if (output is JsonObject) {
                    let fields = (output as JsonObject).getOrThrow().getFields()
                    if (let Some(val) <- fields.get(field)) {
                        return val
                    }
                }
                return output
            }
        }

        if (parts.size >= 3) {
            if (let Some(output) <- _stepOutputs.get(stepName)) {
                var current: JsonValue = output
                for (i in 1..parts.size) {
                    if (current is JsonObject) {
                        let fields = (current as JsonObject).getOrThrow().getFields()
                        if (let Some(val) <- fields.get(parts[i])) {
                            current = val
                        } else {
                            return JsonString("")
                        }
                    } else {
                        return JsonString("")
                    }
                }
                return current
            }
        }

        return JsonString("")
    }

    private func compareEquals(left: JsonValue, right: JsonValue): Bool {
        return left.toString() == right.toString()
    }

    private func compareContains(left: JsonValue, right: JsonValue): Bool {
        let leftStr = left.toString()
        let rightStr = right.toString()
        if (leftStr.startsWith("\"") && leftStr.endsWith("\"")) {
            let inner = leftStr[1..leftStr.size - 1]
            return inner.contains(rightStr)
        }
        return leftStr.contains(rightStr)
    }

    private func compareGreaterThan(left: JsonValue, right: JsonValue): Bool {
        let leftOpt = jsonToInt(left)
        let rightOpt = jsonToInt(right)
        if (leftOpt.isSome() && rightOpt.isSome()) {
            return leftOpt.getOrThrow() > rightOpt.getOrThrow()
        }
        return left.toString() > right.toString()
    }

    private func compareLessThan(left: JsonValue, right: JsonValue): Bool {
        let leftOpt = jsonToInt(left)
        let rightOpt = jsonToInt(right)
        if (leftOpt.isSome() && rightOpt.isSome()) {
            return leftOpt.getOrThrow() < rightOpt.getOrThrow()
        }
        return left.toString() < right.toString()
    }

    private func jsonToInt(v: JsonValue): Option<Int64> {
        if (v is JsonInt) {
            return Some((v as JsonInt).getOrThrow().getValue())
        }
        if (v is JsonString) {
            return Int64.tryParse((v as JsonString).getOrThrow().getValue())
        }
        return None
    }
}