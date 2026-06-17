/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.executor

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.bridge.AgentRuntimeBridge
import magic.agent_executor.AgentExecutorManager
import magic.log.LogUtils
import stdx.encoding.json.*
import std.collection.ArrayList

public class ExecutorSwitchController {

    public func switchExecutor(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonObj = JsonValue.fromStr(body).asObject()

            let agentId = _getStr(jsonObj, "agentId", "")
            let executorName = _getStr(jsonObj, "executorName", "")

            if (agentId.isEmpty() || executorName.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"agentId and executorName are required\"}")
                return
            }

            let bridge = AgentRuntimeBridge.instance
            let agentOpt = bridge.getRuntimeAgent(agentId)

            match (agentOpt) {
                case Some(agent) =>
                    try {
                        let newExecutor = AgentExecutorManager.create(executorName)
                        agent.executor = newExecutor

                        LogUtils.info("Switched executor for agent ${agentId} to ${executorName}")

                        let data = JsonObject()
                        data.put("agentId", JsonString(agentId))
                        data.put("executorName", JsonString(executorName))
                        data.put("agentName", JsonString(agent.name))

                        let result = JsonObject()
                        result.put("success", JsonBool(true))
                        result.put("data", data)
                        res.status(200).json(result.toString())
                    } catch (ex: Exception) {
                        LogUtils.error("Failed to create executor '${executorName}': ${ex.message}")
                        res.status(400).json("{\"success\":false,\"reason\":\"Unknown executor: ${executorName}\"}")
                    }
                case None =>
                    LogUtils.warn("Agent ${agentId} not found in runtime")
                    res.status(404).json("{\"success\":false,\"reason\":\"Agent not found in runtime: ${agentId}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("ExecutorSwitch switchExecutor error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func listExecutors(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let executorNames = ArrayList<String>()
            executorNames.add("naive")
            executorNames.add("react")
            executorNames.add("plan-react")
            executorNames.add("tool-loop")
            executorNames.add("dsl-executor")

            let arr = JsonArray()
            for (name in executorNames) {
                arr.add(JsonString(name))
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", arr)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("ExecutorSwitch listExecutors error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func getAgentExecutor(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let agentId = _getQueryParam(req, "agentId", "")
            if (agentId.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"agentId query parameter is required\"}")
                return
            }

            let bridge = AgentRuntimeBridge.instance
            let agentOpt = bridge.getRuntimeAgent(agentId)

            match (agentOpt) {
                case Some(agent) =>
                    let data = JsonObject()
                    data.put("agentId", JsonString(agentId))
                    data.put("agentName", JsonString(agent.name))
                    data.put("executorName", JsonString(agent.executor.name))

                    let result = JsonObject()
                    result.put("success", JsonBool(true))
                    result.put("data", data)
                    res.status(200).json(result.toString())
                case None =>
                    res.status(404).json("{\"success\":false,\"reason\":\"Agent not found in runtime: ${agentId}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("ExecutorSwitch getAgentExecutor error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    private func _getStr(jsonObj: JsonObject, key: String, default: String): String {
        match (jsonObj.get(key)) {
            case Some(v) => if (v is JsonString) { v.asString().getValue() } else { default }
            case None => default
        }
    }

    private func _getQueryParam(req: HttpRequest, key: String, default: String): String {
        match (req.queryParam(key)) {
            case Some(v) => v
            case None => default
        }
    }
}