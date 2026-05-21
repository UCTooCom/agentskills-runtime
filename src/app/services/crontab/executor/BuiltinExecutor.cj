package magic.app.services.crontab.executor

import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import std.regex.Regex
import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.app.services.crontab.executor.builtin.BuiltinTaskHandler

public class BuiltinExecutor <: CrontabExecutor {
    public prop scheme: String {
        get() { "builtin" }
    }

    private let builtinTasks = ConcurrentHashMap<String, BuiltinTaskHandler>()

    public func registerBuiltinTask(name: String, handler: BuiltinTaskHandler): Unit {
        builtinTasks.put(name, handler)
        LogUtils.info("BuiltinExecutor", "注册内置任务: ${name}")
    }

    public func unregisterBuiltinTask(name: String): Unit {
        builtinTasks.remove(name)
        LogUtils.info("BuiltinExecutor", "注销内置任务: ${name}")
    }

    public func getRegisteredTasks(): ArrayList<String> {
        let result = ArrayList<String>()
        for ((k, _) in builtinTasks) {
            result.add(k)
        }
        result
    }

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let taskName = ExecutorRegistry.parsePath(context.taskUri)

        let handlerOpt = builtinTasks.get(taskName)
        match (handlerOpt) {
            case Some(handler) =>
                try {
                    return handler.handle(context)
                } catch (e: Exception) {
                    LogUtils.error("BuiltinExecutor", "内置任务执行异常: ${taskName}, ${e.message}")
                    return ExecutionResult.failureResult(e.message, 0, -1)
                }
            case None =>
                LogUtils.error("BuiltinExecutor", "未注册的内置任务: ${taskName}")
                return ExecutionResult.failureResult("未注册的内置任务: ${taskName}", 0, -1)
        }
    }

    public func validate(taskUri: String): Bool {
        let name = ExecutorRegistry.parsePath(taskUri)
        if (name.isEmpty()) { return false }
        let validPattern = Regex("^[a-zA-Z0-9-]+$")
        if (!validPattern.matches(name)) { return false }
        return builtinTasks.contains(name)
    }
}
