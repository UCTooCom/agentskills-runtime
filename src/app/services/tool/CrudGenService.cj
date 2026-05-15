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

/**
 * CrudGenService - CRUD代码生成服务
 *
 * 通过调用crudgen命令行工具生成CRUD代码
 */
public class CrudGenService {
    private let dbInfoService: DbInfoService

    public init() {
        this.dbInfoService = DbInfoService()
    }

    /**
     * 生成指定表的CRUD代码
     *
     * @param dbName 数据库名称
     * @param tableName 表名称
     * @return 生成结果，包含生成的各层文件路径
     */
    public func generateCrud(dbName: String, tableName: String): APIResult<CrudGenResult> {
        try {
            LogUtils.info("CrudGenService", "Generating CRUD for ${dbName}.${tableName}")

            let crudgenPath = getCrudgenPath()
            let args = ["--db", dbName, "--table", tableName]

            let execResult = executeCommand(crudgenPath, args)

            if (!execResult.success) {
                return APIResult<CrudGenResult>(false, "执行crudgen失败: ${execResult.error}")
            }

            let basePath = getCodeGenBasePath()
            let result = CrudGenResult()
            result.dbName = dbName
            result.tableName = tableName
            result.className = toPascalCase(tableName)
            result.modelFile = "${basePath}/src/app/models/${dbName}/${result.className}PO.cj"
            result.daoFile = "${basePath}/src/app/dao/${dbName}/${result.className}DAO.cj"
            result.serviceFile = "${basePath}/src/app/services/${dbName}/${result.className}Service.cj"
            result.controllerFile = "${basePath}/src/app/controllers/${dbName}/${tableName}/${result.className}Controller.cj"
            result.routeFile = "${basePath}/src/app/routes/${dbName}/${tableName}/${result.className}Route.cj"
            result.permissionGenerated = true
            result.fieldCount = 0
            result.output = execResult.output

            LogUtils.info("CrudGenService", "CRUD generated successfully for ${dbName}.${tableName}")

            return APIResult<CrudGenResult>(result)
        } catch (e: Exception) {
            LogUtils.error("CrudGenService", "Failed to generate CRUD: ${e.message}")
            return APIResult<CrudGenResult>(false, "生成CRUD失败: ${e.message}")
        }
    }

    private func getCodeGenBasePath(): String {
        let codeGenPath = getEnv("CODE_GEN_BASE_PATH")
        if (codeGenPath.isSome()) {
            let path = codeGenPath.getOrThrow()
            if (!path.isEmpty()) {
                LogUtils.info("CrudGenService", "Using CODE_GEN_BASE_PATH: ${path}")
                return path
            }
        }
        
        let workDir = getWorkingDirectory()
        let workDirStr = workDir.toString()
        LogUtils.info("CrudGenService", "Using working directory as CODE_GEN_BASE_PATH: ${workDirStr}")
        return workDirStr
    }

    /**
     * 生成所有表的CRUD代码
     *
     * @param dbName 数据库名称
     * @return 生成结果，包含所有生成的文件路径
     */
    public func generateAllCrud(dbName: String): APIResult<CrudGenAllResult> {
        try {
            LogUtils.info("CrudGenService", "Generating CRUD for all tables in ${dbName}")

            let tableNamesResult = dbInfoService.getDbTableList(dbName)
            if (!tableNamesResult.success || tableNamesResult.data.isNone()) {
                return APIResult<CrudGenAllResult>(false, "获取表列表失败: ${tableNamesResult.reason ?? '未知错误'}")
            }

            let tables = tableNamesResult.data.getOrThrow()
            let tableCount = tables.size

            if (tableCount == 0) {
                return APIResult<CrudGenAllResult>(false, "数据库 ${dbName} 中没有找到表")
            }

            let results = ArrayList<CrudGenResult>()
            let errors = ArrayList<String>()

            for (i in 0..tableCount) {
                let table = tables[i]
                let genResult = generateCrud(dbName, table.tableName)
                if (genResult.success) {
                    if (let Some(data) <- genResult.data) {
                        results.add(data)
                    }
                } else {
                    errors.add("${table.tableName}: ${genResult.reason ?? '未知错误'}")
                }
            }

            let allResult = CrudGenAllResult()
            allResult.dbName = dbName
            allResult.totalTables = Int32(tableCount)
            allResult.successCount = Int32(results.size)
            allResult.failCount = Int32(errors.size)
            allResult.results = results
            allResult.errors = errors

            LogUtils.info("CrudGenService", "CRUD generation completed: ${results.size}/${tableCount} succeeded")

            return APIResult<CrudGenAllResult>(allResult)
        } catch (e: Exception) {
            LogUtils.error("CrudGenService", "Failed to generate all CRUD: ${e.message}")
            return APIResult<CrudGenAllResult>(false, "批量生成CRUD失败: ${e.message}")
        }
    }

    private func getCrudgenPath(): String {
        let workDir = getWorkingDirectory()
        let workDirStr = workDir.toString()
        let basePath = if (workDirStr.contains(":")) {
            workDirStr
        } else {
            "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime"
        }
        return "${basePath}/target/release/bin/magic.app.tools.crudgen.exe"
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

            LogUtils.info("CrudGenService", "Command exited with code ${exitCode} in ${durationMs}ms")

            if (exitCode == 0) {
                return ExecResult(true, stdout, stderr, exitCode)
            } else {
                return ExecResult(false, stdout, stderr, exitCode)
            }
        } catch (e: Exception) {
            LogUtils.error("CrudGenService", "Command execution failed: ${e.message}")
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
            LogUtils.error("CrudGenService", "Error reading stream: ${e.message}")
        }

        return result.toString()
    }

    private func toPascalCase(name: String): String {
        let parts = name.split("_")
        var result = ""

        for (part in parts) {
            if (part.size > 0) {
                result = result + part[0..1].toAsciiUpper() + part[1..part.size].toAsciiLower()
            }
        }

        return result
    }
}

/**
 * CRUD生成结果
 */
public class CrudGenResult {
    public var dbName: String = ""
    public var tableName: String = ""
    public var className: String = ""
    public var modelFile: String = ""
    public var daoFile: String = ""
    public var serviceFile: String = ""
    public var controllerFile: String = ""
    public var routeFile: String = ""
    public var permissionGenerated: Bool = false
    public var fieldCount: Int32 = 0
    public var output: String = ""

    public init() {}
}

/**
 * 批量CRUD生成结果
 */
public class CrudGenAllResult {
    public var dbName: String = ""
    public var totalTables: Int32 = 0
    public var successCount: Int32 = 0
    public var failCount: Int32 = 0
    public var results: ArrayList<CrudGenResult> = ArrayList<CrudGenResult>()
    public var errors: ArrayList<String> = ArrayList<String>()

    public init() {}
}

/**
 * 命令执行结果
 */
class ExecResult {
    public let success: Bool
    public let output: String
    public let error: String
    public let exitCode: Int64

    public init(success: Bool, output: String, error: String, exitCode: Int64) {
        this.success = success
        this.output = output
        this.error = error
        this.exitCode = exitCode
    }
}
