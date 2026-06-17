/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.dashboard

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.bridge.AgentRuntimeBridge
import magic.app.services.uctoo.{AgentsService, AgentTasksService, AgentMemoriesService, LlmUsageLogsService, AgentGroupsService}
import magic.app.models.uctoo.{AgentsPO, AgentTasksPO, AgentMemoriesPO, LlmUsageLogsPO, AgentGroupsPO}
import magic.app.core.response.APIResult
import magic.log.LogUtils
import stdx.encoding.json.*
import std.collection.{ArrayList, HashMap}
import std.time.DateTime

public class AgentDashboardController {
    private let agentsService = AgentsService()
    private let tasksService = AgentTasksService()
    private let memoriesService = AgentMemoriesService()
    private let usageService = LlmUsageLogsService()
    private let groupsService = AgentGroupsService()

    public func overview(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let bridge = AgentRuntimeBridge.instance
            let activeAgentCount = bridge.getRuntimeAgentCount()
            let totalAgentCount = agentsService.countAll()
            let totalTaskCount = tasksService.countAll()
            let totalMemoryCount = memoriesService.countAll()
            let totalGroupCount = groupsService.countAll()

            let (usageRecords, _) = usageService.getListWithFilter(1, 1, "", "created_at DESC")
            var totalTokens: Int64 = 0
            var totalCost: Float64 = 0.0
            try {
                let (allUsage, _) = usageService.getListWithFilter(1, 10000, "", "created_at DESC")
                for (po in allUsage) {
                    totalTokens = totalTokens + po.totalTokens
                    totalCost = totalCost + po.costAmount
                }
            } catch (_: Exception) {}

            let (recentTasks, _) = tasksService.getListWithFilter(1, 5, "", "created_at DESC")
            let recentTasksArray = JsonArray()
            for (task in recentTasks) {
                let taskObj = JsonObject()
                taskObj.put("id", JsonString(task.id))
                taskObj.put("agentId", JsonString(task.agentId))
                let statusStr = match (task.status) { case Some(s) => s.toString(); case None => "0" }
                taskObj.put("status", JsonString(statusStr))
                taskObj.put("createdAt", JsonString(task.createdAt.toString()))
                recentTasksArray.add(taskObj)
            }

            let data = JsonObject()
            data.put("activeAgentCount", JsonInt(activeAgentCount))
            data.put("totalAgentCount", JsonInt(totalAgentCount))
            data.put("totalTaskCount", JsonInt(totalTaskCount))
            data.put("totalMemoryCount", JsonInt(totalMemoryCount))
            data.put("totalGroupCount", JsonInt(totalGroupCount))
            data.put("totalTokens", JsonInt(totalTokens))
            data.put("totalCost", JsonFloat(totalCost))
            data.put("recentTasks", recentTasksArray)

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", data)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("AgentDashboard overview error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func agentTypeDistribution(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (agents, _) = agentsService.getListWithFilter(1, 10000, "", "")
            let typeMap = HashMap<String, Int64>()
            for (agent in agents) {
                let agentType = agent.agentType
                if (let Some(count) <- typeMap.get(agentType)) {
                    typeMap.add(agentType, count + 1)
                } else {
                    typeMap.add(agentType, 1)
                }
            }

            let distributionArray = JsonArray()
            for ((key, value) in typeMap) {
                let obj = JsonObject()
                obj.put("type", JsonString(key))
                obj.put("count", JsonInt(value))
                distributionArray.add(obj)
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", distributionArray)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("AgentDashboard agentTypeDistribution error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func taskStatusDistribution(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (tasks, _) = tasksService.getListWithFilter(1, 10000, "", "")
            let statusMap = HashMap<String, Int64>()
            for (task in tasks) {
                let statusStr = match (task.status) { case Some(s) => s.toString(); case None => "0" }
                if (let Some(count) <- statusMap.get(statusStr)) {
                    statusMap.add(statusStr, count + 1)
                } else {
                    statusMap.add(statusStr, 1)
                }
            }

            let distributionArray = JsonArray()
            for ((key, value) in statusMap) {
                let obj = JsonObject()
                obj.put("status", JsonString(key))
                obj.put("count", JsonInt(value))
                distributionArray.add(obj)
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", distributionArray)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("AgentDashboard taskStatusDistribution error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func memoryStats(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (memories, total) = memoriesService.getListWithFilter(1, 10000, "", "")
            let scopeMap = HashMap<String, Int64>()
            for (mem in memories) {
                let scope = mem.scope
                if (let Some(count) <- scopeMap.get(scope)) {
                    scopeMap.add(scope, count + 1)
                } else {
                    scopeMap.add(scope, 1)
                }
            }

            let scopeArray = JsonArray()
            for ((key, value) in scopeMap) {
                let obj = JsonObject()
                obj.put("scope", JsonString(key))
                obj.put("count", JsonInt(value))
                scopeArray.add(obj)
            }

            let data = JsonObject()
            data.put("totalMemories", JsonInt(total))
            data.put("byScope", scopeArray)

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", data)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("AgentDashboard memoryStats error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func tokenConsumption(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (records, _) = usageService.getListWithFilter(1, 10000, "", "created_at DESC")

            var totalPromptTokens: Int64 = 0
            var totalCompletionTokens: Int64 = 0
            var totalTokens: Int64 = 0
            var totalCost: Float64 = 0.0
            var errorCount: Int64 = 0

            let agentMap = HashMap<String, JsonObject>()
            let modelMap = HashMap<String, JsonObject>()

            for (po in records) {
                totalPromptTokens = totalPromptTokens + po.promptTokens
                totalCompletionTokens = totalCompletionTokens + po.completionTokens
                totalTokens = totalTokens + po.totalTokens
                totalCost = totalCost + po.costAmount

                if (let Some(_) <- po.errorMessage) {
                    errorCount = errorCount + 1
                }

                let agentId = match (po.agentId) { case Some(a) => a; case None => "unknown" }
                match (agentMap.get(agentId)) {
                    case Some(obj) =>
                        match (obj.get("totalTokens")) {
                            case Some(curr) => if (curr is JsonInt) { obj.put("totalTokens", JsonInt(curr.asInt().getValue() + po.totalTokens)) }
                            case None => ()
                        }
                        match (obj.get("totalCost")) {
                            case Some(currCost) => if (currCost is JsonFloat) { obj.put("totalCost", JsonFloat(currCost.asFloat().getValue() + po.costAmount)) }
                            case None => ()
                        }
                        match (obj.get("count")) {
                            case Some(currCount) => if (currCount is JsonInt) { obj.put("count", JsonInt(currCount.asInt().getValue() + 1)) }
                            case None => ()
                        }
                    case None =>
                        let obj = JsonObject()
                        obj.put("agentId", JsonString(agentId))
                        obj.put("totalTokens", JsonInt(po.totalTokens))
                        obj.put("totalCost", JsonFloat(po.costAmount))
                        obj.put("count", JsonInt(1))
                        agentMap.add(agentId, obj)
                }

                let modelId = po.modelId
                match (modelMap.get(modelId)) {
                    case Some(obj) =>
                        match (obj.get("totalTokens")) {
                            case Some(curr) => if (curr is JsonInt) { obj.put("totalTokens", JsonInt(curr.asInt().getValue() + po.totalTokens)) }
                            case None => ()
                        }
                        match (obj.get("totalCost")) {
                            case Some(currCost) => if (currCost is JsonFloat) { obj.put("totalCost", JsonFloat(currCost.asFloat().getValue() + po.costAmount)) }
                            case None => ()
                        }
                        match (obj.get("count")) {
                            case Some(currCount) => if (currCount is JsonInt) { obj.put("count", JsonInt(currCount.asInt().getValue() + 1)) }
                            case None => ()
                        }
                    case None =>
                        let obj = JsonObject()
                        obj.put("modelId", JsonString(modelId))
                        obj.put("totalTokens", JsonInt(po.totalTokens))
                        obj.put("totalCost", JsonFloat(po.costAmount))
                        obj.put("count", JsonInt(1))
                        modelMap.add(modelId, obj)
                }
            }

            let byAgentArray = JsonArray()
            for ((_, value) in agentMap) {
                byAgentArray.add(value)
            }

            let byModelArray = JsonArray()
            for ((_, value) in modelMap) {
                byModelArray.add(value)
            }

            let data = JsonObject()
            data.put("totalPromptTokens", JsonInt(totalPromptTokens))
            data.put("totalCompletionTokens", JsonInt(totalCompletionTokens))
            data.put("totalTokens", JsonInt(totalTokens))
            data.put("totalCost", JsonFloat(totalCost))
            data.put("errorCount", JsonInt(errorCount))
            data.put("errorRate", JsonFloat(if (records.size > 0) { Float64(errorCount) / Float64(records.size) } else { 0.0 }))
            data.put("byAgent", byAgentArray)
            data.put("byModel", byModelArray)

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", data)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("AgentDashboard tokenConsumption error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func collaborationTopology(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (groups, _) = groupsService.getListWithFilter(1, 10000, "", "created_at DESC")

            let nodesArray = JsonArray()
            let edgesArray = JsonArray()

            let (allAgents, _) = agentsService.getListWithFilter(1, 10000, "", "")
            for (agent in allAgents) {
                let node = JsonObject()
                node.put("id", JsonString(agent.id))
                node.put("name", JsonString(agent.name))
                node.put("type", JsonString(agent.agentType))
                nodesArray.add(node)
            }

            for (group in groups) {
                let edge = JsonObject()
                edge.put("groupId", JsonString(group.id))
                edge.put("groupName", JsonString(group.name))
                edge.put("strategy", JsonString(group.groupType))
                let leaderIdStr = if (let Some(id) <- group.leaderId) { id } else { "" }
                edge.put("leaderId", JsonString(leaderIdStr))
                edge.put("memberIds", JsonString(group.memberIds))
                edgesArray.add(edge)
            }

            let data = JsonObject()
            data.put("nodes", nodesArray)
            data.put("edges", edgesArray)

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", data)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("AgentDashboard collaborationTopology error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }
}