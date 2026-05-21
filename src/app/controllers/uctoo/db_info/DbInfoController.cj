/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.db_info

import magic.app.services.uctoo.DbTableInfo
import magic.app.services.tool.CrudGenService
import magic.app.services.tool.CrudGenResult
import magic.app.services.tool.CrudGenAllResult
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.DbInfoPO
import magic.app.services.uctoo.DbInfoService
import magic.log.LogUtils
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils

public class DbInfoController {
    private var service: DbInfoService
    private var crudGenService: CrudGenService

    public init(service: DbInfoService) {
        this.service = service
        this.crudGenService = CrudGenService()
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
                            let entities = ArrayList<DbInfoPO>()
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
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该db_info\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该db_info\"}")
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

            if (pageSize > 10000) {
                res.status(400).json(APIError("40004", "请求数量不能超过10000条").toJson())
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
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"db_infos\":[${entitiesJson}]}")
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

            if (limitNum > 10000) {
                res.status(400).json(APIError("40004", "请求数量不能超过10000条").toJson())
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"db_infos\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinDbInfo(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinDbInfo()
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

    private func mapToEntity(map: Map<String, Any>): DbInfoPO {
        let entity = DbInfoPO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(tableCatalog) <- map.get("table_catalog")) {
            let tableCatalogStr = tableCatalog as String
            if (let Some(s) <- tableCatalogStr) {
                entity.tableCatalog = s
            }
        }
        if (let Some(tableSchema) <- map.get("table_schema")) {
            let tableSchemaStr = tableSchema as String
            if (let Some(s) <- tableSchemaStr) {
                entity.tableSchema = Some<String>(s)
            }
        }
        if (let Some(dbTableName) <- map.get("table_name")) {
            let dbTableNameStr = dbTableName as String
            if (let Some(s) <- dbTableNameStr) {
                entity.dbTableName = s
            }
        }
        if (let Some(columnName) <- map.get("column_name")) {
            let columnNameStr = columnName as String
            if (let Some(s) <- columnNameStr) {
                entity.columnName = s
            }
        }
        if (let Some(columnDefault) <- map.get("column_default")) {
            let columnDefaultStr = columnDefault as String
            if (let Some(s) <- columnDefaultStr) {
                entity.columnDefault = Some<String>(s)
            }
        }
        if (let Some(isNullable) <- map.get("is_nullable")) {
            let isNullableStr = isNullable as String
            if (let Some(s) <- isNullableStr) {
                entity.isNullable = s
            }
        }
        if (let Some(dataType) <- map.get("data_type")) {
            let dataTypeStr = dataType as String
            if (let Some(s) <- dataTypeStr) {
                entity.dataType = Some<String>(s)
            }
        }
        if (let Some(vueComponentType) <- map.get("vue_component_type")) {
            let vueComponentTypeStr = vueComponentType as String
            if (let Some(s) <- vueComponentTypeStr) {
                entity.vueComponentType = Some<String>(s)
            }
        }
        if (let Some(reactComponentType) <- map.get("react_component_type")) {
            let reactComponentTypeStr = reactComponentType as String
            if (let Some(s) <- reactComponentTypeStr) {
                entity.reactComponentType = Some<String>(s)
            }
        }
        if (let Some(arkuiComponentType) <- map.get("arkui_component_type")) {
            let arkuiComponentTypeStr = arkuiComponentType as String
            if (let Some(s) <- arkuiComponentTypeStr) {
                entity.arkuiComponentType = Some<String>(s)
            }
        }
        if (let Some(uniappComponentType) <- map.get("uniapp_component_type")) {
            let uniappComponentTypeStr = uniappComponentType as String
            if (let Some(s) <- uniappComponentTypeStr) {
                entity.uniappComponentType = Some<String>(s)
            }
        }
        if (let Some(rules) <- map.get("rules")) {
            let rulesStr = rules as String
            if (let Some(s) <- rulesStr) {
                entity.rules = Some<String>(s)
            }
        }
        if (let Some(pattern) <- map.get("pattern")) {
            let patternStr = pattern as String
            if (let Some(s) <- patternStr) {
                entity.pattern = Some<String>(s)
            }
        }
        if (let Some(weight) <- map.get("weight")) {
            let weightInt = weight as Int64
            if (let Some(v) <- weightInt) {
                entity.weight = Int32(v)
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
        if (let Some(placeholder) <- map.get("placeholder")) {
            let placeholderStr = placeholder as String
            if (let Some(s) <- placeholderStr) {
                entity.placeholder = Some<String>(s)
            }
        }
        if (let Some(isColumnHidden) <- map.get("is_column_hidden")) {
            let isColumnHiddenStr = isColumnHidden as String
            if (let Some(s) <- isColumnHiddenStr) {
                entity.isColumnHidden = s
            }
        }
        if (let Some(isTableHidden) <- map.get("is_table_hidden")) {
            let isTableHiddenStr = isTableHidden as String
            if (let Some(s) <- isTableHiddenStr) {
                entity.isTableHidden = s
            }
        }
        if (let Some(columnComment) <- map.get("column_comment")) {
            let columnCommentStr = columnComment as String
            if (let Some(s) <- columnCommentStr) {
                entity.columnComment = Some<String>(s)
            }
        }
        if (let Some(ordinalPosition) <- map.get("ordinal_position")) {
            let ordinalPositionInt = ordinalPosition as Int64
            if (let Some(v) <- ordinalPositionInt) {
                entity.ordinalPosition = Int32(v)
            }
        }
        if (let Some(migrationId) <- map.get("migration_id")) {
            let migrationIdStr = migrationId as String
            if (let Some(s) <- migrationIdStr) {
                entity.migrationId = Some<String>(s)
            }
        }
        if (let Some(characterMaximumLength) <- map.get("character_maximum_length")) {
            let characterMaximumLengthInt = characterMaximumLength as Int64
            if (let Some(v) <- characterMaximumLengthInt) {
                entity.characterMaximumLength = Some<Int64>(v)
            }
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
        try {
            let jsonValue = JsonValue.fromStr(idsStr)
            if (jsonValue is JsonArray) {
                let arr = jsonValue.asArray()
                for (item in arr.getItems()) {
                    if (item is JsonString) {
                        let jsonStr = item.asString()
                        idArray.add(jsonStr.getValue())
                    }
                }
            }
        } catch (e: Exception) {
            let parts = idsStr.split(",")
            for (part in parts) {
                let trimmed = part.trimAscii()
                if (!trimmed.isEmpty()) {
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
            // 获取所有db_info数据
            let (entities, _) = service.getList(1, 10000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,table_catalog,table_schema,table_name,column_name,column_default,is_nullable,data_type,vue_component_type,react_component_type,arkui_component_type,uniapp_component_type,rules,pattern,weight,creator,created_at,updated_at,deleted_at,placeholder,is_column_hidden,is_table_hidden,column_comment,ordinal_position,migration_id,character_maximum_length\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.tableCatalog}" + ",")
                sb.append(if (let Some(v) <- entity.tableSchema) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.dbTableName}" + ",")
                sb.append("\"" + "${entity.columnName}" + ",")
                sb.append(if (let Some(v) <- entity.columnDefault) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.isNullable}" + ",")
                sb.append(if (let Some(v) <- entity.dataType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.vueComponentType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.reactComponentType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.arkuiComponentType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.uniappComponentType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.rules) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.pattern) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.weight}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.placeholder) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.isColumnHidden}" + ",")
                sb.append("\"" + "${entity.isTableHidden}" + ",")
                sb.append(if (let Some(v) <- entity.columnComment) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.ordinalPosition}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.migrationId) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.characterMaximumLength) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=db_info_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode

    // ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 从数据库结构获取数据库信息并添加到db_info表
     * @param req 请求对象
     * @param res 响应对象
     */
    public func loadDbInfo(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let dbName = req.queryParam("dbName")
            if (dbName.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"缺少数据库名称参数\"}")
                return
            }

            let result = service.loadDbInfo(dbName.getOrThrow())
            if (result.success) {
                if (let Some(count) <- result.data) {
                    res.status(200).json("{\"desc\":\"数据库信息加载成功\",\"count\":${count}}")
                } else {
                    res.status(200).json("{\"desc\":\"数据库信息加载成功\",\"count\":0}")
                }
            } else {
                let reason = result.reason ?? "加载失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 获取数据库表列表（从information_schema直接查询，不保存到数据库）
     * @param req 请求对象
     * @param res 响应对象
     */
    public func getDbTableList(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let dbName = req.queryParam("dbName")
            if (dbName.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"缺少数据库名称参数\"}")
                return
            }

            let result = service.getDbTableList(dbName.getOrThrow())
            if (result.success) {
                if (let Some(tables) <- result.data) {
                    let tablesJson = tablesToJson(tables)
                    res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":{\"db_tables\":${tablesJson}}}")
                } else {
                    res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":{\"db_tables\":[]}}")
                }
            } else {
                let reason = result.reason ?? "查询失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 生成指定表的CRUD代码
     * @param req 请求对象，包含 dbName 和 tableName 参数
     * @param res 响应对象
     */
    public func generateCrud(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let dbName = req.queryParam("dbName")
            let tableName = req.queryParam("tableName")

            if (dbName.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"缺少数据库名称参数 (dbName)\"}")
                return
            }

            if (tableName.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"缺少表名称参数 (tableName)\"}")
                return
            }

            LogUtils.info("DbInfoController", "generateCrud called for ${dbName.getOrThrow()}.${tableName.getOrThrow()}")

            let result = crudGenService.generateCrud(dbName.getOrThrow(), tableName.getOrThrow())

            if (result.success) {
                if (let Some(data) <- result.data) {
                    let responseJson = buildCrudGenResultJson(data)
                    res.status(200).json(responseJson)
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"生成失败\"}")
                }
            } else {
                let reason = result.reason ?? "生成失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("DbInfoController", "generateCrud exception: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 批量生成所有表的CRUD代码
     * @param req 请求对象，包含 dbName 参数
     * @param res 响应对象
     */
    public func generateAllCrud(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let dbName = req.queryParam("dbName")

            if (dbName.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"缺少数据库名称参数 (dbName)\"}")
                return
            }

            LogUtils.info("DbInfoController", "generateAllCrud called for ${dbName.getOrThrow()}")

            let result = crudGenService.generateAllCrud(dbName.getOrThrow())

            if (result.success) {
                if (let Some(data) <- result.data) {
                    let responseJson = buildCrudGenAllResultJson(data)
                    res.status(200).json(responseJson)
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"生成失败\"}")
                }
            } else {
                let reason = result.reason ?? "生成失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("DbInfoController", "generateAllCrud exception: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    private func buildCrudGenResultJson(data: CrudGenResult): String {
        let sb = StringBuilder()
        sb.append("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":{")
        sb.append("\"dbName\":\"${data.dbName}\",")
        sb.append("\"tableName\":\"${data.tableName}\",")
        sb.append("\"className\":\"${data.className}\",")
        sb.append("\"modelFile\":\"${data.modelFile}\",")
        sb.append("\"daoFile\":\"${data.daoFile}\",")
        sb.append("\"serviceFile\":\"${data.serviceFile}\",")
        sb.append("\"controllerFile\":\"${data.controllerFile}\",")
        sb.append("\"routeFile\":\"${data.routeFile}\",")
        sb.append("\"permissionGenerated\":${data.permissionGenerated},")
        sb.append("\"fieldCount\":${data.fieldCount}")
        sb.append("}}")
        return sb.toString()
    }

    private func buildCrudGenAllResultJson(data: CrudGenAllResult): String {
        let sb = StringBuilder()
        sb.append("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":{")
        sb.append("\"dbName\":\"${data.dbName}\",")
        sb.append("\"totalTables\":${data.totalTables},")
        sb.append("\"successCount\":${data.successCount},")
        sb.append("\"failCount\":${data.failCount},")
        sb.append("\"results\":[")
        let resultCount = data.results.size
        for (i in 0..resultCount) {
            sb.append("{")
            sb.append("\"tableName\":\"${data.results[i].tableName}\",")
            sb.append("\"className\":\"${data.results[i].className}\",")
            sb.append("\"controllerFile\":\"${data.results[i].controllerFile}\",")
            sb.append("\"fieldCount\":${data.results[i].fieldCount}")
            sb.append("}")
            if (i < resultCount - 1) {
                sb.append(",")
            }
        }
        sb.append("],")
        sb.append("\"errors\":[")
        let errorCount = data.errors.size
        for (i in 0..errorCount) {
            sb.append("\"${data.errors[i]}\"")
            if (i < errorCount - 1) {
                sb.append(",")
            }
        }
        sb.append("]")
        sb.append("}}")
        return sb.toString()
    }

    private func tablesToJson(tables: ArrayList<DbTableInfo>): String {
        let sb = StringBuilder()
        sb.append("[")
        let tableCount = tables.size
        for (i in 0..tableCount) {
            sb.append(tables[i].toJson())
            if (i < tableCount - 1) {
                sb.append(",")
            }
        }
        sb.append("]")
        return sb.toString()
    }
}
