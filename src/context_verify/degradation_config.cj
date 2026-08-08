/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.context_verify

import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonNull}

public enum DegradationStrategyType {
    | SkipStep
    | UseDefault
    | RetryWithSimplerInput
    | FallbackToAlternative
}

public class DegradationConfig {
    public var strategy: DegradationStrategyType = DegradationStrategyType.SkipStep
    public var defaultValue: Option<JsonValue> = None<JsonValue>
    public var alternativeStep: Option<String> = None<String>
    public var simplerInput: Option<JsonValue> = None<JsonValue>

    public init() {}

    public init(strategy!: DegradationStrategyType) {
        this.strategy = strategy
    }

    public init(strategy!: DegradationStrategyType, defaultValue!: Option<JsonValue>, alternativeStep!: Option<String>, simplerInput!: Option<JsonValue>) {
        this.strategy = strategy
        this.defaultValue = defaultValue
        this.alternativeStep = alternativeStep
        this.simplerInput = simplerInput
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("strategy", JsonString(degradationStrategyTypeToString(this.strategy)))
        if (let Some(v) <- this.defaultValue) {
            map.add("default_value", v)
        } else {
            map.add("default_value", JsonNull())
        }
        if (let Some(step) <- this.alternativeStep) {
            map.add("alternative_step", JsonString(step))
        } else {
            map.add("alternative_step", JsonNull())
        }
        if (let Some(v) <- this.simplerInput) {
            map.add("simpler_input", v)
        } else {
            map.add("simpler_input", JsonNull())
        }
        return JsonObject(map)
    }

    public static func fromJsonValue(json: JsonValue): Option<DegradationConfig> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let config = DegradationConfig()
        if (let Some(v) <- fields.get("strategy")) {
            config.strategy = parseDegradationStrategyType(jsonStringValue(v))
        }

        if (let Some(v) <- fields.get("default_value")) {
            if (!(v is JsonNull)) {
                config.defaultValue = Some(v)
            }
        }

        if (let Some(v) <- fields.get("alternative_step")) {
            if (v is JsonString) {
                config.alternativeStep = Some((v as JsonString).getOrThrow().getValue())
            }
        }

        if (let Some(v) <- fields.get("simpler_input")) {
            if (!(v is JsonNull)) {
                config.simplerInput = Some(v)
            }
        }

        return Some(config)
    }

    public static func degradationStrategyTypeToString(t: DegradationStrategyType): String {
        match (t) {
            case DegradationStrategyType.SkipStep => "skip_step"
            case DegradationStrategyType.UseDefault => "use_default"
            case DegradationStrategyType.RetryWithSimplerInput => "retry_with_simpler_input"
            case DegradationStrategyType.FallbackToAlternative => "fallback_to_alternative"
        }
    }

    public static func parseDegradationStrategyType(s: String): DegradationStrategyType {
        match (s) {
            case "skip_step" => DegradationStrategyType.SkipStep
            case "use_default" => DegradationStrategyType.UseDefault
            case "retry_with_simpler_input" => DegradationStrategyType.RetryWithSimplerInput
            case "fallback_to_alternative" => DegradationStrategyType.FallbackToAlternative
            case _ => DegradationStrategyType.SkipStep
        }
    }

    private static func jsonStringValue(v: JsonValue): String {
        if (v is JsonString) {
            return (v as JsonString).getOrThrow().getValue()
        }
        return v.toString()
    }
}