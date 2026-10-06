/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.llm_channel

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.APIError
import magic.app.models.uctoo.ModelRouteRulePO
import magic.model.channel.{ChannelService, ModelRouter, RouteRequest}
import std.collection.{HashMap, Map, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray}
import magic.jsonable.JsonUtils
import magic.log.LogUtils

/**
 * LlmRouteRuleController — 通道路由规则管理 API（T027，design.md §8 / §7）。
 *
 * 端点（统一前缀 /api/v1/uctoo/llm_route_rule）：
 *   GET  /list      规则列表（管理面）
 *   POST /add       新增规则
 *   POST /edit      更新规则
 *   POST /del       删除规则（软删）
 *   POST /evaluate  校验一条选路请求命中的通道 + 候选顺序（T006 / T029 的调试入口）
 *
 * 规则字段中的 JSON 数组（require_capabilities / channel_chain / fallback_chain）以 JSON 字符串
 * 落库，由 ChannelService 解析后注入 ModelRouter；本控制器只负责收口与透传。
 */
public class LlmRouteRuleController {
    private var service: ChannelService

    public init() {
        this.service = ChannelService.shared()
    }

    // ==================== 列表 ====================

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let rules = service.listRouteRules()
            var arr = ""
            var i: Int64 = 0
            let n = Int64(rules.size)
            while (i < n) {
                if (let Some(po) <- rules.get(i)) {
                    if (arr.isEmpty()) {
                        arr = po.toJson()
                    } else {
                        arr = arr + "," + po.toJson()
                    }
                }
                i = i + 1
            }
            res.status(200).json("{\"totalCount\":${n},\"llm_route_rules\":[${arr}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 新增 ====================

    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let po = mapToRulePO(b, "")
                let resultOpt = service.addRouteRule(po, currentOperator(req))
                if (let Some(created) <- resultOpt) {
                    res.status(200).json(created.toJson())
                } else {
                    res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"添加失败（参数错误）\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 更新 ====================

    public func edit(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let id = optStr(b, "id")
                if (id.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少规则 id\"}")
                    return
                }
                let po = mapToRulePO(b, id)
                let ok = service.updateRouteRule(po, currentOperator(req))
                if (ok) {
                    res.status(200).json("{\"desc\":\"更新成功\"}")
                } else {
                    res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"更新失败（规则不存在或参数错误）\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 删除 ====================

    public func del(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let id = optStr(b, "id")
                if (id.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少规则 id\"}")
                    return
                }
                let ok = service.deleteRouteRule(id, currentOperator(req))
                if (ok) {
                    res.status(200).json("{\"desc\":\"删除成功\"}")
                } else {
                    res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"删除失败（规则不存在）\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 选路校验（T006 / T029 调试入口） ====================

    /**
     * POST /api/v1/uctoo/llm_route_rule/evaluate
     *
     * 给定一条选路请求（scope + require_capabilities），返回 ModelRouter 实际命中的通道与候选顺序。
     * 不改动任何状态，纯只读校验，便于运维确认规则/策略生效。
     *
     * 请求体：{"scope":"global","require_capabilities":["tools","vision"]}
     */
    public func evaluate(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求体为空\"}")
                return
            }
            let v = JsonValue.fromStr(body)
            if (!(v is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求体非 JSON 对象\"}")
                return
            }
            let obj = v.asObject()
            var scope = "global"
            if (let Some(sv) <- obj.get("scope")) {
                if (let Some(js) <- JsonUtils.toString(sv)) {
                    scope = js
                }
            }
            var reqCaps = ArrayList<String>()
            if (let Some(capv) <- obj.get("require_capabilities")) {
                if (let Some(arr) <- JsonUtils.asJsonArray(capv)) {
                    for (item in arr.getItems()) {
                        if (let Some(js) <- JsonUtils.toString(item)) {
                            reqCaps.add(js)
                        }
                    }
                }
            }
            let request = RouteRequest(scope, reqCaps)
            let resolvedOpt = ModelRouter.shared().resolve(request)
            let candidates = ModelRouter.shared().candidatesFor(request)
            var resolvedCode = ""
            if (let Some(snap) <- resolvedOpt) {
                resolvedCode = snap.code
            }
            var candArr = JsonArray()
            var i: Int64 = 0
            let n = Int64(candidates.size)
            while (i < n) {
                if (let Some(c) <- candidates.get(i)) {
                    candArr.add(JsonString(c))
                }
                i = i + 1
            }
            var root = HashMap<String, JsonValue>()
            root.add("scope", JsonString(scope))
            root.add("resolved", JsonString(resolvedCode))
            root.add("candidates", candArr)
            res.status(200).json(JsonObject(root).toJsonString())
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 影子流量对比（T032） ====================

    /**
     * GET /api/v1/uctoo/llm_route_rule/shadow-stats
     *
     * 返回影子/主通道的对比指标：{"<code>:main": {requests, failures, totalLatencyMs}, ...}。
     * 影子请求不影响主结果，这里只是把两边的请求数、失败数、累计延迟并排给出，
     * 供 shadow-compare 页面算延迟均值与失败率差异。
     */
    public func shadowStats(req: HttpRequest, res: HttpResponse): Unit {
        try {
            res.status(200).json(ModelRouter.shared().shadowStatsJson())
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 私有辅助 ====================

    private func currentOperator(req: HttpRequest): String {
        let uid = req.getLocals("userId")
        if (let Some(u) <- uid) {
            let sOpt = u as String
            if (let Some(s) <- sOpt) {
                if (!s.isEmpty()) {
                    return s
                }
            }
        }
        return "api"
    }

    private func parseBody(req: HttpRequest): ?Map<String, Any> {
        try {
            let body = req.body
            if (body.isEmpty()) {
                return None<Map<String, Any>>
            }
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                return None<Map<String, Any>>
            }
            let jsonObj = jsonValue.asObject()
            let map = HashMap<String, Any>()
            for ((key, value) in jsonObj.getFields()) {
                map.add(key, jsonValueToAny(value))
            }
            return Some<Map<String, Any>>(map)
        } catch (e: Exception) {
            return None<Map<String, Any>>
        }
    }

    private func jsonValueToAny(value: JsonValue): Any {
        if (value is JsonString) {
            return value.asString().getValue()
        } else if (value is JsonInt) {
            return value.asInt().getValue()
        } else if (value is JsonBool) {
            return value.asBool().getValue()
        } else if (value is JsonArray) {
            // 数组字段（require_capabilities / channel_chain / fallback_chain）以 JSON 字符串落库，
            // 这里把 JsonArray 重新序列化为 JSON 文本，避免被丢弃（map 解析只认标量）。
            return jsonArrayToString(value)
        } else {
            return ""
        }
    }

    /**
     * 把 JsonArray 序列化为 JSON 文本（如 ["tools","vision"]），用于落库为 JSON 字符串列。
     */
    private func jsonArrayToString(v: JsonValue): String {
        if (let Some(arr) <- JsonUtils.asJsonArray(v)) {
            var parts = ArrayList<String>()
            for (item in arr.getItems()) {
                if (item is JsonString) {
                    parts.add("\"" + item.asString().getValue() + "\"")
                } else if (item is JsonInt) {
                    parts.add(item.asInt().getValue().toString())
                } else if (item is JsonBool) {
                    parts.add(if (item.asBool().getValue()) { "true" } else { "false" })
                } else {
                    parts.add(item.toString())
                }
            }
            var s = "["
            var i = 0
            for (p in parts) {
                if (i > 0) {
                    s = s + ","
                }
                s = s + p
                i = i + 1
            }
            s = s + "]"
            return s
        }
        return "[]"
    }

    private func mapToRulePO(map: Map<String, Any>, id: String): ModelRouteRulePO {
        let po = ModelRouteRulePO()
        po.id = id
        if (let Some(scope) <- map.get("scope")) {
            let sOpt = scope as String
            if (let Some(s) <- sOpt) { if (!s.isEmpty()) { po.scope = s } }
        }
        if (let Some(rc) <- map.get("require_capabilities")) {
            let sOpt = rc as String
            if (let Some(s) <- sOpt) { po.requireCapabilities = s }
        }
        if (let Some(cc) <- map.get("channel_chain")) {
            let sOpt = cc as String
            if (let Some(s) <- sOpt) { po.channelChain = s }
        }
        if (let Some(fc) <- map.get("fallback_chain")) {
            let sOpt = fc as String
            if (let Some(s) <- sOpt) { po.fallbackChain = s }
        }
        if (let Some(strategy) <- map.get("strategy")) {
            let sOpt = strategy as String
            if (let Some(s) <- sOpt) { if (!s.isEmpty()) { po.strategy = s } }
        }
        if (let Some(sp) <- map.get("shadow_percent")) {
            let i32Opt = sp as Int32
            if (let Some(i) <- i32Opt) {
                po.shadowPercent = i
            } else {
                let i64Opt = sp as Int64
                if (let Some(i) <- i64Opt) { po.shadowPercent = Int32(i) }
            }
        }
        if (let Some(priority) <- map.get("priority")) {
            let i32Opt = priority as Int32
            if (let Some(i) <- i32Opt) {
                po.priority = i
            } else {
                let i64Opt = priority as Int64
                if (let Some(i) <- i64Opt) { po.priority = Int32(i) }
            }
        }
        if (let Some(enabled) <- map.get("enabled")) {
            let bOpt = enabled as Bool
            if (let Some(b) <- bOpt) { po.enabled = b }
        }
        return po
    }

    private func optStr(map: Map<String, Any>, key: String): String {
        if (let Some(v) <- map.get(key)) {
            let sOpt = v as String
            if (let Some(s) <- sOpt) { return s }
        }
        return ""
    }
}
