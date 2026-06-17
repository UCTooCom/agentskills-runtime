/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.memory

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.agent.memory.database.DatabaseMemory
import magic.agent.memory.tiered.TieredMemory
import magic.app.services.uctoo.AgentMemoriesService
import magic.app.models.uctoo.AgentMemoriesPO
import magic.app.core.response.APIResult
import magic.log.LogUtils
import stdx.encoding.json.*
import std.collection.ArrayList

public class MemoryController {
    private let memoriesService = AgentMemoriesService()

    public func update(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let agentIdOpt = req.pathParam("agentId")
            let agentId = match (agentIdOpt) { case Some(v) => v; case None => "" }
            if (agentId.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"agentId参数缺失\"}")
                return
            }

            let body = req.body
            let content = extractJsonString(body, "content")
            if (content.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"content参数缺失\"}")
                return
            }

            let scope = extractJsonString(body, "scope")
            let effectiveScope = if (scope.isEmpty()) { "episodic" } else { scope }

            let po = AgentMemoriesPO()
            po.agentId = agentId
            po.content = content
            po.scope = effectiveScope
            po.weight = 1.0
            po.tags = "[]"
            po.metadata = "{}"

            let result = memoriesService.create(po, agentId)
            if (result.success) {
                if (let Some(data) <- result.data) {
                    res.status(200).json("{\"success\":true,\"data\":" + data.toJson() + "}")
                } else {
                    res.status(200).json("{\"success\":true}")
                }
            } else {
                let reasonStr = match (result.reason) { case Some(r) => r; case None => "创建失败" }
                res.status(500).json("{\"success\":false,\"reason\":\"${reasonStr}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func search(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let agentIdOpt = req.pathParam("agentId")
            let agentId = match (agentIdOpt) { case Some(v) => v; case None => "" }
            if (agentId.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"agentId参数缺失\"}")
                return
            }

            let body = req.body
            let question = extractJsonString(body, "question")
            let scope = extractJsonString(body, "scope")
            let effectiveScope = if (scope.isEmpty()) { "episodic" } else { scope }

            let results = memoriesService.searchByContent(agentId, effectiveScope, question, 5)
            let arr = JsonArray()
            for (po in results) {
                arr.add(po.toJsonValue())
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", arr)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let agentIdOpt = req.pathParam("agentId")
            let agentId = match (agentIdOpt) { case Some(v) => v; case None => "" }
            if (agentId.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"agentId参数缺失\"}")
                return
            }

            let scopeOpt = req.queryParam("scope")
            let scope = match (scopeOpt) { case Some(v) => v; case None => "" }
            let effectiveScope = if (scope.isEmpty()) { "episodic" } else { scope }

            let (records, total) = memoriesService.findByAgentIdAndScope(agentId, effectiveScope, 1, 50)
            let arr = JsonArray()
            for (po in records) {
                arr.add(po.toJsonValue())
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", arr)
            result.put("total", JsonInt(total))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let memoryIdOpt = req.pathParam("memoryId")
            let memoryId = match (memoryIdOpt) { case Some(v) => v; case None => "" }
            if (memoryId.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"memoryId参数缺失\"}")
                return
            }

            let result = memoriesService.delete(memoryId, true)
            if (result.success) {
                res.status(200).json("{\"success\":true}")
            } else {
                let reasonStr = match (result.reason) { case Some(r) => r; case None => "删除失败" }
                res.status(500).json("{\"success\":false,\"reason\":\"${reasonStr}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    private func extractJsonString(body: String, key: String): String {
        try {
            let json = JsonValue.fromStr(body)
            if (json is JsonObject) {
                let obj = json.asObject()
                if (let Some(v) <- obj.get(key)) {
                    if (v is JsonString) {
                        return v.asString().getValue()
                    }
                }
            }
            ""
        } catch (_: Exception) {
            ""
        }
    }
}