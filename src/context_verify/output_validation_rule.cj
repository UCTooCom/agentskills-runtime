/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.context_verify

import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool}

public enum ValidationRuleType {
    | SchemaCheck
    | AssertionCheck
    | FieldRequired
    | TypeCheck
    | CustomExpression
}

public enum ValidationStatus {
    | Valid
    | Invalid
    | Partial
}

public class OutputValidationRule {
    public var name: String = ""
    public var ruleType: ValidationRuleType = ValidationRuleType.FieldRequired
    public var expression: String = ""
    public var required: Bool = true

    public init() {}

    public init(name!: String, ruleType!: ValidationRuleType, expression!: String, required!: Bool) {
        this.name = name
        this.ruleType = ruleType
        this.expression = expression
        this.required = required
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", JsonString(this.name))
        map.add("rule_type", JsonString(validationRuleTypeToString(this.ruleType)))
        map.add("expression", JsonString(this.expression))
        map.add("required", JsonBool(this.required))
        return JsonObject(map)
    }

    public static func fromJsonValue(json: JsonValue): Option<OutputValidationRule> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let rule = OutputValidationRule()
        if (let Some(v) <- fields.get("name")) {
            rule.name = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("rule_type")) {
            rule.ruleType = parseValidationRuleType(jsonStringValue(v))
        }
        if (let Some(v) <- fields.get("expression")) {
            rule.expression = jsonStringValue(v)
        }
        if (let Some(v) <- fields.get("required")) {
            if (v is JsonBool) {
                rule.required = (v as JsonBool).getOrThrow().getValue()
            }
        }
        return Some(rule)
    }

    public static func validationRuleTypeToString(rt: ValidationRuleType): String {
        match (rt) {
            case ValidationRuleType.SchemaCheck => "schema_check"
            case ValidationRuleType.AssertionCheck => "assertion_check"
            case ValidationRuleType.FieldRequired => "field_required"
            case ValidationRuleType.TypeCheck => "type_check"
            case ValidationRuleType.CustomExpression => "custom_expression"
        }
    }

    public static func parseValidationRuleType(s: String): ValidationRuleType {
        match (s) {
            case "schema_check" => ValidationRuleType.SchemaCheck
            case "assertion_check" => ValidationRuleType.AssertionCheck
            case "type_check" => ValidationRuleType.TypeCheck
            case "custom_expression" => ValidationRuleType.CustomExpression
            case _ => ValidationRuleType.FieldRequired
        }
    }

    private static func jsonStringValue(v: JsonValue): String {
        if (v is JsonString) {
            return (v as JsonString).getOrThrow().getValue()
        }
        return v.toString()
    }
}
