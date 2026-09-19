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

        // ── Ch13.2：从 request 读取可选方案并透传 ─────────────────────
        // 约定（design 2.6.2/2.6.3）：技能把 decision-point 的三元组随请求带入。
        // 三者都缺省时走原 yes/no 审批路径，行为与改造前一致。
        let options = WebHumanAgent.readRequestField(request, "options")
        let defaultOption = WebHumanAgent.readRequestField(request, "default")
        let recommended = WebHumanAgent.readRequestField(request, "recommended")

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
        // 落库：选项集与最终选择分开存，选项集用于事后复盘"当时给了哪些方案"
        if (!options.isEmpty()) {
            approval.options = Some(options)
        }
        approval.selectedOption = None<String>

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
            _defaultTimeoutMs,
            options,
            defaultOption,
            recommended
        )

        match (responseOpt) {
            case Some(userResponse) =>
                // 用户在时限内响应。按 Ch13.3「选择结果回灌」记下选中的选项 id。
                approval.status = "approved"
                approval.userResponse = Some(userResponse)
                let selected = WebHumanAgent.parseSelectedOption(userResponse)
                if (!selected.isEmpty()) {
                    approval.selectedOption = Some(selected)
                }
                approval.updatedAt = DateTime.now()

                try {
                    _approvalsService.update(approvalId, approval)
                } catch (ex: Exception) {
                    LogUtils.error("WebHumanAgent: error updating approval record: ${ex.message}")
                }

                return AgentResponse(AgentResponseStatus.Success, userResponse)
            case None =>
                // ── 超时分支（Ch13.2 关键改动）─────────────────────────
                // 改造前：超时直接 Failed —— 长程任务会因此挂死。
                // 改造后：若决策点声明了 default，则**自动采用 default 并继续**，
                //        记 decision_timeout_default_applied 日志 + 通知用户"已按默认方案 X 继续"。
                //        未声明 default 时保持原 Failed 语义（普通审批无兜底方案可言）。
                if (!defaultOption.isEmpty()) {
                    approval.status = "timeout"
                    approval.userResponse = Some(defaultOption)
                    approval.selectedOption = Some(defaultOption)
                    approval.updatedAt = DateTime.now()

                    try {
                        _approvalsService.update(approvalId, approval)
                    } catch (ex: Exception) {
                        LogUtils.error("WebHumanAgent: error updating approval record on timeout: ${ex.message}")
                    }

                    // 结构化决策日志（tasks.md 11.3 的 decision 类）
                    LogUtils.warn("WebHumanAgent: decision_timeout_default_applied approval_id=${approvalId} default=${defaultOption} timeout_ms=${_defaultTimeoutMs}")

                    let notice = "已按默认方案 '${defaultOption}' 继续（用户 ${_defaultTimeoutMs}ms 未响应）"
                    return AgentResponse(AgentResponseStatus.Success, notice)
                }

                approval.status = "timeout"
                approval.updatedAt = DateTime.now()

                try {
                    _approvalsService.update(approvalId, approval)
                } catch (ex: Exception) {
                    LogUtils.error("WebHumanAgent: error updating approval record on timeout: ${ex.message}")
                }

                return AgentResponse(AgentResponseStatus.Failed, "Approval request timed out after ${_defaultTimeoutMs}ms（未声明 default，无法自动采用兜底方案）")
        }
    }

    /// 从 AgentRequest 读取扩展字段。
    ///
    /// 说明：`options` / `default` / `recommended` 属于长程任务决策点的运行时传参。
    /// AgentRequest 若无对应结构化字段，则退回从 `question` 中按
    /// `key=value` 行提取（技能模板可把决策点写进问题文本），保证后端能力不被
    /// 请求模型未及时扩展所阻塞。
    private static func readRequestField(request: AgentRequest, key: String): String {
        // 暂时统一走 question 文本解析路径：不依赖 AgentRequest 是否已扩展字段
        return WebHumanAgent.extractKeyValueLine(request.question, key)
    }

    /// 从多行文本中提取 `key: value` 或 `key=value` 形式的单行赋值。
    /// 命中返回 value（已 trim），未命中返回空串。
    private static func extractKeyValueLine(text: String, key: String): String {
        for (line in text.split("\n")) {
            let trimmed = line.trimAscii()
            // `key: value`
            if (trimmed.startsWith("${key}:") || trimmed.startsWith("${key}：")) {
                // String.indexOf 返回 Option<Int64>：半角冒号优先，缺失时退到全角冒号
                let cut = match (trimmed.indexOf(":")) {
                    case Some(i) => i
                    case None => match (trimmed.indexOf("：")) {
                        case Some(j) => j
                        case None => -1
                    }
                }
                if (cut >= 0 && cut + 1 <= trimmed.size) {
                    return trimmed[cut + 1..trimmed.size].trimAscii()
                }
            }
            // `key=value`
            if (trimmed.startsWith("${key}=")) {
                return trimmed[key.size + 1..trimmed.size].trimAscii()
            }
        }
        return ""
    }

    /// 从用户响应文本中解析"选中的选项 id"。
    /// 约定：前端选项卡片回传 `option:<id>`；纯文本审批回传自由文本时不记录 id。
    private static func parseSelectedOption(userResponse: String): String {
        let trimmed = userResponse.trimAscii()
        if (trimmed.startsWith("option:")) {
            return trimmed[7..trimmed.size].trimAscii()
        }
        return ""
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