/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{Tool, ToolManager, ToolException, ToolResponse}
import magic.app.services.tool.ToolAuditService
import magic.app.services.uctoo.{UserHasRolesService, RoleHasPermissionService}
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt, JsonArray}

/**
 * ToolDispatcher - 工具调度器
 * 
 * 负责接收和处理工具调用请求，支持CLI、HTTP和内部API三种调用方式
 * 集成数据库审计，将工具调用记录到operate_log表
 * 使用依赖注入的 PermissionProvider，避免直接依赖 app.services.uctoo
 */
public class ToolDispatcher {
    private let toolManager: ToolManager
    private let permissionChecker: PermissionChecker
    private let auditService: ToolAuditService
    
    public init(
        toolManager: ToolManager,
        userHasRolesService: UserHasRolesService,
        roleHasPermissionService: RoleHasPermissionService,
        auditService: ToolAuditService
    ) {
        this.toolManager = toolManager
        this.permissionChecker = PermissionChecker(userHasRolesService, roleHasPermissionService)
        this.auditService = auditService
    }
    
    /**
     * CLI调用入口
     * 
     * @param toolName 工具名称
     * @param args 命令行参数数组
     * @return 工具响应
     */
    public func dispatchFromCli(
        toolName: String,
        args: Array<String>
    ): ToolResponse {
        LogUtils.info("[ToolDispatcher] CLI call: ${toolName}")
        
        // 1. 解析CLI参数
        let parsedArgs = parseCliArgs(args)
        
        // 2. 获取用户ID (从SessionContext)
        let userId = getUserIdFromSession()
        if (userId.isEmpty()) {
            return buildErrorResponse("Not logged in. Please login first using 'agentskills login'")
        }
        
        // 3. 调用内部处理
        return dispatchInternal(toolName, parsedArgs, userId, "cli")
    }
    
    /**
     * HTTP调用入口
     * 
     * @param toolName 工具名称
     * @param args JSON参数
     * @param userId 用户ID
     * @return 工具响应
     */
    public func dispatchFromHttp(
        toolName: String,
        args: HashMap<String, JsonValue>,
        userId: String
    ): ToolResponse {
        LogUtils.info("[ToolDispatcher] HTTP call: ${toolName} by user: ${userId}")
        return dispatchInternal(toolName, args, userId, "http")
    }
    
    /**
     * 内部API调用入口
     * 
     * @param toolName 工具名称
     * @param args JSON参数
     * @param userId 用户ID
     * @return 工具响应
     */
    public func dispatchFromInternal(
        toolName: String,
        args: HashMap<String, JsonValue>,
        userId: String
    ): ToolResponse {
        LogUtils.info("[ToolDispatcher] Internal call: ${toolName} by user: ${userId}")
        return dispatchInternal(toolName, args, userId, "internal")
    }
    
    /**
     * 内部处理逻辑
     */
    private func dispatchInternal(
        toolName: String,
        args: HashMap<String, JsonValue>,
        userId: String,
        source: String
    ): ToolResponse {
        let startTime = DateTime.now()
        var success = false
        var resultSize = 0
        var errorMessage: ?String = None
        
        try {
            // 1. 检查权限
            let permissionResult = permissionChecker.checkPermission(userId, toolName, args)
            if (!permissionResult.allowed) {
                LogUtils.info("[ToolDispatcher] Permission denied: ${permissionResult.reason}")
                return buildErrorResponse(permissionResult.reason)
            }
            
            // 2. 检查是否需要二次确认
            if (permissionChecker.requiresConfirmation(toolName)) {
                // TODO: 实现二次确认机制
                LogUtils.info("[ToolDispatcher] Tool requires confirmation: ${toolName}")
            }
            
            // 3. 查找工具
            let toolOpt = toolManager.findTool(toolName)
            if (let Some(tool) <- toolOpt) {
                // 4. 执行工具
                LogUtils.info("[ToolDispatcher] Executing tool: ${toolName}")
                let response = tool.invoke(args)
                
                // 5. 处理结果
                success = true
                resultSize = response.content.size
                
                // 6. 记录审计日志
                let durationMs = (DateTime.now() - startTime).toMilliseconds()
                recordAuditLog(userId, toolName, args, success, resultSize, durationMs, None, source)
                
                return response
            } else {
                errorMessage = Some("Tool not found: ${toolName}")
                LogUtils.error("[ToolDispatcher] ${errorMessage}")
                return buildErrorResponse(errorMessage.getOrThrow())
            }
        } catch (e: ToolException) {
            errorMessage = Some(e.message)
            LogUtils.error("[ToolDispatcher] Tool execution failed: ${e.message}")
            return buildErrorResponse(e.message)
        } catch (e: Exception) {
            errorMessage = Some(e.message)
            LogUtils.error("[ToolDispatcher] Unexpected error: ${e.message}")
            return buildErrorResponse("Internal error: ${e.message}")
        } finally {
            // 记录失败的审计日志
            if (!success) {
                let durationMs = (DateTime.now() - startTime).toMilliseconds()
                recordAuditLog(userId, toolName, args, success, resultSize, durationMs, errorMessage, source)
            }
        }
    }
    
    /**
     * 解析CLI参数
     * 
     * 支持以下格式:
     * 1. --key value
     * 2. --key=value
     * 3. --flag (布尔标志)
     */
    private func parseCliArgs(args: Array<String>): HashMap<String, JsonValue> {
        let result = HashMap<String, JsonValue>()
        var i = 0

        while (i < args.size) {
            let arg = args[i]

            if (arg.startsWith("--")) {
                let key = arg[2..]

                // 检查是否是 --key=value 格式
                if (key.contains("=")) {
                    let parts = key.split("=")
                    result.add(parts[0], JsonString(parts[1]))
                    i += 1
                }
                // 检查下一个参数是否是值
                else if (i + 1 < args.size && !args[i + 1].startsWith("--")) {
                    result.add(key, JsonString(args[i + 1]))
                    i += 2
                }
                // 布尔标志
                else {
                    result.add(key, JsonBool(true))
                    i += 1
                }
            } else {
                i += 1
            }
        }

        return result
    }
    
    /**
     * 从SessionContext获取用户ID
     */
    private func getUserIdFromSession(): String {
        // TODO: 从SessionContext获取
        // let sessionContext = SessionContext.getInstance()
        // return sessionContext.getUserId()
        ""
    }
    
    /**
     * 记录审计日志到数据库
     */
    private func recordAuditLog(
        userId: String,
        toolName: String,
        args: HashMap<String, JsonValue>,
        success: Bool,
        resultSize: Int64,
        durationMs: Int64,
        errorMessage: ?String,
        source: String
    ): Unit {
        // 检查是否启用审计
        if (!ToolPermissionRegistry.isAuditEnabled(toolName)) {
            return
        }
        
        // 获取客户端IP (TODO: 从SessionContext获取)
        let ip = ""
        
        // 获取工具权限路径
        let permissionPath = if (let Some(permission) <- ToolPermissionRegistry.getPermission(toolName)) {
            permission.permissionPath
        } else {
            "/api/v1/tools/${toolName}"
        }
        
        // 调用审计服务记录到数据库
        auditService.auditToolCall(
            userId,
            toolName,
            args,
            success,
            resultSize,
            durationMs,
            errorMessage,
            source,
            ip,
            permissionPath
        )
    }
    
    /**
     * 构建错误响应
     */
    private func buildErrorResponse(message: String): ToolResponse {
        let result = JsonObject()
        result.put("success", JsonBool(false))
        result.put("error", JsonString(message))
        ToolResponse(result.toJsonString())
    }
    
    /**
     * 获取可用工具列表
     *
     * @param userId 用户ID
     * @return 工具列表
     */
    public func getAvailableTools(userId: String): ArrayList<Tool> {
        let allTools = toolManager.tools
        let availableTools = ArrayList<Tool>()

        for (tool in allTools) {
            // 检查权限
            let args = HashMap<String, JsonValue>()
            let permissionResult = permissionChecker.checkPermission(userId, tool.name, args)

            if (permissionResult.allowed) {
                availableTools.add(tool)
            }
        }

        return availableTools
    }
    
    /**
     * 获取工具信息
     *
     * @param toolName 工具名称
     * @return 工具信息JSON
     */
    public func getToolInfo(toolName: String): ?JsonObject {
        let toolOpt = toolManager.findTool(toolName)
        if (let Some(tool) <- toolOpt) {
            let info = JsonObject()
            info.put("name", JsonString(tool.name))
            info.put("description", JsonString(tool.description))

            // 参数信息
            let paramsArray = JsonArray()
            for (param in tool.parameters) {
                let paramObj = JsonObject()
                paramObj.put("name", JsonString(param.name))
                paramObj.put("description", JsonString(param.description))
                paramObj.put("type", JsonString(param.typeSchema.toString()))
                paramsArray.add(paramObj)
            }
            info.put("parameters", paramsArray)

            // 权限信息
            if (let Some(permission) <- ToolPermissionRegistry.getPermission(toolName)) {
                let permObj = JsonObject()
                permObj.put("path", JsonString(permission.permissionPath))
                permObj.put("sensitiveLevel", JsonInt(permission.sensitiveLevel))
                permObj.put("requiresConfirmation", JsonBool(permission.requiresConfirmation))
                info.put("permission", permObj)
            }

            return Some(info)
        }
        return None
    }
}

/**
 * ToolDispatcherSingleton - 工具调度器单例
 * 
 * 提供全局访问点
 */
public class ToolDispatcherSingleton {
    private static var _instance: ?ToolDispatcher = None
    
    /**
     * 获取单例实例
     */
    public static func getInstance(): ToolDispatcher {
        if (let Some(instance) <- _instance) {
            return instance
        }
        
        // 需要先初始化
        throw Exception("ToolDispatcher not initialized. Call init() first.")
    }
    
    /**
     * 初始化单例
     */
    public static func `init`(
        toolManager: ToolManager,
        userHasRolesService: UserHasRolesService,
        roleHasPermissionService: RoleHasPermissionService,
        auditService: ToolAuditService
    ): Unit {
        _instance = Some(ToolDispatcher(toolManager, userHasRolesService, roleHasPermissionService, auditService))
    }
}
