/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.llm_usage

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.uctoo.LlmUsageLogsService
import magic.app.models.uctoo.LlmUsageLogsPO
import magic.app.core.response.APIResult
import magic.log.LogUtils
import stdx.encoding.json.*
import std.collection.{ArrayList, HashMap}
import std.time.DateTime

public class LlmUsageStatsController {
    private let usageService = LlmUsageLogsService()

    public func summary(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (records, total) = usageService.getListWithFilter(1, 10000, "", "created_at DESC")
            var totalPromptTokens: Int64 = 0
            var totalCompletionTokens: Int64 = 0
            var totalTokens: Int64 = 0
            var totalCost: Float64 = 0.0

            for (po in records) {
                totalPromptTokens += po.promptTokens
                totalCompletionTokens += po.completionTokens
                totalTokens += po.totalTokens
                totalCost += po.costAmount
            }

            let data = JsonObject()
            data.put("totalRecords", JsonInt(total))
            data.put("totalPromptTokens", JsonInt(totalPromptTokens))
            data.put("totalCompletionTokens", JsonInt(totalCompletionTokens))
            data.put("totalTokens", JsonInt(totalTokens))
            data.put("totalCost", JsonFloat(totalCost))

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", data)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func byAgent(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (records, _) = usageService.getListWithFilter(1, 10000, "", "created_at DESC")
            let agentMap = HashMap<String, JsonObject>()

            for (po in records) {
                let agentKey = if (let Some(a) <- po.agentId) { a } else { "unknown" }
                if (let Some(existing) <- agentMap.get(agentKey)) {
                    let newPrompt = _getIntFromObj(existing, "promptTokens") + po.promptTokens
                    let newCompletion = _getIntFromObj(existing, "completionTokens") + po.completionTokens
                    let newTotal = _getIntFromObj(existing, "totalTokens") + po.totalTokens
                    let newCost = _getFloatFromObj(existing, "costAmount") + po.costAmount
                    let newCount = _getIntFromObj(existing, "count") + 1

                    existing.put("promptTokens", JsonInt(newPrompt))
                    existing.put("completionTokens", JsonInt(newCompletion))
                    existing.put("totalTokens", JsonInt(newTotal))
                    existing.put("costAmount", JsonFloat(newCost))
                    existing.put("count", JsonInt(newCount))
                } else {
                    let obj = JsonObject()
                    obj.put("agentId", JsonString(agentKey))
                    obj.put("promptTokens", JsonInt(po.promptTokens))
                    obj.put("completionTokens", JsonInt(po.completionTokens))
                    obj.put("totalTokens", JsonInt(po.totalTokens))
                    obj.put("costAmount", JsonFloat(po.costAmount))
                    obj.put("count", JsonInt(1))
                    agentMap.add(agentKey, obj)
                }
            }

            let arr = JsonArray()
            for ((_, v) in agentMap) { arr.add(v) }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", arr)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func byModel(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (records, _) = usageService.getListWithFilter(1, 10000, "", "created_at DESC")
            let modelMap = HashMap<String, JsonObject>()

            for (po in records) {
                let modelKey = po.modelId
                if (let Some(existing) <- modelMap.get(modelKey)) {
                    let newTotal = _getIntFromObj(existing, "totalTokens") + po.totalTokens
                    let newCost = _getFloatFromObj(existing, "costAmount") + po.costAmount
                    let newCount = _getIntFromObj(existing, "count") + 1

                    existing.put("totalTokens", JsonInt(newTotal))
                    existing.put("costAmount", JsonFloat(newCost))
                    existing.put("count", JsonInt(newCount))
                } else {
                    let obj = JsonObject()
                    obj.put("modelId", JsonString(modelKey))
                    obj.put("provider", JsonString(po.provider))
                    obj.put("model", JsonString(po.model))
                    obj.put("totalTokens", JsonInt(po.totalTokens))
                    obj.put("costAmount", JsonFloat(po.costAmount))
                    obj.put("count", JsonInt(1))
                    modelMap.add(modelKey, obj)
                }
            }

            let arr = JsonArray()
            for ((_, v) in modelMap) { arr.add(v) }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", arr)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    private func _getIntFromObj(obj: JsonObject, key: String): Int64 {
        match (obj.get(key)) {
            case Some(v) => if (v is JsonInt) { v.asInt().getValue() } else { 0 }
            case None => 0
        }
    }

    private func _getFloatFromObj(obj: JsonObject, key: String): Float64 {
        match (obj.get(key)) {
            case Some(v) => if (v is JsonFloat) { v.asFloat().getValue() } else { 0.0 }
            case None => 0.0
        }
    }
}