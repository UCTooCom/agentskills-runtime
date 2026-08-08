/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.context_verify

import std.collection.HashMap
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import magic.interaction.{ExecutionEvidenceRecorder, EvidenceType}
import magic.log.LogUtils

public class DegradationResult {
    public var stepName: String = ""
    public var statusStr: String = "failed"
    public var output: Option<JsonValue> = None<JsonValue>
    public var errorMessage: String = ""

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("step_name", JsonString(this.stepName))
        map.add("status", JsonString(this.statusStr))
        if (let Some(out) <- this.output) {
            map.add("output", out)
        }
        map.add("error_message", JsonString(this.errorMessage))
        return JsonObject(map)
    }
}

public class ValidationRetryHandler {
    private let _maxRetries: Int64
    private let _degradationConfig: Option<DegradationConfig>
    private let _evidenceRecorder: ExecutionEvidenceRecorder

    public init(maxRetries!: Int64, degradationConfig!: Option<DegradationConfig>, evidenceRecorder!: ExecutionEvidenceRecorder) {
        _maxRetries = maxRetries
        _degradationConfig = degradationConfig
        _evidenceRecorder = evidenceRecorder
    }

    public func shouldRetry(summary: AgentValidationSummary, attemptCount: Int64): Bool {
        if (!isInvalid(summary.overallStatus)) {
            return false
        }
        if (attemptCount >= _maxRetries) {
            return false
        }
        LogUtils.info("[ValidationRetryHandler] Validation invalid, retrying (attempt ${attemptCount.toString()}/${_maxRetries.toString()})")
        return true
    }

    public func executeDegradation(stepName: String, context: AgentContext): DegradationResult {
        let evidenceId = _evidenceRecorder.recordStart(
            context.taskId,
            "ValidationRetryHandler",
            "Degradation",
            EvidenceType.AgentExecution,
            Some(context.toJsonValue())
        )

        if (let Some(config) <- _degradationConfig) {
            let result = executeDegradationByStrategy(config, stepName)
            _evidenceRecorder.recordEnd(evidenceId, Some(result.toJsonValue()))
            LogUtils.info("[ValidationRetryHandler] Degradation executed: ${DegradationConfig.degradationStrategyTypeToString(config.strategy)}")
            return result
        }

        let noConfigResult = DegradationResult()
        noConfigResult.stepName = stepName
        noConfigResult.statusStr = "failed"
        noConfigResult.errorMessage = "Validation failed and no degradation config available"

        _evidenceRecorder.recordEnd(evidenceId, Some(noConfigResult.toJsonValue()))
        LogUtils.info("[ValidationRetryHandler] No degradation config, step failed")
        return noConfigResult
    }

    public func getMaxRetries(): Int64 {
        return _maxRetries
    }

    public func getDegradationConfig(): Option<DegradationConfig> {
        return _degradationConfig
    }

    private func isInvalid(status: ValidationStatus): Bool {
        match (status) {
            case ValidationStatus.Invalid => true
            case _ => false
        }
    }

    private func executeDegradationByStrategy(config: DegradationConfig, stepName: String): DegradationResult {
        match (config.strategy) {
            case DegradationStrategyType.SkipStep =>
                return createSkippedResult(stepName)
            case DegradationStrategyType.UseDefault =>
                return createDefaultResult(stepName, config.defaultValue)
            case DegradationStrategyType.RetryWithSimplerInput =>
                return createSimplerInputResult(stepName, config.simplerInput)
            case DegradationStrategyType.FallbackToAlternative =>
                return createAlternativeResult(stepName, config.alternativeStep)
        }
    }

    private func createSkippedResult(stepName: String): DegradationResult {
        let result = DegradationResult()
        result.stepName = stepName
        result.statusStr = "skipped"
        return result
    }

    private func createDefaultResult(stepName: String, defaultValue: Option<JsonValue>): DegradationResult {
        let result = DegradationResult()
        result.stepName = stepName
        result.statusStr = "completed"
        result.output = defaultValue
        return result
    }

    private func createSimplerInputResult(stepName: String, simplerInput: Option<JsonValue>): DegradationResult {
        let result = DegradationResult()
        result.stepName = stepName
        result.statusStr = "pending"
        result.output = simplerInput
        result.errorMessage = "RetryWithSimplerInput: caller should re-execute with simpler input"
        return result
    }

    private func createAlternativeResult(stepName: String, alternativeStep: Option<String>): DegradationResult {
        let result = DegradationResult()
        result.stepName = stepName
        result.statusStr = "pending"
        result.errorMessage = "FallbackToAlternative: caller should execute alternative step"

        if (let Some(altStep) <- alternativeStep) {
            var map = HashMap<String, JsonValue>()
            map.add("alternative_step", JsonString(altStep))
            result.output = Some(JsonObject(map))
        }

        return result
    }
}
