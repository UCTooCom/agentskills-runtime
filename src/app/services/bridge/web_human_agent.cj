/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.agent.HumanAgent
import magic.agent.base.BaseAgent
import magic.core.agent.{AgentRequest, AgentResponse, AgentResponseStatus}
import magic.core.model.ChatModel
import magic.app.models.uctoo.AgentApprovalsPO
import magic.app.services.uctoo.AgentApprovalsService

import magic.log.LogUtils
import f_util.UUID
import std.time.DateTime

public class WebHumanAgent <: BaseAgent {
    private let _sessionId: String
    private let _defaultTimeoutMs: Int64
    private let _approvalType: String
    private let _approvalsService: AgentApprovalsService

    public init(
        sessionId: String,
        timeoutMs!: Int64 = 300000,
        approvalType!: String = "confirm",
        name!: String = "Web Human Agent",
        description!: String = "Human agent that interacts via WebSocket with approval persistence"
    ) {
        super (
            model: unsafe { zeroValue<ChatModel>() },
            name: name,
            description: description
        )
        this._sessionId = sessionId
        this._defaultTimeoutMs = timeoutMs
        this._approvalType = approvalType
        this._approvalsService = AgentApprovalsService()
    }

    override public func chat(request: AgentRequest): AgentResponse {
        let approvalId = UUID.random().toString()
        let question = request.question

        let approval = AgentApprovalsPO()
        approval.id = approvalId
        approval.agentId = this.name
        approval.taskId = ""
        approval.approvalType = _approvalType
        approval.content = question
        approval.status = "pending"
        approval.timeoutMs = _defaultTimeoutMs
        approval.creator = None<String>
        approval.createdAt = DateTime.now()
        approval.updatedAt = DateTime.now()
        approval.deletedAt = None<DateTime>

        try {
            let createResult = _approvalsService.create(approval, "system")
            if (!createResult.success) {
                let errorMsg = match (createResult.reason) {
                    case Some(msg) => msg
                    case None => "Unknown error"
                }
                LogUtils.error("WebHumanAgent: failed to create approval record: ${errorMsg}")
            }
        } catch (ex: Exception) {
            LogUtils.error("WebHumanAgent: error creating approval record: ${ex.message}")
        }

        let sessionManager = WebSocketSessionManager.instance
        let responseOpt = sessionManager.sendApprovalRequest(
            _sessionId,
            approvalId,
            question,
            _approvalType,
            _defaultTimeoutMs
        )

        match (responseOpt) {
            case Some(userResponse) =>
                approval.status = "approved"
                approval.userResponse = Some(userResponse)
                approval.updatedAt = DateTime.now()

                try {
                    _approvalsService.update(approvalId, approval)
                } catch (ex: Exception) {
                    LogUtils.error("WebHumanAgent: error updating approval record: ${ex.message}")
                }

                return AgentResponse(AgentResponseStatus.Success, userResponse)
            case None =>
                approval.status = "timeout"
                approval.updatedAt = DateTime.now()

                try {
                    _approvalsService.update(approvalId, approval)
                } catch (ex: Exception) {
                    LogUtils.error("WebHumanAgent: error updating approval record on timeout: ${ex.message}")
                }

                return AgentResponse(AgentResponseStatus.Failed, "Approval request timed out after ${_defaultTimeoutMs}ms")
        }
    }

    public prop sessionId: String {
        get() { _sessionId }
    }

    public prop defaultTimeoutMs: Int64 {
        get() { _defaultTimeoutMs }
    }

    public prop approvalType: String {
        get() { _approvalType }
    }
}