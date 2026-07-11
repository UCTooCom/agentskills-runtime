/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.sql.Pagination
import magic.app.models.uctoo.{AgentMessagesPO, AgentTasksPO, AipInteractionSessionPO, AipInteractionMessagePO, AipInteractionTaskPO}
import magic.app.dao.uctoo.{AgentMessagesDAO, AgentTasksDAO, AipInteractionSessionDAO, AipInteractionMessageDAO, AipInteractionTaskDAO}
import magic.app.core.response.APIResult
import magic.app.services.aip.model.{LocalSessionRequest, LocalMessageRequest, SessionResult, MessageResult}
import magic.app.services.aip.acps.AcpsMqAdapter
import magic.log.LogUtils
import f_util.UUID

public class AipInteractionService {
    private let mqAdapter: AcpsMqAdapter = AcpsMqAdapter()
    private var mqCallbackRegistered: Bool = false

    private func ensureMqCallback(): Unit {
        if (!mqCallbackRegistered) {
            mqAdapter.setMessageCallback(callback: { sessionId, messageId, senderAic, senderRole, dataItems, taskId =>
                handleMqMessage(sessionId, messageId, senderAic, senderRole, dataItems, taskId)
            })
            mqCallbackRegistered = true
        }
    }

    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    public func createLocalSession(request: LocalSessionRequest, creatorId: String): APIResult<SessionResult> {
        try {
            let sessionId = UUID.random().toString()

            let result = SessionResult()
            result.sessionId = sessionId
            result.requesterAgentId = request.requesterAgentId
            result.receiverAgentIds = request.receiverAgentIds
            result.interactionMode = request.interactionMode
            result.sessionStatus = "active"
            result.createdAt = DateTime.now().toString()

            LogUtils.info("AipInteractionService", "Local session created: ${sessionId}")
            return APIResult<SessionResult>(result)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "createLocalSession failed: ${e.message}")
            return APIResult<SessionResult>(false, "创建本地交互会话失败: ${e.message}")
        }
    }

    public func sendLocalMessage(request: LocalMessageRequest, creatorId: String): APIResult<MessageResult> {
        try {
            let validationError = AipMessageValidator.validate(request)
            if (validationError.isSome()) {
                return APIResult<MessageResult>(false, validationError.getOrThrow())
            }

            let messageId = UUID.random().toString()

            let message = AgentMessagesPO()
            message.fromAgentId = Some<String>(request.senderAgentId)
            message.messageType = "aip_interaction"
            message.content = request.content
            message.aipSessionId = Some<String>(request.sessionId)
            message.aipMessageId = Some<String>(messageId)
            message.senderRole = Some<String>(request.senderRole)
            message.dataItems = request.dataItems
            message.createdAt = DateTime.now()
            message.updatedAt = DateTime.now()
            message.creator = creatorId

            let insertedId = getExecutor().insertAgentMessages(message)

            if (request.taskId.isSome()) {
                let taskId = request.taskId.getOrThrow()
                let taskOpt = getExecutor().findAgentTasksById(taskId)
                if (taskOpt.isSome()) {
                    let task = taskOpt.getOrThrow()
                    task.aipSessionId = Some<String>(request.sessionId)
                    task.updatedAt = DateTime.now()
                    getExecutor().updateAgentTasks(task)
                }
            }

            let result = MessageResult()
            result.messageId = messageId
            result.sessionId = request.sessionId
            result.senderRole = request.senderRole
            result.createdAt = DateTime.now().toString()

            LogUtils.info("AipInteractionService", "Local message sent: ${messageId}")
            return APIResult<MessageResult>(result)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "sendLocalMessage failed: ${e.message}")
            return APIResult<MessageResult>(false, "发送本地交互消息失败: ${e.message}")
        }
    }

    public func getSessionMessages(sessionId: String, page: Int64, size: Int64): APIResult<Pagination<AgentMessagesPO>> {
        try {
            let pagination = getExecutor().findMessagesByAipSessionIdPage(sessionId, page, size)
            return APIResult<Pagination<AgentMessagesPO>>(pagination)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "getSessionMessages failed: ${e.message}")
            return APIResult<Pagination<AgentMessagesPO>>(false, "查询会话消息失败: ${e.message}")
        }
    }

    public func getSessionTasks(sessionId: String): APIResult<ArrayList<AgentTasksPO>> {
        try {
            let tasks = getExecutor().findTasksByAipSessionId(sessionId)
            return APIResult<ArrayList<AgentTasksPO>>(tasks)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "getSessionTasks failed: ${e.message}")
            return APIResult<ArrayList<AgentTasksPO>>(false, "查询会话任务失败: ${e.message}")
        }
    }

    public func closeSession(sessionId: String): APIResult<Bool> {
        try {
            LogUtils.info("AipInteractionService", "Local session closed: ${sessionId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "closeSession failed: ${e.message}")
            return APIResult<Bool>(false, "关闭交互会话失败: ${e.message}")
        }
    }

    public func createInterconnectionSession(requesterAgentId: String, requesterAic: String, interactionMode: String, receivers: String, creatorId: String): APIResult<AipInteractionSessionPO> {
        try {
            let sessionId = UUID.random().toString()

            let session = AipInteractionSessionPO()
            session.sessionId = sessionId
            session.requesterAgentId = requesterAgentId
            session.requesterAic = requesterAic
            session.interactionMode = interactionMode
            session.receivers = receivers
            session.sessionStatus = "active"
            session.creator = creatorId
            session.createdAt = DateTime.now()
            session.updatedAt = DateTime.now()

            let insertedId = getExecutor().insertAipInteractionSession(session)
            session.id = insertedId

            if (interactionMode == "group") {
                ensureMqCallback()
                try {
                    let memberAics = ArrayList<String>()
                    if (!receivers.isEmpty()) {
                        for (r in receivers.split(",")) {
                            let trimmed = r.trimAscii()
                            if (!trimmed.isEmpty()) { memberAics.add(trimmed) }
                        }
                    }
                    memberAics.add(requesterAic)
                    let mqResult = mqAdapter.createGroupChannel(
                        sessionId: sessionId,
                        requesterAic: requesterAic,
                        memberAics: memberAics,
                        durable: false
                    )
                    if (!mqResult.success) {
                        LogUtils.warn("AipInteractionService", "MQ group channel creation skipped: ${mqResult.reason ?? "unknown"}")
                    }
                } catch (e: Exception) {
                    LogUtils.warn("AipInteractionService", "MQ group channel creation failed: ${e.message}")
                }
            }

            LogUtils.info("AipInteractionService", "Interconnection session created: ${sessionId}")
            return APIResult<AipInteractionSessionPO>(session)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "createInterconnectionSession failed: ${e.message}")
            return APIResult<AipInteractionSessionPO>(false, "AIP-INTER-001: 创建互联交互会话失败: ${e.message}")
        }
    }

    public func sendInterconnectionMessage(sessionId: String, senderAgentId: String, senderAic: String, senderRole: String, dataItems: String, taskId: Option<String>, creatorId: String): APIResult<MessageResult> {
        try {
            let sessionOpt = getExecutor().setSql(
                "select * from aip_interaction_session where session_id = '${sessionId}' and deleted_at is null"
            ).first<AipInteractionSessionPO>()
            if (sessionOpt.isNone()) {
                return APIResult<MessageResult>(false, "AIP-INTER-002: 互联交互会话不存在")
            }

            let messageId = UUID.random().toString()

            let aipMsg = AipInteractionMessagePO()
            aipMsg.messageId = messageId
            aipMsg.sessionId = sessionId
            aipMsg.taskId = taskId
            aipMsg.senderRole = senderRole
            aipMsg.senderAic = senderAic
            aipMsg.dataItems = dataItems
            aipMsg.creator = creatorId
            aipMsg.createdAt = DateTime.now()
            aipMsg.updatedAt = DateTime.now()

            getExecutor().insertAipInteractionMessage(aipMsg)

            let message = AgentMessagesPO()
            message.fromAgentId = Some<String>(senderAgentId)
            message.messageType = "aip_interconnection"
            message.content = Some<String>(dataItems)
            message.aipSessionId = Some<String>(sessionId)
            message.aipMessageId = Some<String>(messageId)
            message.senderRole = Some<String>(senderRole)
            message.dataItems = Some<String>(dataItems)
            message.createdAt = DateTime.now()
            message.updatedAt = DateTime.now()
            message.creator = creatorId

            getExecutor().insertAgentMessages(message)

            if (taskId.isSome()) {
                let tid = taskId.getOrThrow()
                let taskOpt = getExecutor().findAgentTasksById(tid)
                if (taskOpt.isSome()) {
                    let task = taskOpt.getOrThrow()
                    task.aipSessionId = Some<String>(sessionId)
                    task.updatedAt = DateTime.now()
                    getExecutor().updateAgentTasks(task)
                }
            }

            let result = MessageResult()
            result.messageId = messageId
            result.sessionId = sessionId
            result.senderRole = senderRole
            result.createdAt = DateTime.now().toString()

            try {
                ensureMqCallback()
                let mqResult = mqAdapter.publishGroupMessage(
                    sessionId: sessionId,
                    messageId: messageId,
                    senderAic: senderAic,
                    senderRole: senderRole,
                    dataItems: dataItems,
                    deliveryMode: "PERSISTENT",
                    timeToLive: 0
                )
                if (!mqResult.success) {
                    LogUtils.warn("AipInteractionService", "MQ message publish skipped: ${mqResult.reason ?? "unknown"}")
                }
            } catch (e: Exception) {
                LogUtils.warn("AipInteractionService", "MQ message publish failed: ${e.message}")
            }

            LogUtils.info("AipInteractionService", "Interconnection message sent: ${messageId}")
            return APIResult<MessageResult>(result)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "sendInterconnectionMessage failed: ${e.message}")
            return APIResult<MessageResult>(false, "AIP-INTER-002: 发送互联交互消息失败: ${e.message}")
        }
    }

    public func closeInterconnectionSession(sessionId: String): APIResult<Bool> {
        try {
            let sessionOpt = getExecutor().setSql(
                "select * from aip_interaction_session where session_id = '${sessionId}' and deleted_at is null"
            ).first<AipInteractionSessionPO>()
            if (sessionOpt.isNone()) {
                return APIResult<Bool>(false, "AIP-INTER-003: 互联交互会话不存在")
            }

            let session = sessionOpt.getOrThrow()

            try {
                ensureMqCallback()
                let mqResult = mqAdapter.destroyGroupChannel(sessionId: sessionId)
                if (!mqResult.success) {
                    LogUtils.warn("AipInteractionService", "MQ group channel destroy skipped: ${mqResult.reason ?? "unknown"}")
                }
            } catch (e: Exception) {
                LogUtils.warn("AipInteractionService", "MQ group channel destroy failed: ${e.message}")
            }

            session.sessionStatus = "closed"
            session.updatedAt = DateTime.now()
            getExecutor().updateAipInteractionSession(session)

            LogUtils.info("AipInteractionService", "Interconnection session closed: ${sessionId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "closeInterconnectionSession failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-INTER-003: 关闭互联交互会话失败: ${e.message}")
        }
    }

    public func handleMqMessage(sessionId: String, messageId: String, senderAic: String, senderRole: String, dataItems: String, taskId: Option<String>): APIResult<Bool> {
        try {
            let existing = getExecutor().setSql(
                "select count(*) as cnt from aip_interaction_message where message_id = '${messageId}' and deleted_at is null"
            ).singleFirst<Int64>() ?? 0
            if (existing > 0) {
                return APIResult<Bool>(true)
            }

            let aipMsg = AipInteractionMessagePO()
            aipMsg.messageId = messageId
            aipMsg.sessionId = sessionId
            aipMsg.taskId = taskId
            aipMsg.senderRole = senderRole
            aipMsg.senderAic = senderAic
            aipMsg.dataItems = dataItems
            aipMsg.creator = "mq_callback"
            aipMsg.createdAt = DateTime.now()
            aipMsg.updatedAt = DateTime.now()

            getExecutor().insertAipInteractionMessage(aipMsg)

            let message = AgentMessagesPO()
            message.fromAgentId = Some<String>(senderAic)
            message.messageType = "aip_interconnection"
            message.content = Some<String>(dataItems)
            message.aipSessionId = Some<String>(sessionId)
            message.aipMessageId = Some<String>(messageId)
            message.senderRole = Some<String>(senderRole)
            message.dataItems = Some<String>(dataItems)
            message.createdAt = DateTime.now()
            message.updatedAt = DateTime.now()
            message.creator = "mq_callback"

            getExecutor().insertAgentMessages(message)

            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipInteractionService", "AIP-MQ-010: handleMqMessage failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-MQ-010: MQ消息回调处理失败: ${e.message}")
        }
    }
}