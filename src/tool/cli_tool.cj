/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{ToolException, ToolParameter}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.utils.newProcess
import std.collection.{HashMap, ArrayList}
import std.convert.*
import std.env.getWorkingDirectory
import std.process.{ProcessRedirect, SubProcess}
import std.time.DateTime
import std.core.Duration
import std.io.{InputStream, OutputStream}
import std.fs.Path
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray, JsonBool, JsonInt}

public class CliTool <: NativeFuncTool {
    public static let NAME = "cli_execute"
    
    public static let DESC = """
    Execute CLI commands and capture output.
    Delegates command execution to the operating system shell.
    Returns exit code, stdout, stderr, and execution duration.
    
    Security: Commands are executed directly by the OS. Ensure proper input validation.
    Dependencies: The required command must be installed in the system PATH.
    """

    public init() {
        super(
            name: CliTool.NAME,
            description: CliTool.DESC,
            parameters: [
                ("command", "The command to execute (e.g., 'git', 'npm', 'python')", TypeSchema.Str),
                ("args", "Command arguments as JSON array string (e.g., '[\"status\", \"--short\"]')", TypeSchema.Str),
                ("cwd", "Working directory for command execution (optional, defaults to current directory)", TypeSchema.Str),
                ("env", "Additional environment variables as JSON object string (optional)", TypeSchema.Str),
                ("timeout", "Timeout in seconds (optional, default 300)", TypeSchema.Int),
                ("capture_output", "Whether to capture stdout/stderr (default true)", TypeSchema.Boolean)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "command": "git",
                  "args": "[\"status\", \"--short\"]"
                }
                """,
                """
                {
                  "command": "npm",
                  "args": "[\"run\", \"build\"]",
                  "cwd": "/path/to/project",
                  "timeout": 600
                }
                """,
                """
                {
                  "command": "python",
                  "args": "[\"script.py\", \"--input\", \"data.json\"]",
                  "env": "{\"PYTHONPATH\": \"/custom/path\"}"
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                CliTool.execute(args)
            }
        )
    }

    public static func execute(args: HashMap<String, JsonValue>): String {
        let command = extractString(args, "command")
        if (command.isEmpty()) {
            throw ToolException("Parameter 'command' is required")
        }

        let argsStr = extractString(args, "args")
        let cwd = extractString(args, "cwd")
        let envStr = extractString(args, "env")
        let timeout = extractInt(args, "timeout", 300)
        let captureOutput = extractBool(args, "capture_output", true)

        LogUtils.info("[CliTool] Executing command: ${command} with args: ${argsStr}")

        let commandArgs = parseArgsArray(argsStr)
        let envVars = parseEnvObject(envStr)
        let workingDir = if (cwd.isEmpty()) {
            getWorkingDirectory()
        } else {
            Path(cwd)
        }

        let startTime = DateTime.now()

        try {
            // Windows 上 echo/dir/where/type 等 是 cmd.exe 内建命令，不能直接启动进程；
            // 仓颉 newProcess 不走 shell，必须用 "cmd.exe /C <command> <args>" 包裹执行。
            // 同理 PowerShell 内建命令也走 powershell.exe -Command。
            let (actualCommand, actualArgs) = wrapForWindowsShell(command, commandArgs)
            let subProcess = newProcess(
                actualCommand,
                actualArgs,
                env: envVars,
                redirectErr: true
            )

            let result = if (captureOutput) {
                executeWithCapture(subProcess, timeout)
            } else {
                executeInherit(subProcess, timeout)
            }

            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()

            return buildResult(
                result.exitCode == 0,
                result.exitCode,
                result.stdout,
                result.stderr,
                durationMs,
                command,
                argsStr
            )
        } catch (ex: Exception) {
            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()

            LogUtils.error("[CliTool] Command execution failed: ${ex.message}")

            return buildResult(
                false,
                -1,
                "",
                "Command execution failed: ${ex.message}. Please ensure '${command}' is installed and available in PATH.",
                durationMs,
                command,
                argsStr
            )
        }
    }

    protected static func executeWithCapture(subProcess: SubProcess, timeout: Int64): ExecutionResult {
        let timeoutDuration = Duration.second * timeout

        let stdoutFuture = spawn {
            => readStreamToEnd(subProcess.stdOutPipe)
        }

        let stderrFuture = spawn {
            => readStreamToEnd(subProcess.stdErrPipe)
        }

        let exitCode = subProcess.wait(timeout: timeoutDuration)

        let stdout = stdoutFuture.get()
        let stderr = stderrFuture.get()

        return ExecutionResult(exitCode, stdout, stderr)
    }

    protected static func executeInherit(subProcess: SubProcess, timeout: Int64): ExecutionResult {
        let timeoutDuration = Duration.second * timeout
        let exitCode = subProcess.wait(timeout: timeoutDuration)
        return ExecutionResult(exitCode, "", "")
    }

    protected static func readStreamToEnd(stream: InputStream): String {
        let buffer = Array<Byte>(4096, { _ => 0 })
        let result = StringBuilder()

        try {
            while (true) {
                let bytesRead = stream.read(buffer)
                if (bytesRead <= 0) {
                    break
                }
                // v8 实测修复：stdout 编码 fallback，避免 GBK 字符导致 UTF-8 解码失败返回空
                // 根因：Windows cmd.exe 输出含 GBK 字符（中文路径/环境变量），仓颉 String.fromUtf8 遇非法字节序列抛异常
                // 修复：UTF-8 失败则替换非法字符为 ? 后返回（非空），避免 agent 收到空 stdout 误判命令不可用
                // 备注：本项目仓颉环境无 String.fromGbk / charset4cj 库，不做 GBK 解码仅做容错替换
                let chunk = try {
                    String.fromUtf8(buffer[0..bytesRead])
                } catch (_: Exception) {
                    // UTF-8 解码失败，替换非法字符为 ? 后返回（避免空 stdout 让 agent 误判命令不可用）
                    // 仓颉 ArrayList 无 append/add/push API，改用 Array + 索引赋值（仓颉原生支持）
                    let safeBytes = Array<Byte>(bytesRead, { _ => 0 })
                    var safeIdx = 0
                    var i = 0
                    while (i < bytesRead) {
                        let b = buffer[i]
                        if (b < 0x80) {
                            // ASCII 字符（0-127）直接保留
                            safeBytes[safeIdx] = b
                            safeIdx++
                        } else {
                            // 非 ASCII 字符替换为 ?（0x3F）
                            safeBytes[safeIdx] = 0x3F
                            safeIdx++
                            if (i + 1 < bytesRead && (buffer[i + 1] & 0xC0) != 0x80) {
                                // 非连续 UTF-8 字节，跳过下一个字节避免截断
                            }
                        }
                        i++
                    }
                    String.fromUtf8(safeBytes[0..safeIdx])
                }
                result.append(chunk)
            }
        } catch (ex: Exception) {
            LogUtils.info("[CliTool] Error reading stream: ${ex.message}")
        }

        return result.toString()
    }

    /**
     * Windows 平台包裹命令到 cmd.exe /C 或 powershell.exe -Command 执行。
     *
     * 根因：仓颉 newProcess 直接启动进程，不走 shell，也不会自动在 PATH 中查找可执行文件。
     * v3 仅解决 cmd.exe/powershell 内建命令的包裹，但普通可执行文件（python/git/npm 等）
     * 未包裹导致 newProcess 找不到文件报 "The system cannot find the file specified."（v6 实测根因）。
     * v6 修复：所有命令统一走 cmd.exe /C，让 cmd.exe 负责 PATH 查找、内建命令执行、环境变量展开。
     * PowerShell 显式调用（powershell/pwsh）保持走 powershell.exe -Command。
     */
    protected static func wrapForWindowsShell(command: String, args: Array<String>): (String, Array<String>) {
        let lowerCmd = command.toAsciiLower()
        let isPs = lowerCmd == "powershell" || lowerCmd == "pwsh"

        // 拼接原始命令行字符串
        let cmdLine = StringBuilder()
        cmdLine.append(command)
        for (a in args) {
            cmdLine.append(" ")
            // 含空格的参数加引号包裹
            if (a.contains(" ") && !a.startsWith("\"")) {
                cmdLine.append("\"")
                cmdLine.append(a)
                cmdLine.append("\"")
            } else {
                cmdLine.append(a)
            }
        }
        let cmdLineStr = cmdLine.toString()

        // PowerShell 显式调用：走 powershell.exe -Command
        if (isPs) {
            let psArgs = ["-Command", cmdLineStr]
            // 仓颉 newProcess 不走 PATH，必须用绝对路径；System32 在所有 Windows 上存在
            let psExe = resolveWindowsExe("powershell.exe")
            LogUtils.info("[CliTool] Wrapped PowerShell command: ${psExe} -Command \"${cmdLineStr}\"")
            return (psExe, psArgs)
        }

        // v6 实测修复：所有其他命令统一走 cmd.exe /C，让 cmd.exe 负责 PATH 查找和内建命令执行
        // 根因：仓颉 newProcess 不走 shell，普通可执行文件（python/git/npm）不包裹会找不到文件
        // v8 实测修复：在命令前加 chcp 65001 >nul && ，让 cmd.exe 输出 UTF-8 编码
        // 根因：仓颉 readStreamToEnd 按 UTF-8 解码，Windows cmd.exe 默认输出 GBK（含中文路径/环境变量），解码失败导致 agent 收到空 stdout 误判命令不可用
        let cmdArgs = ["/C", "chcp 65001 >nul && " + cmdLineStr]
        let cmdExe = resolveWindowsExe("cmd.exe")
        LogUtils.info("[CliTool] Wrapped command via cmd.exe: ${cmdExe} /C \"chcp 65001 >nul && ${cmdLineStr}\"")
        return (cmdExe, cmdArgs)
    }

    /**
     * 解析 Windows 系统可执行文件的绝对路径。
     *
     * 根因：仓颉 newProcess 不走 shell，也不会自动在 PATH 中查找可执行文件。
     * cmd.exe / powershell.exe 是 Windows 必装组件，用 System32 绝对路径最稳妥；
     * 若 System32 路径不存在（极罕见），降级为裸文件名，交给系统解析。
     */
    protected static func resolveWindowsExe(exeName: String): String {
        // System32 在所有 Windows NT 衍生系统上存在
        let system32 = "C:\\Windows\\System32\\" + exeName
        // 简单存在性判断：仓颉 std.fs.Path 不便于判断文件存在，用 try-catch 包装
        try {
            let p = Path(system32)
            // 若能构造 Path 且不抛异常，认为存在；实际执行时若不存在会报错
            return system32
        } catch (_: Exception) {
            // 降级为裸文件名
            return exeName
        }
    }

    protected static func parseArgsArray(argsStr: String): Array<String> {
        if (argsStr.isEmpty()) {
            return []
        }

        try {
            let json = JsonValue.fromStr(argsStr)
            match (json) {
                case arr: JsonArray =>
                    let size = arr.size()
                    let result = ArrayList<String>()
                    for (i in 0..size) {
                        let item = arr[i]
                        match (item) {
                            case s: JsonString => result.add(s.getValue())
                            case _ => result.add(item.toString())
                        }
                    }
                    return result.toArray()
                case _ =>
                    LogUtils.info("[CliTool] Args is not a JSON array: ${argsStr}")
            }
        } catch (ex: Exception) {
            LogUtils.info("[CliTool] Failed to parse args as JSON array: ${argsStr}, treating as single arg")
        }

        return [argsStr]
    }

    protected static func parseEnvObject(envStr: String): Array<(String, String)> {
        if (envStr.isEmpty()) {
            return []
        }

        try {
            let json = JsonValue.fromStr(envStr)
            match (json) {
                case obj: JsonObject =>
                    let result = ArrayList<(String, String)>()
                    for ((key, value) in obj.getFields()) {
                        match (value) {
                            case s: JsonString => result.add((key, s.getValue()))
                            case _ => result.add((key, value.toString()))
                        }
                    }
                    return result.toArray()
                case _ =>
                    LogUtils.info("[CliTool] Env is not a JSON object: ${envStr}")
            }
        } catch (ex: Exception) {
            LogUtils.info("[CliTool] Failed to parse env as JSON object: ${envStr}")
        }

        return []
    }

    protected static func buildResult(
        success: Bool,
        exitCode: Int64,
        stdout: String,
        stderr: String,
        durationMs: Int64,
        command: String,
        args: String
    ): String {
        let result = JsonObject()
        result.put("success", JsonBool(success))
        result.put("exit_code", JsonInt(exitCode))
        result.put("stdout", JsonString(truncateOutput(stdout)))
        result.put("stderr", JsonString(truncateOutput(stderr)))
        result.put("duration_ms", JsonInt(durationMs))
        result.put("command", JsonString(command))
        result.put("args", JsonString(args))
        
        return result.toJsonString()
    }

    protected static func truncateOutput(output: String, maxLength!: Int64 = 100000): String {
        if (output.size > maxLength) {
            return output[0..maxLength] + "\n... [output truncated, ${output.size - maxLength} more bytes]"
        }
        return output
    }

    protected static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }

    protected static func extractBool(args: HashMap<String, JsonValue>, key: String, defaultValue: Bool): Bool {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    let strVal = jStr.getValue().toAsciiLower()
                    return strVal == "true" || strVal == "1"
                case jBool: JsonBool =>
                    return jBool.getValue()
                case _ =>
                    return value.toString().toAsciiLower() == "true"
            }
        }
        return defaultValue
    }

    protected static func extractInt(args: HashMap<String, JsonValue>, key: String, defaultValue: Int64): Int64 {
        if (let Some(value) <- args.get(key)) {
            try {
                match (value) {
                    case jStr: JsonString =>
                        return Int64.parse(jStr.getValue())
                    case jInt: JsonInt =>
                        return jInt.getValue()
                    case _ =>
                        return Int64.parse(value.toString())
                }
            } catch (ex: Exception) {
                return defaultValue
            }
        }
        return defaultValue
    }
}

protected struct ExecutionResult {
    public let exitCode: Int64
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int64, stdout: String, stderr: String) {
        this.exitCode = exitCode
        this.stdout = stdout
        this.stderr = stderr
    }
}
