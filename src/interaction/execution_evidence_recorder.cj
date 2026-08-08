/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool}
import magic.log.LogUtils

public enum EvidenceType {
    | AgentExecution
    | ToolCall
    | SkillExecution
    | TeamMessage
    | ConditionEvaluation
}

public enum EvidenceStatus {
    | Started
    | Completed
    | Failed
    | Skipped
}

public struct SideEffect {
    public let effectType: String
    public let target: String
    public let description: String
    public let timestamp: DateTime

    public init(effectType!: String, target!: String, description!: String) {
        this.effectType = effectType
        this.target = target
        this.description = description
        this.timestamp = DateTime.now()
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("effect_type", JsonString(this.effectType))
        map.add("target", JsonString(this.target))
        map.add("description", JsonString(this.description))
        map.add("timestamp", JsonString(this.timestamp.toString()))
        return JsonObject(map)
    }
}

public class ExecutionEvidence {
    public var id: String = ""
    public var sessionId: String = ""
    public var parentEvidenceId: Option<String> = None<String>
    public var evidenceType: EvidenceType = EvidenceType.AgentExecution
    public var status: EvidenceStatus = EvidenceStatus.Started
    public var agentName: String = ""
    public var stepName: String = ""
    public var input: Option<JsonValue> = None<JsonValue>
    public var output: Option<JsonValue> = None<JsonValue>
    public var errorMessage: Option<String> = None<String>
    public var durationMs: Int64 = 0
    public var sideEffects: ArrayList<SideEffect> = ArrayList<SideEffect>()
    public var previousHash: Option<String> = None<String>
    public var currentHash: Option<String> = None<String>
    public var startedAt: Option<DateTime> = None<DateTime>
    public var completedAt: Option<DateTime> = None<DateTime>
    public var metadata: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", JsonString(this.id))
        map.add("session_id", JsonString(this.sessionId))
        if (let Some(pid) <- this.parentEvidenceId) {
            map.add("parent_evidence_id", JsonString(pid))
        }
        map.add("evidence_type", JsonString(evidenceTypeToString(this.evidenceType)))
        map.add("status", JsonString(evidenceStatusToString(this.status)))
        map.add("agent_name", JsonString(this.agentName))
        map.add("step_name", JsonString(this.stepName))
        if (let Some(inp) <- this.input) {
            map.add("input", inp)
        }
        if (let Some(out) <- this.output) {
            map.add("output", out)
        }
        if (let Some(err) <- this.errorMessage) {
            map.add("error_message", JsonString(err))
        }
        map.add("duration_ms", JsonInt(this.durationMs))
        let effectsArr = JsonArray()
        for (e in this.sideEffects) {
            effectsArr.add(e.toJsonValue())
        }
        map.add("side_effects", effectsArr)
        if (let Some(ph) <- this.previousHash) {
            map.add("previous_hash", JsonString(ph))
        }
        if (let Some(ch) <- this.currentHash) {
            map.add("current_hash", JsonString(ch))
        }
        if (let Some(sa) <- this.startedAt) {
            map.add("started_at", JsonString(sa.toString()))
        }
        if (let Some(ca) <- this.completedAt) {
            map.add("completed_at", JsonString(ca.toString()))
        }
        var metaMap = HashMap<String, JsonValue>()
        for ((k, v) in this.metadata) {
            metaMap.add(k, JsonString(v))
        }
        map.add("metadata", JsonObject(metaMap))
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }

    public static func evidenceTypeToString(t: EvidenceType): String {
        match (t) {
            case EvidenceType.AgentExecution => "agent_execution"
            case EvidenceType.ToolCall => "tool_call"
            case EvidenceType.SkillExecution => "skill_execution"
            case EvidenceType.TeamMessage => "team_message"
            case EvidenceType.ConditionEvaluation => "condition_evaluation"
        }
    }

    public static func evidenceStatusToString(s: EvidenceStatus): String {
        match (s) {
            case EvidenceStatus.Started => "started"
            case EvidenceStatus.Completed => "completed"
            case EvidenceStatus.Failed => "failed"
            case EvidenceStatus.Skipped => "skipped"
        }
    }
}

public class ExecutionEvidenceRecorder {
    private var _evidences: HashMap<String, ExecutionEvidence>
    private var _sessionEvidences: HashMap<String, ArrayList<String>>
    private var _activeEvidences: HashMap<String, ExecutionEvidence>
    private var _lastHash: Option<String>

    public init() {
        _evidences = HashMap<String, ExecutionEvidence>()
        _sessionEvidences = HashMap<String, ArrayList<String>>()
        _activeEvidences = HashMap<String, ExecutionEvidence>()
        _lastHash = None<String>
    }

    public func recordStart(sessionId: String, agentName: String, stepName: String, evidenceType: EvidenceType, input: Option<JsonValue>): String {
        let evidenceId = generateEvidenceId()
        let evidence = ExecutionEvidence()
        evidence.id = evidenceId
        evidence.sessionId = sessionId
        evidence.evidenceType = evidenceType
        evidence.status = EvidenceStatus.Started
        evidence.agentName = agentName
        evidence.stepName = stepName
        evidence.input = input
        evidence.startedAt = Some(DateTime.now())
        evidence.previousHash = _lastHash

        _evidences.add(evidenceId, evidence)
        _activeEvidences.add(evidenceId, evidence)

        if (!_sessionEvidences.contains(sessionId)) {
            _sessionEvidences.add(sessionId, ArrayList<String>())
        }
        if (let Some(list) <- _sessionEvidences.get(sessionId)) {
            list.add(evidenceId)
        }

        LogUtils.info("[ExecutionEvidenceRecorder] Recorded start: ${agentName}/${stepName} (${evidenceId})")
        return evidenceId
    }

    public func recordEnd(evidenceId: String, output: Option<JsonValue>): Unit {
        if (let Some(evidence) <- _activeEvidences.get(evidenceId)) {
            evidence.status = EvidenceStatus.Completed
            evidence.output = output
            evidence.completedAt = Some(DateTime.now())

            if (let Some(startedAt) <- evidence.startedAt) {
                evidence.durationMs = (DateTime.now() - startedAt).toMilliseconds()
            }

            let hash = computeHash(evidence)
            evidence.currentHash = Some(hash)
            _lastHash = Some(hash)

            _activeEvidences.remove(evidenceId)
            LogUtils.info("[ExecutionEvidenceRecorder] Recorded end: ${evidenceId}, duration: ${evidence.durationMs.toString()}ms")
        } else {
            LogUtils.warn("[ExecutionEvidenceRecorder] No active evidence found for id: ${evidenceId}")
        }
    }

    public func recordError(evidenceId: String, errorMessage: String): Unit {
        if (let Some(evidence) <- _activeEvidences.get(evidenceId)) {
            evidence.status = EvidenceStatus.Failed
            evidence.errorMessage = Some(errorMessage)
            evidence.completedAt = Some(DateTime.now())

            if (let Some(startedAt) <- evidence.startedAt) {
                evidence.durationMs = (DateTime.now() - startedAt).toMilliseconds()
            }

            let hash = computeHash(evidence)
            evidence.currentHash = Some(hash)
            _lastHash = Some(hash)

            _activeEvidences.remove(evidenceId)
            LogUtils.error("[ExecutionEvidenceRecorder] Recorded error: ${evidenceId}, error: ${errorMessage}")
        }
    }

    public func addSideEffect(evidenceId: String, effect: SideEffect): Unit {
        if (let Some(evidence) <- _evidences.get(evidenceId)) {
            evidence.sideEffects.add(effect)
        }
    }

    public func addMetadata(evidenceId: String, key: String, value: String): Unit {
        if (let Some(evidence) <- _evidences.get(evidenceId)) {
            evidence.metadata.add(key, value)
        }
    }

    public func setParentEvidence(evidenceId: String, parentId: String): Unit {
        if (let Some(evidence) <- _evidences.get(evidenceId)) {
            evidence.parentEvidenceId = Some(parentId)
        }
    }

    public func getEvidence(evidenceId: String): Option<ExecutionEvidence> {
        return _evidences.get(evidenceId)
    }

    public func getSessionEvidences(sessionId: String): ArrayList<ExecutionEvidence> {
        let result = ArrayList<ExecutionEvidence>()
        if (let Some(ids) <- _sessionEvidences.get(sessionId)) {
            for (id in ids) {
                if (let Some(evidence) <- _evidences.get(id)) {
                    result.add(evidence)
                }
            }
        }
        return result
    }

    public func getEvidenceChain(sessionId: String): ArrayList<ExecutionEvidence> {
        let evidences = getSessionEvidences(sessionId)
        let sorted = ArrayList<ExecutionEvidence>()
        let byParent = HashMap<String, ArrayList<ExecutionEvidence>>()
        var root: Option<ExecutionEvidence> = None<ExecutionEvidence>

        for (e in evidences) {
            if (e.parentEvidenceId.isNone()) {
                root = Some(e)
            } else {
                let parentId = e.parentEvidenceId.getOrThrow()
                if (!byParent.contains(parentId)) {
                    byParent.add(parentId, ArrayList<ExecutionEvidence>())
                }
                if (let Some(children) <- byParent.get(parentId)) {
                    children.add(e)
                }
            }
        }

        if (root.isSome()) {
            buildChain(root.getOrThrow(), byParent, sorted)
        } else {
            for (e in evidences) {
                sorted.add(e)
            }
        }
        return sorted
    }

    public func verifyIntegrity(sessionId: String): Option<Bool> {
        let evidences = getSessionEvidences(sessionId)
        if (evidences.isEmpty()) {
            return None
        }

        for (i in 0..evidences.size) {
            let evidence = evidences[i]
            if (evidence.currentHash.isNone()) {
                continue
            }
            let expectedHash = computeHash(evidence)
            let currentHash = evidence.currentHash.getOrThrow()
            if (currentHash != expectedHash) {
                LogUtils.error("[ExecutionEvidenceRecorder] Integrity check failed for evidence: ${evidence.id}")
                return Some(false)
            }

            if (i > 0) {
                let prevEvidence = evidences[i - 1]
                if (let Some(prevHash) <- prevEvidence.currentHash) {
                    if (let Some(evidencePrevHash) <- evidence.previousHash) {
                        if (evidencePrevHash != prevHash) {
                            LogUtils.error("[ExecutionEvidenceRecorder] Hash chain broken at evidence: ${evidence.id}")
                            return Some(false)
                        }
                    }
                }
            }
        }
        return Some(true)
    }

    public func getActiveEvidenceCount(): Int64 {
        var count: Int64 = 0
        for (_ in _activeEvidences) {
            count = count + 1
        }
        return count
    }

    public func getAllEvidences(): ArrayList<ExecutionEvidence> {
        let result = ArrayList<ExecutionEvidence>()
        for ((_, evidence) in _evidences) {
            result.add(evidence)
        }
        return result
    }

    public func clear(): Unit {
        _evidences.clear()
        _sessionEvidences.clear()
        _activeEvidences.clear()
        _lastHash = None<String>
    }

    private func buildChain(
        current: ExecutionEvidence,
        byParent: HashMap<String, ArrayList<ExecutionEvidence>>,
        result: ArrayList<ExecutionEvidence>
    ): Unit {
        result.add(current)
        if (let Some(children) <- byParent.get(current.id)) {
            for (child in children) {
                buildChain(child, byParent, result)
            }
        }
    }

    private func computeHash(evidence: ExecutionEvidence): String {
        var content = evidence.id + evidence.sessionId + evidence.agentName + evidence.stepName
        content = content + ExecutionEvidence.evidenceTypeToString(evidence.evidenceType)
        content = content + ExecutionEvidence.evidenceStatusToString(evidence.status)
        content = content + evidence.durationMs.toString()
        if (let Some(err) <- evidence.errorMessage) {
            content = content + err
        }
        if (let Some(ph) <- evidence.previousHash) {
            content = content + ph
        }
        return content.hashCode().toString()
    }

    private func generateEvidenceId(): String {
        let timestamp = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        return "ev_${timestamp.toString()}_${_evidences.size.toString()}"
    }
}