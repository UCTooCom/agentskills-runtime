/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.crontab.executor

import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.interaction.{EvaluationEngine, EvaluationResult}
import std.time.DateTime
import std.core.Duration
import std.convert
import std.collection.ArrayList

public class EvaluationExecutor <: CrontabExecutor {
    public prop scheme: String {
        get() { "evaluation" }
    }

    private let evaluationEngine = EvaluationEngine()

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()

        let evaluationType = parseEvaluationType(context.taskUri)
        let timeRangeHours = parseTimeRangeHours(context.taskUri, context.parameters)

        LogUtils.info("EvaluationExecutor", "开始执行评估: type=${evaluationType}, timeRangeHours=${timeRangeHours}, taskName=${context.taskName}")

        try {
            let timeRangeEnd = DateTime.now()
            let timeRangeStart = timeRangeEnd - Duration.hour * Int64(timeRangeHours)

            let results = ArrayList<EvaluationResult>()
            let output = StringBuilder()

            if (evaluationType == "global" || evaluationType == "all") {
                let allResults = evaluationEngine.evaluateAll(timeRangeStart, timeRangeEnd)
                for (r in allResults) {
                    results.add(r)
                }
                output.append("全局评估完成: ${allResults.size}个Agent")
            } else if (evaluationType == "agent") {
                let agentId = parseAgentId(context.parameters)
                if (agentId.size > 0) {
                    let result = evaluationEngine.evaluateAgent(agentId, timeRangeStart, timeRangeEnd)
                    results.add(result)
                    output.append("Agent评估完成: agentId=${agentId}, successRate=${result.successRate}")
                } else {
                    output.append("Agent评估跳过: 缺少agentId参数")
                }
            } else if (evaluationType == "session") {
                let sessionId = parseSessionId(context.parameters)
                if (sessionId.size > 0) {
                    let result = evaluationEngine.evaluateSession(sessionId)
                    results.add(result)
                    output.append("会话评估完成: sessionId=${sessionId}, successRate=${result.successRate}")
                } else {
                    output.append("会话评估跳过: 缺少sessionId参数")
                }
            } else {
                let allResults = evaluationEngine.evaluateAll(timeRangeStart, timeRangeEnd)
                for (r in allResults) {
                    results.add(r)
                }
                output.append("默认全局评估完成: ${allResults.size}个Agent")
            }

            let duration = calcDuration(startTime)
            let outputStr = output.toString()
            let summary = if (outputStr.size <= 200) { outputStr } else { outputStr[0..200] }

            LogUtils.info("EvaluationExecutor", "评估执行完成: duration=${duration}ms, results=${results.size}")
            return ExecutionResult.successResult(outputStr, duration, summary)
        } catch (e: Exception) {
            let duration = calcDuration(startTime)
            LogUtils.error("EvaluationExecutor", "评估执行异常: ${e.message}")
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }

    public func validate(taskUri: String): Bool {
        let lower = taskUri.toAsciiLower()
        if (!lower.startsWith("evaluation://")) {
            return false
        }
        let path = taskUri[13..]
        path.size > 0
    }

    private func parseEvaluationType(taskUri: String): String {
        let lower = taskUri.toAsciiLower()
        if (!lower.startsWith("evaluation://")) {
            return "global"
        }
        let pathAndQuery = taskUri[13..]
        var path = pathAndQuery
        let queryIdx = pathAndQuery.indexOf("?")
        if (let Some(idx) <- queryIdx) {
            if (idx > 0) {
                path = pathAndQuery[0..idx]
            } else {
                path = ""
            }
        }
        if (path.size == 0) {
            return "global"
        }
        path.toAsciiLower()
    }

    private func parseTimeRangeHours(taskUri: String, parameters: String): Int64 {
        let lower = taskUri.toAsciiLower()
        let queryIdx = lower.indexOf("?")
        if (let Some(idx) <- queryIdx) {
            let query = taskUri[(idx + 1)..]
            let timeRangeIdx = query.indexOf("timeRangeHours=")
            if (let Some(trIdx) <- timeRangeIdx) {
                let valueStart = query[(trIdx + 15)..]
                let ampIdx = valueStart.indexOf("&")
                let valueStr = if (let Some(aIdx) <- ampIdx) { valueStart[0..aIdx] } else { valueStart }
                try {
                    return Int64.parse(valueStr)
                } catch (_: Exception) {
                    return 1
                }
            }
        }
        1
    }

    private func parseAgentId(parameters: String): String {
        parseJsonField(parameters, "agentId")
    }

    private func parseSessionId(parameters: String): String {
        parseJsonField(parameters, "sessionId")
    }

    private func parseJsonField(json: String, fieldName: String): String {
        let searchKey = "\"${fieldName}\":\""
        let idx = json.indexOf(searchKey)
        if (let Some(startIdx) <- idx) {
            let valueStart = json[(startIdx + searchKey.size)..]
            let endIdx = valueStart.indexOf("\"")
            if (let Some(eIdx) <- endIdx) {
                return valueStart[0..eIdx]
            }
        }
        ""
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