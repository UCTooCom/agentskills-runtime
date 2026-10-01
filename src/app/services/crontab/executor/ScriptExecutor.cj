package magic.app.services.crontab.executor

import std.time.DateTime
import std.process.{executeWithOutput, ProcessRedirect}
import std.env.getVariables
import std.collection.HashMap
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

            // 加固（2026-09-22）：显式注入子进程环境（父进程全量 + UTF-8 输出强制项），
            // 详见 childEnv() 注释；stdout/stderr 改走宽松解码，详见 decodeOutput()。
            let (exitCode, stdout, stderr) = executeWithOutput(
                command,
                args,
                environment: ScriptExecutor.childEnv(),
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )

            let output = ScriptExecutor.decodeOutput(stdout)
            let errOutput = ScriptExecutor.decodeOutput(stderr)
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

    /// 构造子进程环境变量：继承父进程全量变量，并追加 UTF-8 输出强制项。
    ///
    /// 根因（2026-09-22）：Windows 上子进程（尤其 Python）默认按 GBK(cp936) 写
    /// stdout/stderr；旧实现用 String.fromUtf8 严格解码，遇非 UTF-8 字节抛
    /// "Invalid utf8 byte sequence"，异常冒泡到外层 catch —— 一个**退出码 0 的脚本
    /// 被报成失败**，且错误信息完全误导排查方向。
    ///
    /// 为什么必须手工带上 getVariables()：executeWithOutput 的 environment 形参是
    /// **整体替换**而非合并（同 utils/os.cj 手写合并父环境的做法），只塞两个键会丢掉
    /// PATH，导致 `script://python3 xxx.py` 之类的命令直接找不到可执行文件。
    ///
    /// PYTHONIOENCODING/PYTHONUTF8 只对 Python 子进程生效，其它解释器/可执行文件
    /// 忽略这两个键，无副作用。
    private static func childEnv(): HashMap<String, String> {
        let allEnv = HashMap(getVariables())
        let utf8Defaults: Array<(String, String)> = [("PYTHONIOENCODING", "utf-8"), ("PYTHONUTF8", "1")]
        allEnv.add(all: utf8Defaults)
        return allEnv
    }

    /// 宽松解码子进程输出：UTF-8 严格解码失败时退化为 unchecked 解码
    /// （产生 mojibake 但不丢内容、不抛异常），避免一次编码问题让整段输出丢失、
    /// 甚至让已成功的脚本被判为失败。
    ///
    /// 与 src/tool/python_executor_tool.cj（2026-09-20 修复）、src/tool/cli_tool.cj
    /// 采用同一套降级策略。注：ScriptExecutor 拿到的是一次性完整字节数组，
    /// 不存在流式读取的「多字节字符跨 4096 块边界」问题，故无需分块处理。
    private static func decodeOutput(bytes: Array<Byte>): String {
        if (bytes.size == 0) {
            return ""
        }
        let text = try {
            String.fromUtf8(bytes)
        } catch (_: Exception) {
            unsafe { String.fromUtf8Unchecked(bytes) }
        }
        return text
    }

    public func validate(taskUri: String): Bool {
        let path = ExecutorRegistry.parsePath(taskUri)
        if (path.isEmpty()) { return false }
        if (path.contains("..")) { return false }
        let command = path.split(" ", 2)[0]
        return command.size > 0
    }
}
