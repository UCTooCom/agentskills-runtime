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
import std.fs.{Path, FileInfo, exists}
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
        // Ch0.4 修复：与 CliTool 完全同源的 cwd 死代码缺陷。
        // 旧代码算出 workingDir 后**从未透传给 newProcess**，子进程 CWD 恒为
        // runtime 根目录 → D 层脚本（scripts/*.py）里的相对路径读写必然落到错误位置。
        // 现做 exists + isDirectory 校验后真正透传，行为与 CliTool.resolveWorkingDirectory 对齐。
        let workingDir: ?Path = PythonExecutorTool.resolveWorkingDirectory(cwd)

        let startTime = DateTime.now()

        try {
            let subProcess = newProcess(
                pythonCmd,
                commandArgs,
                env: envVars,
                redirectErr: true,
                workingDirectory: workingDir
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
                pythonCmd,
                cwd: cwd,
                cwdApplied: cwd.isEmpty() || workingDir.isSome()
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
                pythonCmd,
                cwd: cwd,
                cwdApplied: false
            )
        }
    }

    /**
     * 把 cwd 参数解析成子进程工作目录（Ch0.4 新增）。
     *
     * 与 `CliTool.resolveWorkingDirectory` 语义完全对齐：
     *   - 空字符串 → None（未指定，子进程继承 runtime 当前目录）
     *   - 存在的目录 → Some(Path)
     *   - 不存在 / 非目录 / 解析异常 → None，并记日志，调用方退化为进程当前工作目录
     *
     * 约束（依据 std.process.launch 文档）：workingDirectory 必须是**存在的目录**，
     * 否则 launch 直接抛异常。因此这里必须先校验，不能把裸字符串丢给 launch。
     */
    protected static func resolveWorkingDirectory(cwd: String): ?Path {
        if (cwd.isEmpty()) {
            return None<Path>
        }
        try {
            if (exists(cwd) && FileInfo(cwd).isDirectory()) {
                LogUtils.info("[PythonExecutorTool] Using working directory: ${cwd}")
                return Some(Path(cwd))
            }
            LogUtils.info("[PythonExecutorTool] cwd is not an existing directory, fallback to process working directory: ${cwd}")
            return None<Path>
        } catch (ex: Exception) {
            LogUtils.info("[PythonExecutorTool] Failed to resolve cwd '${cwd}': ${ex.message}, fallback to process working directory")
            return None<Path>
        }
    }

    protected static func determinePythonCommand(pythonPath: String, venvPath: String): String {
        if (!pythonPath.isEmpty()) {
            return pythonPath
        }

        if (!venvPath.isEmpty()) {
            // Ch0.4 修复：虚拟环境解释器路径随平台而变。
            // 旧代码硬编码 `bin/python`（仅 Unix/macOS），Windows 下 venv 是 `Scripts\python.exe`，
            // 结果必然启动失败。现按平台选择。
            return determineVenvPython(venvPath)
        }

        return "python"
    }

    /// Windows：venv 布局为 `Scripts\python.exe`
    @When[os == "Windows"]
    protected static func determineVenvPython(venvPath: String): String {
        return Path(venvPath).join("Scripts").join("python.exe").toString()
    }

    /// 非 Windows：venv 布局为 `bin/python`
    @When[os != "Windows"]
    protected static func determineVenvPython(venvPath: String): String {
        return Path(venvPath).join("bin").join("python").toString()
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
        pythonCmd: String,
        cwd!: String = "",
        cwdApplied!: Bool = true
    ): String {
        let result = JsonObject()
        result.put("success", JsonBool(success))
        result.put("exit_code", JsonInt(exitCode))
        result.put("stdout", JsonString(truncateOutput(stdout)))
        result.put("stderr", JsonString(truncateOutput(stderr)))
        result.put("duration_ms", JsonInt(durationMs))
        result.put("script_path", JsonString(scriptPath))
        result.put("python_cmd", JsonString(pythonCmd))
        // Ch0.4：把工作目录回显给 agent，让它能自己判断 cwd 是否生效
        // （此前 cwd 是死代码，agent 只能靠试错发现"相对路径被解析到 runtime 根目录"）
        let cwdDesc = if (cwd.isEmpty()) { getWorkingDirectory().toString() } else { cwd }
        result.put("cwd", JsonString(cwdDesc))
        result.put("cwd_applied", JsonBool(cwdApplied))

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
