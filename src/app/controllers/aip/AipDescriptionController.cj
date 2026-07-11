/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.aip

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.aip.AipDescriptionService
import magic.app.services.aip.model.AcsDescription
import magic.log.LogUtils
import stdx.encoding.json.{JsonValue, JsonObject}

public class AipDescriptionController {
    private var descriptionService: AipDescriptionService

    public init() {
        this.descriptionService = AipDescriptionService()
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

            let agentId = getStringFromJson(obj, "agent_id")
            if (agentId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"agent_id不能为空\"}")
                return
            }

            let acs = AcsDescription()
            acs.name = getStringFromJson(obj, "name")
            acs.version = getStringFromJson(obj, "version")
            acs.description = getStringFromJson(obj, "description")
            let capStr = getStringFromJson(obj, "capabilities")
            if (!capStr.isEmpty()) { acs.capabilities = Some<String>(capStr) }
            let inputStr = getStringFromJson(obj, "default_input_types")
            if (!inputStr.isEmpty()) { acs.defaultInputTypes = Some<String>(inputStr) }
            let outputStr = getStringFromJson(obj, "default_output_types")
            if (!outputStr.isEmpty()) { acs.defaultOutputTypes = Some<String>(outputStr) }
            acs.discoverable = getBoolFromJson(obj, "discoverable", true)

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = descriptionService.registerLocalDescription(agentId, acs, creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"注册描述失败\"}")
                }
            } else {
                let reason = result.reason ?? "注册描述失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionController", "registerLocal failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getDescription(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let agentId = req.pathParam("agentId")
            if (agentId.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少agentId参数\"}")
                return
            }

            let result = descriptionService.getDescription(agentId.getOrThrow())
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该智能体描述\"}")
                }
            } else {
                let reason = result.reason ?? "查询失败"
                res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionController", "getDescription failed: ${e.message}")
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

    private func getBoolFromJson(obj: JsonObject, key: String, defaultVal: Bool): Bool {
        let val = obj.get(key)
        if (val.isSome()) {
            let v = val.getOrThrow()
            let b = v as Bool
            if (let Some(bv) <- b) { return bv }
        }
        return defaultVal
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

            let acs = AcsDescription()
            acs.name = getStringFromJson(obj, "name")
            acs.version = getStringFromJson(obj, "version")
            acs.description = getStringFromJson(obj, "description")
            let capStr = getStringFromJson(obj, "capabilities")
            if (!capStr.isEmpty()) { acs.capabilities = Some<String>(capStr) }
            let inputStr = getStringFromJson(obj, "default_input_types")
            if (!inputStr.isEmpty()) { acs.defaultInputTypes = Some<String>(inputStr) }
            let outputStr = getStringFromJson(obj, "default_output_types")
            if (!outputStr.isEmpty()) { acs.defaultOutputTypes = Some<String>(outputStr) }
            acs.discoverable = getBoolFromJson(obj, "discoverable", true)

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = descriptionService.registerInterconnectionDescription(agentId, acs, creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"互联描述注册失败\"}")
                }
            } else {
                let reason = result.reason ?? "互联描述注册失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionController", "registerInterconnection failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func publishDescription(req: HttpRequest, res: HttpResponse): Unit {
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

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = descriptionService.publishDescription(agentId, creatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "发布失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionController", "publishDescription failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func updateInterconnection(req: HttpRequest, res: HttpResponse): Unit {
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

            let acs = AcsDescription()
            acs.name = getStringFromJson(obj, "name")
            acs.version = getStringFromJson(obj, "version")
            acs.description = getStringFromJson(obj, "description")
            let capStr = getStringFromJson(obj, "capabilities")
            if (!capStr.isEmpty()) { acs.capabilities = Some<String>(capStr) }
            let inputStr = getStringFromJson(obj, "default_input_types")
            if (!inputStr.isEmpty()) { acs.defaultInputTypes = Some<String>(inputStr) }
            let outputStr = getStringFromJson(obj, "default_output_types")
            if (!outputStr.isEmpty()) { acs.defaultOutputTypes = Some<String>(outputStr) }
            acs.discoverable = getBoolFromJson(obj, "discoverable", true)

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = descriptionService.updateInterconnectionDescription(agentId, acs, creatorId)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reason = result.reason ?? "更新失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionController", "updateInterconnection failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
}