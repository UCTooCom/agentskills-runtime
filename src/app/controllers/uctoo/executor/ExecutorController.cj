/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.executor

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.agent_executor.AgentExecutorManager
import magic.app.services.crontab.executor.ExecutorRegistry
import magic.app.services.crontab.SchedulerEngine
import magic.log.LogUtils
import stdx.encoding.json.*

public class ExecutorController {
    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let executors = JsonArray()
            let builtinNames = ["naive", "react", "plan-react", "tool-loop", "dsl-executor"]
            for (name in builtinNames) {
                let obj = JsonObject()
                obj.put("name", JsonString(name))
                obj.put("type", JsonString("builtin"))
                obj.put("description", JsonString(getExecutorDescription(name)))
                executors.add(obj)
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", executors)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func getByName(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let nameOpt = req.pathParam("name")
            if (nameOpt.isNone()) {
                res.status(400).json("{\"success\":false,\"reason\":\"name参数缺失\"}")
                return
            }
            let name = nameOpt.getOrThrow()

            let obj = JsonObject()
            obj.put("name", JsonString(name))
            obj.put("type", JsonString("builtin"))
            obj.put("description", JsonString(getExecutorDescription(name)))

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", obj)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func listSchemes(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let schemes = JsonArray()
            let builtinSchemes = ["naive", "react", "plan-react", "tool-loop", "dsl-executor"]
            for (s in builtinSchemes) {
                schemes.add(JsonString(s))
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", schemes)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    private func getExecutorDescription(name: String): String {
        match (name) {
            case "naive" => "Naive executor - single pass, no tool loop"
            case "react" => "ReAct executor - reasoning and acting loop"
            case "plan-react" => "Plan-ReAct executor - plan then execute with ReAct"
            case "tool-loop" => "Tool loop executor - iterative tool calling"
            case "dsl-executor" => "DSL executor - domain specific language driven"
            case _ => "Custom executor: ${name}"
        }
    }
}