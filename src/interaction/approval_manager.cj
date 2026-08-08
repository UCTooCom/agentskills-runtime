/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonNull, JsonArray, JsonFloat}
import magic.log.LogUtils

public enum ApprovalStatus {
    | Pending | Approved | Rejected | Timeout | Cancelled
}

public enum ApprovalType {
    | HighRiskOperation | DataDeletion | SystemConfig | ResourceIntensive | RollbackOperation | Custom
}

public class ApprovalConfig {
    public var enabled: Bool = true
    public var defaultTimeoutMs: Int64 = 300000
    public var timeoutAction: ApprovalStatus = ApprovalStatus.Rejected
    public var autoApproveLowRisk: Bool = false
    public var highRiskTypes: ArrayList<String> = ArrayList<String>()
    public var approvalNeededMark: String = "approval_needed"

    public init() {
        highRiskTypes.add("high_risk_operation")
        highRiskTypes.add("data_deletion")
        highRiskTypes.add("system_config")
        highRiskTypes.add("rollback_operation")
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("enabled", JsonBool(this.enabled))
        map.add("default_timeout_ms", JsonInt(this.defaultTimeoutMs))
        map.add("auto_approve_low_risk", JsonBool(this.autoApproveLowRisk))
        JsonObject(map)
    }
}

public class ApprovalRequest {
    public var agentId: String = ""
    public var taskId: String = ""
    public var approvalType: ApprovalType = ApprovalType.HighRiskOperation
    public var content: String = ""
    public var timeoutMs: Int64 = 300000
    public var metadata: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("agent_id", JsonString(this.agentId))
        map.add("task_id", JsonString(this.taskId))
        map.add("approval_type", JsonString(approvalTypeToString(this.approvalType)))
        map.add("content", JsonString(this.content))
        map.add("timeout_ms", JsonInt(this.timeoutMs))
        var metaMap = HashMap<String, JsonValue>()
        for ((k, v) in this.metadata) {
            metaMap.add(k, JsonString(v))
        }
        map.add("metadata", JsonObject(metaMap))
        JsonObject(map)
    }

    public static func approvalTypeToString(t: ApprovalType): String {
        match (t) {
            case ApprovalType.HighRiskOperation => "high_risk_operation"
            case ApprovalType.DataDeletion => "data_deletion"
            case ApprovalType.SystemConfig => "system_config"
            case ApprovalType.ResourceIntensive => "resource_intensive"
            case ApprovalType.RollbackOperation => "rollback_operation"
            case ApprovalType.Custom => "custom"
        }
    }

    public static func parseApprovalType(s: String): ApprovalType {
        match (s) {
            case "high_risk_operation" => ApprovalType.HighRiskOperation
            case "data_deletion" => ApprovalType.DataDeletion
            case "system_config" => ApprovalType.SystemConfig
            case "resource_intensive" => ApprovalType.ResourceIntensive
            case "rollback_operation" => ApprovalType.RollbackOperation
            case _ => ApprovalType.Custom
        }
    }
}

public class ApprovalResult {
    public var approvalId: String = ""
    public var status: ApprovalStatus = ApprovalStatus.Pending
    public var userResponse: Option<String> = None<String>
    public var reviewedAt: Option<DateTime> = None<DateTime>

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("approval_id", JsonString(this.approvalId))
        map.add("status", JsonString(approvalStatusToString(this.status)))
        if (let Some(ur) <- this.userResponse) {
            map.add("user_response", JsonString(ur))
        }
        if (let Some(ra) <- this.reviewedAt) {
            map.add("reviewed_at", JsonString(ra.toString()))
        }
        JsonObject(map)
    }

    public static func approvalStatusToString(s: ApprovalStatus): String {
        match (s) {
            case ApprovalStatus.Pending => "pending"
            case ApprovalStatus.Approved => "approved"
            case ApprovalStatus.Rejected => "rejected"
            case ApprovalStatus.Timeout => "timeout"
            case ApprovalStatus.Cancelled => "cancelled"
        }
    }

    public static func parseApprovalStatus(s: String): ApprovalStatus {
        match (s) {
            case "pending" => ApprovalStatus.Pending
            case "approved" => ApprovalStatus.Approved
            case "rejected" => ApprovalStatus.Rejected
            case "timeout" => ApprovalStatus.Timeout
            case "cancelled" => ApprovalStatus.Cancelled
            case _ => ApprovalStatus.Pending
        }
    }
}

public class ApprovalManager {
    private let _config: ApprovalConfig
    private let _createApproval: (String, String, String, String, Int64) -> String
    private let _updateApprovalStatus: (String, String, Option<String>) -> Bool
    private let _getApproval: (String) -> Option<ApprovalRecord>
    private let _getApprovalsByFilter: (String, String) -> ArrayList<ApprovalRecord>
    private var _pendingTimers: HashMap<String, DateTime>

    public init(config!: ApprovalConfig, createApproval!: (String, String, String, String, Int64) -> String, updateApprovalStatus!: (String, String, Option<String>) -> Bool, getApproval!: (String) -> Option<ApprovalRecord>, getApprovalsByFilter!: (String, String) -> ArrayList<ApprovalRecord>) {
        _config = config
        _createApproval = createApproval
        _updateApprovalStatus = updateApprovalStatus
        _getApproval = getApproval
        _getApprovalsByFilter = getApprovalsByFilter
        _pendingTimers = HashMap<String, DateTime>()
    }

    public func requestApproval(request: ApprovalRequest): Option<ApprovalResult> {
        if (!_config.enabled) {
            LogUtils.info("[ApprovalManager] Approval disabled, auto-approving")
            let result = ApprovalResult()
            result.approvalId = ""
            result.status = ApprovalStatus.Approved
            result.reviewedAt = Some(DateTime.now())
            return Some(result)
        }

        let typeStr = ApprovalRequest.approvalTypeToString(request.approvalType)
        let approvalId = _createApproval(request.agentId, request.taskId, typeStr, request.content, request.timeoutMs)

        if (approvalId.size == 0) {
            LogUtils.error("[ApprovalManager] Failed to create approval record")
            return None<ApprovalResult>
        }

        _pendingTimers.add(approvalId, DateTime.now())

        let result = ApprovalResult()
        result.approvalId = approvalId
        result.status = ApprovalStatus.Pending
        LogUtils.info("[ApprovalManager] Approval requested: id=${approvalId}, type=${typeStr}")
        return Some(result)
    }

    public func checkApprovalNeeded(stepName: String, stepConfig: Option<JsonValue>): Bool {
        if (!_config.enabled) { return false }
        if (let Some(cfg) <- stepConfig) {
            if (cfg is JsonObject) {
                let obj = cfg.asObject()
                if (let Some(val) <- obj.get("approval_needed")) {
                    if (val is JsonBool) { return val.asBool().getValue() }
                    if (val is JsonString) { return val.asString().getValue() == "true" }
                }
                if (let Some(val) <- obj.get("risk_level")) {
                    if (val is JsonString) {
                        let risk = val.asString().getValue()
                        return risk == "high" || risk == "critical"
                    }
                }
            }
        }
        false
    }

    public func approve(approvalId: String, userResponse: Option<String>): Option<ApprovalResult> {
        let success = _updateApprovalStatus(approvalId, "approved", userResponse)
        if (!success) {
            LogUtils.error("[ApprovalManager] Failed to approve: ${approvalId}")
            return None<ApprovalResult>
        }
        _pendingTimers.remove(approvalId)
        let result = ApprovalResult()
        result.approvalId = approvalId
        result.status = ApprovalStatus.Approved
        result.userResponse = userResponse
        result.reviewedAt = Some(DateTime.now())
        LogUtils.info("[ApprovalManager] Approved: ${approvalId}")
        return Some(result)
    }

    public func reject(approvalId: String, reason: Option<String>): Option<ApprovalResult> {
        let success = _updateApprovalStatus(approvalId, "rejected", reason)
        if (!success) {
            LogUtils.error("[ApprovalManager] Failed to reject: ${approvalId}")
            return None<ApprovalResult>
        }
        _pendingTimers.remove(approvalId)
        let result = ApprovalResult()
        result.approvalId = approvalId
        result.status = ApprovalStatus.Rejected
        result.userResponse = reason
        result.reviewedAt = Some(DateTime.now())
        LogUtils.info("[ApprovalManager] Rejected: ${approvalId}")
        return Some(result)
    }

    public func handleTimeout(approvalId: String): Option<ApprovalResult> {
        let statusStr = ApprovalResult.approvalStatusToString(_config.timeoutAction)
        let success = _updateApprovalStatus(approvalId, statusStr, Some("timeout"))
        if (!success) { return None<ApprovalResult> }
        _pendingTimers.remove(approvalId)
        let result = ApprovalResult()
        result.approvalId = approvalId
        result.status = _config.timeoutAction
        result.reviewedAt = Some(DateTime.now())
        LogUtils.info("[ApprovalManager] Timeout handled: ${approvalId}, action=${statusStr}")
        return Some(result)
    }

    public func getApproval(approvalId: String): Option<ApprovalRecord> {
        _getApproval(approvalId)
    }

    public func getPendingApprovals(agentId: String): ArrayList<ApprovalRecord> {
        _getApprovalsByFilter(agentId, "pending")
    }

    public func getApprovalHistory(taskId: String): ArrayList<ApprovalRecord> {
        _getApprovalsByFilter("", taskId)
    }

    public func checkTimeouts(): ArrayList<ApprovalResult> {
        let results = ArrayList<ApprovalResult>()
        let now = DateTime.now()
        var expiredIds = ArrayList<String>()
        for ((approvalId, createdAt) in _pendingTimers) {
            let recordOpt = _getApproval(approvalId)
            if (let Some(record) <- recordOpt) {
                let elapsed = (now - createdAt).toMilliseconds()
                if (elapsed > record.timeoutMs * 1000) {
                    if (let Some(r) <- handleTimeout(approvalId)) {
                        results.add(r)
                    }
                    expiredIds.add(approvalId)
                }
            } else {
                expiredIds.add(approvalId)
            }
        }
        for (id in expiredIds) {
            _pendingTimers.remove(id)
        }
        results
    }
}

public class ApprovalRecord {
    public var id: String = ""
    public var agentId: String = ""
    public var taskId: String = ""
    public var approvalType: String = ""
    public var content: String = ""
    public var status: String = "pending"
    public var userResponse: Option<String> = None<String>
    public var timeoutMs: Int64 = 300000
    public var createdAt: DateTime = DateTime.now()

    public init() {}
}