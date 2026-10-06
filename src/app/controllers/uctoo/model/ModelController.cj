/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.model

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.model.ModelManager
import magic.model.channel.ChannelRegistry
import magic.log.LogUtils
import stdx.encoding.json.*

public class ModelController {
    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let providers = JsonArray()

            // T020：数据源改为通道注册表（llm_channel 表 / 内置种子），消除第三处硬编码。
            // 注册表非空 → 后台列表 = 注册表（新增通道零代码即可出现在列表里，V2）。
            let snapshots = ChannelRegistry.shared().listSnapshots()
            if (snapshots.size > 0) {
                for (snap in snapshots) {
                    let obj = JsonObject()
                    obj.put("name", JsonString(snap.code))
                    obj.put("type", JsonString(snap.protocol))
                    obj.put("display_name", JsonString(snap.displayName))
                    providers.add(obj)
                }
            } else {
                // 注册表未装配（DB 未就绪且种子也未加载）时退化为原硬编码名单，
                // 保证后台列表不会因注册表为空而变成空白页。
                // 【原「接入新模型通道必改点之二」】这份兜底名单后续可随 T013 回归后删除。
                let providerNames = [
                    "deepseek", "openai", "ollama", "qwen", "stepfun",
                    "dashscope", "zhipu", "moonshot", "baichuan",
                    "minimax", "yi", "volcengine", "azure", "anthropic",
                    "gemini", "mistral", "groq", "tokendance",
                    "ark", "siliconflow", "google", "openrouter", "maas",
                    "sophnet", "orbitai", "gmicloud", "atomgit", "evomap",
                    "arcbench"
                ]
                for (name in providerNames) {
                    let obj = JsonObject()
                    obj.put("name", JsonString(name))
                    obj.put("type", JsonString("chat"))
                    providers.add(obj)
                }
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
