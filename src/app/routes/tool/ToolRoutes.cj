/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.tool

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.router.Router
import magic.app.core.middleware.Middleware
import magic.tool.{ToolDispatcher, ToolPermissionRegistry}
import magic.core.tool.ToolResponse
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt, JsonArray}

/**
 * ToolRoutes - 工具HTTP路由
 * 
 * 提供统一的HTTP工具调用接口
 * 
 * 路由设计:
 *   POST /api/v1/tools/:toolName       - 调用工具
 *   GET  /api/v1/tools/list            - 获取工具列表
 *   GET  /api/v1/tools/:toolName/info  - 获取工具信息
 */
public class ToolRoutes {
    private let router: Router
    private let dispatcher: ToolDispatcher
    
    public init(router: Router, dispatcher: ToolDispatcher) {
        this.router = router
        this.dispatcher = dispatcher
    }
    
    /**
     * 注册路由
     */
    public func register(): Unit {
        // 工具调用接口
        router.post("/api/v1/tools/:toolName", { req, res =>
            handleToolCall(req, res)
        })
        
        // 工具列表接口
        router.get("/api/v1/tools/list", { req, res =>
            handleToolList(req, res)
        })
        
        // 工具信息接口
        router.get("/api/v1/tools/:toolName/info", { req, res =>
            handleToolInfo(req, res)
        })
        
        LogUtils.info("[ToolRoutes] Routes registered successfully")
    }
    
    /**
     * 处理工具调用
     */
    private func handleToolCall(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 1. 获取工具名称
            let toolNameOption = req.pathParam("toolName")
            if (toolNameOption == None<String>) {
                res.status(400).json(buildErrorResponse("Tool name is required"))
                return
            }
            
            let toolName = toolNameOption.getOrThrow()
            
            // 2. 获取用户ID (从JWT中间件注入)
            let userIdOpt = req.getLocals("userId")
            let userId = if (let Some(uid) <- userIdOpt) {
                let uidStr = uid as String
                if (let Some(s) <- uidStr) { s } else { "" }
            } else {
                ""
            }
            
            if (userId.isEmpty()) {
                res.status(401).json(buildErrorResponse("Unauthorized: Please login first"))
                return
            }
            
            // 3. 解析请求参数
            let args = parseRequestBody(req)
            
            // 4. 调用工具调度器
            LogUtils.info("[ToolRoutes] Tool call: ${toolName} by user: ${userId}")
            let response = dispatcher.dispatchFromHttp(toolName, args, userId)
            
            // 5. 返回结果
            res.json(buildSuccessResponse(response))
        } catch (e: Exception) {
            LogUtils.error("[ToolRoutes] Exception: ${e.message}")
            res.status(500).json(buildErrorResponse("Internal error: ${e.message}"))
        }
    }
    
    /**
     * 处理工具列表
     */
    private func handleToolList(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 获取用户ID
            let userIdOpt = req.getLocals("userId")
            let userId = if (let Some(uid) <- userIdOpt) {
                let uidStr = uid as String
                if (let Some(s) <- uidStr) { s } else { "" }
            } else {
                ""
            }
            
            // 获取所有工具权限
            let permissions = ToolPermissionRegistry.getAllPermissions()
            
            // 构建工具列表
            let toolsArray = JsonArray()
            for ((toolName, permission) in permissions) {
                let toolObj = JsonObject()
                toolObj.put("name", JsonString(toolName))
                toolObj.put("path", JsonString(permission.permissionPath))
                toolObj.put("sensitiveLevel", JsonInt(permission.sensitiveLevel))
                toolObj.put("requiresConfirmation", JsonBool(permission.requiresConfirmation))
                toolObj.put("auditEnabled", JsonBool(permission.auditEnabled))
                toolsArray.add(toolObj)
            }
            
            // 返回结果
            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("tools", toolsArray)
            let totalSize = permissions.size
            result.put("total", JsonInt(totalSize))
            
            res.json(result.toJsonString())
        } catch (e: Exception) {
            LogUtils.error("[ToolRoutes] Exception: ${e.message}")
            res.status(500).json(buildErrorResponse("Internal error: ${e.message}"))
        }
    }
    
    /**
     * 处理工具信息查询
     */
    private func handleToolInfo(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 获取工具名称
            let toolNameOption = req.pathParam("toolName")
            if (toolNameOption == None<String>) {
                res.status(400).json(buildErrorResponse("Tool name is required"))
                return
            }
            
            let toolName = toolNameOption.getOrThrow()
            
            // 获取工具权限信息
            if (let Some(perm) <- ToolPermissionRegistry.getPermission(toolName)) {
                let result = JsonObject()
                result.put("success", JsonBool(true))
                result.put("name", JsonString(toolName))
                result.put("path", JsonString(perm.permissionPath))
                result.put("sensitiveLevel", JsonInt(perm.sensitiveLevel))
                result.put("requiresConfirmation", JsonBool(perm.requiresConfirmation))
                result.put("auditEnabled", JsonBool(perm.auditEnabled))
                
                res.json(result.toJsonString())
            } else {
                res.status(404).json(buildErrorResponse("Tool not found: ${toolName}"))
            }
        } catch (e: Exception) {
            LogUtils.error("[ToolRoutes] Exception: ${e.message}")
            res.status(500).json(buildErrorResponse("Internal error: ${e.message}"))
        }
    }
    
    /**
     * 解析请求体
     */
    private func parseRequestBody(req: HttpRequest): HashMap<String, JsonValue> {
        let args = HashMap<String, JsonValue>()
        
        try {
            let body = req.body
            if (!body.isEmpty()) {
                let json = JsonValue.fromStr(body)
                match (json) {
                    case obj: JsonObject =>
                        for ((key, value) in obj.getFields()) {
                            args[key] = value
                        }
                    case _ =>
                        LogUtils.info("[ToolRoutes] Request body is not a JSON object")
                }
            }
        } catch (e: Exception) {
            LogUtils.info("[ToolRoutes] Failed to parse request body: ${e.message}")
        }
        
        return args
    }
    
    /**
     * 构建成功响应
     */
    private func buildSuccessResponse(toolResponse: ToolResponse): String {
        let result = JsonObject()
        result.put("success", JsonBool(true))
        result.put("result", JsonString(toolResponse.content))
        result.put("isError", JsonBool(toolResponse.isError))
        result.toJsonString()
    }
    
    /**
     * 构建错误响应
     */
    private func buildErrorResponse(message: String): String {
        let result = JsonObject()
        result.put("success", JsonBool(false))
        result.put("error", JsonString(message))
        result.toJsonString()
    }
}
