/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool}
import magic.log.LogUtils

public enum VerificationType {
    | Build
    | Lint
    | Test
    | BusinessRule
}

public enum VerificationStatus {
    | Passed
    | Failed
    | Skipped
    | Error
}

public class VerificationEvidence {
    public var id: String = ""
    public var sessionId: String = ""
    public var verificationType: VerificationType = VerificationType.Build
    public var status: VerificationStatus = VerificationStatus.Passed
    public var target: String = ""
    public var details: String = ""
    public var output: String = ""
    public var errorCount: Int64 = 0
    public var warningCount: Int64 = 0
    public var durationMs: Int64 = 0
    public var timestamp: DateTime = DateTime.now()
    public var metadata: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", JsonString(this.id))
        map.add("session_id", JsonString(this.sessionId))
        map.add("verification_type", JsonString(verificationTypeToString(this.verificationType)))
        map.add("status", JsonString(verificationStatusToString(this.status)))
        map.add("target", JsonString(this.target))
        map.add("details", JsonString(this.details))
        map.add("output", JsonString(this.output))
        map.add("error_count", JsonInt(this.errorCount))
        map.add("warning_count", JsonInt(this.warningCount))
        map.add("duration_ms", JsonInt(this.durationMs))
        map.add("timestamp", JsonString(this.timestamp.toString()))
        var metaMap = HashMap<String, JsonValue>()
        for ((k, v) in this.metadata) {
            metaMap.add(k, JsonString(v))
        }
        map.add("metadata", JsonObject(metaMap))
        return JsonObject(map)
    }

    public static func verificationTypeToString(t: VerificationType): String {
        match (t) {
            case VerificationType.Build => "build"
            case VerificationType.Lint => "lint"
            case VerificationType.Test => "test"
            case VerificationType.BusinessRule => "business_rule"
        }
    }

    public static func verificationStatusToString(s: VerificationStatus): String {
        match (s) {
            case VerificationStatus.Passed => "passed"
            case VerificationStatus.Failed => "failed"
            case VerificationStatus.Skipped => "skipped"
            case VerificationStatus.Error => "error"
        }
    }
}

public class SessionVerificationSummary {
    public var sessionId: String = ""
    public var totalVerifications: Int64 = 0
    public var passedCount: Int64 = 0
    public var failedCount: Int64 = 0
    public var skippedCount: Int64 = 0
    public var errorCount: Int64 = 0
    public var byType: HashMap<String, Int64> = HashMap<String, Int64>()
    public var overallStatus: VerificationStatus = VerificationStatus.Passed

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("session_id", JsonString(this.sessionId))
        map.add("total_verifications", JsonInt(this.totalVerifications))
        map.add("passed_count", JsonInt(this.passedCount))
        map.add("failed_count", JsonInt(this.failedCount))
        map.add("skipped_count", JsonInt(this.skippedCount))
        map.add("error_count", JsonInt(this.errorCount))
        var typeMap = HashMap<String, JsonValue>()
        for ((k, v) in this.byType) {
            typeMap.add(k, JsonInt(v))
        }
        map.add("by_type", JsonObject(typeMap))
        map.add("overall_status", JsonString(VerificationEvidence.verificationStatusToString(this.overallStatus)))
        return JsonObject(map)
    }
}

public class VerificationEvidenceCollector {
    private var _evidences: HashMap<String, VerificationEvidence>
    private var _sessionEvidences: HashMap<String, ArrayList<String>>
    private var _counter: Int64 = 0

    public init() {
        _evidences = HashMap<String, VerificationEvidence>()
        _sessionEvidences = HashMap<String, ArrayList<String>>()
    }

    public func recordBuild(sessionId: String, target: String, output: String, errorCount: Int64, durationMs: Int64): String {
        let status = if (errorCount > 0) { VerificationStatus.Failed } else { VerificationStatus.Passed }
        return record(sessionId, VerificationType.Build, status, target, "Build verification", output, errorCount, 0, durationMs)
    }

    public func recordLint(sessionId: String, target: String, output: String, errorCount: Int64, warningCount: Int64, durationMs: Int64): String {
        let status = if (errorCount > 0) { VerificationStatus.Failed } else { VerificationStatus.Passed }
        return record(sessionId, VerificationType.Lint, status, target, "Lint verification", output, errorCount, warningCount, durationMs)
    }

    public func recordTest(sessionId: String, target: String, output: String, passed: Bool, errorCount: Int64, durationMs: Int64): String {
        let status = if (passed) { VerificationStatus.Passed } else { VerificationStatus.Failed }
        return record(sessionId, VerificationType.Test, status, target, "Test verification", output, errorCount, 0, durationMs)
    }

    public func recordBusinessRule(sessionId: String, target: String, ruleName: String, passed: Bool, details: String): String {
        let status = if (passed) { VerificationStatus.Passed } else { VerificationStatus.Failed }
        return record(sessionId, VerificationType.BusinessRule, status, target, "Business rule: ${ruleName}", details, if (passed) { 0 } else { 1 }, 0, 0)
    }

    public func getSessionSummary(sessionId: String): SessionVerificationSummary {
        let summary = SessionVerificationSummary()
        summary.sessionId = sessionId

        if (let Some(ids) <- _sessionEvidences.get(sessionId)) {
            summary.totalVerifications = ids.size

            for (id in ids) {
                if (let Some(evidence) <- _evidences.get(id)) {
                    match (evidence.status) {
                        case VerificationStatus.Passed => summary.passedCount = summary.passedCount + 1
                        case VerificationStatus.Failed => summary.failedCount = summary.failedCount + 1
                        case VerificationStatus.Skipped => summary.skippedCount = summary.skippedCount + 1
                        case VerificationStatus.Error => summary.errorCount = summary.errorCount + 1
                    }

                    let typeKey = VerificationEvidence.verificationTypeToString(evidence.verificationType)
                    if (let Some(count) <- summary.byType.get(typeKey)) {
                        summary.byType.add(typeKey, count + 1)
                    } else {
                        summary.byType.add(typeKey, 1)
                    }
                }
            }
        }

        if (summary.failedCount > 0 || summary.errorCount > 0) {
            summary.overallStatus = VerificationStatus.Failed
        } else if (summary.passedCount == 0) {
            summary.overallStatus = VerificationStatus.Skipped
        } else {
            summary.overallStatus = VerificationStatus.Passed
        }

        return summary
    }

    public func getRepositorySummary(): SessionVerificationSummary {
        let summary = SessionVerificationSummary()
        summary.sessionId = "__repository__"

        for ((_, evidence) in _evidences) {
            summary.totalVerifications = summary.totalVerifications + 1
            match (evidence.status) {
                case VerificationStatus.Passed => summary.passedCount = summary.passedCount + 1
                case VerificationStatus.Failed => summary.failedCount = summary.failedCount + 1
                case VerificationStatus.Skipped => summary.skippedCount = summary.skippedCount + 1
                case VerificationStatus.Error => summary.errorCount = summary.errorCount + 1
            }

            let typeKey = VerificationEvidence.verificationTypeToString(evidence.verificationType)
            if (let Some(count) <- summary.byType.get(typeKey)) {
                summary.byType.add(typeKey, count + 1)
            } else {
                summary.byType.add(typeKey, 1)
            }
        }

        if (summary.failedCount > 0 || summary.errorCount > 0) {
            summary.overallStatus = VerificationStatus.Failed
        } else if (summary.passedCount == 0) {
            summary.overallStatus = VerificationStatus.Skipped
        } else {
            summary.overallStatus = VerificationStatus.Passed
        }

        return summary
    }

    public func getEvidence(evidenceId: String): Option<VerificationEvidence> {
        return _evidences.get(evidenceId)
    }

    public func getSessionEvidences(sessionId: String): ArrayList<VerificationEvidence> {
        let result = ArrayList<VerificationEvidence>()
        if (let Some(ids) <- _sessionEvidences.get(sessionId)) {
            for (id in ids) {
                if (let Some(evidence) <- _evidences.get(id)) {
                    result.add(evidence)
                }
            }
        }
        return result
    }

    public func clear(): Unit {
        _evidences.clear()
        _sessionEvidences.clear()
        _counter = 0
    }

    private func record(
        sessionId: String,
        verificationType: VerificationType,
        status: VerificationStatus,
        target: String,
        details: String,
        output: String,
        errorCount: Int64,
        warningCount: Int64,
        durationMs: Int64
    ): String {
        _counter = _counter + 1
        let id = "ve_${_counter.toString()}"

        let evidence = VerificationEvidence()
        evidence.id = id
        evidence.sessionId = sessionId
        evidence.verificationType = verificationType
        evidence.status = status
        evidence.target = target
        evidence.details = details
        evidence.output = output
        evidence.errorCount = errorCount
        evidence.warningCount = warningCount
        evidence.durationMs = durationMs
        evidence.timestamp = DateTime.now()

        _evidences.add(id, evidence)

        if (!_sessionEvidences.contains(sessionId)) {
            _sessionEvidences.add(sessionId, ArrayList<String>())
        }
        if (let Some(list) <- _sessionEvidences.get(sessionId)) {
            list.add(id)
        }

        LogUtils.info("[VerificationEvidenceCollector] Recorded: ${VerificationEvidence.verificationTypeToString(verificationType)} -> ${VerificationEvidence.verificationStatusToString(status)} (${target})")
        return id
    }
}