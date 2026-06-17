/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.crontab.executor

import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.app.services.bridge.AgentRuntimeBridge
import magic.app.services.uctoo.AgentTasksService
import magic.app.models.uctoo.AgentTasksPO
import magic.app.core.response.APIResult
import magic.core.agent.{AgentRequest, AgentResponse}
import std.time.DateTime
import std.core.Duration

public class AgentExecutionExecutor <: CrontabExecutor {
    public prop scheme: String {
        get() { "agent_execution" }
    }

    private let bridge = AgentRuntimeBridge.instance
    private let tasksService = AgentTasksService()

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
                let request = AgentRequest(question)

                let response = agent.chat(request)

                let duration = calcDuration(startTime)
                let resultSummary = if (response.content.size <= 200) { response.content } else { response.content[0..200] }

                updateTaskStatus(context.crontabId, agentId, Some(2), Some(response.content), None)

                LogUtils.info("AgentExecutionExecutor", "Agent任务执行完成: agentId=${agentId}, duration=${duration}ms")
                return ExecutionResult.successResult(response.content, duration, resultSummary)
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