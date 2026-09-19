package magic.app.services.crontab.executor

import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}

public class ExecutorRegistry {
    private let executors = ConcurrentHashMap<String, CrontabExecutor>()

    public func register(scheme: String, executor: CrontabExecutor): Unit {
        executors.put(scheme, executor)
        LogUtils.info("ExecutorRegistry", "注册执行器: ${scheme}")
    }

    public func getExecutor(taskUri: String): Option<CrontabExecutor> {
        let scheme = parseScheme(taskUri)
        executors.get(scheme)
    }

    public static func parseScheme(taskUri: String): String {
        let lower = taskUri.toAsciiLower()
        if (lower.startsWith("script://")) { return "script" }
        if (lower.startsWith("https://")) { return "http" }
        if (lower.startsWith("http://")) { return "http" }
        if (lower.startsWith("builtin://")) { return "builtin" }
        if (lower.startsWith("evaluation://")) { return "evaluation" }
        if (lower.startsWith("skill-curator://")) { return "skill-curator" }
        if (lower.startsWith("agent_execution://")) { return "agent_execution" }
        // lrt://<agentId> —— 长程任务（long-running-task 插件）专用 scheme。
        // 与 agent_execution:// 分开是为了**避免宿主 AgentExecutionExecutor 无条件置
        // status=2**（spec 5.6.1 规则 7：未经用户确认不得交付）。详见 LrtPluginExecutor 类注释。
        if (lower.startsWith("lrt://")) { return "lrt" }
        if (lower.startsWith("quota_reset://")) { return "quota_reset" }
        return ""
    }

    public static func parsePath(taskUri: String): String {
        let lower = taskUri.toAsciiLower()
        if (lower.startsWith("script://")) { return taskUri[9..] }
        if (lower.startsWith("builtin://")) { return taskUri[10..] }
        if (lower.startsWith("evaluation://")) { return taskUri[13..] }
        if (lower.startsWith("skill-curator://")) { return taskUri[16..] }
        if (lower.startsWith("agent_execution://")) { return taskUri[18..] }
        // "lrt://" 前缀长 6 个字符
        if (lower.startsWith("lrt://")) { return taskUri[6..] }
        if (lower.startsWith("quota_reset://")) { return taskUri[15..] }
        if (lower.startsWith("http://")) { return taskUri }
        if (lower.startsWith("https://")) { return taskUri }
        return taskUri
    }

    public func getRegisteredSchemes(): ArrayList<String> {
        let result = ArrayList<String>()
        for ((k, _) in executors) {
            result.add(k)
        }
        result
    }
}
