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
            let subProcess = newProcess(
                command,
                commandArgs,
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
                let chunk = String.fromUtf8(buffer[0..bytesRead])
                result.append(chunk)
            }
        } catch (ex: Exception) {
            LogUtils.info("[CliTool] Error reading stream: ${ex.message}")
        }
        
        return result.toString()
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
