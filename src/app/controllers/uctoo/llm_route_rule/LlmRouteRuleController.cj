/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.llm_route_rule

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.model.channel.{ChannelService, ModelRouter, RouteRequest}
import magic.jsonable.JsonUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.LlmRouteRulePO
import magic.app.services.uctoo.LlmRouteRuleService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class LlmRouteRuleController {
    private var service: LlmRouteRuleService

    public init(service: LlmRouteRuleService) {
        this.service = service
    }

    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let userIdStr = userId.getOrThrow() as String
            if (let Some(str) <- userIdStr) {
                if (str.isEmpty()) {
                    res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                    return
                }

                let body = parseBody(req)
                if (let Some(b) <- body) {
                    let entity = mapToEntity(b)
                    let result = service.createWithPermission(entity, str)
                    if (result.success) {
                        if (result.data.isSome()) {
                            let data = result.data.getOrThrow()
                            res.status(200).json(data.toJson())
                        } else {
                            res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建失败\"}")
                        }
                    } else {
                        let reason = result.reason ?? "创建失败"
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                }
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func edit(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let ids = b.get("ids")
                let id = b.get("id")

                let deletedAt = b.get("deleted_at")
                let isRestore = if (let Some(da) <- deletedAt) {
                    let daStr = da as String
                    if (let Some(s) <- daStr) {
                        s == "0"
                    } else {
                        false
                    }
                } else {
                    false
                }

                if (let Some(idsVal) <- ids) {
                    let idsStrOpt = idsVal as String
                    if (let Some(idsStr) <- idsStrOpt) {
                        let idArray = parseIdsArray(idsStr)

                        if (isRestore) {
                            let result = service.restoreMultiple(idArray)
                            if (result.success) {
                                res.status(200).json("{\"desc\":\"恢复成功\"}")
                            } else {
                                let reason = result.reason ?? "批量恢复失败"
                                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                            }
                        } else {
                            let entities = ArrayList<LlmRouteRulePO>()
                            for (idStr in idArray) {
                                let entity = mapToEntity(b)
                                entity.id = idStr
                                entities.add(entity)
                            }

                            let result = service.updateMultiple(entities)
                            if (result.success) {
                                if (let Some(data) <- result.data) {
                                    let sb = StringBuilder()
                                    sb.append("[")
                                    let size = data.size
                                    for (i in 0..size) {
                                        sb.append(data[i].toJson())
                                        if (i < size - 1) {
                                            sb.append(",")
                                        }
                                    }
                                    sb.append("]")
                                    res.status(200).json(sb.toString())
                                } else {
                                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"批量更新失败\"}")
                                }
                            } else {
                                let reason = result.reason ?? "批量更新失败"
                                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                            }
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"IDs参数格式错误\"}")
                    }
                } else {
                    if (let Some(idVal) <- id) {
                        let idStrOpt = idVal as String
                        if (let Some(idStr) <- idStrOpt) {
                            if (isRestore) {
                                let result = service.restore(idStr)
                                if (result.success) {
                                    if (let Some(data) <- result.data) {
                                        res.status(200).json(data.toJson())
                                    } else {
                                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"恢复失败\"}")
                                    }
                                } else {
                                    let reason = result.reason ?? "恢复失败"
                                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                                }
                            } else {
                                let entity = mapToEntity(b)
                                let editUserId = req.getLocals("userId")
                                var editUserIdStr = ""
                                if (let Some(u) <- editUserId) {
                                    let sOpt = u as String
                                    if (let Some(s) <- sOpt) { editUserIdStr = s }
                                }
                                let result = if (editUserIdStr.isEmpty()) {
                                    service.update(idStr, entity)
                                } else {
                                    service.updateWithPermission(idStr, entity, editUserIdStr)
                                }
                                if (result.success) {
                                    if (let Some(data) <- result.data) {
                                        res.status(200).json(data.toJson())
                                    } else {
                                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"更新失败\"}")
                                    }
                                } else {
                                    let reason = result.reason ?? "更新失败"
                                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                                }
                            }
                        } else {
                            res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"ID参数格式错误\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
                    }
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let id = b.get("id")
                let ids = b.get("ids")
                let forceOpt = b.get("force")
                let force = parseForce(forceOpt)

                if (let Some(idsVal) <- ids) {
                    let idsStrOpt = idsVal as String
                    if (let Some(idsStr) <- idsStrOpt) {
                        let idArray = parseIdsArray(idsStr)
                        let result = service.deleteMultiple(idArray, force)
                        if (result.success) {
                            res.status(200).json("{\"desc\":\"删除成功\"}")
                        } else {
                            let reason = result.reason ?? "批量删除失败"
                            res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"IDs参数格式错误\"}")
                    }
                } else if (let Some(idVal) <- id) {
                    let idStrOpt = idVal as String
                    if (let Some(idStr) <- idStrOpt) {
                        let delUserId = req.getLocals("userId")
                        var delUserIdStr = ""
                        if (let Some(u) <- delUserId) {
                            let sOpt = u as String
                            if (let Some(s) <- sOpt) { delUserIdStr = s }
                        }
                        let result = if (delUserIdStr.isEmpty()) {
                            service.delete(idStr, force)
                        } else {
                            service.deleteWithPermission(idStr, force, delUserIdStr)
                        }
                        if (result.success) {
                            res.status(200).json("{\"desc\":\"删除成功\"}")
                        } else {
                            let reason = result.reason ?? "删除失败"
                            res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"${reason}\"}")
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"ID参数格式错误\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")

            if (let Some(idVal) <- id) {
                let userId = req.getLocals("userId")
                var userIdStr = ""
                if (let Some(u) <- userId) {
                    let sOpt = u as String
                    if (let Some(s) <- sOpt) { userIdStr = s }
                }
                let result = if (userIdStr.isEmpty()) {
                    service.getById(idVal)
                } else {
                    service.getByIdWithPermission(idVal, userIdStr)
                }

                if (result.success) {
                    if (let Some(data) <- result.data) {
                        res.status(200).json(data.toJson())
                    } else {
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该llm_route_rule\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该llm_route_rule\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let currentPageParam = req.queryParam("currentPage")
            let pageSizeParam = req.queryParam("pageSize")

            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")

            let pageSize = if (let Some(ps) <- pageSizeParam) {
                Int32.parse(ps)
            } else if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }

            let currentPage = if (let Some(cp) <- currentPageParam) {
                Int32.parse(cp)
            } else if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)
            }

            if (pageSize > 1000) {
                res.status(400).json(APIError("40004", "请求数量不能超过1000条").toJson())
                return
            }

            let sortParam = req.queryParam("sort")
            let filterParam = req.queryParam("filter")

            let sortStr = if (let Some(s) <- sortParam) { s } else { "" }
            var filterStr = ""
            if (let Some(f) <- filterParam) {
                let decodedFilter = f.replace("%7B", "{")
                    .replace("%7D", "}")
                    .replace("%22", "\"")
                    .replace("%3A", ":")
                    .replace("%2C", ",")
                    .replace("+", " ")
                filterStr = decodedFilter
            }

            let userId = req.getLocals("userId")
            var userIdStr = ""
            if (let Some(u) <- userId) {
                let sOpt = u as String
                if (let Some(s) <- sOpt) { userIdStr = s }
            }

            let (entities, total) = if (userIdStr.isEmpty()) {
                service.getListWithFilter(
                    currentPage,
                    pageSize,
                    sortStr,
                    filterStr
                )
            } else {
                service.getListWithPermission(
                    currentPage,
                    pageSize,
                    sortStr,
                    filterStr,
                    userIdStr
                )
            }

            let totalPage = if (pageSize > 0) {
                Int32((total + Int64(pageSize) - 1) / Int64(pageSize))
            } else {
                Int32(0)
            }

            var entitiesJson = ""
            for (e in entities) {
                if (entitiesJson.isEmpty()) {
                    entitiesJson = e.toJson()
                } else {
                    entitiesJson = entitiesJson + "," + e.toJson()
                }
            }
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"llm_route_rules\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func getManyWithSkip(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")
            let skipParam = req.pathParam("skip")

            let limitNum = if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }

            let pageNum = if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)
            }

            let skipNum = if (let Some(s) <- skipParam) {
                Int32.parse(s)
            } else {
                Int32(0)
            }

            if (limitNum > 1000) {
                res.status(400).json(APIError("40004", "请求数量不能超过1000条").toJson())
                return
            }

            let sortParam = req.queryParam("sort")
            let filterParam = req.queryParam("filter")

            let sortStr = if (let Some(s) <- sortParam) { s } else { "" }
            let filterStr = if (let Some(f) <- filterParam) { f } else { "" }

            let userId = req.getLocals("userId")
            var userIdStr = ""
            if (let Some(u) <- userId) {
                let sOpt = u as String
                if (let Some(s) <- sOpt) { userIdStr = s }
            }

            let (entities, total) = if (userIdStr.isEmpty()) {
                service.getListWithSkip(pageNum - 1, limitNum, skipNum, sortStr, filterStr)
            } else {
                service.getListWithSkipWithPermission(pageNum - 1, limitNum, skipNum, sortStr, filterStr, userIdStr)
            }

            let totalPage = if (limitNum > 0) {
                Int32((total + Int64(limitNum) - 1) / Int64(limitNum))
            } else {
                Int32(0)
            }

            var entitiesJson = ""
            for (e in entities) {
                if (entitiesJson.isEmpty()) {
                    entitiesJson = e.toJson()
                } else {
                    entitiesJson = entitiesJson + "," + e.toJson()
                }
            }
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"llm_route_rules\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinLlmRouteRule(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinLlmRouteRule()
            if (result.success) {
                res.status(200).json("{\"desc\":\"清空回收站成功\"}")
            } else {
                let reason = result.reason ?? "清空回收站失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
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
                let anyValue = jsonValueToAny(value)
                map.add(key, anyValue)
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

    private func mapToEntity(map: Map<String, Any>): LlmRouteRulePO {
        let entity = LlmRouteRulePO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(scope) <- map.get("scope")) {
            let scopeStr = scope as String
            if (let Some(s) <- scopeStr) {
                entity.scope = s
            }
        }
        if (let Some(requireCapabilities) <- map.get("require_capabilities")) {
            let requireCapabilitiesStr = requireCapabilities as String
            if (let Some(s) <- requireCapabilitiesStr) {
                entity.requireCapabilities = s
            }
        }
        if (let Some(channelChain) <- map.get("channel_chain")) {
            let channelChainStr = channelChain as String
            if (let Some(s) <- channelChainStr) {
                entity.channelChain = s
            }
        }
        if (let Some(fallbackChain) <- map.get("fallback_chain")) {
            let fallbackChainStr = fallbackChain as String
            if (let Some(s) <- fallbackChainStr) {
                entity.fallbackChain = s
            }
        }
        if (let Some(strategy) <- map.get("strategy")) {
            let strategyStr = strategy as String
            if (let Some(s) <- strategyStr) {
                entity.strategy = s
            }
        }
        if (let Some(shadowPercent) <- map.get("shadow_percent")) {
            let shadowPercentInt = shadowPercent as Int64
            if (let Some(v) <- shadowPercentInt) {
                entity.shadowPercent = Int32(v)
            }
        }
        if (let Some(enabled) <- map.get("enabled")) {
            let enabledBool = enabled as Bool
            if (let Some(v) <- enabledBool) {
                entity.enabled = v
            }
        }
        if (let Some(priority) <- map.get("priority")) {
            let priorityInt = priority as Int64
            if (let Some(v) <- priorityInt) {
                entity.priority = Int32(v)
            }
        }
        if (let Some(revision) <- map.get("revision")) {
            let revisionInt = revision as Int64
            if (let Some(v) <- revisionInt) {
                entity.revision = v
            }
        }
        if (let Some(creator) <- map.get("creator")) {
            let creatorStr = creator as String
            if (let Some(s) <- creatorStr) {
                entity.creator = Some<String>(s)
            }
        }
        if (let Some(createdAt) <- map.get("created_at")) {
        }
        if (let Some(updatedAt) <- map.get("updated_at")) {
        }
        if (let Some(deletedAt) <- map.get("deleted_at")) {
            // DateTime类型, 由数据库处理
        }
        return entity
    }


    private func parseForce(forceOpt: ?Any): Bool {
        if (let Some(f) <- forceOpt) {
            let fInt64 = f as Int64
            if (let Some(v) <- fInt64) {
                v == 1
            } else {
                let fInt32 = f as Int32
                if (let Some(v) <- fInt32) {
                    v == 1
                } else {
                    let fStr = f as String
                    if (let Some(s) <- fStr) {
                        s == "true" || s == "1"
                    } else {
                        false
                    }
                }
            }
        } else {
            false
        }
    }

    private func parseIdsArray(idsStr: String): ArrayList<String> {
        let idArray = ArrayList<String>()
        if (idsStr.isEmpty()) {
            return idArray
        }
        try {
            let jsonValue = JsonValue.fromStr(idsStr)
            if (jsonValue is JsonArray) {
                let arr = jsonValue.asArray()
                for (item in arr.getItems()) {
                    if (item is JsonString) {
                        let jsonStr = item.asString()
                        let val = jsonStr.getValue()
                        if (!val.isEmpty()) {
                            idArray.add(val)
                        }
                    } else if (item is JsonObject) {
                        let obj = item.asObject()
                        if (let Some(idsObj) <- obj.get("ids")) {
                            if (idsObj is JsonArray) {
                                let idsArr = idsObj.asArray()
                                for (subItem in idsArr.getItems()) {
                                    if (subItem is JsonString) {
                                        let jsonStr = subItem.asString()
                                        let val = jsonStr.getValue()
                                        if (!val.isEmpty()) {
                                            idArray.add(val)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else if (jsonValue is JsonObject) {
                let obj = jsonValue.asObject()
                if (let Some(idsVal) <- obj.get("ids")) {
                    if (idsVal is JsonArray) {
                        let idsArr = idsVal.asArray()
                        for (item in idsArr.getItems()) {
                            if (item is JsonString) {
                                let jsonStr = item.asString()
                                let val = jsonStr.getValue()
                                if (!val.isEmpty()) {
                                    idArray.add(val)
                                }
                            }
                        }
                    } else if (idsVal is JsonString) {
                        let jsonStr = idsVal.asString()
                        let val = jsonStr.getValue()
                        if (!val.isEmpty()) {
                            idArray.add(val)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            let parts = idsStr.split(",")
            for (part in parts) {
                let trimmed = part.trimAscii()
                if (!trimmed.isEmpty() && trimmed != "[" && trimmed != "]" && trimmed != "{" && trimmed != "}") {
                    idArray.add(trimmed)
                }
            }
        }
        return idArray
    }

    private func parseLimit(limit: ?String): Int32 {
        if (let Some(l) <- limit) {
            Int32.parse(l)
        } else {
            10
        }
    }

    private func parsePage(page: ?String): Int32 {
        if (let Some(p) <- page) {
            Int32.parse(p)
        } else {
            1
        }
    }

    public func export(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 获取所有llm_route_rule数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,scope,require_capabilities,channel_chain,fallback_chain,strategy,shadow_percent,enabled,priority,revision,creator,created_at,updated_at,deleted_at\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.scope}" + ",")
                sb.append("\"" + "${entity.requireCapabilities}" + ",")
                sb.append("\"" + "${entity.channelChain}" + ",")
                sb.append("\"" + "${entity.fallbackChain}" + ",")
                sb.append("\"" + "${entity.strategy}" + ",")
                sb.append("${entity.shadowPercent}")
                sb.append(",")
                sb.append("${entity.enabled}")
                sb.append(",")
                sb.append("${entity.priority}")
                sb.append(",")
                sb.append("${entity.revision}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=llm_route_rule_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode

    // ==================== 动态路由规则业务端点（手写，委托 ChannelService / ModelRouter；方法名以 RouteRule 后缀避免与标准 CRUD 重名） ====================

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let rules = ChannelService.shared().listRouteRules()
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

    public func addRouteRule(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseRuleBody(req)
            if (let Some(b) <- body) {
                let po = mapToRulePO(b, "")
                let resultOpt = ChannelService.shared().addRouteRule(po, currentOperator(req))
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

    public func editRouteRule(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseRuleBody(req)
            if (let Some(b) <- body) {
                let id = optStr(b, "id")
                if (id.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少规则 id\"}")
                    return
                }
                let po = mapToRulePO(b, id)
                let ok = ChannelService.shared().updateRouteRule(po, currentOperator(req))
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

    public func delRouteRule(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseRuleBody(req)
            if (let Some(b) <- body) {
                let id = optStr(b, "id")
                if (id.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少规则 id\"}")
                    return
                }
                let ok = ChannelService.shared().deleteRouteRule(id, currentOperator(req))
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

    /**
     * POST /api/v1/uctoo/llm_route_rule/evaluate
     *
     * 给定一条选路请求（scope + require_capabilities），返回 ModelRouter 实际命中的通道与候选顺序。
     * 不改动任何状态，纯只读校验，便于运维确认规则/策略生效（T006 / T029 调试入口）。
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

    /**
     * GET /api/v1/uctoo/llm_route_rule/shadow-stats
     *
     * 影子/主通道的对比指标（T032）：{"<code>:main": {requests, failures, totalLatencyMs}, ...}。
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

    private func parseRuleBody(req: HttpRequest): ?Map<String, Any> {
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
                map.add(key, jsonValueToAnyRule(value))
            }
            return Some<Map<String, Any>>(map)
        } catch (e: Exception) {
            return None<Map<String, Any>>
        }
    }

    private func jsonValueToAnyRule(value: JsonValue): Any {
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

    private func mapToRulePO(map: Map<String, Any>, id: String): LlmRouteRulePO {
        let po = LlmRouteRulePO()
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
