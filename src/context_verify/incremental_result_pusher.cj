/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.context_verify

import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt}
import magic.log.LogUtils

public class IncrementalResultPusher {
    private let _sendFunc: (String, String, JsonValue) -> Unit
    private let _broadcastFunc: (String, JsonValue) -> Unit

    public init(sendFunc!: (String, String, JsonValue) -> Unit, broadcastFunc!: (String, JsonValue) -> Unit) {
        _sendFunc = sendFunc
        _broadcastFunc = broadcastFunc
    }

    public func pushIncrementalResult(sessionId: String, stepName: String, statusStr: String, output: Option<JsonValue>, durationMs: Int64): Unit {
        try {
            var map = HashMap<String, JsonValue>()
            map.add("step_name", JsonString(stepName))
            map.add("status", JsonString(statusStr))
            if (let Some(out) <- output) {
                map.add("output", out)
            }
            map.add("duration_ms", JsonInt(durationMs))
            let payload = JsonObject(map)
            _sendFunc(sessionId, "incremental_result", payload)
            LogUtils.info("[IncrementalResultPusher] Pushed incremental result for step '${stepName}' to session '${sessionId}'")
        } catch (ex: Exception) {
            LogUtils.error("[IncrementalResultPusher] Failed to push incremental result: ${ex.message}")
        }
    }

    public func pushValidationResult(sessionId: String, stepName: String, summary: AgentValidationSummary): Unit {
        try {
            var map = HashMap<String, JsonValue>()
            map.add("step_name", JsonString(stepName))
            map.add("overall_status", JsonString(ValidationResult.validationStatusToString(summary.overallStatus)))
            map.add("valid_count", JsonInt(summary.validCount))
            map.add("invalid_count", JsonInt(summary.invalidCount))
            map.add("partial_count", JsonInt(summary.partialCount))
            let payload = JsonObject(map)
            _sendFunc(sessionId, "validation_result", payload)
            LogUtils.info("[IncrementalResultPusher] Pushed validation result for step '${stepName}' to session '${sessionId}'")
        } catch (ex: Exception) {
            LogUtils.error("[IncrementalResultPusher] Failed to push validation result: ${ex.message}")
        }
    }

    public func pushContextPass(sessionId: String, from: String, to: String, context: AgentContext): Unit {
        try {
            var map = HashMap<String, JsonValue>()
            map.add("from", JsonString(from))
            map.add("to", JsonString(to))
            map.add("task_id", JsonString(context.taskId))
            let payload = JsonObject(map)
            _sendFunc(sessionId, "context_pass", payload)
            LogUtils.info("[IncrementalResultPusher] Pushed context pass from '${from}' to '${to}' for session '${sessionId}'")
        } catch (ex: Exception) {
            LogUtils.error("[IncrementalResultPusher] Failed to push context pass: ${ex.message}")
        }
    }

    public func broadcastIncrementalResult(stepName: String, statusStr: String, output: Option<JsonValue>, durationMs: Int64): Unit {
        try {
            var map = HashMap<String, JsonValue>()
            map.add("step_name", JsonString(stepName))
            map.add("status", JsonString(statusStr))
            if (let Some(out) <- output) {
                map.add("output", out)
            }
            map.add("duration_ms", JsonInt(durationMs))
            let payload = JsonObject(map)
            _broadcastFunc("incremental_result", payload)
            LogUtils.info("[IncrementalResultPusher] Broadcast incremental result for step '${stepName}'")
        } catch (ex: Exception) {
            LogUtils.error("[IncrementalResultPusher] Failed to broadcast incremental result: ${ex.message}")
        }
    }
}
