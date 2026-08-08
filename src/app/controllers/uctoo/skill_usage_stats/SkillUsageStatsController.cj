/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.skill_usage_stats

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.SkillUsageStatsPO
import magic.app.services.uctoo.SkillUsageStatsService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class SkillUsageStatsController {
    private var service: SkillUsageStatsService

    public init(service: SkillUsageStatsService) {
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
                            let entities = ArrayList<SkillUsageStatsPO>()
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
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该skill_usage_stats\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该skill_usage_stats\"}")
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
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"skill_usage_statss\":[${entitiesJson}]}")
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"skill_usage_statss\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinSkillUsageStats(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinSkillUsageStats()
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

    private func mapToEntity(map: Map<String, Any>): SkillUsageStatsPO {
        let entity = SkillUsageStatsPO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(skillName) <- map.get("skill_name")) {
            let skillNameStr = skillName as String
            if (let Some(s) <- skillNameStr) {
                entity.skillName = s
            }
        }
        if (let Some(useCount) <- map.get("use_count")) {
            let useCountInt = useCount as Int64
            if (let Some(v) <- useCountInt) {
                entity.useCount = v
            }
        }
        if (let Some(viewCount) <- map.get("view_count")) {
            let viewCountInt = viewCount as Int64
            if (let Some(v) <- viewCountInt) {
                entity.viewCount = v
            }
        }
        if (let Some(modifyCount) <- map.get("modify_count")) {
            let modifyCountInt = modifyCount as Int64
            if (let Some(v) <- modifyCountInt) {
                entity.modifyCount = v
            }
        }
        if (let Some(successCount) <- map.get("success_count")) {
            let successCountInt = successCount as Int64
            if (let Some(v) <- successCountInt) {
                entity.successCount = v
            }
        }
        if (let Some(failureCount) <- map.get("failure_count")) {
            let failureCountInt = failureCount as Int64
            if (let Some(v) <- failureCountInt) {
                entity.failureCount = v
            }
        }
        if (let Some(state) <- map.get("state")) {
            let stateStr = state as String
            if (let Some(s) <- stateStr) {
                entity.state = s
            }
        }
        if (let Some(avgExecutionTimeMs) <- map.get("avg_execution_time_ms")) {
            if (avgExecutionTimeMs is Int64) {
                let avgExecutionTimeMsInt = avgExecutionTimeMs as Int64
                if (let Some(v) <- avgExecutionTimeMsInt) {
                    entity.avgExecutionTimeMs = Float64(v)
                }
            } else if (avgExecutionTimeMs is Float64) {
                let avgExecutionTimeMsFloat = avgExecutionTimeMs as Float64
                if (let Some(v) <- avgExecutionTimeMsFloat) {
                    entity.avgExecutionTimeMs = v
                }
            }
        }
        if (let Some(userRating) <- map.get("user_rating")) {
            if (userRating is Int64) {
                let userRatingInt = userRating as Int64
                if (let Some(v) <- userRatingInt) {
                    entity.userRating = Float64(v)
                }
            } else if (userRating is Float64) {
                let userRatingFloat = userRating as Float64
                if (let Some(v) <- userRatingFloat) {
                    entity.userRating = v
                }
            }
        }
        if (let Some(lastUsedAt) <- map.get("last_used_at")) {
            // DateTime类型, 由数据库处理
        }
        if (let Some(statsDetail) <- map.get("stats_detail")) {
            let statsDetailStr = statsDetail as String
            if (let Some(s) <- statsDetailStr) {
                entity.statsDetail = s
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
            // 获取所有skill_usage_stats数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,skill_name,use_count,view_count,modify_count,success_count,failure_count,state,avg_execution_time_ms,user_rating,last_used_at,stats_detail,creator,created_at,updated_at,deleted_at\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.skillName}" + ",")
                sb.append("${entity.useCount}")
                sb.append(",")
                sb.append("${entity.viewCount}")
                sb.append(",")
                sb.append("${entity.modifyCount}")
                sb.append(",")
                sb.append("${entity.successCount}")
                sb.append(",")
                sb.append("${entity.failureCount}")
                sb.append(",")
                sb.append("\"" + "${entity.state}" + ",")
                sb.append("${entity.avgExecutionTimeMs}")
                sb.append(",")
                sb.append("${entity.userRating}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.lastUsedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("\"" + "${entity.statsDetail}" + ",")
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=skill_usage_stats_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode

    public func incrementUsage(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                var skillName = ""
                var success = true
                var executionTimeMs: Float64 = 0.0
                if (let Some(sn) <- b.get("skill_name")) { let s = sn as String; if (let Some(v) <- s) { skillName = v } }
                if (let Some(suc) <- b.get("success")) { let s = suc as Bool; if (let Some(v) <- s) { success = v } }
                if (let Some(et) <- b.get("execution_time_ms")) { let s = et as Float64; if (let Some(v) <- s) { executionTimeMs = v } }
                let result = service.incrementUsage(skillName, success, executionTimeMs)
                if (result.success) {
                    if (let Some(data) <- result.data) { res.status(200).json(data.toJson()) }
                    else { res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"更新失败\"}") }
                } else {
                    let reason = result.reason ?? "更新失败"
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                }
            } else { res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}") }
        } catch (e: Exception) { res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}") }
    }

    public func getTopUsedSkills(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let limitParam = req.queryParam("limit")
            let limit = if (let Some(l) <- limitParam) { Int32.parse(l) } else { Int32(10) }
            let records = service.getTopUsedSkills(limit)
            var json = ""
            for (r in records) { json = if (json.isEmpty()) { r.toJson() } else { json + "," + r.toJson() } }
            res.status(200).json("{\"skill_usage_statss\":[${json}]}")
        } catch (e: Exception) { res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}") }
    }
}
