/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.interaction.{EventHandlerManager, AgentStartEvent, AgentEndEvent, ChatModelEndEvent, AgentStartEventHandler, AgentEndEventHandler, ChatModelEndEventHandler, EventResponse}
import magic.core.agent.{AgentResponse, AgentResponseStatus, AgentTerminationReason}
import magic.app.models.uctoo.{AgentTasksPO, AgentMessagesPO, AgentContextsPO, AgentMemoriesPO, AgentsPO}
import magic.app.services.uctoo.{AgentTasksService, AgentMessagesService, AgentContextsService, AgentMemoriesService, AgentsService}
import magic.log.LogUtils
import std.time.DateTime
import std.collection.concurrent.ConcurrentHashMap
import magic.app.core.database.DbSerialLock

func reasonStr(reason: ?String): String {
    match (reason) { case Some(s) => s; case None => "unknown" }
}

func toJsonString(text: String): String {
    "\"${text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\r", "\\r").replace("\n", "\\n")}\""
}

func toJsonArrayString(text: String): String {
    "[\"${text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\r", "\\r").replace("\n", "\\n")}\"]"
}

/**
 * Ch0 / 中断语义：把 AgentResponse 的终止原因映射为 agent_tasks.status 整型。
 * 状态约定（与 AgentExecutionExecutor 对齐）：
 *   1=running 2=completed 3=failed/error 4=cancelled 5=步数耗尽未收敛（新增）
 * 核心目的：步数耗尽但未达成目标的任务，绝不再记为 completed(2)。
 */
func resolveTaskStatus(resp: AgentResponse): Int32 {
    match (resp.terminationReason) {
        case AgentTerminationReason.MaxStepsExhausted => return 5
        case AgentTerminationReason.Cancelled => return 4
        case AgentTerminationReason.Error => return 3
        case AgentTerminationReason.Completed =>
            match (resp.status) {
                case AgentResponseStatus.Cancelled => return 4
                case AgentResponseStatus.Failed => return 3
                case _ => return 2
            }
    }
}

public class AgentPersistenceEventHandler {
    private let tasksService = AgentTasksService()
    private let messagesService = AgentMessagesService()
    private let contextsService = AgentContextsService()
    private let memoriesService = AgentMemoriesService()
    private let agentsService = AgentsService()
    private let activeTasks = ConcurrentHashMap<String, String>()
    private let agentUuidCache = ConcurrentHashMap<String, String>()

    private func resolveAgentUuid(agentName: String): String {
        if (let Some(cached) <- agentUuidCache.get(agentName)) {
            return cached
        }
        let (agentList, _) = DbSerialLock.withLock({ => agentsService.getListWithFilter(1, 1, "", "{\"name\":{\"equals\":\"${agentName}\"}}") })
        if (agentList.size > 0) {
            let uuid = agentList[0].id
            agentUuidCache.add(agentName, uuid)
            return uuid
        }
        return agentName
    }

    public func registerGlobalHandlers(): Unit {
        let manager = EventHandlerManager.global
        let handler = this

        let startHandler: AgentStartEventHandler = { evt =>
            handler.onAgentStart(evt)
        }
        manager.addHandler(startHandler)

        let chatEndHandler: ChatModelEndEventHandler = { evt =>
            handler.onChatModelEnd(evt)
        }
        manager.addHandler(chatEndHandler)

        let endHandler: AgentEndEventHandler = { evt =>
            handler.onAgentEnd(evt)
        }
        manager.addHandler(endHandler)

        LogUtils.info("AgentPersistenceEventHandler: registered AgentStart/ChatModelEnd/AgentEnd handlers")
    }

    public func onAgentStart(event: AgentStartEvent): EventResponse<AgentResponse> {
        let agentName = event.agent.name
        let question = event.agentRequest.question
        spawn {
            try {
                let agentUuid = resolveAgentUuid(agentName)

                let taskPo = AgentTasksPO()
                taskPo.agentId = agentUuid
                taskPo.status = Some(1)
                taskPo.priority = Some(0)
                taskPo.payload = Some(toJsonString(question))
                taskPo.creator = Some(agentUuid)
                let taskResult = DbSerialLock.withLock({ => tasksService.create(taskPo, agentName) })
                if (taskResult.success) {
                    let dbTaskId = if (let Some(data) <- taskResult.data) { data.id } else { "" }
                    activeTasks.add(agentName, dbTaskId)
                    LogUtils.info("AgentPersistenceEventHandler: created task ${dbTaskId} for agent ${agentName}")
                } else {
                    LogUtils.error("AgentPersistenceEventHandler: create task FAILED for agent ${agentName}, reason: ${reasonStr(taskResult.reason)}")
                }

                let userMsg = AgentMessagesPO()
                userMsg.fromAgentId = None<String>
                userMsg.toAgentId = Some(agentUuid)
                userMsg.messageType = "user"
                userMsg.content = Some(toJsonString(question))
                userMsg.status = Some(1)
                userMsg.creator = None<String>
                let userMsgResult = DbSerialLock.withLock({ => messagesService.create(userMsg, agentName) })
                if (userMsgResult.success) {
                    LogUtils.info("AgentPersistenceEventHandler: saved user message for agent ${agentName}")
                } else {
                    LogUtils.error("AgentPersistenceEventHandler: save user message FAILED for agent ${agentName}, reason: ${reasonStr(userMsgResult.reason)}")
                }

                // 加载历史上下文（用于多轮对话）
                let checkpointManager = CheckpointManager()
                if (let Some(historyMessages) <- checkpointManager.loadLatestCheckpoint(agentUuid)) {
                    LogUtils.info("AgentPersistenceEventHandler: loaded ${historyMessages.size} historical messages for agent ${agentName}")
                    // 这里可以将历史消息传递给 agent，需要修改事件或使用其他方式
                }

                let (agentList, _) = DbSerialLock.withLock({ => agentsService.getListWithFilter(1, 1, "", "{\"name\":{\"equals\":\"${agentName}\"}}") })
                if (agentList.size > 0) {
                    let existingAgent = agentList[0]
                    let updatePo = AgentsPO()
                    updatePo.status = Some(1)
                    let agentUpdateResult = DbSerialLock.withLock({ => agentsService.update(existingAgent.id, updatePo) })
                    if (agentUpdateResult.success) {
                        LogUtils.info("AgentPersistenceEventHandler: updated agent ${agentName} status to running")
                    } else {
                        LogUtils.error("AgentPersistenceEventHandler: update agent status FAILED for ${agentName}, reason: ${reasonStr(agentUpdateResult.reason)}")
                    }
                } else {
                    let agentPo = AgentsPO()
                    agentPo.name = agentName
                    agentPo.agentType = "skill"
                    agentPo.status = Some(1)
                    agentPo.creator = None<String>
                    let agentResult = DbSerialLock.withLock({ => agentsService.create(agentPo, agentName) })
                    if (agentResult.success) {
                        let newUuid = if (let Some(data) <- agentResult.data) { data.id } else { "" }
                        agentUuidCache.add(agentName, newUuid)
                        LogUtils.info("AgentPersistenceEventHandler: created agent record for ${agentName}")
                    } else {
                        LogUtils.error("AgentPersistenceEventHandler: create agent record FAILED for ${agentName}, reason: ${reasonStr(agentResult.reason)}")
                    }
                }
            } catch (e: Exception) {
                LogUtils.error("AgentPersistenceEventHandler.onAgentStart failed: ${e.message}")
            }
        }
        return EventResponse.Continue
    }

    public func onChatModelEnd(event: ChatModelEndEvent): Unit {
        let agentName = event.agent.name
        let content = event.chatResponse.message.content
        spawn {
            try {
                let agentUuid = resolveAgentUuid(agentName)

                let po = AgentMessagesPO()
                po.fromAgentId = Some(agentUuid)
                po.messageType = "assistant"
                po.content = Some(toJsonString(content))
                po.status = Some(1)
                po.creator = Some(agentUuid)
                let taskIdOpt = activeTasks.get(agentName)
                if (let Some(taskId) <- taskIdOpt) {
                    po.taskId = Some(taskId)
                }
                let result = DbSerialLock.withLock({ => messagesService.create(po, agentName) })
                if (result.success) {
                    LogUtils.info("AgentPersistenceEventHandler: saved assistant message for agent ${agentName}")
                } else {
                    LogUtils.error("AgentPersistenceEventHandler: save assistant message FAILED for agent ${agentName}, reason: ${reasonStr(result.reason)}")
                }
            } catch (e: Exception) {
                LogUtils.error("AgentPersistenceEventHandler.onChatModelEnd failed: ${e.message}")
            }
        }
    }

    public func onAgentEnd(event: AgentEndEvent): Unit {
        let agentName = event.agent.name
        spawn {
            try {
                let agentUuid = resolveAgentUuid(agentName)

                if (let Some(taskId) <- activeTasks.get(agentName)) {
                    let po = AgentTasksPO()
                    po.id = taskId
                    // Ch0 中断语义：状态必须由终止原因推导，不能一律写 completed(2)。
                    // 此前硬编码 2 导致「步数耗尽未闭环」也被记成成功完成，
                    // 使 resolveTaskStatus 形同虚设（从未被调用）。
                    let finalStatus: Int32 = match (event.agentResponse) {
                        case Some(resp) => resolveTaskStatus(resp)
                        case None => 2
                    }
                    po.status = Some(finalStatus)
                    po.completedAt = Some(DateTime.now())
                    if (let Some(resp) <- event.agentResponse) {
                        po.result = Some(toJsonString(resp.content))
                    }
                    let updateResult = DbSerialLock.withLock({ => tasksService.update(taskId, po) })
                    if (updateResult.success) {
                        activeTasks.remove(agentName)
                        LogUtils.info("AgentPersistenceEventHandler: updated task ${taskId} to status=${finalStatus} (2=completed 3=failed 4=cancelled 5=步数耗尽未闭环) for agent ${agentName}")
                    } else {
                        LogUtils.error("AgentPersistenceEventHandler: update task FAILED for ${taskId}, reason: ${reasonStr(updateResult.reason)}")
                    }
                }

                if (let Some(resp) <- event.agentResponse) {
                    let msg = AgentMessagesPO()
                    msg.fromAgentId = Some(agentUuid)
                    msg.messageType = "agent_end"
                    msg.content = Some(toJsonString(resp.content))
                    msg.status = Some(1)
                    msg.creator = Some(agentUuid)
                    let msgResult = DbSerialLock.withLock({ => messagesService.create(msg, agentName) })
                    if (!msgResult.success) {
                        LogUtils.error("AgentPersistenceEventHandler: save agent_end message FAILED, reason: ${reasonStr(msgResult.reason)}")
                    }

                    let checkpointManager = CheckpointManager()
                    try {
                        let execution = resp.execution
                        let taskIdOpt = activeTasks.get(agentName)
                        let taskId = match (taskIdOpt) { case Some(t) => Some(t); case None => None<String> }
                        checkpointManager.saveCheckpoint(agentUuid, execution, taskId)
                        LogUtils.info("AgentPersistenceEventHandler: saved checkpoint for agent ${agentName}")
                    } catch (_: Exception) {
                        LogUtils.debug("AgentPersistenceEventHandler: no execution context to save checkpoint")
                    }

                    let memPo = AgentMemoriesPO()
                    memPo.agentId = agentUuid
                    memPo.content = resp.content
                    memPo.scope = "result"
                    memPo.weight = 1.0
                    memPo.tags = "[\"conversation\",\"result\"]"
                    memPo.metadata = "{\"source\":\"agent_end\"}"
                    memPo.creator = Some(agentUuid)
                    let memResult = DbSerialLock.withLock({ => memoriesService.create(memPo, agentName) })
                    if (memResult.success) {
                        LogUtils.info("AgentPersistenceEventHandler: saved memory for agent ${agentName}")
                    } else {
                        LogUtils.error("AgentPersistenceEventHandler: save memory FAILED for agent ${agentName}, reason: ${reasonStr(memResult.reason)}")
                    }

                }
            } catch (e: Exception) {
                LogUtils.error("AgentPersistenceEventHandler.onAgentEnd failed: ${e.message}")
            }
        }
    }
}
