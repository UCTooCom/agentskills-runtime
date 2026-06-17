/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.tool

import magic.app.core.response.APIResult
import magic.app.services.uctoo.DbInfoService
import magic.log.LogUtils
import magic.utils.{newProcess, getEnv}
import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.env.getWorkingDirectory
import std.process.{ProcessRedirect, SubProcess}
import std.time.DateTime
import std.core.Duration
import std.io.{InputStream}
import std.fs.File

/**
 * WebCrudGenService - Web CRUD页面生成服务
 *
 * 通过调用crudweb命令行工具生成Web CRUD页面代码
 */
public class WebCrudGenService {
    private let dbInfoService: DbInfoService

    public init() {
        this.dbInfoService = DbInfoService()
    }

    /**
     * 生成指定表的Web CRUD页面
     * @param dbName 数据库名称
     * @param tableName 表名称
     * @return 生成结果
     */
    public func generateWeb(dbName: String, tableName: String): Bool {
        try {
            LogUtils.info("WebCrudGenService", "开始生成 ${dbName}.${tableName} 的Web页面")

            let crudwebPath = getCrudwebPath()
            let args = ["--db", dbName, "--table", tableName]

            let execResult = executeCommand(crudwebPath, args)

            if (execResult.success) {
                LogUtils.info("WebCrudGenService", "成功生成 ${dbName}.${tableName} 的Web页面")
                true
            } else {
                LogUtils.error("WebCrudGenService", "生成Web页面失败: ${execResult.error}")
                false
            }
        } catch (e: Exception) {
            LogUtils.error("WebCrudGenService", "生成Web页面异常: ${e.message}")
            false
        }
    }

    /**
     * 批量生成所有表的Web CRUD页面
     * @param dbName 数据库名称
     * @return 生成结果
     */
    public func generateAllWeb(dbName: String): Bool {
        try {
            LogUtils.info("WebCrudGenService", "开始批量生成 ${dbName} 的Web页面")

            let crudwebPath = getCrudwebPath()
            let args = ["--db", dbName, "--all"]

            let execResult = executeCommand(crudwebPath, args)

            if (execResult.success) {
                LogUtils.info("WebCrudGenService", "成功批量生成 ${dbName} 的Web页面")
                true
            } else {
                LogUtils.error("WebCrudGenService", "批量生成Web页面失败: ${execResult.error}")
                false
            }
        } catch (e: Exception) {
            LogUtils.error("WebCrudGenService", "批量生成Web页面异常: ${e.message}")
            false
        }
    }

    private func getCrudwebPath(): String {
        let workDir = getWorkingDirectory()
        let workDirStr = workDir.toString()
        let basePath = if (workDirStr.contains(":")) {
            workDirStr
        } else {
            "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime"
        }
        // 先尝试 debug 版本，再尝试 release 版本
        let debugPath = "${basePath}/target/debug/bin/magic.app.tools.crudweb.exe"
        let releasePath = "${basePath}/target/release/bin/magic.app.tools.crudweb.exe"
        
        if (fileExists(debugPath)) {
            println("Using debug version: ${debugPath}")
            return debugPath
        } else if (fileExists(releasePath)) {
            println("Using release version: ${releasePath}")
            return releasePath
        } else {
            println("Warning: crudweb executable not found, using default path")
            return releasePath
        }
    }
    
    private func fileExists(path: String): Bool {
        try {
            let _ = File.readFrom(path)
            true
        } catch (e: Exception) {
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

            LogUtils.info("WebCrudGenService", "Command exited with code ${exitCode} in ${durationMs}ms")

            if (exitCode == 0) {
                return ExecResult(true, stdout, stderr, exitCode)
            } else {
                return ExecResult(false, stdout, stderr, exitCode)
            }
        } catch (e: Exception) {
            LogUtils.error("WebCrudGenService", "Command execution failed: ${e.message}")
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
                result.append(String.fromUtf8(buffer[0..bytesRead]))
            }
        } catch (e: Exception) {
            LogUtils.error("WebCrudGenService", "Error reading stream: ${e.message}")
        }

        return result.toString()
    }
}

