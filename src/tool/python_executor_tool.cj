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

public class PythonExecutorTool <: NativeFuncTool {
    public static let NAME = "python_execute"
    
    public static let DESC = """
    Execute Python scripts and capture output.
    Delegates execution to the operating system's Python interpreter.
    Supports virtual environments and custom Python paths.
    
    Requirements: Python must be installed and available in system PATH.
    """

    public init() {
        super(
            name: PythonExecutorTool.NAME,
            description: PythonExecutorTool.DESC,
            parameters: [
                ("script_path", "Path to the Python script to execute", TypeSchema.Str),
                ("args", "Command line arguments as JSON array string (optional)", TypeSchema.Str),
                ("env", "Additional environment variables as JSON object string (optional)", TypeSchema.Str),
                ("cwd", "Working directory for script execution (optional)", TypeSchema.Str),
                ("timeout", "Timeout in seconds (optional, default 300)", TypeSchema.Int),
                ("python_path", "Path to Python interpreter (optional, defaults to 'python' or 'python3')", TypeSchema.Str),
                ("venv_path", "Path to virtual environment directory (optional)", TypeSchema.Str),
                ("capture_output", "Whether to capture stdout/stderr (default true)", TypeSchema.Boolean)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "script_path": "/path/to/script.py"
                }
                """,
                """
                {
                  "script_path": "/path/to/script.py",
                  "args": "[\"--input\", \"data.json\", \"--verbose\"]",
                  "timeout": 600
                }
                """,
                """
                {
                  "script_path": "/path/to/script.py",
                  "venv_path": "/path/to/venv",
                  "env": "{\"DEBUG\": \"true\"}"
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                PythonExecutorTool.execute(args)
            }
        )
    }

    public static func execute(args: HashMap<String, JsonValue>): String {
        let scriptPath = extractString(args, "script_path")
        if (scriptPath.isEmpty()) {
            throw ToolException("Parameter 'script_path' is required")
        }

        let argsStr = extractString(args, "args")
        let envStr = extractString(args, "env")
        let cwd = extractString(args, "cwd")
        let timeout = extractInt(args, "timeout", 300)
        let pythonPath = extractString(args, "python_path")
        let venvPath = extractString(args, "venv_path")
        let captureOutput = extractBool(args, "capture_output", true)

        LogUtils.info("[PythonExecutorTool] Executing script: ${scriptPath}")

        let pythonCmd = determinePythonCommand(pythonPath, venvPath)
        let commandArgs = buildCommandArgs(scriptPath, argsStr)
        let envVars = parseEnvObject(envStr)
        let workingDir = if (cwd.isEmpty()) {
            getWorkingDirectory()
        } else {
            Path(cwd)
        }

        let startTime = DateTime.now()

        try {
            let subProcess = newProcess(
                pythonCmd,
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
                scriptPath,
                pythonCmd
            )
        } catch (ex: Exception) {
            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()

            LogUtils.error("[PythonExecutorTool] Script execution failed: ${ex.message}")

            return buildResult(
                false,
                -1,
                "",
                "Python script execution failed: ${ex.message}. Please ensure Python is installed and '${scriptPath}' exists.",
                durationMs,
                scriptPath,
                pythonCmd
            )
        }
    }

    protected static func determinePythonCommand(pythonPath: String, venvPath: String): String {
        if (!pythonPath.isEmpty()) {
            return pythonPath
        }

        if (!venvPath.isEmpty()) {
            let venvPython = Path(venvPath).join("bin").join("python").toString()
            return venvPython
        }

        return "python"
    }

    protected static func buildCommandArgs(scriptPath: String, argsStr: String): Array<String> {
        let result = ArrayList<String>()
        result.add(scriptPath)

        let scriptArgs = parseArgsArray(argsStr)
        result.add(all: scriptArgs)

        return result.toArray()
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
            LogUtils.info("[PythonExecutorTool] Error reading stream: ${ex.message}")
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
                    LogUtils.info("[PythonExecutorTool] Args is not a JSON array: ${argsStr}")
            }
        } catch (ex: Exception) {
            LogUtils.info("[PythonExecutorTool] Failed to parse args as JSON array: ${argsStr}")
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
                    LogUtils.info("[PythonExecutorTool] Env is not a JSON object: ${envStr}")
            }
        } catch (ex: Exception) {
            LogUtils.info("[PythonExecutorTool] Failed to parse env as JSON object: ${envStr}")
        }

        return []
    }

    protected static func buildResult(
        success: Bool,
        exitCode: Int64,
        stdout: String,
        stderr: String,
        durationMs: Int64,
        scriptPath: String,
        pythonCmd: String
    ): String {
        let result = JsonObject()
        result.put("success", JsonBool(success))
        result.put("exit_code", JsonInt(exitCode))
        result.put("stdout", JsonString(truncateOutput(stdout)))
        result.put("stderr", JsonString(truncateOutput(stderr)))
        result.put("duration_ms", JsonInt(durationMs))
        result.put("script_path", JsonString(scriptPath))
        result.put("python_cmd", JsonString(pythonCmd))
        
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
