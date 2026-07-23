/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.config

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.services.uctoo.ConfigUpdateItem
import magic.app.services.uctoo.ConfigMetadataVO

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.ConfigPO
import magic.app.services.uctoo.ConfigService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class ConfigController {
    private var service: ConfigService

    public init(service: ConfigService) {
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
                            let entities = ArrayList<ConfigPO>()
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
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该config\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该config\"}")
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
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"configs\":[${entitiesJson}]}")
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"configs\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinConfig(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinConfig()
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

    private func mapToEntity(map: Map<String, Any>): ConfigPO {
        let entity = ConfigPO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(name) <- map.get("name")) {
            let nameStr = name as String
            if (let Some(s) <- nameStr) {
                entity.name = s
            }
        }
        if (let Some(parentId) <- map.get("parent_id")) {
            let parentIdStr = parentId as String
            if (let Some(s) <- parentIdStr) {
                entity.parentId = Some<String>(s)
            }
        }
        if (let Some(component) <- map.get("component")) {
            let componentStr = component as String
            if (let Some(s) <- componentStr) {
                entity.component = s
            }
        }
        if (let Some(key) <- map.get("key")) {
            let keyStr = key as String
            if (let Some(s) <- keyStr) {
                entity.key = s
            }
        }
        if (let Some(value) <- map.get("value")) {
            let valueStr = value as String
            if (let Some(s) <- valueStr) {
                entity.value = Some<String>(s)
            }
        }
        if (let Some(status) <- map.get("status")) {
            let statusInt = status as Int64
            if (let Some(v) <- statusInt) {
                entity.status = Int32(v)
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
        if (let Some(envKey) <- map.get("env_key")) {
            let envKeyStr = envKey as String
            if (let Some(s) <- envKeyStr) {
                entity.envKey = Some<String>(s)
            }
        }
        if (let Some(configGroup) <- map.get("config_group")) {
            let configGroupStr = configGroup as String
            if (let Some(s) <- configGroupStr) {
                entity.configGroup = Some<String>(s)
            }
        }
        if (let Some(configType) <- map.get("config_type")) {
            let configTypeStr = configType as String
            if (let Some(s) <- configTypeStr) {
                entity.configType = Some<String>(s)
            }
        }
        if (let Some(isSensitive) <- map.get("is_sensitive")) {
            let isSensitiveBool = isSensitive as Bool
            if (let Some(v) <- isSensitiveBool) {
                entity.isSensitive = Some<Bool>(v)
            }
        }
        if (let Some(defaultValue) <- map.get("default_value")) {
            let defaultValueStr = defaultValue as String
            if (let Some(s) <- defaultValueStr) {
                entity.defaultValue = Some<String>(s)
            }
        }
        if (let Some(validationRule) <- map.get("validation_rule")) {
            let validationRuleStr = validationRule as String
            if (let Some(s) <- validationRuleStr) {
                entity.validationRule = Some<String>(s)
            }
        }
        if (let Some(description) <- map.get("description")) {
            let descriptionStr = description as String
            if (let Some(s) <- descriptionStr) {
                entity.description = Some<String>(s)
            }
        }
        if (let Some(displayOrder) <- map.get("display_order")) {
            let displayOrderInt = displayOrder as Int64
            if (let Some(v) <- displayOrderInt) {
                entity.displayOrder = Some<Int32>(Int32(v))
            }
        }
        if (let Some(editable) <- map.get("editable")) {
            let editableBool = editable as Bool
            if (let Some(v) <- editableBool) {
                entity.editable = Some<Bool>(v)
            }
        }
        if (let Some(lastSyncedAt) <- map.get("last_synced_at")) {
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
            // 获取所有config数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,name,parent_id,component,key,value,status,creator,created_at,updated_at,deleted_at,env_key,config_group,config_type,is_sensitive,default_value,validation_rule,description,display_order,editable,last_synced_at\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.name}" + ",")
                sb.append(if (let Some(v) <- entity.parentId) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.component}" + ",")
                sb.append("\"" + "${entity.key}" + ",")
                sb.append(if (let Some(v) <- entity.value) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.status}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.envKey) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.configGroup) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.configType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.isSensitive) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.defaultValue) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.validationRule) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.description) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.displayOrder) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.editable) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.lastSyncedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=config_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode

    public func getConfigs(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let group = req.queryParam("group")
            let result = if (group.isSome()) {
                service.getConfigsByGroup(group.getOrThrow())
            } else {
                service.getAllConfigs()
            }
            if (result.success) {
                if (result.data.isSome()) {
                    let data = result.data.getOrThrow()
                    let sb = StringBuilder()
                    sb.append("[")
                    for (i in 0..data.size) {
                        if (i > 0) { sb.append(",") }
                        sb.append(data[i].toJson())
                    }
                    sb.append("]")
                    res.status(200).json(sb.toString())
                } else {
                    res.status(200).json("[]")
                }
            } else {
                let reason = result.reason ?? "查询失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getConfigByKey(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let keyOpt = req.pathParam("key")
            if (keyOpt.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"Missing key parameter\"}")
                return
            }
            let key = keyOpt.getOrThrow()
            let result = service.getConfigByKey(key)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJson())
                } else {
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"Config not found\"}")
                }
            } else {
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${result.reason ?? "查询失败"}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func updateConfigByKey(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = req.getLocals("userId")
            var userIdStr = ""
            match (userIdOpt) {
                case Some(u) =>
                    match (u as String) {
                        case Some(s) => userIdStr = s
                        case None => ()
                    }
                case None => ()
            }
            let keyOpt = req.pathParam("key")
            if (keyOpt.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"Missing key parameter\"}")
                return
            }
            let key = keyOpt.getOrThrow()
            let body = parseBody(req)
            if (body.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                return
            }
            let b = body.getOrThrow()
            let valueOpt = b.get("value")
            if (valueOpt.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"Missing value field\"}")
                return
            }
            var value = ""
            match (valueOpt.getOrThrow() as String) {
                case Some(s) => value = s
                case None => ()
            }
            let result = service.updateConfigByKey(key, value, userIdStr, "api")
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJson())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"更新失败\"}")
                }
            } else {
                let reason = result.reason ?? "更新失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func batchUpdateConfigs(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = req.getLocals("userId")
            var userIdStr = ""
            match (userIdOpt) {
                case Some(u) =>
                    match (u as String) {
                        case Some(s) => userIdStr = s
                        case None => ()
                    }
                case None => ()
            }
            let bodyStr = req.body
            if (bodyStr.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                return
            }
            let items = ArrayList<ConfigUpdateItem>()
            let rootJson = JsonValue.fromStr(bodyStr)
            if (!(rootJson is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"Invalid request body\"}")
                return
            }
            let rootObj = rootJson.asObject()
            let itemsField = rootObj.get("items")
            match (itemsField) {
                case Some(itemsVal) =>
                    if (itemsVal is JsonArray) {
                        let arr = itemsVal.asArray()
                        for (i in 0..arr.size()) {
                            let item = arr[i]
                            if (item is JsonObject) {
                                let obj = item.asObject()
                                let ci = ConfigUpdateItem()
                                let ekField = obj.get("envKey")
                                match (ekField) {
                                    case Some(ekVal) =>
                                        if (ekVal is JsonString) {
                                            ci.envKey = ekVal.asString().getValue()
                                        }
                                    case None => ()
                                }
                                let vField = obj.get("value")
                                match (vField) {
                                    case Some(vVal) =>
                                        if (vVal is JsonString) {
                                            ci.value = vVal.asString().getValue()
                                        }
                                    case None => ()
                                }
                                items.add(ci)
                            }
                        }
                    } else {
                        res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"Invalid items format\"}")
                        return
                    }
                case None =>
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"Missing items field\"}")
                    return
            }
            let result = service.batchUpdateConfigs(items, userIdStr, "api")
            if (result.success) {
                if (result.data.isSome()) {
                    let data = result.data.getOrThrow()
                    let sb = StringBuilder()
                    sb.append("[")
                    for (i in 0..data.size) {
                        if (i > 0) { sb.append(",") }
                        sb.append(data[i].toJson())
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
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getConfigMetadata(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let result = service.getConfigMetadata()
            if (result.success) {
                if (result.data.isSome()) {
                    let data = result.data.getOrThrow()
                    let sb = StringBuilder()
                    sb.append("[")
                    for (i in 0..data.size) {
                        if (i > 0) { sb.append(",") }
                        let vo = data[i]
                        sb.append("{\"envKey\":\"${vo.envKey}\",\"name\":\"${vo.name}\",\"configGroup\":\"${vo.configGroup}\",\"configType\":\"${vo.configType}\",\"isSensitive\":${vo.isSensitive},\"displayOrder\":${vo.displayOrder},\"editable\":${vo.editable}}")
                    }
                    sb.append("]")
                    res.status(200).json(sb.toString())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"查询失败\"}")
                }
            } else {
                let reason = result.reason ?? "查询失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func exportConfigHandler(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let formatOpt = req.queryParam("format")
            let format = match (formatOpt) {
                case Some(f) => f
                case None => "json"
            }
            let result = service.exportConfig(format)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"导出失败\"}")
                }
            } else {
                let reason = result.reason ?? "导出失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func importConfigHandler(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userIdOpt = req.getLocals("userId")
            var userIdStr = ""
            match (userIdOpt) {
                case Some(u) =>
                    match (u as String) {
                        case Some(s) => userIdStr = s
                        case None => ()
                    }
                case None => ()
            }
            let body = parseBody(req)
            if (body.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                return
            }
            let b = body.getOrThrow()
            let dataOpt = b.get("data")
            let formatOpt = b.get("format")
            var data = ""
            match (dataOpt) {
                case Some(d) =>
                    match (d as String) {
                        case Some(s) => data = s
                        case None => ()
                    }
                case None => ()
            }
            var format = "env"
            match (formatOpt) {
                case Some(f) =>
                    match (f as String) {
                        case Some(s) => format = s
                        case None => ()
                    }
                case None => ()
            }
            let result = service.importConfig(data, format, userIdStr)
            if (result.success) {
                res.status(200).json("{\"desc\":\"导入成功\"}")
            } else {
                let reason = result.reason ?? "导入失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
}
