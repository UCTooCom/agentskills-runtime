/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.aip

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.APIResult
import magic.app.services.aip.{AipIdentityService, AgentAuthService}
import magic.app.services.aip.model.{LocalIdentityRequest, AgentLoginResult, IdentityInfo}
import magic.log.LogUtils
import stdx.encoding.json.{JsonValue, JsonObject}
import std.convert.*

public class AipIdentityController {
    private var identityService: AipIdentityService
    private var authService: AgentAuthService

    public init() {
        this.identityService = AipIdentityService()
        this.authService = AgentAuthService()
    }

    public func registerLocal(req: HttpRequest, res: HttpResponse): Unit {
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

            let request = LocalIdentityRequest()
            request.name = getStringFromJson(obj, "name")
            request.agentType = getStringFromJson(obj, "agent_type")
            let descOpt = obj.get("description")
            if (descOpt.isSome()) {
                let descStr = descOpt.getOrThrow().toString()
                request.description = Some<String>(descStr)
            }

            let userIdStr = userId.getOrThrow() as String
            var creatorId = ""
            if (let Some(s) <- userIdStr) {
                creatorId = s
            }

            let result = identityService.registerLocalIdentity(request, creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"注册失败\"}")
                }
            } else {
                let reason = result.reason ?? "注册失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "registerLocal failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func agentLogin(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            let obj = jsonValue.asObject()
            let agentId = getStringFromJson(obj, "agent_id")

            if (agentId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"agent_id不能为空\"}")
                return
            }

            let result = authService.agentAutoLogin(agentId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"登录失败\"}")
                }
            } else {
                let reason = result.reason ?? "登录失败"
                res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "agentLogin failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getIdentity(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let agentId = req.pathParam("agentId")
            if (agentId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少agentId参数\"}")
                return
            }

            let result = identityService.getIdentityInfo(agentId.getOrThrow())
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该智能体\"}")
                }
            } else {
                let reason = result.reason ?? "查询失败"
                res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "getIdentity failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    private func getStringFromJson(obj: JsonObject, key: String): String {
        let val = obj.get(key)
        if (val.isSome()) {
            let v = val.getOrThrow()
            let s = v as String
            if (let Some(str) <- s) {
                return str
            }
        }
        return ""
    }

    public func listIdentities(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let pageStr = req.pathParam("page")
            let sizeStr = req.pathParam("size")
            var page: Int64 = 1
            var size: Int64 = 20
            if (pageStr.isSome()) { page = Int64.parse(pageStr.getOrThrow()) }
            if (sizeStr.isSome()) { size = Int64.parse(sizeStr.getOrThrow()) }

            let result = identityService.listIdentities(page, size)
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
                    res.status(200).json("{\"page\":1,\"size\":20,\"rows\":0,\"pages\":0,\"items\":[]}")
                }
            } else {
                let reason = result.reason ?? "查询失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "listIdentities failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func disableAgent(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let agentId = req.pathParam("agentId")
            if (agentId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少agentId参数\"}")
                return
            }

            var operatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { operatorId = s }

            let result = identityService.disableAgent(agentId.getOrThrow(), operatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "禁用失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "disableAgent failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func enableAgent(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let agentId = req.pathParam("agentId")
            if (agentId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少agentId参数\"}")
                return
            }

            var operatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { operatorId = s }

            let result = identityService.enableAgent(agentId.getOrThrow(), operatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "启用失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "enableAgent failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func registerInterconnection(req: HttpRequest, res: HttpResponse): Unit {
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
            let agentId = getStringFromJson(obj, "agent_id")
            if (agentId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"agent_id不能为空\"}")
                return
            }
            var operatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { operatorId = s }

            let result = identityService.registerInterconnectionIdentity(agentId, operatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "互联身份注册失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "registerInterconnection failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func updateIdentity(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let agentId = req.pathParam("agentId")
            if (agentId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少agentId参数\"}")
                return
            }
            var operatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { operatorId = s }

            let result = identityService.updateIdentity(agentId.getOrThrow(), operatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "更新失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "updateIdentity failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func lockIdentity(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let agentId = req.pathParam("agentId")
            if (agentId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少agentId参数\"}")
                return
            }
            var operatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { operatorId = s }

            let result = identityService.lockIdentity(agentId.getOrThrow(), operatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "锁定失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "lockIdentity failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func unlockIdentity(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let agentId = req.pathParam("agentId")
            if (agentId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少agentId参数\"}")
                return
            }
            var operatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { operatorId = s }

            let result = identityService.unlockIdentity(agentId.getOrThrow(), operatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "解锁失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "unlockIdentity failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func revokeIdentity(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let agentId = req.pathParam("agentId")
            if (agentId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少agentId参数\"}")
                return
            }
            var operatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { operatorId = s }

            let result = identityService.revokeIdentity(agentId.getOrThrow(), operatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "注销失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipIdentityController", "revokeIdentity failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
}