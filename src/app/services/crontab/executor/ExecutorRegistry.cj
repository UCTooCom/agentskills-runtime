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
        return ""
    }

    public static func parsePath(taskUri: String): String {
        let lower = taskUri.toAsciiLower()
        if (lower.startsWith("script://")) { return taskUri[9..] }
        if (lower.startsWith("builtin://")) { return taskUri[10..] }
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
