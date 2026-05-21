package magic.app.services.crontab.executor

import std.time.DateTime
import std.process.{executeWithOutput, ProcessRedirect}
import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult, durationMsBetween}

public class ScriptExecutor <: CrontabExecutor {
    public prop scheme: String {
        get() { "script" }
    }

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()
        let scriptPath = ExecutorRegistry.parsePath(context.taskUri)

        if (scriptPath.contains("..")) {
            LogUtils.error("ScriptExecutor", "路径穿越检测: ${scriptPath}")
            return ExecutionResult.failureResult("路径穿越检测失败: ${scriptPath}", 0, -1)
        }

        try {
            let parts = scriptPath.split(" ", 2)
            let command = parts[0]
            let args = if (parts.size > 1) { [parts[1]] } else { Array<String>(0, {i => ""}) }

            let (exitCode, stdout, stderr) = executeWithOutput(
                command,
                args,
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )

            let output = String.fromUtf8(stdout)
            let errOutput = String.fromUtf8(stderr)
            let fullOutput = if (errOutput.size > 0) { output + "\n" + errOutput } else { output }
            let truncatedOutput = if (fullOutput.size > 2000) { fullOutput[0..2000] } else { fullOutput }

            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)

            if (exitCode == 0) {
                LogUtils.info("ScriptExecutor", "脚本执行成功: ${scriptPath}, 耗时: ${duration}ms")
                return ExecutionResult.successResult(truncatedOutput, duration, truncatedOutput[0..(if (truncatedOutput.size > 200) { 200 } else { truncatedOutput.size })])
            } else {
                LogUtils.error("ScriptExecutor", "脚本执行失败: ${scriptPath}, exitCode: ${exitCode}")
                return ExecutionResult.failureResult(truncatedOutput, duration, Int32(exitCode))
            }
        } catch (e: Exception) {
            let endTime = DateTime.now()
            let duration = durationMsBetween(startTime, endTime)
            LogUtils.error("ScriptExecutor", "脚本执行异常: ${e.message}")
            return ExecutionResult.failureResult(e.message, duration, -1)
        }
    }

    public func validate(taskUri: String): Bool {
        let path = ExecutorRegistry.parsePath(taskUri)
        if (path.isEmpty()) { return false }
        if (path.contains("..")) { return false }
        let command = path.split(" ", 2)[0]
        return command.size > 0
    }
}
