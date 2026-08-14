/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.crontab.executor

import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.app.services.bridge.{AgentRuntimeBridge, CheckpointManager}
import magic.app.services.uctoo.AgentTasksService
import magic.app.models.uctoo.AgentTasksPO
import magic.app.core.response.APIResult
import magic.core.agent.{AgentRequest, AgentResponse, AgentResponseStatus}
import magic.core.message.{Message, Conversation}
import std.time.DateTime
import std.core.Duration

public class AgentExecutionExecutor <: CrontabExecutor {
    public prop scheme: String {
        get() { "agent_execution" }
    }

    private let bridge = AgentRuntimeBridge.instance
    private let tasksService = AgentTasksService()
    private let checkpointManager = CheckpointManager()
    /// v11：多步循环最大轮数，防止无限循环
    private let maxRounds = 10

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        let taskUri = context.taskUri
        let agentId = ExecutorRegistry.parsePath(taskUri)

        if (agentId.isEmpty()) {
            LogUtils.error("AgentExecutionExecutor", "无效的agent_execution URI: ${taskUri}")
            return ExecutionResult.failureResult("无效的agent_execution URI: ${taskUri}", 0, -1)
        }

        LogUtils.info("AgentExecutionExecutor", "开始执行Agent任务: agentId=${agentId}, taskName=${context.taskName}")

        try {
            let agentResult = bridge.loadFromDatabase(agentId)
            if (!agentResult.success) {
                LogUtils.error("AgentExecutionExecutor", "Agent加载失败: ${agentId}, reason=${agentResult.reason}")
                updateTaskStatus(context.crontabId, agentId, Some(3), None, Some("Agent加载失败: ${agentResult.reason}"))
                return ExecutionResult.failureResult("Agent加载失败: ${agentId}", calcDuration(startTime), -1)
            }

            if (let Some(agent) <- agentResult.data) {
                let question = if (context.parameters.size > 2) { context.parameters } else { "" }
                var finalContent = ""
                var finalStatus = AgentResponseStatus.Success
                var round = 0

                // v11：多步循环执行，接入 CheckpointManager
                while (round < maxRounds) {
                    round++
                    LogUtils.info("AgentExecutionExecutor", "Agent任务第${round}轮执行: agentId=${agentId}")

                    // 1. 加载历史检查点
                    var conversation: ?Conversation = None
                    if (let Some(historyMessages) <- checkpointManager.loadLatestCheckpoint(agentId)) {
                        if (historyMessages.size > 0) {
                            LogUtils.info("AgentExecutionExecutor", "加载历史检查点: ${historyMessages.size}条消息")
                            conversation = Some(Conversation())
                            var i = 0
                            while (i < historyMessages.size - 1) {
                                if (i + 1 < historyMessages.size) {
                                    conversation.getOrThrow().addChatRound(historyMessages[i], historyMessages[i + 1])
                                }
                                i = i + 2
                            }
                        }
                    }

                    // 2. 执行 Agent
                    let request = AgentRequest(question, conversation: conversation)
                    let response = agent.chat(request)
                    finalContent = response.content
                    finalStatus = response.status

                    // 3. 保存检查点
                    try {
                        let _ = checkpointManager.saveCheckpoint(agentId, response.execution, Some(context.crontabId))
                    } catch (_: Exception) {}

                    // 4. 检查是否完成
                    if (response.status == AgentResponseStatus.Cancelled) {
                        LogUtils.info("AgentExecutionExecutor", "Agent任务被取消: agentId=${agentId}")
                        updateTaskStatus(context.crontabId, agentId, Some(4), Some(response.content), Some("任务被用户取消"))
                        return ExecutionResult.failureResult("Agent任务被取消: ${agentId}", calcDuration(startTime), -1)
                    }

                    if (response.status == AgentResponseStatus.Failed) {
                        LogUtils.error("AgentExecutionExecutor", "Agent任务执行失败: agentId=${agentId}")
                        updateTaskStatus(context.crontabId, agentId, Some(3), Some(response.content), Some("Agent执行返回失败状态"))
                        return ExecutionResult.failureResult("Agent执行失败: ${agentId}", calcDuration(startTime), -1)
                    }

                    // 5. SOP 完成判定：response 内容中包含完成标志，或没有更多工具调用需求
                    if (isSopCompleted(response.content)) {
                        LogUtils.info("AgentExecutionExecutor", "SOP已完成，退出循环: agentId=${agentId}, round=${round}")
                        break
                    }

                    // 6. 未完成则继续下一轮，将上一轮结果作为下一轮的上下文
                    LogUtils.info("AgentExecutionExecutor", "SOP未完成，继续下一轮: agentId=${agentId}, round=${round}")
                }

                let duration = calcDuration(startTime)
                let resultSummary = if (finalContent.size <= 200) { finalContent } else { finalContent[0..200] }

                updateTaskStatus(context.crontabId, agentId, Some(2), Some(finalContent), None)

                LogUtils.info("AgentExecutionExecutor", "Agent任务执行完成: agentId=${agentId}, duration=${duration}ms, rounds=${round}")
                return ExecutionResult.successResult(finalContent, duration, resultSummary)
            } else {
                LogUtils.error("AgentExecutionExecutor", "Agent数据为空: agentId=${agentId}")
                updateTaskStatus(context.crontabId, agentId, Some(3), None, Some("Agent数据为空"))
                let duration = calcDuration(startTime)
                return ExecutionResult.failureResult("Agent数据为空", duration, -1)
            }
        } catch (e: Exception) {
            let duration = calcDuration(startTime)
            LogUtils.error("AgentExecutionExecutor", "Agent任务执行异常: agentId=${agentId}, error=${e.message}")
            updateTaskStatus(context.crontabId, agentId, Some(3), None, Some(e.message))
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }

    /// v11：SOP 完成判定
    /// 检查 response 内容中是否包含完成标志
    private func isSopCompleted(content: String): Bool {
        // 如果内容中包含以下完成标志，认为 SOP 已完成
        let completionMarkers = ["## 完成总结", "## 执行总结", "任务已完成", "所有步骤已完成", "投研报告已生成", "Final Answer"]
        for (marker in completionMarkers) {
            if (content.contains(marker)) {
                return true
            }
        }
        // 如果内容较短（<100字符）且不包含工具调用格式，认为是总结性回复
        if (content.size < 100 && !content.contains("Action:") && !content.contains("```json")) {
            return true
        }
        return false
    }

    public func validate(taskUri: String): Bool {
        let path = ExecutorRegistry.parsePath(taskUri)
        if (path.isEmpty()) {
            return false
        }
        path.size > 0 && path.size <= 36
    }

    private func updateTaskStatus(crontabId: String, agentId: String, status: Option<Int32>, result: Option<String>, errorMessage: Option<String>): Unit {
        spawn {
            try {
                let task = AgentTasksPO()
                task.agentId = agentId
                task.status = status
                task.result = result
                task.errorMessage = errorMessage
                if (status == Some(2)) {
                    task.completedAt = Some(DateTime.now())
                }
                tasksService.update(crontabId, task)
            } catch (_: Exception) {}
        }
    }

    private func calcDuration(startTime: DateTime): Int64 {
        try {
            let now = DateTime.now()
            let diff = now - startTime
            diff.toMilliseconds()
        } catch (_: Exception) {
            0
        }
    }
}
