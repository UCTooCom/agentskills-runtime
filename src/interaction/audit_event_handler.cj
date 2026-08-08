/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import magic.log.LogUtils

public class AuditEventHandler {
    private let _evidenceRecorder: ExecutionEvidenceRecorder
    private let _sideEffectTracker: SideEffectTracker
    private let _hashChain: AuditHashChain
    private let _verificationCollector: VerificationEvidenceCollector
    private var _activeSessions: HashMap<String, String>

    public init() {
        _evidenceRecorder = ExecutionEvidenceRecorder()
        _sideEffectTracker = SideEffectTracker()
        _hashChain = AuditHashChain()
        _verificationCollector = VerificationEvidenceCollector()
        _activeSessions = HashMap<String, String>()
    }

    public func onAgentStart(agentName: String, sessionId: String, input: Option<JsonValue>): String {
        let evidenceId = _evidenceRecorder.recordStart(
            sessionId,
            agentName,
            "agent_execution",
            EvidenceType.AgentExecution,
            input
        )

        _activeSessions.add(agentName, evidenceId)
        _hashChain.append(evidenceId, "agent_start:${agentName}:${sessionId}")

        LogUtils.info("[AuditEventHandler] Agent started: ${agentName}, evidence: ${evidenceId}")
        return evidenceId
    }

    public func onAgentEnd(agentName: String, output: Option<JsonValue>): Unit {
        if (let Some(evidenceId) <- _activeSessions.get(agentName)) {
            _evidenceRecorder.recordEnd(evidenceId, output)
            _hashChain.append("${evidenceId}_end", "agent_end:${agentName}")

            if (let Some(out) <- output) {
                _sideEffectTracker.trackApiCall(evidenceId, "agent://${agentName}", None, Some(out))
            }

            _activeSessions.remove(agentName)
            LogUtils.info("[AuditEventHandler] Agent ended: ${agentName}")
        }
    }

    public func onAgentError(agentName: String, errorMessage: String): Unit {
        if (let Some(evidenceId) <- _activeSessions.get(agentName)) {
            _evidenceRecorder.recordError(evidenceId, errorMessage)
            _hashChain.append("${evidenceId}_error", "agent_error:${agentName}:${errorMessage}")

            _activeSessions.remove(agentName)
            LogUtils.error("[AuditEventHandler] Agent error: ${agentName}, error: ${errorMessage}")
        }
    }

    public func onToolCall(agentName: String, toolName: String, args: Option<JsonValue>, result: Option<JsonValue>): Unit {
        if (let Some(evidenceId) <- _activeSessions.get(agentName)) {
            _evidenceRecorder.addMetadata(evidenceId, "tool_call", toolName)
            _sideEffectTracker.trackApiCall(evidenceId, "tool://${toolName}", args, result)
            LogUtils.info("[AuditEventHandler] Tool call: ${toolName} by ${agentName}")
        }
    }

    public func onFileWrite(agentName: String, filePath: String, content: String, beforeContent: Option<String>): Unit {
        if (let Some(evidenceId) <- _activeSessions.get(agentName)) {
            _sideEffectTracker.trackFileWrite(evidenceId, filePath, content, beforeContent)
            LogUtils.info("[AuditEventHandler] File write: ${filePath} by ${agentName}")
        }
    }

    public func onDbChange(agentName: String, tableName: String, recordId: String, operation: String, beforeData: Option<JsonValue>, afterData: Option<JsonValue>): Unit {
        if (let Some(evidenceId) <- _activeSessions.get(agentName)) {
            match (operation) {
                case "insert" => _sideEffectTracker.trackDbInsert(evidenceId, tableName, recordId, afterData)
                case "update" => _sideEffectTracker.trackDbUpdate(evidenceId, tableName, recordId, beforeData, afterData)
                case "delete" => _sideEffectTracker.trackDbDelete(evidenceId, tableName, recordId, beforeData)
                case _ => _sideEffectTracker.trackApiCall(evidenceId, "db://${tableName}/${operation}", beforeData, afterData)
            }
            LogUtils.info("[AuditEventHandler] DB change: ${operation} ${tableName}/${recordId} by ${agentName}")
        }
    }

    public func onVerification(sessionId: String, verificationType: String, target: String, passed: Bool, output: String, errorCount: Int64, durationMs: Int64): Unit {
        match (verificationType) {
            case "build" => _verificationCollector.recordBuild(sessionId, target, output, errorCount, durationMs)
            case "lint" => _verificationCollector.recordLint(sessionId, target, output, errorCount, 0, durationMs)
            case "test" => _verificationCollector.recordTest(sessionId, target, output, passed, errorCount, durationMs)
            case "business_rule" => _verificationCollector.recordBusinessRule(sessionId, target, "rule_check", passed, output)
            case _ => _verificationCollector.recordBuild(sessionId, target, output, errorCount, durationMs)
        }
    }

    public func onTeamMessage(fromAgent: String, toAgent: String, messageType: String, content: String): Unit {
        if (let Some(evidenceId) <- _activeSessions.get(fromAgent)) {
            _evidenceRecorder.addMetadata(evidenceId, "team_msg_${messageType}", "${fromAgent}->${toAgent}: ${content}")
        }
    }

    public func getEvidenceRecorder(): ExecutionEvidenceRecorder {
        return _evidenceRecorder
    }

    public func getSideEffectTracker(): SideEffectTracker {
        return _sideEffectTracker
    }

    public func getHashChain(): AuditHashChain {
        return _hashChain
    }

    public func getVerificationCollector(): VerificationEvidenceCollector {
        return _verificationCollector
    }

    public func verifySessionIntegrity(sessionId: String): Option<Bool> {
        return _evidenceRecorder.verifyIntegrity(sessionId)
    }

    public func getSessionEvidences(sessionId: String): ArrayList<ExecutionEvidence> {
        return _evidenceRecorder.getSessionEvidences(sessionId)
    }

    public func getSessionVerificationSummary(sessionId: String): SessionVerificationSummary {
        return _verificationCollector.getSessionSummary(sessionId)
    }
}