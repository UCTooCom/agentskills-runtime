/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

import magic.core.tool.{ToolResponse, ToolException}
import magic.log.LogUtils
import std.collection.HashMap
import std.time.DateTime
import std.core.Duration
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

/**
 * WebMCP 工具调用辅助类
 *
 * 提取 WebNavigateTool/WebNotifyTool/WebRequestApprovalTool/FrontendToolAdapter 共用的
 * SSE 推送 + 阻塞等待逻辑，避免代码重复（DRY 原则）。
 *
 * 工作流程：
 * 1. 从 WebMCPToolContext 获取当前会话的 sessionId、sseManager、pendingManager
 * 2. 生成唯一 callId
 * 3. 构建 SSE 推送数据（tool_call 事件），通过 sseManager.pushMessage 推送到前端
 * 4. 通过 pendingManager.register 注册回调 entry，阻塞等待前端回传结果
 * 5. 前端通过 /tool-result 回传结果时，pendingManager.handleResult 唤醒等待线程
 * 6. 超时未收到结果时返回超时错误
 *
 * 包路径：magic.tool.webmcp（基础设施层）
 * 同包内的 WebMCPToolContext、SSEConnectionManager、PendingToolCallManager 默认可见，不需要 import。
 */
public class WebMCPToolHelper {
    /**
     * 执行 WebMCP 工具调用（SSE 推送指令 → 阻塞等待前端回传结果）
     * @param toolName 工具名称
     * @param args 工具调用参数
     * @param timeoutMs 超时时间（毫秒）
     * @param route 前端工具的目标页面路由（后端内置工具传空字符串）
     * @return ToolResponse 包含前端回传的结果或错误信息
     */
    public static func executeToolCall(toolName: String, args: HashMap<String, JsonValue>, timeoutMs: Int64, route: String): ToolResponse {
        // 1. 获取工具执行上下文
        let ctx = WebMCPToolContext.instance
        let sessionIdOpt = ctx.getSessionId()
        let sseManagerOpt = ctx.getSSEManager()
        let pendingManagerOpt = ctx.getPendingManager()

        if (sessionIdOpt.isNone() || sseManagerOpt.isNone() || pendingManagerOpt.isNone()) {
            LogUtils.warn("[WebMCPToolHelper] Frontend connection unavailable, toolName=${toolName}")
            return ToolResponse("{\"error\":\"前端连接不可用，无法执行${toolName}操作\"}", isError: true)
        }

        let sessionId = sessionIdOpt.getOrThrow()
        let sseManager = sseManagerOpt.getOrThrow()
        let pendingManager = pendingManagerOpt.getOrThrow()

        // 2. 生成 callId
        let callId = _generateCallId()

        // 3. 构建 SSE 推送数据（统一使用 tool_call 事件类型）
        let argsObj = JsonObject()
        for ((key, value) in args) {
            argsObj.put(key, value)
        }

        let dataObj = JsonObject()
        dataObj.put("toolName", JsonString(toolName))
        dataObj.put("arguments", argsObj)
        dataObj.put("callId", JsonString(callId))
        if (!route.isEmpty()) {
            dataObj.put("route", JsonString(route))
        }
        let dataStr = dataObj.toString()

        // 4. 通过 SSE 推送指令
        let pushed = sseManager.pushMessage(sessionId, "tool_call", dataStr)
        if (!pushed) {
            LogUtils.warn("[WebMCPToolHelper] SSE push failed, toolName=${toolName}, callId=${callId}")
            return ToolResponse("{\"error\":\"操作推送失败，请刷新页面重试\",\"toolName\":\"${toolName}\"}", isError: true)
        }

        // 5. 注册回调并阻塞等待
        LogUtils.info("[WebMCPToolHelper] tool_call pushed, toolName=${toolName}, callId=${callId}, timeoutMs=${timeoutMs.toString()}")
        let entry = pendingManager.register(callId, toolName, timeoutMs)

        entry.mutex.lock()
        var timedOut = false
        let startTime = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        while (!entry.completed) {
            let elapsed = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds() - startTime
            let remaining = timeoutMs - elapsed
            if (remaining <= 0) {
                // 超时
                entry.completed = true
                entry.timedOut = true
                timedOut = true
                entry.result = "{\"error\":\"${toolName}操作超时，未收到前端响应\",\"callId\":\"${callId}\"}"
                pendingManager.remove(callId)
                LogUtils.warn("[WebMCPToolHelper] tool_call timed out, toolName=${toolName}, callId=${callId}")
                break
            }
            entry.condition.wait(timeout: Duration.millisecond * remaining)
        }
        let result = entry.result
        entry.mutex.unlock()

        // 6. 返回结果
        if (timedOut) {
            return ToolResponse(result, isError: true)
        }
        LogUtils.info("[WebMCPToolHelper] tool_call completed, toolName=${toolName}, callId=${callId}")
        return ToolResponse(result, isError: false)
    }

    /// 生成 callId：call_{timestamp}_{random8位}
    private static func _generateCallId(): String {
        let ts = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        let rand = ts % 100000000
        "call_${ts.toString()}_${rand.toString()}"
    }
}
