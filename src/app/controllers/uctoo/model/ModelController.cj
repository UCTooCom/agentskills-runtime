/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.model

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.model.ModelManager
import magic.log.LogUtils
import stdx.encoding.json.*

public class ModelController {
    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let providers = JsonArray()
            let providerNames = [
                "deepseek", "openai", "ollama", "qwen", "stepfun",
                "dashscope", "zhipu", "moonshot", "baichuan",
                "minimax", "yi", "volcengine", "azure", "anthropic",
                "gemini", "mistral", "groq", "tokendance"
            ]
            for (name in providerNames) {
                let obj = JsonObject()
                obj.put("name", JsonString(name))
                obj.put("type", JsonString("chat"))
                providers.add(obj)
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", providers)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func test(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let modelOpt = req.queryParam("model")
            let modelName = match (modelOpt) { case Some(v) => v; case None => "" }
            if (modelName.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"model参数缺失\"}")
                return
            }

            let chatModel = ModelManager.createChatModel(modelName)
            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("model", JsonString(modelName))
            result.put("status", JsonString("model_created"))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            let result = JsonObject()
            result.put("success", JsonBool(false))
            result.put("reason", JsonString(e.message))
            res.status(500).json(result.toString())
        }
    }
}
