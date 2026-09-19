/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.crontab.executor

import magic.log.LogUtils
import magic.config.Config
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.app.services.bridge.{AgentRuntimeBridge, CheckpointManager}
import magic.app.services.uctoo.AgentTasksService
import magic.app.models.uctoo.AgentTasksPO
import magic.app.core.response.APIResult
import magic.core.agent.{AgentRequest, AgentResponse, AgentResponseStatus}
import magic.core.message.{Message, Conversation}
import std.time.DateTime
import std.core.Duration
import magic.app.core.database.DbSerialLock

public class AgentExecutionExecutor <: CrontabExecutor {
    /// 终端内容最小长度阈值（见 isSopCompleted 说明）
    private static let MIN_TERMINAL_CONTENT_LENGTH = 120

    public prop scheme: String {
        get() { "agent_execution" }
    }

    private let bridge = AgentRuntimeBridge.instance
    private let tasksService = AgentTasksService()
    private let checkpointManager = CheckpointManager()
    /// v11：多步循环最大轮数，防止无限循环。
    ///
    /// Ch0.1 统一（tasks.md 0.1）：原为硬编码 30，与 `Config.maxReactNumber` 各自维护一份，改一处忘一处。
    /// 现拆分出独立配置 `Config.agentExecutionSteps`（子 agent / crontab 执行，默认 30，env `AGENT_EXEC_STEPS` 可覆盖）。
    /// 普通任务见 `Config.normalReactSteps`，长程任务内循环见 `Config.longRunningTaskSteps`。
    /// （10 过紧——格式错误会消耗重试步数）。
    /// 长程任务侧另有 `plugin.yaml` 的 `config.maxRounds`，由 LrtExecutor 自行读取，
    /// 二者语义一致（单次执行的最大 ReAct 轮数），此处不再各写一份。
    private let maxRounds = Config.agentExecutionSteps

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
            let agentResult = DbSerialLock.withLock({ => bridge.loadFromDatabase(agentId) })
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

                    // 5. SOP 完成判定（Ch0.1 改造：废弃魔法字符串）
                    //    原实现匹配 "## 完成总结"/"投研报告已生成" 等中文魔法串，
                    //    换措辞即失效，且与长程任务的结构化判定口径不一致。
                    //    现改为结构化判定：优先 <answer> 标签（执行内核基线 spec 5.14），
                    //    其次要求内容达到最小实质长度；长度过短视为中间态，继续下一轮。
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

    /// v11 / Ch0.1：SOP 完成判定（结构化）
    ///
    /// 判定优先级：
    ///   1. 显式 `<answer>` 闭合标签 —— 执行内核基线（spec 5.14），最可靠的"已给出最终答复"信号；
    ///   2. 内容达到最小实质长度且不含工具调用痕迹 —— 视为已收敛的总结性回复。
    ///
    /// 注意：
    ///   - 这里**不再**匹配 "## 完成总结"/"投研报告已生成" 等业务措辞魔法串。
    ///     长程任务的"是否真的完成"由插件侧 `LrtArtifactVerifier`（文件存在/非空/日期/内容）
    ///     与 `LrtVerifier`（结构化验核报告）判定，宿主侧只做"循环是否该退出"的收敛判断，
    ///     职责边界清晰（tasks.md 0.1 / design 2.4.4）。
    ///   - 最小长度阈值 120：低于此长度通常仍是中间态碎片，过早退出会让任务"假完成"。
    private func isSopCompleted(content: String): Bool {
        let trimmed = content.trimAscii()
        if (trimmed.isEmpty()) {
            return false
        }
        // 1. 显式 answer 闭合标签 —— 最强信号
        if (trimmed.contains("</answer>")) {
            return true
        }
        // 2. 已收敛：内容足够长且不再要求工具调用
        let hasToolCallTrace = trimmed.contains("Action:") ||
            trimmed.contains("<tool_call") ||
            trimmed.contains("```json")
        if (trimmed.size >= MIN_TERMINAL_CONTENT_LENGTH && !hasToolCallTrace) {
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
                DbSerialLock.withLock({ => tasksService.update(crontabId, task) })
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
