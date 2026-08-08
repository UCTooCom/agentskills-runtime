/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray, JsonNull, JsonFloat}
import magic.log.LogUtils

public enum ErrorCategory {
    | NetworkError | TimeoutError | AuthError | ResourceError | ValidationError | ExecutionError | UnknownError
}

public enum RecoveryStrategy {
    | Retry | RetryWithBackoff | Fallback | Skip | Abort
}

public class ErrorRecord {
    public var id: String = ""
    public var agentId: String = ""
    public var sessionId: String = ""
    public var category: ErrorCategory = ErrorCategory.UnknownError
    public var errorMessage: String = ""
    public var stackTrace: Option<String> = None<String>
    public var context: Option<JsonValue> = None<JsonValue>
    public var timestamp: DateTime = DateTime.now()
    public var retryCount: Int64 = 0

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", JsonString(this.id))
        map.add("agent_id", JsonString(this.agentId))
        map.add("session_id", JsonString(this.sessionId))
        map.add("category", JsonString(errorCategoryToString(this.category)))
        map.add("error_message", JsonString(this.errorMessage))
        if (let Some(st) <- this.stackTrace) { map.add("stack_trace", JsonString(st)) }
        if (let Some(ctx) <- this.context) { map.add("context", ctx) }
        map.add("timestamp", JsonString(this.timestamp.toString()))
        map.add("retry_count", JsonInt(this.retryCount))
        JsonObject(map)
    }

    public static func errorCategoryToString(c: ErrorCategory): String {
        match (c) {
            case ErrorCategory.NetworkError => "network_error"
            case ErrorCategory.TimeoutError => "timeout_error"
            case ErrorCategory.AuthError => "auth_error"
            case ErrorCategory.ResourceError => "resource_error"
            case ErrorCategory.ValidationError => "validation_error"
            case ErrorCategory.ExecutionError => "execution_error"
            case ErrorCategory.UnknownError => "unknown_error"
        }
    }

    public static func classifyError(message: String): ErrorCategory {
        let lower = message.toAsciiLower()
        if (lower.contains("timeout") || lower.contains("timed out")) { return ErrorCategory.TimeoutError }
        if (lower.contains("network") || lower.contains("connection") || lower.contains("econnrefused")) { return ErrorCategory.NetworkError }
        if (lower.contains("auth") || lower.contains("unauthorized") || lower.contains("forbidden")) { return ErrorCategory.AuthError }
        if (lower.contains("resource") || lower.contains("limit") || lower.contains("quota")) { return ErrorCategory.ResourceError }
        if (lower.contains("validation") || lower.contains("invalid") || lower.contains("format")) { return ErrorCategory.ValidationError }
        if (lower.contains("execution") || lower.contains("runtime") || lower.contains("panic")) { return ErrorCategory.ExecutionError }
        ErrorCategory.UnknownError
    }
}

public class RecoveryConfig {
    public var maxRetries: Int64 = 3
    public var baseBackoffMs: Int64 = 1000
    public var maxBackoffMs: Int64 = 60000
    public var retryableCategories: ArrayList<ErrorCategory> = ArrayList<ErrorCategory>()

    public init() {
        retryableCategories.add(ErrorCategory.NetworkError)
        retryableCategories.add(ErrorCategory.TimeoutError)
        retryableCategories.add(ErrorCategory.ResourceError)
    }

    public func isRetryable(category: ErrorCategory): Bool {
        for (c in retryableCategories) {
            if (isSameErrorCategory(c, category)) { return true }
        }
        false
    }

    public static func isSameErrorCategory(a: ErrorCategory, b: ErrorCategory): Bool {
        match (a) {
            case ErrorCategory.NetworkError => match (b) { case ErrorCategory.NetworkError => true case _ => false }
            case ErrorCategory.TimeoutError => match (b) { case ErrorCategory.TimeoutError => true case _ => false }
            case ErrorCategory.AuthError => match (b) { case ErrorCategory.AuthError => true case _ => false }
            case ErrorCategory.ResourceError => match (b) { case ErrorCategory.ResourceError => true case _ => false }
            case ErrorCategory.ValidationError => match (b) { case ErrorCategory.ValidationError => true case _ => false }
            case ErrorCategory.ExecutionError => match (b) { case ErrorCategory.ExecutionError => true case _ => false }
            case ErrorCategory.UnknownError => match (b) { case ErrorCategory.UnknownError => true case _ => false }
        }
    }

    public func getBackoffMs(retryCount: Int64): Int64 {
        let backoff = baseBackoffMs * (Int64(1) << Int32(retryCount))
        if (backoff > maxBackoffMs) { maxBackoffMs } else { backoff }
    }
}

public class RecoveryResult {
    public var errorId: String = ""
    public var strategy: RecoveryStrategy = RecoveryStrategy.Retry
    public var success: Bool = false
    public var retryCount: Int64 = 0
    public var result: Option<JsonValue> = None<JsonValue>
    public var recoveredAt: DateTime = DateTime.now()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("error_id", JsonString(this.errorId))
        map.add("strategy", JsonString(recoveryStrategyToString(this.strategy)))
        map.add("success", JsonBool(this.success))
        map.add("retry_count", JsonInt(this.retryCount))
        if (let Some(r) <- this.result) { map.add("result", r) }
        map.add("recovered_at", JsonString(this.recoveredAt.toString()))
        JsonObject(map)
    }

    public static func recoveryStrategyToString(s: RecoveryStrategy): String {
        match (s) {
            case RecoveryStrategy.Retry => "retry"
            case RecoveryStrategy.RetryWithBackoff => "retry_with_backoff"
            case RecoveryStrategy.Fallback => "fallback"
            case RecoveryStrategy.Skip => "skip"
            case RecoveryStrategy.Abort => "abort"
        }
    }
}

public class ErrorRecoveryManager {
    private let _config: RecoveryConfig
    private let _retryExecutor: (String, Option<JsonValue>) -> Option<JsonValue>
    private let _fallbackExecutor: (ErrorCategory, String) -> Option<JsonValue>
    private let _recordEvidence: (String, String, String, Option<JsonValue>) -> String
    private var _errorHistory: HashMap<String, ArrayList<ErrorRecord>>
    private var _counter: Int64 = 0

    public init(config!: RecoveryConfig, retryExecutor!: (String, Option<JsonValue>) -> Option<JsonValue>, fallbackExecutor!: (ErrorCategory, String) -> Option<JsonValue>, recordEvidence!: (String, String, String, Option<JsonValue>) -> String) {
        _config = config
        _retryExecutor = retryExecutor
        _fallbackExecutor = fallbackExecutor
        _recordEvidence = recordEvidence
        _errorHistory = HashMap<String, ArrayList<ErrorRecord>>()
    }

    public func handleError(agentId: String, sessionId: String, errorMessage: String, context: Option<JsonValue>): RecoveryResult {
        _counter = _counter + 1
        let errorId = "err_${_counter.toString()}"

        let record = ErrorRecord()
        record.id = errorId
        record.agentId = agentId
        record.sessionId = sessionId
        record.category = ErrorRecord.classifyError(errorMessage)
        record.errorMessage = errorMessage
        record.context = context
        record.timestamp = DateTime.now()

        addErrorToHistory(sessionId, record)

        LogUtils.info("[ErrorRecoveryManager] Error: id=${errorId}, category=${ErrorRecord.errorCategoryToString(record.category)}, agent=${agentId}")

        let result = RecoveryResult()
        result.errorId = errorId

        if (_config.isRetryable(record.category)) {
            result.strategy = RecoveryStrategy.RetryWithBackoff
            let retryResult = executeRetryWithBackoff(agentId, context, record)
            result.success = retryResult.isSome()
            result.result = retryResult
        } else if (RecoveryConfig.isSameErrorCategory(record.category, ErrorCategory.ValidationError)) {
            result.strategy = RecoveryStrategy.Skip
            result.success = false
            LogUtils.info("[ErrorRecoveryManager] Validation error, skipping: ${errorId}")
        } else {
            result.strategy = RecoveryStrategy.Fallback
            let fallbackResult = _fallbackExecutor(record.category, errorMessage)
            result.success = fallbackResult.isSome()
            result.result = fallbackResult
        }

        _recordEvidence(sessionId, "error_recovery", "Error recovery: ${ErrorRecord.errorCategoryToString(record.category)} → ${RecoveryResult.recoveryStrategyToString(result.strategy)}", Some(result.toJsonValue()))

        result.recoveredAt = DateTime.now()
        result
    }

    private func executeRetryWithBackoff(agentId: String, context: Option<JsonValue>, error: ErrorRecord): Option<JsonValue> {
        var retryCount: Int64 = 0
        while (retryCount < _config.maxRetries) {
            let backoffMs = _config.getBackoffMs(retryCount)
            LogUtils.info("[ErrorRecoveryManager] Retry ${retryCount.toString()}/${_config.maxRetries.toString()} after ${backoffMs.toString()}ms backoff")

            let result = _retryExecutor(agentId, context)
            if (result.isSome()) {
                error.retryCount = retryCount + 1
                LogUtils.info("[ErrorRecoveryManager] Retry succeeded after ${retryCount.toString()} attempts")
                return result
            }
            retryCount = retryCount + 1
        }

        LogUtils.error("[ErrorRecoveryManager] All ${_config.maxRetries.toString()} retries exhausted")
        None<JsonValue>
    }

    public func getErrorHistory(sessionId: String): ArrayList<ErrorRecord> {
        match (_errorHistory.get(sessionId)) {
            case Some(errors) => errors
            case None => ArrayList<ErrorRecord>()
        }
    }

    public func getErrorStats(sessionId: String): HashMap<String, Int64> {
        let stats = HashMap<String, Int64>()
        let errors = getErrorHistory(sessionId)
        for (error in errors) {
            let key = ErrorRecord.errorCategoryToString(error.category)
            if (let Some(count) <- stats.get(key)) {
                stats.add(key, count + 1)
            } else {
                stats.add(key, 1)
            }
        }
        stats
    }

    private func addErrorToHistory(sessionId: String, record: ErrorRecord): Unit {
        if (!_errorHistory.contains(sessionId)) {
            _errorHistory.add(sessionId, ArrayList<ErrorRecord>())
        }
        if (let Some(list) <- _errorHistory.get(sessionId)) {
            list.add(record)
        }
    }
}