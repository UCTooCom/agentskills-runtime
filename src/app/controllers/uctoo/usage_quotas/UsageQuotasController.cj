/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.usage_quotas

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.UsageQuotasPO
import magic.app.services.uctoo.UsageQuotasService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class UsageQuotasController {
    private var service: UsageQuotasService

    public init(service: UsageQuotasService) {
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
                            let entities = ArrayList<UsageQuotasPO>()
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
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该usage_quotas\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该usage_quotas\"}")
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
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"usage_quotass\":[${entitiesJson}]}")
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"usage_quotass\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinUsageQuotas(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinUsageQuotas()
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

    private func mapToEntity(map: Map<String, Any>): UsageQuotasPO {
        let entity = UsageQuotasPO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(targetType) <- map.get("target_type")) {
            let targetTypeStr = targetType as String
            if (let Some(s) <- targetTypeStr) {
                entity.targetType = s
            }
        }
        if (let Some(targetId) <- map.get("target_id")) {
            let targetIdStr = targetId as String
            if (let Some(s) <- targetIdStr) {
                entity.targetId = s
            }
        }
        if (let Some(quotaType) <- map.get("quota_type")) {
            let quotaTypeStr = quotaType as String
            if (let Some(s) <- quotaTypeStr) {
                entity.quotaType = s
            }
        }
        if (let Some(quotaLimit) <- map.get("quota_limit")) {
            if (quotaLimit is Int64) {
                let quotaLimitInt = quotaLimit as Int64
                if (let Some(v) <- quotaLimitInt) {
                    entity.quotaLimit = Float64(v)
                }
            } else if (quotaLimit is Float64) {
                let quotaLimitFloat = quotaLimit as Float64
                if (let Some(v) <- quotaLimitFloat) {
                    entity.quotaLimit = v
                }
            }
        }
        if (let Some(quotaUsed) <- map.get("quota_used")) {
            if (quotaUsed is Int64) {
                let quotaUsedInt = quotaUsed as Int64
                if (let Some(v) <- quotaUsedInt) {
                    entity.quotaUsed = Float64(v)
                }
            } else if (quotaUsed is Float64) {
                let quotaUsedFloat = quotaUsed as Float64
                if (let Some(v) <- quotaUsedFloat) {
                    entity.quotaUsed = v
                }
            }
        }
        if (let Some(quotaPeriodStart) <- map.get("quota_period_start")) {
            let quotaPeriodStartStr = quotaPeriodStart as String
            if (let Some(s) <- quotaPeriodStartStr) {
                entity.quotaPeriodStart = s
            }
        }
        if (let Some(isHardLimit) <- map.get("is_hard_limit")) {
            let isHardLimitBool = isHardLimit as Bool
            if (let Some(v) <- isHardLimitBool) {
                entity.isHardLimit = v
            }
        }
        if (let Some(alertThreshold) <- map.get("alert_threshold")) {
            if (alertThreshold is Int64) {
                let alertThresholdInt = alertThreshold as Int64
                if (let Some(v) <- alertThresholdInt) {
                    entity.alertThreshold = Float64(v)
                }
            } else if (alertThreshold is Float64) {
                let alertThresholdFloat = alertThreshold as Float64
                if (let Some(v) <- alertThresholdFloat) {
                    entity.alertThreshold = v
                }
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
            // 获取所有usage_quotas数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,target_type,target_id,quota_type,quota_limit,quota_used,quota_period_start,is_hard_limit,alert_threshold,creator,created_at,updated_at,deleted_at\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.targetType}" + ",")
                sb.append("\"" + "${entity.targetId}" + ",")
                sb.append("\"" + "${entity.quotaType}" + ",")
                sb.append("${entity.quotaLimit}")
                sb.append(",")
                sb.append("${entity.quotaUsed}")
                sb.append(",")
                sb.append("\"" + "${entity.quotaPeriodStart}" + ",")
                sb.append("${entity.isHardLimit}")
                sb.append(",")
                sb.append("${entity.alertThreshold}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=usage_quotas_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode
}
