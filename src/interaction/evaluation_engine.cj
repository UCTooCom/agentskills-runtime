/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat}
import magic.log.LogUtils

public class EvaluationEngine {
    private let _evidenceRecorder: ExecutionEvidenceRecorder

    public init() {
        _evidenceRecorder = ExecutionEvidenceRecorder()
    }

    public init(evidenceRecorder!: ExecutionEvidenceRecorder) {
        _evidenceRecorder = evidenceRecorder
    }

    public func evaluateSession(sessionId: String): EvaluationResult {
        let result = EvaluationResult()
        result.sessionId = sessionId
        result.evaluationType = "session"
        result.evaluatedAt = DateTime.now()

        let evidences = _evidenceRecorder.getSessionEvidences(sessionId)
        if (evidences.size > 0) {
            var completedCount: Int64 = 0
            var failedCount: Int64 = 0
            var totalDuration: Int64 = 0
            var totalSideEffects: Int64 = 0
            for (i in 0..evidences.size) {
                let e = evidences[i]
                if (isEvidenceCompleted(e.status)) { completedCount = completedCount + 1 }
                else if (isEvidenceFailed(e.status)) { failedCount = failedCount + 1 }
                totalDuration = totalDuration + e.durationMs
                totalSideEffects = totalSideEffects + Int64(e.sideEffects.size)
            }
            result.successRate = calculateSuccessRate(completedCount, failedCount)
            result.avgDurationMs = calculateAvgDuration(totalDuration, Int64(evidences.size))
            result.sideEffectCount = totalSideEffects
        }

        LogUtils.info("[EvaluationEngine] Evaluating session: ${sessionId}, successRate=${result.successRate.toString()}")
        return result
    }

    public func evaluateAgent(agentId: String, timeRangeStart: DateTime, timeRangeEnd: DateTime): EvaluationResult {
        let result = EvaluationResult()
        result.agentId = agentId
        result.evaluationType = "agent"
        result.timeRangeStart = timeRangeStart
        result.timeRangeEnd = timeRangeEnd
        result.evaluatedAt = DateTime.now()

        let allEvidences = _evidenceRecorder.getAllEvidences()
        var completedCount: Int64 = 0
        var failedCount: Int64 = 0
        var totalDuration: Int64 = 0
        var totalSideEffects: Int64 = 0
        for (i in 0..allEvidences.size) {
            let e = allEvidences[i]
            if (e.agentName == agentId) {
                let inRange = matchTimeRange(e, timeRangeStart, timeRangeEnd)
                if (inRange) {
                    if (isEvidenceCompleted(e.status)) { completedCount = completedCount + 1 }
                    else if (isEvidenceFailed(e.status)) { failedCount = failedCount + 1 }
                    totalDuration = totalDuration + e.durationMs
                    totalSideEffects = totalSideEffects + Int64(e.sideEffects.size)
                }
            }
        }
        let totalCount = completedCount + failedCount
        if (totalCount > 0) {
            result.successRate = calculateSuccessRate(completedCount, failedCount)
            result.avgDurationMs = calculateAvgDuration(totalDuration, totalCount)
            result.sideEffectCount = totalSideEffects
        }

        LogUtils.info("[EvaluationEngine] Evaluating agent: ${agentId}, successRate=${result.successRate.toString()}")
        return result
    }

    public func evaluateAll(timeRangeStart: DateTime, timeRangeEnd: DateTime): ArrayList<EvaluationResult> {
        let results = ArrayList<EvaluationResult>()
        let allEvidences = _evidenceRecorder.getAllEvidences()
        var agentNames = ArrayList<String>()
        for (i in 0..allEvidences.size) {
            let name = allEvidences[i].agentName
            var found = false
            for (j in 0..agentNames.size) {
                if (agentNames[j] == name) { found = true; break }
            }
            if (!found) { agentNames.add(name) }
        }
        for (i in 0..agentNames.size) {
            results.add(evaluateAgent(agentNames[i], timeRangeStart, timeRangeEnd))
        }
        LogUtils.info("[EvaluationEngine] Evaluated ${results.size.toString()} agents from ${timeRangeStart.toString()} to ${timeRangeEnd.toString()}")
        return results
    }

    public func calculateSuccessRate(completedCount: Int64, failedCount: Int64): Float64 {
        let total = completedCount + failedCount
        if (total == 0) {
            return 0.0
        }
        return Float64(completedCount) / Float64(total)
    }

    public func calculateAvgDuration(totalDurationMs: Int64, count: Int64): Int64 {
        if (count == 0) {
            return 0
        }
        return totalDurationMs / count
    }

    private func isEvidenceCompleted(status: EvidenceStatus): Bool {
        match (status) {
            case EvidenceStatus.Completed => true
            case _ => false
        }
    }

    private func isEvidenceFailed(status: EvidenceStatus): Bool {
        match (status) {
            case EvidenceStatus.Failed => true
            case _ => false
        }
    }

    private func matchTimeRange(e: ExecutionEvidence, start: DateTime, end: DateTime): Bool {
        if (let Some(sa) <- e.startedAt) {
            if (sa >= start && sa <= end) { return true }
        }
        false
    }
}

public class EvaluationResult {
    public var agentId: String = ""
    public var sessionId: String = ""
    public var evaluationType: String = "session"
    public var successRate: Float64 = 0.0
    public var avgDurationMs: Int64 = 0
    public var promptTokens: Int64 = 0
    public var completionTokens: Int64 = 0
    public var totalTokens: Int64 = 0
    public var toolCallCount: Int64 = 0
    public var sideEffectCount: Int64 = 0
    public var timeRangeStart: DateTime = DateTime.now()
    public var timeRangeEnd: DateTime = DateTime.now()
    public var evaluatedAt: DateTime = DateTime.now()
    public var metricsDetail: HashMap<String, JsonValue> = HashMap<String, JsonValue>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("agent_id", JsonString(this.agentId))
        map.add("session_id", JsonString(this.sessionId))
        map.add("evaluation_type", JsonString(this.evaluationType))
        map.add("success_rate", JsonFloat(this.successRate))
        map.add("avg_duration_ms", JsonInt(this.avgDurationMs))
        map.add("prompt_tokens", JsonInt(this.promptTokens))
        map.add("completion_tokens", JsonInt(this.completionTokens))
        map.add("total_tokens", JsonInt(this.totalTokens))
        map.add("tool_call_count", JsonInt(this.toolCallCount))
        map.add("side_effect_count", JsonInt(this.sideEffectCount))
        map.add("evaluated_at", JsonString(this.evaluatedAt.toString()))
        return JsonObject(map)
    }
}
