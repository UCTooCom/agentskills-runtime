/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.tool

import magic.app.core.response.APIResult
import magic.log.LogUtils
import magic.utils.{newProcess, getEnv}
import std.collection.ArrayList
import std.convert.*
import std.env.getWorkingDirectory
import std.process.{ProcessRedirect, SubProcess}
import std.time.DateTime
import std.core.Duration
import std.io.InputStream
import std.fs.exists

/**
 * PluginGenService - 插件轨代码生成服务（plugingen）
 *
 * 与 CrudGenService（宿主模块轨，crudgen）/ WebCrudGenService（前端页面轨，crudweb）并列，
 * 本服务承担**插件轨**：调用 plugingen 可执行体产出 skills/{name}/ 下的插件工程。
 *
 * 与另两个服务的差异（也是本服务不能省掉参数的原因）：
 * - crudgen/crudweb 都是「按表名生成」，插件名 = 表名，界面点一下即可；
 * - plugingen 的**插件名与表名解耦**（如长程任务插件 long-running-task 并不存在同名表），
 *   且加载轨（sync/dylib/process）、是否顺带产出数据契约都是独立开关，
 *   所以必须由页面弹出表单收集参数，再由本服务拼装命令行。
 *
 * plugingen 参数契约（见 src/plugin/tools/plugingen/plugingen.cj）：
 *   --name <插件名>    必填，包名段（小写字母/数字/下划线，不以数字开头）
 *   --db <数据库名>    表驱动模式
 *   --table <表名>     表驱动模式（与 --tables 二选一）
 *   --tables <a,b,c>   多表，仅供 --contract-only
 *   --mode <轨>        sync（缺省）/ dylib / process（L3 进程隔离轨）
 *   --contract         额外产出 DATA_CONTRACT.yaml
 *   --contract-only    只产出 DATA_CONTRACT.yaml
 *   --blank            空白骨架（跳过表结构）
 *
 * 注意：process 轨不连 DB，plugingen 对 process+--contract 只打印提示并忽略，
 *      因此本服务在 process 轨下**不下发** --contract，避免误导调用方。
 */
public class PluginGenService {

    public init() {}

    /**
     * 生成插件
     *
     * @param pluginName 插件名（原始输入，内部做规范化：连字符转下划线 + 转小写）
     * @param dbName 数据库名
     * @param tableName 表名
     * @param mode 加载轨：sync / dylib / process
     * @param blank 是否只生成空白骨架
     * @param contract 是否额外产出 DATA_CONTRACT.yaml
     * @param contractOnly 是否只产出 DATA_CONTRACT.yaml
     * @return 生成结果
     */
    public func generatePlugin(
        pluginName: String,
        dbName: String,
        tableName: String,
        mode: String,
        blank: Bool,
        contract: Bool,
        contractOnly: Bool
    ): APIResult<PluginGenResult> {
        try {
            // ---- 1. 加载轨校验（与 plugingen 的 --mode 校验保持一致）----
            let modeFixed = mode.trimAscii().toAsciiLower()
            if (modeFixed != "sync" && modeFixed != "dylib" && modeFixed != "process") {
                return APIResult<PluginGenResult>(false, "加载轨 mode 仅支持 sync/dylib/process，当前值: ${mode}")
            }

            // ---- 2. 插件名规范化与校验（对齐 NameRules）----
            let rawName = pluginName.trimAscii()
            if (rawName.isEmpty()) {
                return APIResult<PluginGenResult>(false, "必须指定插件名 (--name)")
            }
            let normalized = rawName.replace("-", "_").toAsciiLower()
            if (!isValidPluginName(normalized)) {
                return APIResult<PluginGenResult>(
                    false,
                    "插件名 '${normalized}' 不是合法包名段（仅小写字母/数字/下划线，不以数字开头）"
                )
            }
            if (isReservedPluginName(normalized)) {
                return APIResult<PluginGenResult>(
                    false,
                    "插件名 '${normalized}' 是保留名（src/plugins/ 示例插件，禁止覆盖）"
                )
            }

            // ---- 3. 拼装命令行参数 ----
            let argsList = ArrayList<String>()
            argsList.add("--name")
            argsList.add(normalized)
            argsList.add("--mode")
            argsList.add(modeFixed)

            var emitContract = false
            var emitContractOnly = false

            if (blank) {
                // 空白骨架：不需要 db/table
                argsList.add("--blank")
            } else if (contractOnly) {
                // 只出契约骨架：需要 db + (table 或 tables)
                if (dbName.isEmpty() || tableName.isEmpty()) {
                    return APIResult<PluginGenResult>(false, "仅生成数据契约需要指定数据库名与表名")
                }
                if (modeFixed == "process") {
                    return APIResult<PluginGenResult>(
                        false,
                        "process 轨不连数据库，无法生成数据契约；请改用 sync 轨，或改用「表驱动 CRUD」"
                    )
                }
                argsList.add("--db")
                argsList.add(dbName)
                argsList.add("--table")
                argsList.add(tableName)
                argsList.add("--contract-only")
                emitContract = true
                emitContractOnly = true
            } else {
                // 表驱动 CRUD：需要 db + table
                if (dbName.isEmpty() || tableName.isEmpty()) {
                    return APIResult<PluginGenResult>(false, "表驱动模式必须指定数据库名与表名")
                }
                argsList.add("--db")
                argsList.add(dbName)
                argsList.add("--table")
                argsList.add(tableName)
                // process 轨下 plugingen 会忽略 --contract，这里干脆不下发
                if (contract && modeFixed != "process") {
                    argsList.add("--contract")
                    emitContract = true
                }
            }

            let args = argsList.toArray()

            // ---- 4. 执行 plugingen ----
            let plugingenPath = getPlugingenPath()
            LogUtils.info("PluginGenService", "Executing: ${plugingenPath} ${joinArgs(args)}")

            let execResult = executeCommand(plugingenPath, args)

            if (!execResult.success) {
                let detail = if (execResult.error.isEmpty()) { execResult.output } else { execResult.error }
                return APIResult<PluginGenResult>(false, "执行 plugingen 失败(exit=${execResult.exitCode}): ${trimMessage(detail)}")
            }

            // ---- 5. 组装返回结构 ----
            let basePath = getCodeGenBasePath()
            let result = PluginGenResult()
            result.pluginName = normalized
            result.dbName = dbName
            result.tableName = tableName
            result.mode = modeFixed
            result.blank = blank
            result.contractGenerated = emitContract
            result.contractOnly = emitContractOnly
            result.skillDir = "${basePath}/skills/${normalized}"
            result.pluginYamlFile = "${basePath}/skills/${normalized}/plugin.yaml"
            result.skillMdFile = "${basePath}/skills/${normalized}/SKILL.md"
            result.dataContractFile = if (emitContract) {
                Some<String>("${basePath}/skills/${normalized}/DATA_CONTRACT.yaml")
            } else {
                None<String>
            }
            result.command = "${plugingenPath} ${joinArgs(args)}"
            result.output = execResult.output

            LogUtils.info("PluginGenService", "Plugin '${normalized}' generated (mode=${modeFixed})")
            return APIResult<PluginGenResult>(result)
        } catch (e: Exception) {
            LogUtils.error("PluginGenService", "Failed to generate plugin: ${e.message}")
            return APIResult<PluginGenResult>(false, "生成插件失败: ${e.message}")
        }
    }

    /// 插件名合法性：小写字母/数字/下划线，首字符不为数字
    private func isValidPluginName(name: String): Bool {
        if (name.isEmpty()) {
            return false
        }
        let runes = name.toRuneArray()
        let first = runes[0]
        if (!((first >= r'a' && first <= r'z') || first == r'_')) {
            return false
        }
        for (ch in runes) {
            let ok = (ch >= r'a' && ch <= r'z') || (ch >= r'0' && ch <= r'9') || ch == r'_'
            if (!ok) {
                return false
            }
        }
        return true
    }

    /// 保留名保护（与 plugingen/NameRules.cj 的 RESERVED_PLUGIN_NAMES 一致）
    private func isReservedPluginName(name: String): Bool {
        name == "hello" || name == "doc_helper" || name == "doc-helper"
    }

    private func joinArgs(args: Array<String>): String {
        let sb = StringBuilder()
        for (i in 0..args.size) {
            sb.append(args[i])
            if (i < args.size - 1) {
                sb.append(" ")
            }
        }
        return sb.toString()
    }

    /// 错误信息裁剪：子进程输出可能很长，只回传尾部的有效信息
    private func trimMessage(msg: String): String {
        let text = msg.trimAscii()
        if (text.size <= 500) {
            return text
        }
        return text[text.size - 500..text.size]
    }

    private func getCodeGenBasePath(): String {
        let codeGenPath = getEnv("CODE_GEN_BASE_PATH")
        if (let Some(path) <- codeGenPath) {
            if (!path.isEmpty()) {
                LogUtils.info("PluginGenService", "Using CODE_GEN_BASE_PATH: ${path}")
                return path
            }
        }

        let workDir = getWorkingDirectory()
        let workDirStr = workDir.toString()
        LogUtils.info("PluginGenService", "Using working directory as CODE_GEN_BASE_PATH: ${workDirStr}")
        return workDirStr
    }

    /**
     * 定位 plugingen 可执行体
     *
     * 与 crudgen/crudweb 同构：优先 release，其次 debug；
     * 两者都不存在时仍返回 release 路径，让子进程报错信息暴露真实缺失位置。
     */
    private func getPlugingenPath(): String {
        let workDir = getWorkingDirectory()
        let workDirStr = workDir.toString()
        let basePath = if (workDirStr.contains(":")) {
            workDirStr
        } else {
            "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime"
        }
        let releasePath = "${basePath}/target/release/bin/magic.plugin.tools.plugingen.exe"
        let debugPath = "${basePath}/target/debug/bin/magic.plugin.tools.plugingen.exe"

        if (fileExists(releasePath)) {
            return releasePath
        } else if (fileExists(debugPath)) {
            return debugPath
        } else {
            LogUtils.error("PluginGenService", "plugingen executable not found at ${releasePath}")
            return releasePath
        }
    }

    private func fileExists(path: String): Bool {
        try {
            exists(path)
        } catch (_: Exception) {
            false
        }
    }

    private func executeCommand(command: String, args: Array<String>): ExecResult {
        let startTime = DateTime.now()

        try {
            let subProcess = newProcess(
                command,
                args,
                redirectErr: true
            )

            let timeoutDuration = Duration.second * 300

            let stdoutFuture = spawn {
                => readStreamToEnd(subProcess.stdOutPipe)
            }

            let stderrFuture = spawn {
                => readStreamToEnd(subProcess.stdErrPipe)
            }

            let exitCode = subProcess.wait(timeout: timeoutDuration)

            let stdout = stdoutFuture.get()
            let stderr = stderrFuture.get()

            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()

            LogUtils.info("PluginGenService", "Command exited with code ${exitCode} in ${durationMs}ms")

            if (exitCode == 0) {
                return ExecResult(true, stdout, stderr, exitCode)
            } else {
                return ExecResult(false, stdout, stderr, exitCode)
            }
        } catch (e: Exception) {
            LogUtils.error("PluginGenService", "Command execution failed: ${e.message}")
            return ExecResult(false, "", "Command execution failed: ${e.message}", -1)
        }
    }

    private func readStreamToEnd(stream: InputStream): String {
        let buffer = Array<Byte>(4096, { _ => 0 })
        let result = StringBuilder()

        try {
            while (true) {
                let bytesRead = stream.read(buffer)
                if (bytesRead <= 0) {
                    break
                }
                // 加固（2026-09-22）：生成器子进程输出可能是非 UTF-8 字节（Windows 默认
                // GBK/cp936），或中文多字节字符正好被 4096 块边界切断；旧实现直接
                // String.fromUtf8 会抛异常并中止整个读取循环，导致生成器输出被截断。
                // UTF-8 严格解码失败时退化为 unchecked 解码，保证内容不丢。
                // 同款策略见 src/tool/python_executor_tool.cj（2026-09-20 修复）。
                let chunk = try {
                    String.fromUtf8(buffer[0..bytesRead])
                } catch (_: Exception) {
                    unsafe { String.fromUtf8Unchecked(buffer[0..bytesRead]) }
                }
                result.append(chunk)
            }
        } catch (e: Exception) {
            LogUtils.error("PluginGenService", "Error reading stream: ${e.message}")
        }

        return result.toString()
    }
}

/**
 * 插件生成结果
 */
public class PluginGenResult {
    /// 规范化后的插件名（连字符已转下划线）
    public var pluginName: String = ""
    public var dbName: String = ""
    public var tableName: String = ""
    /// 加载轨：sync / dylib / process
    public var mode: String = ""
    /// 是否为空白骨架
    public var blank: Bool = false
    /// 是否产出了 DATA_CONTRACT.yaml
    public var contractGenerated: Bool = false
    /// 是否只产出契约（未生成代码）
    public var contractOnly: Bool = false
    /// 插件根目录（skills/{name}）
    public var skillDir: String = ""
    public var pluginYamlFile: String = ""
    public var skillMdFile: String = ""
    public var dataContractFile: Option<String> = None<String>
    /// 实际下发的命令行（便于页面回显与人工复盘）
    public var command: String = ""
    /// plugingen 的 stdout
    public var output: String = ""

    public init() {}
}
