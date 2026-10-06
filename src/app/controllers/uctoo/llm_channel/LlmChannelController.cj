/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.llm_channel

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.APIError
import magic.app.models.uctoo.ModelChannelPO
import magic.model.channel.{ChannelService, ChannelProbe}
import std.collection.{HashMap, Map}
import std.convert.Parsable
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.log.LogUtils

/**
 * LlmChannelController — 通道管理 API（T012）。
 *
 * 委托 magic.model.channel.ChannelService 完成持久化 / 审计 / 热生效广播；
 * 本类只做 HTTP 收口、请求体解析与 JSON 序列化。
 *
 * 端点（design.md §8）：
 *   GET  /list                 通道列表（管理面；密钥仅回显 secret_ref 引用，绝不返回明文）
 *   GET  /catalog              用户面通道目录（T035；字段裁剪，普通用户可读）
 *   GET  /health               健康总览（T018；各通道状态/健康位 + 总览计数）
 *   GET  /audit                变更审计（T019；append-only，含 source 追溯）
 *   GET  /:code               详情
 *   POST /add /edit /del      增删改（写审计 + 广播）
 *   POST /:code/toggle        启停
 *   POST /:code/default       一键设为默认（热生效核心动作）
 *   POST /:code/test          连通性测试（返回错误明细）
 *   POST /reload              手动刷新注册表（救急）
 *
 * 待实现（Phase 1 后续）：POST /:code/probe（T017）、POST /:code/sync-models（T016）、
 * GET /models（T016）—— 都依赖新增的 channel_probe.cj 探测服务。
 */
public class LlmChannelController {
    private var service: ChannelService

    public init() {
        this.service = ChannelService.shared()
    }

    // ==================== 列表 ====================

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            var currentPage: Int64 = 1
            var pageSize: Int64 = 10
            let cpOpt = req.queryParam("currentPage")
            if (cpOpt.isSome()) { currentPage = Int64.parse(cpOpt.getOrThrow()) }
            let psOpt = req.queryParam("pageSize")
            if (psOpt.isSome()) { pageSize = Int64.parse(psOpt.getOrThrow()) }
            if (pageSize > 1000) {
                res.status(400).json(APIError("40004", "请求数量不能超过1000条").toJson())
                return
            }
            let channels = service.listChannels()
            let total = Int64(channels.size)
            let totalPage = if (pageSize > 0) {
                (total + Int64(pageSize) - 1) / Int64(pageSize)
            } else {
                Int64(0)
            }
            let start = (currentPage - 1) * pageSize
            let end = if (start + pageSize > total) { total } else { start + pageSize }
            var arr = ""
            var i = start
            while (i < end) {
                if (let Some(po) <- channels.get(i)) {
                    if (arr.isEmpty()) {
                        arr = po.toJson()
                    } else {
                        arr = arr + "," + po.toJson()
                    }
                }
                i = i + 1
            }
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"llm_channels\":[${arr}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 详情 ====================

    public func detail(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let poOpt = service.getChannelByCode(code)
                if (let Some(po) <- poOpt) {
                    res.status(200).json(po.toJson())
                } else {
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"通道不存在\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 用户面通道目录（T035 / REQ-DMC-021） ====================

    /**
     * GET /api/v1/uctoo/llm_channel/catalog
     *
     * 终端用户（普通用户，无 llm_channel 管理权限）在聊天框切换器拉取的通道目录。
     * 与管理面 /list 的区别（design.md §8）：
     * - 数据源是 ChannelService.listUserCatalog()，只含 enabled 且作用域对用户可见的通道；
     * - 字段裁剪：只给 code / display_name / default_model / capabilities / priority / is_default，
     *   **绝不返回** base_url / secret_ref / health / config / probe_at 等管理字段（V5）；
     * - 独立权限节点，与管理 API 的 RBAC 分离。
     *
     * 返回 default 字段：当前全局默认通道编码，前端用它决定切换器初始选中项。
     */
    public func catalog(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let list = service.listUserCatalog()
            var arr = JsonArray()
            var defaultCode = ""
            for (po in list) {
                var item = HashMap<String, JsonValue>()
                item.add("code", JsonString(po.code))
                item.add("display_name", JsonString(po.displayName.getOrDefault({ => po.code })))
                item.add("default_model", JsonString(po.defaultModel.getOrDefault({ => "" })))
                item.add("capabilities", JsonString(po.capabilities))
                item.add("priority", JsonInt(Int64(po.priority)))
                item.add("is_default", JsonBool(po.isDefault))
                if (po.isDefault) {
                    defaultCode = po.code
                }
                arr.add(JsonObject(item))
            }
            var root = HashMap<String, JsonValue>()
            root.add("totalCount", JsonInt(Int64(list.size)))
            root.add("default", JsonString(defaultCode))
            root.add("llm_channels", arr)
            res.status(200).json(JsonObject(root).toJsonString())
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 新增 ====================

    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let po = mapToChannelPO(b)
                let resultOpt = service.addChannel(po, currentOperator(req))
                if (let Some(created) <- resultOpt) {
                    res.status(200).json(created.toJson())
                } else {
                    res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"添加失败（code 为空或已存在）\"}")
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
                let po = mapToChannelPO(b)
                let ok = service.updateChannel(po, currentOperator(req))
                if (ok) {
                    res.status(200).json("{\"desc\":\"更新成功\"}")
                } else {
                    res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"更新失败（通道不存在或参数错误）\"}")
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
                let code = optStr(b, "code")
                if (code.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
                    return
                }
                let ok = service.deleteChannel(code, currentOperator(req))
                if (ok) {
                    res.status(200).json("{\"desc\":\"删除成功\"}")
                } else {
                    res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"删除失败（通道不存在）\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 启停 ====================

    public func toggle(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let body = parseBody(req)
                let enabled = if (let Some(b) <- body) { optBool(b, "enabled") } else { true }
                let ok = service.toggleChannel(code, enabled, currentOperator(req))
                if (ok) {
                    res.status(200).json("{\"desc\":\"ok\"}")
                } else {
                    res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"启停失败（通道不存在）\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 设为默认 ====================

    public func setDefault(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let ok = service.setDefault(code)
                if (ok) {
                    res.status(200).json("{\"desc\":\"ok\"}")
                } else {
                    res.status(400).json("{\"errno\":\"40003\",\"errmsg\":\"设置默认失败（通道不存在）\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 连通性测试 ====================

    public func test(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let (ok, detail) = service.testChannel(code)
                // 用 JsonObject 组装而非手拼字符串：detail 是上游错误原文，含引号/换行，
                // 手拼既要自己转义又易漏；库组装天然安全（仓颉 String 遍历出的是 UInt8 字节，
                // 不能与字符串字面量比较，故不自己写 escapeJson）。
                let payload = JsonObject()
                payload.put("ok", JsonBool(ok))
                payload.put("detail", JsonString(detail))
                res.status(200).json(payload.toJsonString())
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 手动刷新注册表 ====================

    public func reload(req: HttpRequest, res: HttpResponse): Unit {
        try {
            service.reloadRegistry()
            res.status(200).json("{\"desc\":\"ok\"}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 全通道模型清单（T016） ====================

    /**
     * GET /api/v1/uctoo/llm_channel/models
     *
     * 全部通道下的模型条目（llm_channel_model），供聊天框 / 管理页下拉。
     * 支持可选过滤：?status=pending / ?channel=arcbench。
     */
    public func models(req: HttpRequest, res: HttpResponse): Unit {
        try {
            var statusFilter = ""
            let stOpt = req.queryParam("status")
            if (stOpt.isSome()) { statusFilter = stOpt.getOrThrow() }
            var channelFilter = ""
            let chOpt = req.queryParam("channel")
            if (chOpt.isSome()) { channelFilter = chOpt.getOrThrow() }

            let all = service.listAllModels()
            var arr = ""
            var i: Int64 = 0
            let n = Int64(all.size)
            while (i < n) {
                if (let Some(po) <- all.get(i)) {
                    if (!statusFilter.isEmpty() && po.status != statusFilter) {
                        i = i + 1
                        continue
                    }
                    if (!channelFilter.isEmpty() && !po.channelId.isEmpty()) {
                        let ch = service.getChannelByCode(channelFilter)
                        if (ch.isNone() || ch.getOrThrow().id != po.channelId) {
                            i = i + 1
                            continue
                        }
                    }
                    if (arr.isEmpty()) {
                        arr = po.toJson()
                    } else {
                        arr = arr + "," + po.toJson()
                    }
                }
                i = i + 1
            }
            res.status(200).json("{\"totalCount\":${n},\"llm_channel_models\":[${arr}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 拉模型清单（T016） ====================

    /**
     * POST /api/v1/uctoo/llm_channel/:code/sync-models
     *
     * 拉取该通道的模型清单并增量写入 llm_channel_model（新增默认 pending）。
     */
    public func syncModels(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let (added, detail) = ChannelProbe.shared().syncModels(code)
                let payload = JsonObject()
                payload.put("added", JsonInt(added))
                payload.put("detail", JsonString(detail))
                payload.put("ok", JsonBool(detail == "ok" || added > 0))
                res.status(200).json(payload.toJsonString())
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 三枪能力探测（T017） ====================

    /**
     * POST /api/v1/uctoo/llm_channel/:code/probe
     *
     * 对指定模型跑三枪（chat / stream / tools），写回能力位与健康快照。
     * 请求体可选 model_id（缺省用通道 default_model）。
     */
    public func probe(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                var modelId = ""
                let body = parseBody(req)
                if (let Some(b) <- body) {
                    modelId = optStr(b, "model_id")
                    if (modelId.isEmpty()) {
                        modelId = optStr(b, "modelId")
                    }
                }
                let result = ChannelProbe.shared().probe(code, modelId)
                res.status(200).json(result.toJsonString())
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 健康总览（T018） ====================

    /**
     * GET /api/v1/uctoo/llm_channel/health
     *
     * 各通道状态 / 健康位 / 探测时间 + 总览计数与当前默认通道。
     * 数据源是 llm_channel 表（DB 真相），不是注册表快照——因为 health / probe_at
     * 只有表里才有。T026（周期探活）落地后这里就是探活结果的总览视图。
     */
    public func health(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let channels = service.listChannels()
            var arr = ""
            var enabledCount: Int64 = 0
            var disabledCount: Int64 = 0
            var defaultCode = ""
            var i: Int64 = 0
            let n = Int64(channels.size)
            while (i < n) {
                if (let Some(po) <- channels.get(i)) {
                    var item = HashMap<String, JsonValue>()
                    item.add("code", JsonString(po.code))
                    item.add("display_name", JsonString(po.displayName.getOrDefault({ => po.code })))
                    item.add("status", JsonString(po.status))
                    item.add("is_default", JsonBool(po.isDefault))
                    item.add("health", JsonString(po.health))
                    item.add("capabilities", JsonString(po.capabilities))
                    let obj = JsonObject(item).toJsonString()
                    if (arr.isEmpty()) {
                        arr = obj
                    } else {
                        arr = arr + "," + obj
                    }
                    if (po.status == "enabled") {
                        enabledCount = enabledCount + 1
                    } else {
                        disabledCount = disabledCount + 1
                    }
                    if (po.isDefault) {
                        defaultCode = po.code
                    }
                }
                i = i + 1
            }
            res.status(200).json("{\"totalCount\":${n},\"enabledCount\":${enabledCount},\"disabledCount\":${disabledCount},\"default\":\"${defaultCode}\",\"llm_channels\":[${arr}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 变更审计（T019） ====================

    /**
     * GET /api/v1/uctoo/llm_channel/audit
     *
     * 变更审计列表（append-only）：每次 add / edit / del / toggle / default 都留痕，
     * 含 source（seed / api / ui / agent），可追溯是谁改的（design.md §8、spec.md）。
     *
     * 查询参数：
     *   code  可选，按通道编码过滤；不传则查全部通道
     *   limit 可选，返回条数，默认 50，上限 200（审计表只增不减，必须设上限）
     */
    public func audit(req: HttpRequest, res: HttpResponse): Unit {
        try {
            var limit: Int64 = 50
            let lpOpt = req.queryParam("limit")
            if (lpOpt.isSome()) { limit = Int64.parse(lpOpt.getOrThrow()) }
            if (limit <= 0) { limit = 50 }
            if (limit > 200) { limit = 200 }

            var code = ""
            let cOpt = req.queryParam("code")
            if (cOpt.isSome()) { code = cOpt.getOrThrow() }

            let list = service.listAudits(code, limit)
            var arr = ""
            var i: Int64 = 0
            let n = Int64(list.size)
            while (i < n) {
                if (let Some(po) <- list.get(i)) {
                    if (arr.isEmpty()) {
                        arr = po.toJson()
                    } else {
                        arr = arr + "," + po.toJson()
                    }
                }
                i = i + 1
            }
            res.status(200).json("{\"totalCount\":${n},\"llm_channel_audit\":[${arr}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    // ==================== 配置导出 / 导入（T033） ====================

    /**
     * GET /api/v1/uctoo/llm_channel/export
     *
     * 导出全部通道 + 路由规则配置。**密钥只导引用名，不导明文**（V5）：
     * 合法形式 `env:NAME` 或全大写变量名原样输出；疑似明文一律抹成 "***"。
     */
    public func exportConfig(req: HttpRequest, res: HttpResponse): Unit {
        try {
            res.status(200).json(service.exportConfig())
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    /**
     * POST /api/v1/uctoo/llm_channel/import
     *
     * 导入 exportConfig 产出的 JSON。**幂等且不覆盖**：code 已存在直接跳过，
     * 避免误覆盖目标环境已有配置；密钥为 "***" 或空时留空，由管理员按引用名补环境变量。
     */
    public func importConfig(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"导入内容为空\"}")
                return
            }
            res.status(200).json(service.importConfig(body))
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
        } else if (value is JsonFloat) {
            return value.asFloat().getValue()
        } else if (value is JsonBool) {
            return value.asBool().getValue()
        } else {
            return ""
        }
    }

    private func mapToChannelPO(map: Map<String, Any>): ModelChannelPO {
        let po = ModelChannelPO()
        if (let Some(code) <- map.get("code")) {
            let sOpt = code as String
            if (let Some(s) <- sOpt) { po.code = s }
        }
        if (let Some(displayName) <- map.get("display_name")) {
            let sOpt = displayName as String
            if (let Some(s) <- sOpt) { if (!s.isEmpty()) { po.displayName = Some<String>(s) } }
        }
        if (let Some(protocol) <- map.get("protocol")) {
            let sOpt = protocol as String
            if (let Some(s) <- sOpt) { po.protocol = s }
        }
        if (let Some(baseUrl) <- map.get("base_url")) {
            let sOpt = baseUrl as String
            if (let Some(s) <- sOpt) { if (!s.isEmpty()) { po.baseUrl = Some<String>(s) } }
        }
        if (let Some(secretRef) <- map.get("secret_ref")) {
            let sOpt = secretRef as String
            if (let Some(s) <- sOpt) { if (!s.isEmpty()) { po.secretRef = Some<String>(s) } }
        }
        if (let Some(defaultModel) <- map.get("default_model")) {
            let sOpt = defaultModel as String
            if (let Some(s) <- sOpt) { if (!s.isEmpty()) { po.defaultModel = Some<String>(s) } }
        }
        if (let Some(capabilities) <- map.get("capabilities")) {
            let sOpt = capabilities as String
            if (let Some(s) <- sOpt) { po.capabilities = s }
        }
        if (let Some(scopes) <- map.get("scopes")) {
            let sOpt = scopes as String
            if (let Some(s) <- sOpt) { po.scopes = s }
        }
        if (let Some(priority) <- map.get("priority")) {
            let i64Opt = priority as Int64
            if (let Some(i) <- i64Opt) {
                po.priority = Int32(i)
            } else {
                let i32Opt = priority as Int32
                if (let Some(i) <- i32Opt) {
                    po.priority = i
                } else {
                    let sOpt = priority as String
                    if (let Some(s) <- sOpt) {
                        try {
                            po.priority = Int32.parse(s)
                        } catch (e: Exception) {
                            po.priority = 0
                        }
                    }
                }
            }
        }
        if (let Some(status) <- map.get("status")) {
            let sOpt = status as String
            if (let Some(s) <- sOpt) { po.status = s }
        }
        if (let Some(config) <- map.get("config")) {
            let sOpt = config as String
            if (let Some(s) <- sOpt) { po.config = s }
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

    private func optBool(map: Map<String, Any>, key: String): Bool {
        if (let Some(v) <- map.get(key)) {
            let bOpt = v as Bool
            if (let Some(b) <- bOpt) { return b }
        }
        return true
    }

}
