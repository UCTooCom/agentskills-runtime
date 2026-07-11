/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.aip

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.aip.AipInteractionService
import magic.app.services.aip.model.{LocalSessionRequest, LocalMessageRequest}
import magic.log.LogUtils
import stdx.encoding.json.{JsonValue, JsonObject}
import std.convert.*

public class AipInteractionController {
    private var interactionService: AipInteractionService

    public init() {
        this.interactionService = AipInteractionService()
    }

    public func createLocalSession(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            let obj = jsonValue.asObject()

            let request = LocalSessionRequest()
            request.requesterAgentId = getStringFromJson(obj, "requester_agent_id")
            request.interactionMode = getStringFromJson(obj, "interaction_mode")
            if (request.interactionMode.isEmpty()) {
                request.interactionMode = "p2p"
            }

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = interactionService.createLocalSession(request, creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建会话失败\"}")
                }
            } else {
                let reason = result.reason ?? "创建会话失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipInteractionController", "createLocalSession failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func sendLocalMessage(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            let obj = jsonValue.asObject()

            let request = LocalMessageRequest()
            request.sessionId = getStringFromJson(obj, "session_id")
            request.senderAgentId = getStringFromJson(obj, "sender_agent_id")
            request.senderRole = getStringFromJson(obj, "sender_role")
            if (request.senderRole.isEmpty()) {
                request.senderRole = "requester"
            }

            let taskIdVal = obj.get("task_id")
            if (taskIdVal.isSome()) {
                let s = taskIdVal.getOrThrow() as String
                if (let Some(str) <- s) { request.taskId = Some<String>(str) }
            }
            let dataItemsVal = obj.get("data_items")
            if (dataItemsVal.isSome()) {
                let s = dataItemsVal.getOrThrow() as String
                if (let Some(str) <- s) { request.dataItems = Some<String>(str) }
            }
            let contentVal = obj.get("content")
            if (contentVal.isSome()) {
                let s = contentVal.getOrThrow() as String
                if (let Some(str) <- s) { request.content = Some<String>(str) }
            }

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = interactionService.sendLocalMessage(request, creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"发送消息失败\"}")
                }
            } else {
                let reason = result.reason ?? "发送消息失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipInteractionController", "sendLocalMessage failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getSessionMessages(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let sessionId = req.pathParam("sessionId")
            if (sessionId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少sessionId参数\"}")
                return
            }

            let limitStr = req.pathParam("limit")
            let pageStr = req.pathParam("page")
            var limit: Int64 = 20
            var page: Int64 = 1
            if (limitStr.isSome()) {
                limit = Int64.parse(limitStr.getOrThrow())
            }
            if (pageStr.isSome()) {
                page = Int64.parse(pageStr.getOrThrow())
            }

            let result = interactionService.getSessionMessages(sessionId.getOrThrow(), page, limit)
            if (result.success) {
                if (result.data.isSome()) {
                    let pagination = result.data.getOrThrow()
                    var itemsJson = "["
                    var first = true
                    for (item in pagination.list) {
                        if (!first) { itemsJson = itemsJson + "," }
                        itemsJson = itemsJson + item.toJson()
                        first = false
                    }
                    itemsJson = itemsJson + "]"
                    res.status(200).json("{\"page\":${pagination.page},\"size\":${pagination.size},\"rows\":${pagination.rows},\"pages\":${pagination.pages},\"items\":${itemsJson}}")
                } else {
                    res.status(200).json("{\"total\":0,\"items\":[]}")
                }
            } else {
                let reason = result.reason ?? "查询会话消息失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipInteractionController", "getSessionMessages failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func closeSession(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let sessionId = req.pathParam("sessionId")
            if (sessionId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少sessionId参数\"}")
                return
            }

            let result = interactionService.closeSession(sessionId.getOrThrow())
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "关闭会话失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipInteractionController", "closeSession failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func createInterconnectionSession(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            let obj = jsonValue.asObject()

            let requesterAgentId = getStringFromJson(obj, "requester_agent_id")
            if (requesterAgentId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"requester_agent_id不能为空\"}")
                return
            }
            let requesterAic = getStringFromJson(obj, "requester_aic")
            if (requesterAic.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"requester_aic不能为空\"}")
                return
            }
            let interactionMode = getStringFromJson(obj, "interaction_mode")
            if (interactionMode.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"interaction_mode不能为空\"}")
                return
            }
            let receivers = getStringFromJson(obj, "receivers")
            if (receivers.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"receivers不能为空\"}")
                return
            }

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = interactionService.createInterconnectionSession(requesterAgentId, requesterAic, interactionMode, receivers, creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建互联会话失败\"}")
                }
            } else {
                let reason = result.reason ?? "创建互联会话失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipInteractionController", "createInterconnectionSession failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func sendInterconnectionMessage(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            let obj = jsonValue.asObject()

            let sessionId = getStringFromJson(obj, "session_id")
            if (sessionId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"session_id不能为空\"}")
                return
            }
            let senderAgentId = getStringFromJson(obj, "sender_agent_id")
            if (senderAgentId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"sender_agent_id不能为空\"}")
                return
            }
            let senderAic = getStringFromJson(obj, "sender_aic")
            if (senderAic.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"sender_aic不能为空\"}")
                return
            }
            let senderRole = getStringFromJson(obj, "sender_role")
            if (senderRole.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"sender_role不能为空\"}")
                return
            }
            let dataItems = getStringFromJson(obj, "data_items")
            if (dataItems.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"data_items不能为空\"}")
                return
            }

            var taskId: Option<String> = None<String>
            let taskIdVal = obj.get("task_id")
            if (taskIdVal.isSome()) {
                let s = taskIdVal.getOrThrow() as String
                if (let Some(str) <- s) { taskId = Some<String>(str) }
            }

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = interactionService.sendInterconnectionMessage(sessionId, senderAgentId, senderAic, senderRole, dataItems, taskId, creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"发送互联消息失败\"}")
                }
            } else {
                let reason = result.reason ?? "发送互联消息失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipInteractionController", "sendInterconnectionMessage failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func closeInterconnectionSession(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let sessionId = req.pathParam("sessionId")
            if (sessionId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少sessionId参数\"}")
                return
            }

            let result = interactionService.closeInterconnectionSession(sessionId.getOrThrow())
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "关闭互联会话失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipInteractionController", "closeInterconnectionSession failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    private func getStringFromJson(obj: JsonObject, key: String): String {
        let val = obj.get(key)
        if (val.isSome()) {
            let v = val.getOrThrow()
            let s = v as String
            if (let Some(str) <- s) { return str }
        }
        return ""
    }
}