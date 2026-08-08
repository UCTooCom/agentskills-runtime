/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.context_verify

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull}
import magic.skill.SkillOutput
import magic.interaction.VerificationEvidenceCollector
import magic.log.LogUtils

public class ValidationResult {
    public var ruleName: String = ""
    public var status: ValidationStatus = ValidationStatus.Invalid
    public var details: String = ""
    public var actualValue: Option<JsonValue> = None<JsonValue>

    public init() {}

    public init(ruleName!: String, status!: ValidationStatus, details!: String) {
        this.ruleName = ruleName
        this.status = status
        this.details = details
    }

    public init(ruleName!: String, status!: ValidationStatus, details!: String, actualValue!: Option<JsonValue>) {
        this.ruleName = ruleName
        this.status = status
        this.details = details
        this.actualValue = actualValue
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("rule_name", JsonString(this.ruleName))
        map.add("status", JsonString(validationStatusToString(this.status)))
        map.add("details", JsonString(this.details))
        if (let Some(v) <- this.actualValue) {
            map.add("actual_value", v)
        } else {
            map.add("actual_value", JsonNull())
        }
        return JsonObject(map)
    }

    public static func validationStatusToString(s: ValidationStatus): String {
        match (s) {
            case ValidationStatus.Valid => "valid"
            case ValidationStatus.Invalid => "invalid"
            case ValidationStatus.Partial => "partial"
        }
    }

    public static func parseValidationStatus(s: String): ValidationStatus {
        match (s) {
            case "valid" => ValidationStatus.Valid
            case "invalid" => ValidationStatus.Invalid
            case "partial" => ValidationStatus.Partial
            case _ => ValidationStatus.Invalid
        }
    }
}

public class AgentValidationSummary {
    public var overallStatus: ValidationStatus = ValidationStatus.Valid
    public var results: ArrayList<ValidationResult> = ArrayList<ValidationResult>()
    public var validCount: Int64 = 0
    public var invalidCount: Int64 = 0
    public var partialCount: Int64 = 0

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("overall_status", JsonString(ValidationResult.validationStatusToString(this.overallStatus)))
        let resultsArr = ArrayList<JsonValue>()
        for (r in this.results) {
            resultsArr.add(r.toJsonValue())
        }
        let arr = JsonArray()
        for (v in resultsArr) {
            arr.add(v)
        }
        map.add("results", arr)
        map.add("valid_count", JsonInt(this.validCount))
        map.add("invalid_count", JsonInt(this.invalidCount))
        map.add("partial_count", JsonInt(this.partialCount))
        return JsonObject(map)
    }
}

public class AgentResultValidator {
    private let _evidenceCollector: VerificationEvidenceCollector

    public init(evidenceCollector!: VerificationEvidenceCollector) {
        _evidenceCollector = evidenceCollector
    }

    public func validate(output: SkillOutput, rules: ArrayList<OutputValidationRule>): AgentValidationSummary {
        let summary = AgentValidationSummary()

        if (rules.isEmpty()) {
            summary.overallStatus = ValidationStatus.Valid
            LogUtils.info("[AgentResultValidator] No validation rules, skipping validation")
            return summary
        }

        for (rule in rules) {
            let result = validateSingleRule(output, rule)
            summary.results.add(result)
        }

        computeSummary(summary)

        _evidenceCollector.recordBusinessRule(
            "agent_validation",
            "AgentResultValidator",
            "overall_${ValidationResult.validationStatusToString(summary.overallStatus)}",
            isOverallValid(summary.overallStatus),
            summary.toJsonValue().toString()
        )

        LogUtils.info("[AgentResultValidator] Validation complete: ${ValidationResult.validationStatusToString(summary.overallStatus)} (valid=${summary.validCount.toString()}, invalid=${summary.invalidCount.toString()}, partial=${summary.partialCount.toString()})")
        return summary
    }

    public func validateFromStep(status: String, output: Option<JsonValue>, errorMessage: String, rules: ArrayList<OutputValidationRule>): AgentValidationSummary {
        let summary = AgentValidationSummary()

        if (rules.isEmpty()) {
            summary.overallStatus = ValidationStatus.Valid
            return summary
        }

        if (status == "failed") {
            let failResult = ValidationResult(
                ruleName: "step_status_check",
                status: ValidationStatus.Invalid,
                details: "Step failed with error: ${errorMessage}"
            )
            summary.results.add(failResult)
            summary.invalidCount = 1
            summary.overallStatus = ValidationStatus.Invalid
            return summary
        }

        if (status == "skipped") {
            let skipResult = ValidationResult(
                ruleName: "step_status_check",
                status: ValidationStatus.Partial,
                details: "Step was skipped"
            )
            summary.results.add(skipResult)
            summary.partialCount = 1
            summary.overallStatus = ValidationStatus.Partial
            return summary
        }

        if (let Some(outputJson) <- output) {
            let skillOutput = jsonToSkillOutput(outputJson)
            return validate(skillOutput, rules)
        }

        let noOutputResult = ValidationResult(
            ruleName: "output_existence_check",
            status: ValidationStatus.Partial,
            details: "Step completed but produced no output"
        )
        summary.results.add(noOutputResult)
        summary.partialCount = 1
        summary.overallStatus = ValidationStatus.Partial
        return summary
    }

    public func loadRulesFromSkillOutputs(outputsDef: JsonValue): ArrayList<OutputValidationRule> {
        let rules = ArrayList<OutputValidationRule>()

        if (!(outputsDef is JsonArray)) {
            return rules
        }

        let arr = (outputsDef as JsonArray).getOrThrow()
        let size = arr.size()
        var i: Int64 = 0
        while (i < size) {
            if (let Some(elem) <- arr.get(i)) {
                if (elem is JsonObject) {
                    let obj = (elem as JsonObject).getOrThrow()
                    let fields = obj.getFields()

                    var name = ""
                    if (let Some(v) <- fields.get("name")) {
                        name = jsonStringValue(v)
                    }

                    var ruleType = ValidationRuleType.FieldRequired
                    if (let Some(v) <- fields.get("type")) {
                        ruleType = OutputValidationRule.parseValidationRuleType(jsonStringValue(v))
                    }

                    var required = true
                    if (let Some(v) <- fields.get("required")) {
                        if (v is JsonBool) {
                            required = (v as JsonBool).getOrThrow().getValue()
                        }
                    }

                    if (let Some(v) <- fields.get("validation")) {
                        if (v is JsonArray) {
                            let validationArr = (v as JsonArray).getOrThrow()
                            let vSize = validationArr.size()
                            var j: Int64 = 0
                            while (j < vSize) {
                                if (let Some(vElem) <- validationArr.get(j)) {
                                    if (vElem is JsonObject) {
                                        let vObj = (vElem as JsonObject).getOrThrow()
                                        let vFields = vObj.getFields()

                                        var ruleName = name
                                        if (let Some(rn) <- vFields.get("rule")) {
                                            ruleName = "${name}_${jsonStringValue(rn)}"
                                        }

                                        var expression = ""
                                        if (let Some(expr) <- vFields.get("expression")) {
                                            expression = jsonStringValue(expr)
                                        }

                                        var vRuleType = ruleType
                                        if (let Some(rt) <- vFields.get("rule")) {
                                            vRuleType = OutputValidationRule.parseValidationRuleType(jsonStringValue(rt))
                                        }

                                        rules.add(OutputValidationRule(name: ruleName, ruleType: vRuleType, expression: expression, required: required))
                                    }
                                }
                                j = j + 1
                            }
                        }
                    }
                }
            }
            i = i + 1
        }

        return rules
    }

    private func validateSingleRule(output: SkillOutput, rule: OutputValidationRule): ValidationResult {
        match (rule.ruleType) {
            case ValidationRuleType.FieldRequired =>
                return validateFieldRequired(output, rule)
            case ValidationRuleType.TypeCheck =>
                return validateTypeCheck(output, rule)
            case ValidationRuleType.SchemaCheck =>
                return validateSchemaCheck(output, rule)
            case ValidationRuleType.AssertionCheck =>
                return validateAssertionCheck(output, rule)
            case ValidationRuleType.CustomExpression =>
                return validateCustomExpression(output, rule)
        }
    }

    private func validateFieldRequired(output: SkillOutput, rule: OutputValidationRule): ValidationResult {
        let fieldName = rule.expression
        if (fieldName.isEmpty()) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "No field specified, skipping")
        }

        if (output.data.contains(fieldName)) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "Field '${fieldName}' exists", actualValue: output.data.get(fieldName))
        }

        if (output.metrics.contains(fieldName)) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "Metric '${fieldName}' exists", actualValue: Some(JsonInt(output.metrics.get(fieldName).getOrThrow())))
        }

        let found = checkRawOutputField(output.rawOutput, fieldName)
        if (found) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "Field '${fieldName}' found in raw output")
        }

        if (rule.required) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Invalid, details: "Required field '${fieldName}' not found")
        }
        return ValidationResult(ruleName: rule.name, status: ValidationStatus.Partial, details: "Optional field '${fieldName}' not found")
    }

    private func validateTypeCheck(output: SkillOutput, rule: OutputValidationRule): ValidationResult {
        let parts = rule.expression.split(":")
        if (parts.size < 2) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Invalid, details: "TypeCheck expression format: fieldName:expectedType")
        }

        let fieldName = parts[0]
        let expectedType = parts[1]

        if (let Some(value) <- output.data.get(fieldName)) {
            let actualType = jsonValueType(value)
            if (actualType == expectedType) {
                return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "Field '${fieldName}' type is '${actualType}'", actualValue: Some(value))
            }
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Invalid, details: "Field '${fieldName}' expected type '${expectedType}' but got '${actualType}'", actualValue: Some(value))
        }

        return ValidationResult(ruleName: rule.name, status: ValidationStatus.Invalid, details: "Field '${fieldName}' not found for type check")
    }

    private func validateSchemaCheck(output: SkillOutput, rule: OutputValidationRule): ValidationResult {
        let outputJson = output.toJsonValue()
        if (!(outputJson is JsonObject)) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Invalid, details: "Output is not a JSON object")
        }

        let requiredFields = rule.expression.split(",")
        var missingFields = ArrayList<String>()
        for (field in requiredFields) {
            let trimmed = field.trimAscii()
            if (trimmed.isEmpty()) {
                continue
            }
            if (!output.data.contains(trimmed)) {
                missingFields.add(trimmed)
            }
        }

        if (missingFields.isEmpty()) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "Schema check passed, all required fields present")
        }

        if (rule.required) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Invalid, details: "Schema check failed, missing fields: ${missingFields.toString()}")
        }
        return ValidationResult(ruleName: rule.name, status: ValidationStatus.Partial, details: "Schema check partial, missing optional fields: ${missingFields.toString()}")
    }

    private func validateAssertionCheck(output: SkillOutput, rule: OutputValidationRule): ValidationResult {
        let expression = rule.expression
        if (expression.isEmpty()) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "No assertion expression")
        }

        let result = evaluateSimpleAssertion(output, expression)
        if (result) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "Assertion passed: ${expression}")
        }
        return ValidationResult(ruleName: rule.name, status: ValidationStatus.Invalid, details: "Assertion failed: ${expression}")
    }

    private func validateCustomExpression(output: SkillOutput, rule: OutputValidationRule): ValidationResult {
        let expression = rule.expression
        if (expression.isEmpty()) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Partial, details: "No custom expression provided")
        }

        let result = evaluateSimpleAssertion(output, expression)
        if (result) {
            return ValidationResult(ruleName: rule.name, status: ValidationStatus.Valid, details: "Custom expression passed: ${expression}")
        }
        return ValidationResult(ruleName: rule.name, status: ValidationStatus.Invalid, details: "Custom expression failed: ${expression}")
    }

    private func evaluateSimpleAssertion(output: SkillOutput, expression: String): Bool {
        let trimmed = expression.trimAscii()

        let ops = [" != ", " == ", " > ", " < ", " >= ", " <= "]
        var opFound = false
        var op = ""
        var leftPart = ""
        var rightPart = ""

        for (candidate in ops) {
            let idxOpt = trimmed.indexOf(candidate)
            if (let Some(idx) <- idxOpt) {
                op = candidate.trimAscii()
                leftPart = trimmed[0..idx].trimAscii()
                rightPart = trimmed[idx + candidate.size..trimmed.size].trimAscii()
                opFound = true
                break
            }
        }

        if (!opFound) {
            return resolveOutputValue(output, trimmed).isSome()
        }

        let leftOpt = resolveOutputValue(output, leftPart)
        let rightOpt = resolveOutputValue(output, rightPart)

        if (leftOpt.isNone() || rightOpt.isNone()) {
            return false
        }

        let leftVal = leftOpt.getOrThrow()
        let rightVal = rightOpt.getOrThrow()

        match (op) {
            case "==" => return leftVal == rightVal
            case "!=" => return leftVal != rightVal
            case ">" => return leftVal > rightVal
            case "<" => return leftVal < rightVal
            case ">=" => return leftVal >= rightVal
            case "<=" => return leftVal <= rightVal
            case _ => return false
        }
    }

    private func resolveOutputValue(output: SkillOutput, expr: String): Option<String> {
        if (expr.startsWith("\"") && expr.endsWith("\"") && expr.size >= 2) {
            return Some(expr[1..expr.size - 1])
        }

        if (output.data.contains(expr)) {
            let val = output.data.get(expr).getOrThrow()
            return Some(val.toString())
        }

        if (output.metrics.contains(expr)) {
            return Some(output.metrics.get(expr).getOrThrow().toString())
        }

        if (expr == "files.size" || expr == "file_count") {
            return Some(output.files.size.toString())
        }

        if (expr == "errors.size" || expr == "error_count") {
            return Some(output.errors.size.toString())
        }

        if (expr == "has_errors") {
            return Some(if (output.hasErrors()) { "true" } else { "false" })
        }

        return None
    }

    private func checkRawOutputField(rawOutput: String, fieldName: String): Bool {
        return rawOutput.contains(fieldName)
    }

    private func jsonValueType(v: JsonValue): String {
        if (v is JsonString) {
            return "string"
        }
        if (v is JsonInt) {
            return "int"
        }
        if (v is JsonBool) {
            return "bool"
        }
        if (v is JsonObject) {
            return "object"
        }
        if (v is JsonArray) {
            return "array"
        }
        if (v is JsonNull) {
            return "null"
        }
        return "unknown"
    }

    private func jsonToSkillOutput(json: JsonValue): SkillOutput {
        let output = SkillOutput()
        if (!(json is JsonObject)) {
            output.rawOutput = json.toString()
            return output
        }

        let obj = (json as JsonObject).getOrThrow()
        let fields = obj.getFields()

        if (let Some(v) <- fields.get("raw_output")) {
            output.rawOutput = jsonStringValue(v)
        }

        if (let Some(v) <- fields.get("data")) {
            if (v is JsonObject) {
                let dataObj = (v as JsonObject).getOrThrow()
                let dataFields = dataObj.getFields()
                for ((k, val) in dataFields) {
                    output.data.add(k, val)
                }
            }
        }

        if (let Some(v) <- fields.get("errors")) {
            if (v is JsonArray) {
                let errArr = (v as JsonArray).getOrThrow()
                let size = errArr.size()
                var i: Int64 = 0
                while (i < size) {
                    if (let Some(elem) <- errArr.get(i)) {
                        output.errors.add(jsonStringValue(elem))
                    }
                    i = i + 1
                }
            }
        }

        return output
    }

    private func isOverallValid(status: ValidationStatus): Bool {
        match (status) {
            case ValidationStatus.Valid => true
            case _ => false
        }
    }

    private func computeSummary(summary: AgentValidationSummary): Unit {
        summary.validCount = 0
        summary.invalidCount = 0
        summary.partialCount = 0

        for (result in summary.results) {
            match (result.status) {
                case ValidationStatus.Valid => summary.validCount = summary.validCount + 1
                case ValidationStatus.Invalid => summary.invalidCount = summary.invalidCount + 1
                case ValidationStatus.Partial => summary.partialCount = summary.partialCount + 1
            }
        }

        if (summary.invalidCount > 0) {
            summary.overallStatus = ValidationStatus.Invalid
        } else if (summary.partialCount > 0) {
            summary.overallStatus = ValidationStatus.Partial
        } else {
            summary.overallStatus = ValidationStatus.Valid
        }
    }

    private static func jsonStringValue(v: JsonValue): String {
        if (v is JsonString) {
            return (v as JsonString).getOrThrow().getValue()
        }
        return v.toString()
    }
}
