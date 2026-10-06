/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import magic.app.models.uctoo.{ModelChannelPO, ModelChannelModelPO, ModelChannelHealthPO}
import magic.app.dao.uctoo.{ModelChannelModelDAO, ModelChannelHealthDAO}
import magic.utils.http.HttpUtils
import f_orm.*
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonBool, JsonInt}
import magic.jsonable.JsonUtils
import std.time.DateTime
import magic.log.LogUtils

/**
 * ChannelProbe — 模型清单同步（T016）+ 三枪能力探测（T017）+ 周期健康探活（T026）。
 *
 * 设计（design.md §8 / spec REQ-DMC-008 / REQ-DMC-011）：
 * - 复用既有 OpenAI 兼容协议：清单走 `GET {base}/models`，三枪与探活走 `POST {base}/chat/completions`；
 *   不重写协议实现，保持「确定性在代码」的边界。
 * - 三枪 = chat（同步补全）/ stream（SSE）/ tools（带 function 工具），逐个独立判定，
 *   失败项给出**原始错误原文**（如 200 空体、provider_not_selected），而非笼统「不可用」。
 * - 探测结果写回两层：通道级 `capabilities`/`health`（T017 手动）与 `llm_channel_model` 条目级能力位，
 *   以及 `llm_channel_health` 历史（T026 周期探活）。
 * - 写回**不 bump 通道 revision**：避免探测导致 ModelInstanceCache 整体失效、打断进行中会话（V4 drain）；
 *   能力/健康变化经 T011 的 2s 轮询刷新注册表，2s 内对 catalog / 运行注册表可见。
 * - 周期探活默认不自动翻转 `status`（避免瞬时抖动误摘默认通道）；仅当**连续失败**才置 `degraded`，
 *   恢复后自动归位 `enabled`（REQ-DMC-011 错误率阈值 + 冷却半开语义的简化版）。
 */
public class ChannelProbe {
    private static let INSTANCE = ChannelProbe()
    public static func shared(): ChannelProbe {
        INSTANCE
    }

    // ==================== T016：拉模型清单 ====================

    /**
     * 拉取通道模型清单并增量写入 llm_channel_model：新增模型默认 `pending`（REQ-DMC-009，避免网关悄悄上线新模型）。
     * 返回 (新增条数, 明细)；失败返回 (0, 错误原文)。
     */
    public func syncModels(code: String): (Int64, String) {
        try {
            let chOpt = ChannelService.shared().getChannelByCode(code)
            if (chOpt.isNone()) {
                return (0, "通道 ${code} 不存在")
            }
            let ch = chOpt.getOrThrow()
            let baseUrl = ChannelRegistry.shared().resolveBaseUrl(code)
            let apiKey = ChannelRegistry.shared().resolveSecret(code)
            if (baseUrl.isEmpty()) {
                return (0, "通道未配置 base_url，无法拉取模型清单")
            }
            let url = if (baseUrl.endsWith("/")) { baseUrl + "models" } else { baseUrl + "/models" }
            let header = authHeader(apiKey)
            let respOpt = HttpUtils.get(url, header, None)
            if (let Some(s) <- respOpt) {
                return parseAndUpsertModels(ch, s)
            }
            return (0, "拉取模型清单失败（网络不可达或鉴权失败）")
        } catch (e: Exception) {
            return (0, e.message)
        }
    }

    private func parseAndUpsertModels(ch: ModelChannelPO, json: String): (Int64, String) {
        try {
            let root = JsonValue.fromStr(json)
            if (!(root is JsonObject)) {
                return (0, "响应不是 JSON 对象")
            }
            let obj = root.asObject()
            let dataOpt = obj.get("data")
            if (let Some(d) <- dataOpt) {
                if (!(d is JsonArray)) {
                    return (0, "响应无 data 数组（可能鉴权失败或返回错误体）")
                }
                let arr = d.asArray()
                var n = 0
                for (item in arr.getItems()) {
                    if (item is JsonObject) {
                        let io = item.asObject()
                        if (let Some(idv) <- io.get("id")) {
                            if (idv is JsonString) {
                                let mid = idv.asString().getValue()
                                if (!mid.isEmpty()) {
                                    if (tryInsertModel(ch, mid)) {
                                        n = n + 1
                                    }
                                }
                            }
                        }
                    }
                }
                return (Int64(n), "ok")
            }
            return (0, "响应无 data 数组（可能鉴权失败或返回错误体）")
        } catch (e: Exception) {
            return (0, e.message)
        }
    }

    private func tryInsertModel(ch: ModelChannelPO, modelId: String): Bool {
        try {
            let daoOpt = ORM.executor() as ModelChannelModelDAO
            if (let Some(dao) <- daoOpt) {
                if (dao.findModelChannelModelByChannelAndModel(ch.id, modelId).isSome()) {
                    return false
                }
                let po = ModelChannelModelPO(
                    "",
                    ch.id,
                    modelId,
                    None<String>,
                    "",
                    0,
                    0,
                    None<String>,
                    "pending",
                    None<DateTime>,
                    0,
                    None<String>,
                    DateTime.now(),
                    DateTime.now(),
                    None<DateTime>
                )
                let id = dao.insertModelChannelModel(po)
                return id != ""
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("ChannelProbe.tryInsertModel(${ch.code}/${modelId}) 失败：${e.message}")
            return false
        }
    }

    // ==================== T017：三枪能力探测 ====================

    /**
     * 对指定模型跑三枪（chat / stream / tools），写回能力位与健康快照。
     * @param modelId 目标模型；空串则用通道 default_model（再退化为 code）。
     * 返回探测明细 JsonObject（含各枪 ok / detail / capabilities / ok 总判）。
     */
    public func probe(code: String, modelId: String): JsonObject {
        let result = JsonObject()
        try {
            let chOpt = ChannelService.shared().getChannelByCode(code)
            if (chOpt.isNone()) {
                result.put("ok", JsonBool(false))
                result.put("detail", JsonString("通道 ${code} 不存在"))
                return result
            }
            let ch = chOpt.getOrThrow()
            let baseUrl = ChannelRegistry.shared().resolveBaseUrl(code)
            let apiKey = ChannelRegistry.shared().resolveSecret(code)
            let mid = if (modelId.isEmpty()) {
                ch.defaultModel.getOrDefault({ => code })
            } else {
                modelId
            }

            // T023 模式B（protocol = plugin:<name>）：协议私有，宿主不能假设有
            // OpenAI 兼容的 /chat/completions，委派插件自己实现三枪（契约 §3.4）。
            // 插件只报事实，熔断计数/降级仍由本类后续流程统一处理。
            if (PluginAdapterBridge.isPluginProtocol(ch.protocol)) {
                return this.probeViaPlugin(ch, mid)
            }

            let (chatOk, chatDetail) = gunChat(baseUrl, apiKey, mid)
            let (streamOk, streamDetail) = gunStream(baseUrl, apiKey, mid)
            let (toolsOk, toolsDetail) = gunTools(baseUrl, apiKey, mid)

            var caps = ArrayList<String>()
            if (chatOk) { caps.add("chat") }
            if (streamOk) { caps.add("stream") }
            if (toolsOk) { caps.add("tools") }
            let capStr = joinCaps(caps)

            // 条目级能力位写回
            writeModelCapabilities(ch, mid, capStr, chatOk)
            // 通道级能力位 + 健康快照（不 bump revision）
            var healthMap = HashMap<String, JsonValue>()
            healthMap.add("chat", JsonBool(chatOk))
            healthMap.add("stream", JsonBool(streamOk))
            healthMap.add("tools", JsonBool(toolsOk))
            healthMap.add("chat_detail", JsonString(truncate(chatDetail, 500)))
            healthMap.add("stream_detail", JsonString(truncate(streamDetail, 500)))
            healthMap.add("tools_detail", JsonString(truncate(toolsDetail, 500)))
            healthMap.add("checked_at", JsonString(DateTime.now().toString()))
            let healthJson = JsonObject(healthMap).toJsonString()
            ChannelService.shared().applyProbeResult(code, capStr, healthJson)
            // 健康历史
            writeHealth(ch, mid, chatOk || streamOk, chatDetail)

            result.put("ok", JsonBool(chatOk || streamOk))
            result.put("chat", JsonBool(chatOk))
            result.put("chat_detail", JsonString(truncate(chatDetail, 500)))
            result.put("stream", JsonBool(streamOk))
            result.put("stream_detail", JsonString(truncate(streamDetail, 500)))
            result.put("tools", JsonBool(toolsOk))
            result.put("tools_detail", JsonString(truncate(toolsDetail, 500)))
            result.put("capabilities", JsonString(capStr))
            return result
        } catch (e: Exception) {
            result.put("ok", JsonBool(false))
            result.put("detail", JsonString(e.message))
            return result
        }
    }

    /**
     * 模式 B 三枪探测（T023）：委派 L3 插件实现，宿主只做结果归一化与写回。
     *
     * 与模式 A 的差异只有"谁来发请求"：模式 A 宿主直接打
     * `POST {base}/chat/completions`，模式 B 由插件自己发（协议私有可能根本没有这个端点）。
     * 归一化后写入 llm_channel.capabilities / health / llm_channel_health 的逻辑与模式 A 完全一致，
     * 这样前端 `probe-result.vue` 与健康总览对两种协议无需区分。
     *
     * 插件不可用 / RPC 失败时返回 ok=false + 原始错误，不抛异常（探测失败不是宿主崩溃）。
     */
    private func probeViaPlugin(ch: ModelChannelPO, modelId: String): JsonObject {
        let result = JsonObject()
        let pluginName = PluginAdapterBridge.pluginNameOf(ch.protocol)
        try {
            // 跨包 JSON 类型转换的坑：cordis RPC 用 jsonvalue.JsonValue，
            // 宿主内部用 stdx 的 JsonValue，两者不通。**不要手写转换器**——
            // 统一走「cordis 侧 stringify() → 文本 → 宿主侧 JsonValue.fromStr」，
            // 这是唯一低风险路径（手工逐字段转换必漏字段且难维护）。
            let rawJson = PluginAdapterBridge.shared().probeText(
                pluginName,
                "{\"channel\":${quoteJson(ch.code)},\"model\":${quoteJson(modelId)}}"
            )
            let parsed = JsonValue.fromStr(rawJson)
            let objOpt = JsonUtils.asJsonObject(parsed)
            if (objOpt.isNone()) {
                result.put("ok", JsonBool(false))
                result.put("detail", JsonString("插件 ${pluginName} 返回格式非法（期望 JSON 对象）"))
                result.put("probe_via", JsonString("plugin:${pluginName}"))
                return result
            }
            let obj = objOpt.getOrThrow()
            let chatOk = jsonBool(obj, "chat", false)
            let streamOk = jsonBool(obj, "stream", false)
            let toolsOk = jsonBool(obj, "tools", false)
            let chatDetail = jsonStr(obj, "chat_detail")
            let streamDetail = jsonStr(obj, "stream_detail")
            let toolsDetail = jsonStr(obj, "tools_detail")

            // 能力位：优先用插件上报的 capabilities，缺失则按三枪结果推
            // 注意读的是已校验过的 obj（不是原始 parsed），复用本文件统一的 jsonStr 辅助
            var capStr = jsonStr(obj, "capabilities")
            if (capStr.isEmpty()) {
                var caps = ArrayList<String>()
                if (chatOk) { caps.add("chat") }
                if (streamOk) { caps.add("stream") }
                if (toolsOk) { caps.add("tools") }
                capStr = joinCaps(caps)
            }

            writeModelCapabilities(ch, modelId, capStr, chatOk)
            var healthMap = HashMap<String, JsonValue>()
            healthMap.add("chat", JsonBool(chatOk))
            healthMap.add("stream", JsonBool(streamOk))
            healthMap.add("tools", JsonBool(toolsOk))
            healthMap.add("chat_detail", JsonString(truncate(chatDetail, 500)))
            healthMap.add("stream_detail", JsonString(truncate(streamDetail, 500)))
            healthMap.add("tools_detail", JsonString(truncate(toolsDetail, 500)))
            healthMap.add("probe_via", JsonString("plugin:${pluginName}"))
            healthMap.add("checked_at", JsonString(DateTime.now().toString()))
            ChannelService.shared().applyProbeResult(ch.code, capStr, JsonObject(healthMap).toJsonString())
            writeHealth(ch, modelId, chatOk || streamOk, chatDetail)

            result.put("ok", JsonBool(chatOk || streamOk))
            result.put("chat", JsonBool(chatOk))
            result.put("chat_detail", JsonString(truncate(chatDetail, 500)))
            result.put("stream", JsonBool(streamOk))
            result.put("stream_detail", JsonString(truncate(streamDetail, 500)))
            result.put("tools", JsonBool(toolsOk))
            result.put("tools_detail", JsonString(truncate(toolsDetail, 500)))
            result.put("capabilities", JsonString(capStr))
            result.put("probe_via", JsonString("plugin:${pluginName}"))
            return result
        } catch (e: Exception) {
            result.put("ok", JsonBool(false))
            result.put("detail", JsonString("插件 ${pluginName} 探测失败：${e.message}"))
            result.put("probe_via", JsonString("plugin:${pluginName}"))
            return result
        }
    }

    /**
     * 对所有非 disabled 通道跑一次轻量健康探活（chat 枪），写 llm_channel_health 历史与通道 health 快照。
     * 连续失败达阈值（3 次）置 degraded（从 catalog 摘除）；恢复后自动归位 enabled。
     */
    public func probeHealthAll(): Unit {
        try {
            let channels = ChannelService.shared().listChannels()
            for (ch in channels) {
                if (ch.status == "disabled") {
                    continue
                }
                let code = ch.code
                let baseUrl = ChannelRegistry.shared().resolveBaseUrl(code)
                let apiKey = ChannelRegistry.shared().resolveSecret(code)
                let mid = ch.defaultModel.getOrDefault({ => code })
                let (ok, detail) = gunChat(baseUrl, apiKey, mid)
                writeHealth(ch, mid, ok, detail)

                // 读取上一次 failStreak（存在 health JSON 中）
                var streak = 0
                if (!ch.health.isEmpty()) {
                    streak = readFailStreak(ch.health)
                }
                if (ok) {
                    streak = 0
                } else {
                    streak = streak + 1
                }
                // 写回新的 health（含 failStreak）
                var healthMap = HashMap<String, JsonValue>()
                healthMap.add("ok", JsonBool(ok))
                healthMap.add("detail", JsonString(truncate(detail, 500)))
                healthMap.add("failStreak", JsonInt(Int64(streak)))
                healthMap.add("checked_at", JsonString(DateTime.now().toString()))
                ChannelService.shared().applyProbeResult(code, ch.capabilities, JsonObject(healthMap).toJsonString())

                // 状态机：连续失败 >=3 -> degraded；恢复且曾 degraded -> enabled
                let newStatus = if (streak >= 3) {
                    "degraded"
                } else if (ok && ch.status == "degraded") {
                    "enabled"
                } else {
                    ch.status
                }
                if (newStatus != ch.status) {
                    ChannelService.shared().applyHealthStatus(code, newStatus)
                    LogUtils.info("ChannelProbe.probeHealthAll: ${code} 状态 ${ch.status} -> ${newStatus} (failStreak=${streak})")
                }
            }
        } catch (e: Exception) {
            LogUtils.error("ChannelProbe.probeHealthAll 失败：${e.message}")
        }
    }

    private func readFailStreak(healthJson: String): Int64 {
        try {
            let root = JsonValue.fromStr(healthJson)
            if (root is JsonObject) {
                let obj = root.asObject()
                if (let Some(v) <- obj.get("failStreak")) {
                    if (v is JsonInt) {
                        return v.asInt().getValue()
                    }
                }
            }
        } catch (_: Exception) {}
        return 0
    }

    // ==================== 三枪私有实现 ====================

    private func gunChat(baseUrl: String, apiKey: String, modelId: String): (Bool, String) {
        if (baseUrl.isEmpty()) {
            return (false, "通道未配置 base_url")
        }
        try {
            let url = if (baseUrl.endsWith("/")) { baseUrl + "chat/completions" } else { baseUrl + "/chat/completions" }
            let body = buildChatBody(modelId, false, false)
            let respOpt = HttpUtils.post(url, authHeader(apiKey), body)
            if (let Some(s) <- respOpt) {
                if (s.contains("choices")) {
                    return (true, "ok")
                }
                return (false, truncate(s, 500))
            }
            return (false, "无响应（网络/鉴权/超时）")
        } catch (e: Exception) {
            return (false, e.message)
        }
    }

    private func gunStream(baseUrl: String, apiKey: String, modelId: String): (Bool, String) {
        if (baseUrl.isEmpty()) {
            return (false, "通道未配置 base_url")
        }
        try {
            let url = if (baseUrl.endsWith("/")) { baseUrl + "chat/completions" } else { baseUrl + "/chat/completions" }
            let body = buildChatBody(modelId, true, false)
            // HttpUtils.post 对 SSE 返回完整响应体字符串；判定含 "data:" 即视为流式可用
            let respOpt = HttpUtils.post(url, authHeader(apiKey), body)
            if (let Some(s) <- respOpt) {
                if (s.contains("data:")) {
                    return (true, "ok")
                }
                return (false, truncate(s, 500))
            }
            return (false, "无响应（网络/鉴权/超时）")
        } catch (e: Exception) {
            return (false, e.message)
        }
    }

    private func gunTools(baseUrl: String, apiKey: String, modelId: String): (Bool, String) {
        if (baseUrl.isEmpty()) {
            return (false, "通道未配置 base_url")
        }
        try {
            let url = if (baseUrl.endsWith("/")) { baseUrl + "chat/completions" } else { baseUrl + "/chat/completions" }
            let body = buildChatBody(modelId, false, true)
            let respOpt = HttpUtils.post(url, authHeader(apiKey), body)
            if (let Some(s) <- respOpt) {
                // 带 tools 请求，2xx 且未被当作错误体返回即视为支持（tool_calls 可选）
                if (s.contains("choices") || s.contains("tool_calls")) {
                    return (true, "ok")
                }
                return (false, truncate(s, 500))
            }
            return (false, "无响应（网络/鉴权/超时）")
        } catch (e: Exception) {
            return (false, e.message)
        }
    }

    // ==================== 写回辅助 ====================

    private func writeModelCapabilities(ch: ModelChannelPO, modelId: String, capStr: String, ok: Bool): Unit {
        try {
            let daoOpt = ORM.executor() as ModelChannelModelDAO
            if (let Some(dao) <- daoOpt) {
                let existing = dao.findModelChannelModelByChannelAndModel(ch.id, modelId)
                if (let Some(po) <- existing) {
                    po.capabilities = capStr
                    if (ok && po.status == "pending") {
                        po.status = "enabled"
                    }
                    po.probedAt = Some(DateTime.now())
                    po.revision = po.revision + 1
                    dao.updateModelChannelModelCapabilities(po)
                }
            }
        } catch (e: Exception) {
            LogUtils.error("ChannelProbe.writeModelCapabilities(${ch.code}/${modelId}) 失败：${e.message}")
        }
    }

    private func writeHealth(ch: ModelChannelPO, modelId: String, ok: Bool, detail: String): Unit {
        try {
            let daoOpt = ORM.executor() as ModelChannelHealthDAO
            if (let Some(dao) <- daoOpt) {
                let po = ModelChannelHealthPO(
                    "",
                    ch.id,
                    Some(modelId),
                    ok,
                    0,
                    None<String>,
                    Some(truncate(detail, 500)),
                    DateTime.now()
                )
                dao.insertModelChannelHealth(po)
            }
        } catch (e: Exception) {
            LogUtils.error("ChannelProbe.writeHealth(${ch.code}/${modelId}) 失败：${e.message}")
        }
    }

    // ==================== HTTP 辅助 ====================

    private func authHeader(apiKey: String): HashMap<String, String> {
        let h = HashMap<String, String>()
        h.add("Content-Type", "application/json")
        if (!apiKey.isEmpty()) {
            h.add("Authorization", "Bearer ${apiKey}")
        }
        return h
    }

    private func buildChatBody(modelId: String, stream: Bool, tools: Bool): JsonObject {
        let body = JsonObject()
        body.put("model", JsonString(modelId))
        let msgArr = JsonArray()
        let um = JsonObject()
        um.put("role", JsonString("user"))
        um.put("content", JsonString("ping"))
        msgArr.add(um)
        body.put("messages", msgArr)
        body.put("stream", JsonBool(stream))
        body.put("max_tokens", JsonInt(Int64(16)))
        if (tools) {
            let toolsArr = JsonArray()
            let tool = JsonObject()
            tool.put("type", JsonString("function"))
            let fn = JsonObject()
            fn.put("name", JsonString("get_weather"))
            fn.put("description", JsonString("获取指定城市天气"))
            let params = JsonObject()
            params.put("type", JsonString("object"))
            let props = JsonObject()
            let city = JsonObject()
            city.put("type", JsonString("string"))
            city.put("description", JsonString("城市名"))
            props.put("city", city)
            params.put("properties", props)
            let reqArr = JsonArray()
            reqArr.add(JsonString("city"))
            params.put("required", reqArr)
            fn.put("parameters", params)
            tool.put("function", fn)
            toolsArr.add(tool)
            body.put("tools", toolsArr)
        }
        return body
    }

    private func joinCaps(arr: ArrayList<String>): String {
        var s = "["
        var i = 0
        for (x in arr) {
            if (i > 0) {
                s = s + ","
            }
            s = s + "\"" + x + "\""
            i = i + 1
        }
        s = s + "]"
        return s
    }

    // ========== 模式 B 探测结果读取辅助（T023） ==========

    /** 从插件返回的 JSON 对象里读布尔字段，缺失/类型不符时用默认值 */
    private func jsonBool(obj: JsonObject, key: String, defaultVal: Bool): Bool {
        match (obj.get(key)) {
            case Some(v) => JsonUtils.toBool(v).getOrDefault({ => defaultVal })
            case None => defaultVal
        }
    }

    /** 从插件返回的 JSON 对象里读字符串字段，缺失/类型不符时返回空串 */
    private func jsonStr(obj: JsonObject, key: String): String {
        match (obj.get(key)) {
            case Some(v) => JsonUtils.toString(v).getOrDefault({ => "" })
            case None => ""
        }
    }

    /**
     * 把字符串包成 JSON 字符串字面量（含转义），用于拼 params 文本。
     * 通道 code / 模型 id 都是配置值，可能含引号或反斜杠，必须转义。
     */
    private func quoteJson(s: String): String {
        let obj = JsonObject()
        obj.put("v", JsonString(s))
        // 产出 {"v":"..."}，再截出 "..." 部分
        let text = obj.toJsonString()
        let marker = "\"v\":"
        if (let Some(idx) <- text.indexOf(marker)) {
            let start = idx + marker.size
            return text[start..(text.size - 1)]
        }
        return "\"\""
    }

    private func truncate(s: String, n: Int64): String {
        if (s.size <= n) {
            return s
        }
        let runes = s.toRuneArray()
        if (runes.size <= n) {
            return s
        }
        var out = ""
        var i = Int64(0)
        while (i < n) {
            out = out + runes[i].toString()
            i = i + 1
        }
        return out + "..."
    }
}
