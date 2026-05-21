/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.permissions

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.core.router.Router
import magic.app.core.http.HttpMethod
import std.collection.HashSet
// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

    //#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.PermissionsPO
import magic.app.services.uctoo.PermissionsService
import std.collection.{HashMap, Map, ArrayList}
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class PermissionsController {
    private var service: PermissionsService
    private var router: ?Router = None<Router>

    public init(service: PermissionsService) {
        this.service = service
    }

    public func setRouter(router: Router): Unit {
        this.router = Some<Router>(router)
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
                            let entities = ArrayList<PermissionsPO>()
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
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该permissions\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该permissions\"}")
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
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"permissionss\":[${entitiesJson}]}")
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"permissionss\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinPermissions(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinPermissions()
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
        } else if (value is JsonArray) {
            let arr = value.asArray()
            let result = ArrayList<Any>()
            for (i in 0..arr.size()) {
                result.add(jsonValueToAny(arr[i]))
            }
            return result
        } else if (value is JsonObject) {
            return value.toString()
        } else {
            return ""
        }
    }

    private func mapToEntity(map: Map<String, Any>): PermissionsPO {
        let entity = PermissionsPO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(permissionName) <- map.get("permission_name")) {
            let permissionNameStr = permissionName as String
            if (let Some(s) <- permissionNameStr) {
                entity.permissionName = s
            }
        }
        if (let Some(level) <- map.get("level")) {
            let levelStr = level as String
            if (let Some(s) <- levelStr) {
                entity.level = Some<String>(s)
            }
        }
        if (let Some(icon) <- map.get("icon")) {
            let iconStr = icon as String
            if (let Some(s) <- iconStr) {
                entity.icon = Some<String>(s)
            }
        }
        if (let Some(module) <- map.get("module")) {
            let moduleStr = module as String
            if (let Some(s) <- moduleStr) {
                entity.module = Some<String>(s)
            }
        }
        if (let Some(component) <- map.get("component")) {
            let componentStr = component as String
            if (let Some(s) <- componentStr) {
                entity.component = Some<String>(s)
            }
        }
        if (let Some(redirect) <- map.get("redirect")) {
            let redirectStr = redirect as String
            if (let Some(s) <- redirectStr) {
                entity.redirect = Some<String>(s)
            }
        }
        if (let Some(typeVal) <- map.get("type")) {
            let typeValInt = typeVal as Int64
            if (let Some(v) <- typeValInt) {
                entity.typeVal = Int32(v)
            }
        }
        if (let Some(hidden) <- map.get("hidden")) {
            let hiddenInt = hidden as Int64
            if (let Some(v) <- hiddenInt) {
                entity.hidden = Int32(v)
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
        if (let Some(keepalive) <- map.get("keepalive")) {
            let keepaliveInt = keepalive as Int64
            if (let Some(v) <- keepaliveInt) {
                entity.keepalive = Int32(v)
            }
        }
        if (let Some(path) <- map.get("path")) {
            let pathStr = path as String
            if (let Some(s) <- pathStr) {
                entity.path = Some<String>(s)
            }
        }
        if (let Some(title) <- map.get("title")) {
            let titleStr = title as String
            if (let Some(s) <- titleStr) {
                entity.title = Some<String>(s)
            }
        }
        if (let Some(parentId) <- map.get("parent_id")) {
            let parentIdStr = parentId as String
            if (let Some(s) <- parentIdStr) {
                entity.parentId = Some<String>(s)
            }
        }
        if (let Some(meta) <- map.get("meta")) {
            let metaStr = meta as String
            if (let Some(s) <- metaStr) {
                entity.meta = Some<String>(s)
            }
        }
        if (let Some(method) <- map.get("method")) {
            let methodStr = method as String
            if (let Some(s) <- methodStr) {
                entity.method = Some<String>(s)
            }
        }
        if (let Some(menuType) <- map.get("menu_type")) {
            let menuTypeStr = menuType as String
            if (let Some(s) <- menuTypeStr) {
                entity.menuType = Some<String>(s)
            }
        }
        if (let Some(locale) <- map.get("locale")) {
            let localeStr = locale as String
            if (let Some(s) <- localeStr) {
                entity.locale = Some<String>(s)
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
            // 获取所有permissions数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,permission_name,level,icon,module,component,redirect,type,hidden,weight,creator,created_at,updated_at,deleted_at,keepalive,path,title,parent_id,meta,method,menu_type,locale\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.permissionName}" + ",")
                sb.append(if (let Some(v) <- entity.level) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.icon) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.module) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.component) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.redirect) { "\"" + v + "\"," } else { "" })
                sb.append("${entity.typeVal}")
                sb.append(",")
                sb.append("${entity.hidden}")
                sb.append(",")
                sb.append("${entity.weight}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("${entity.keepalive}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.path) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.title) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.parentId) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.meta) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.method) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.menuType) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.locale) { "\"" + v + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=permissions_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 从应用中加载路由到permissions表（增量更新模式）
     * 
     * 增量更新算法：
     * 1. 查询或创建API父菜单
     * 2. 查询已有API权限节点（type=3且parent_id为API父菜单ID）
     * 3. 从应用路由中收集所有路由
     * 4. 三路对比：新增/更新/软删除
     *    - 新路由（已有中不存在）→ 插入
     *    - 已有路由且无变化 → 跳过
     *    - 已有路由但有变化 → 更新（利用ON UPDATE CASCADE同步role_has_permission等）
     *    - 已有但新路由中不存在 → 软删除（SET deleted_at，避免外键RESTRICT冲突）
     * 
     * 外键依赖关系：
     * - role_has_permission.permission_name → permissions.permission_name (ON DELETE RESTRICT, ON UPDATE CASCADE)
     * - group_has_permission.permission_name → permissions.permission_name (ON DELETE RESTRICT, ON UPDATE CASCADE)
     * - permissions.parent_id → permissions.id (ON DELETE SET NULL, ON UPDATE CASCADE)
     */
    public func loadRouteFromApp(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== loadRouteFromApp() called (incremental mode) ===")
            if (router.isSome()) {
                LogUtils.info("PermissionsController", "=== controller.router is set (Some) ===")
            } else {
                LogUtils.info("PermissionsController", "=== controller.router is None ===")
            }
            if (let Some(gr) <- Router.getGlobalRouter()) {
                let grRoutes = gr.getRoutes()
                LogUtils.info("PermissionsController", "=== Router.globalRouter is set, has ${grRoutes.size} routes ===")
            } else {
                LogUtils.error("PermissionsController", "=== Router.globalRouter is None! ===")
            }
            
            // 1. 查询或创建API父菜单
            let apiParentMenu = getOrCreateAPIParentMenu()
            LogUtils.info("PermissionsController", "=== API parent menu: id=${apiParentMenu.id}, name=${apiParentMenu.permissionName} ===")
            
            // 2. 修复孤立API节点（parent_id=NULL的type=3节点），将其parent_id指向API父菜单
            let orphanCount = service.findOrphanApiPermissions().size
            if (orphanCount > 0) {
                let fixedCount = service.updateParentIdForApiPermissions(apiParentMenu.id)
                LogUtils.info("PermissionsController", "=== Fixed ${fixedCount} orphan API permissions (parent_id was NULL) ===")
            }
            
            // 3. 查询已有API权限节点（包含刚修复的孤立节点）
            let existingPermissions = service.findApiPermissionsByParentId(apiParentMenu.id)
            LogUtils.info("PermissionsController", "=== Found ${existingPermissions.size} existing API permissions ===")
            
            // 4. 从应用路由中收集所有新路由
            let newRoutes = collectAppRoutes(apiParentMenu.id)
            LogUtils.info("PermissionsController", "=== Collected ${newRoutes.size} new routes from app ===")
            
            // 5. 增量对比并执行更新
            let (addedCount, updatedCount, skippedCount, deletedCount, firstError) = incrementalUpdate(existingPermissions, newRoutes)
            
            // 6. 构建包含路由列表的详细响应
            let routeListSb = StringBuilder()
            routeListSb.append("[")
            for (i in 0..newRoutes.size) {
                let rt = newRoutes[i]
                let mt = if (let Some(v) <- rt.method) { v } else { "ANY" }
                routeListSb.append("{\"name\":\"${rt.permissionName}\",\"method\":\"${mt}\"}")
                if (i < newRoutes.size - 1) {
                    routeListSb.append(",")
                }
            }
            routeListSb.append("]")
            let errorJson = if (firstError.size > 0) { "\"error\":\"${firstError}\"" } else { "\"error\":\"\"" }
            let resultJson = "{\"added\":${addedCount},\"updated\":${updatedCount},\"skipped\":${skippedCount},\"deleted\":${deletedCount},\"total\":${newRoutes.size},\"existing\":${existingPermissions.size},${errorJson},\"routes\":${routeListSb}}"
            res.status(200).json(resultJson)
            
            LogUtils.info("PermissionsController", "=== loadRouteFromApp() completed: added=${addedCount}, updated=${updatedCount}, skipped=${skippedCount}, deleted=${deletedCount} ===")
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== loadRouteFromApp() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 获取或创建API父菜单
     * - 查找 permission_name='API' 的记录
     * - 不存在则创建，参照已有0级菜单（Board、AI、database）的格式
     */
    private func getOrCreateAPIParentMenu(): PermissionsPO {
        let existingMenu = service.findByPermissionName("API")
        
        if (let Some(menu) <- existingMenu) {
            LogUtils.info("PermissionsController", "=== Found existing API parent menu: id=${menu.id} ===")
            return menu
        }
        
        LogUtils.info("PermissionsController", "=== API parent menu not found, creating new one ===")
        let apiMenu = PermissionsPO()
        apiMenu.permissionName = "API"
        apiMenu.typeVal = 1
        apiMenu.icon = Some<String>("IconApplication")
        apiMenu.component = Some<String>("api/index")
        apiMenu.hidden = 1
        apiMenu.weight = 17
        apiMenu.keepalive = 1
        apiMenu.path = Some<String>("api")
        apiMenu.title = Some<String>("API")
        apiMenu.menuType = Some<String>("normal")
        apiMenu.locale = Some<String>("menu.api")
        
        let result = service.create(apiMenu, "system")
        if (result.success) {
            if (let Some(data) <- result.data) {
                LogUtils.info("PermissionsController", "=== Created API parent menu: id=${data.id} ===")
                return data
            }
        }
        
        let reason = result.reason ?? "unknown"
        LogUtils.error("PermissionsController", "=== Failed to create API parent menu: ${reason} ===")
        throw Exception("Failed to create API parent menu: ${reason}")
    }
    
    /**
     * 增量更新API权限节点
     * 
     * @param existingPermissions 数据库中已有的API权限节点
     * @param newRoutes 从路由收集的新API权限节点
     * @return (added, updated, skipped, deleted) 四个计数
     */
    private func incrementalUpdate(
        existingPermissions: ArrayList<PermissionsPO>,
        newRoutes: ArrayList<PermissionsPO>
    ): (Int64, Int64, Int64, Int64, String) {
        var addedCount: Int64 = 0
        var updatedCount: Int64 = 0
        var skippedCount: Int64 = 0
        var deletedCount: Int64 = 0
        var firstError: String = ""
        
        // 构建已有权限的查找Map: key = "permissionName|method"
        let existingMap = HashMap<String, PermissionsPO>()
        let existingIds = ArrayList<String>()
        for (perm in existingPermissions) {
            let method = if (let Some(m) <- perm.method) { m } else { "ANY" }
            let key = "${perm.permissionName}|${method}"
            existingMap.add(key, perm)
            existingIds.add(perm.id)
        }
        
        // 构建新路由的key集合，用于后续判断哪些已有权限需要软删除
        let newRouteKeys = HashSet<String>()
        for (route in newRoutes) {
            let method = if (let Some(m) <- route.method) { m } else { "ANY" }
            let key = "${route.permissionName}|${method}"
            newRouteKeys.add(key)
        }
        
        // 遍历新路由：新增或更新
        for (route in newRoutes) {
            let method = if (let Some(m) <- route.method) { m } else { "ANY" }
            let key = "${route.permissionName}|${method}"
            
            if (let Some(existing) <- existingMap.get(key)) {
                // 已存在且key相同 → 跳过
                skippedCount++
            } else {
                // 不存在 → 新增
                let result = service.create(route, "system")
                if (result.success) {
                    addedCount++
                } else {
                    let reason = result.reason ?? "unknown"
                    LogUtils.error("PermissionsController", "=== Failed to add route ${route.permissionName}: ${reason} ===")
                    if (firstError.size == 0) {
                        firstError = "${route.permissionName}: ${reason}"
                    }
                }
            }
        }
        
        // 查找需要软删除的已有权限（已有但新路由中不存在的）
        let idsToDelete = ArrayList<String>()
        for (perm in existingPermissions) {
            let method = if (let Some(m) <- perm.method) { m } else { "ANY" }
            let key = "${perm.permissionName}|${method}"
            if (!newRouteKeys.contains(key)) {
                idsToDelete.add(perm.id)
            }
        }
        
        if (idsToDelete.size > 0) {
            deletedCount = service.softDeleteApiPermissionsByIds(idsToDelete)
            LogUtils.info("PermissionsController", "=== Soft deleted ${deletedCount} obsolete API permissions ===")
        }
        
        return (addedCount, updatedCount, skippedCount, deletedCount, firstError)
    }
    
    /**
     * 收集应用路由
     * 首先添加通配符权限节点, method='ANY'
     * 然后遍历Router中所有路由，跳过通配路由
     * 每个路由创建API权限节点：name=路由路径, method=HTTP方法, type=3
     */
    private func collectAppRoutes(parentId: String): ArrayList<PermissionsPO> {
        let routes = ArrayList<PermissionsPO>()

        let allPermission = PermissionsPO()
        allPermission.permissionName = "/*"
        allPermission.typeVal = 3
        allPermission.hidden = 1
        allPermission.weight = 0
        allPermission.keepalive = 1
        allPermission.method = Some<String>("ANY")
        allPermission.path = Some<String>("/*")
        allPermission.parentId = Some<String>(parentId)
        routes.add(allPermission)

        // 优先使用controller的router字段，其次使用Router全局引用
        var activeRouter: ?Router = router
        if (activeRouter.isNone()) {
            LogUtils.info("PermissionsController", "=== controller.router is None, trying Router.getGlobalRouter() ===")
            activeRouter = Router.getGlobalRouter()
        }

        if (let Some(r) <- activeRouter) {
            let appRoutes = r.getRoutes()
            LogUtils.info("PermissionsController", "=== Router is set, getRoutes() returned ${appRoutes.size} routes ===")

            for (route in appRoutes) {
                if (route.path == "/*") {
                    continue
                }

                let permission = PermissionsPO()
                permission.permissionName = route.path
                permission.typeVal = 3
                permission.hidden = 1
                permission.weight = 0
                permission.keepalive = 1
                permission.method = Some<String>(httpMethodToString(route.method))
                permission.path = Some<String>(route.path)
                permission.parentId = Some<String>(parentId)

                routes.add(permission)
            }
        } else {
            LogUtils.error("PermissionsController", "=== Both controller.router and Router.globalRouter are None! ===")
        }

        LogUtils.info("PermissionsController", "=== Collected ${routes.size} API permission routes (including /*) ===")
        return routes
    }

    /**
     * 判断是否为公开路由(无需权限检查)
     */
    private func isPublicRoute(path: String): Bool {
        let publicRoutes = [
            "/api/v1/uctoo/user/signin",
            "/api/v1/uctoo/user/signup",
            "/api/v1/health",
            "/api/v1/info"
        ]

        for (publicPath in publicRoutes) {
            if (path == publicPath) {
                return true
            }
        }

        return false
    }

    /**
     * 将HttpMethod转换为字符串
     */
    private func httpMethodToString(method: HttpMethod): String {
        if (method.level() == HttpMethod.GET.level()) {
            return "GET"
        } else if (method.level() == HttpMethod.POST.level()) {
            return "POST"
        } else if (method.level() == HttpMethod.PUT.level()) {
            return "PUT"
        } else if (method.level() == HttpMethod.DELETE.level()) {
            return "DELETE"
        } else {
            return "ANY"
        }
    }
    
    /**
     * 获取用户菜单树 - V4 标准 RBAC
     * POST /api/v1/uctoo/permissions/user/menu
     * 
     * 实现逻辑（参考 backend 的 getUserPermissionsTree）：
     * 1. 从 user_has_roles 获取用户所有角色
     * 2. 从 role_has_permission 获取角色所有权限名称
     * 3. 从 permissions 获取权限详情（type=1 为菜单）
     * 4. 构建树形结构返回
     */
    public func getUserMenuTree(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== getUserMenuTree() called ===")
            
            // 获取用户ID（从请求体或token）
            let userId = extractUserId(req)
            
            if (let Some(uid) <- userId) {
                LogUtils.info("PermissionsController", "=== Getting menu for user: ${uid} ===")
                
                // 获取用户菜单树
                let menuTree = service.getUserMenuTree(uid)
                
                // 返回结果
                let menuJson = buildMenuTreeJson(menuTree)
                res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":${menuJson}}")
                
                LogUtils.info("PermissionsController", "=== getUserMenuTree() completed ===")
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== getUserMenuTree() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 获取所有菜单树
     * GET /api/v1/uctoo/permissions/menu/all
     */
    public func getAllMenuTree(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== getAllMenuTree() called ===")
            
            let menuTree = service.getAllMenuTree()
            let menuJson = buildMenuTreeJson(menuTree)
            res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":${menuJson}}")
            
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== getAllMenuTree() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 根据角色ID获取菜单树
     * POST /api/v1/uctoo/permissions/role/menu
     */
    public func getRoleMenuTree(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== getRoleMenuTree() called ===")
            
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let roleIdOpt = b.get("id")
                if (let Some(roleIdVal) <- roleIdOpt) {
                    let roleIdStr = roleIdVal as String
                    if (let Some(roleId) <- roleIdStr) {
                        let menuTree = service.getRoleMenuTree(roleId)
                        let menuJson = buildMenuTreeJson(menuTree)
                        res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":${menuJson}}")
                        return
                    }
                }
            }
            
            res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少角色ID参数\"}")
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== getRoleMenuTree() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 从请求中提取用户ID
     */
    private func extractUserId(req: HttpRequest): ?String {
        // 1. 优先从请求体获取
        let body = parseBody(req)
        if (let Some(b) <- body) {
            let idOpt = b.get("id")
            if (let Some(idVal) <- idOpt) {
                let idStr = idVal as String
                if (let Some(s) <- idStr) {
                    LogUtils.info("PermissionsController", "=== Extracting userId from request body ===")
                    return Some<String>(s)
                }
            }
        }
        
        // 2. 从 locals 获取（由 DeserializeUserMiddleware 从 token 解析后的用户信息）
        let userId = req.getLocals("userId")
            if (let Some(uid) <- userId) {
              let uidStr = uid as String
              if (let Some(s) <- uidStr) {
                LogUtils.info("PermissionsController", "=== Extracting userId from locals ===")
                return Some<String>(s)
            }
        }
        
        LogUtils.error("PermissionsController", "=== No userId found in request ===")
        return None<String>
    }
    
    /**
     * 构建菜单树JSON - 直接使用数据库字段名并构建树形结构
     * 数据库字段名：permission_name, path, icon, menu_type, parent_id, weight, locale
     */
    private func buildMenuTreeJson(menus: ArrayList<PermissionsPO>): String {
        // 构建树形结构
        let treeMenus = buildTree(menus, None<String>)
        
        let sb = StringBuilder()
        sb.append("[")
        
        let size = treeMenus.size
        for (i in 0..size) {
            let menu = treeMenus[i]
            sb.append(convertToDatabaseFormatWithChildren(menu, menus))
            
            if (i < size - 1) {
                sb.append(",")
            }
        }
        
        sb.append("]")
        return sb.toString()
    }
    
    /**
     * 构建树形结构 - 递归查找子菜单
     * 
     * 注意：数据库中的 parent_id 可能是空字符串 "" 而不是 null
     * 需要将空字符串也视为根菜单
     */
    private func buildTree(menus: ArrayList<PermissionsPO>, parentId: ?String): ArrayList<PermissionsPO> {
        let result = ArrayList<PermissionsPO>()
        
        for (menu in menus) {
            let menuParentId = menu.parentId
            
            // 判断是否匹配父ID
            let isMatch = if (let Some(pid) <- parentId) {
                // 有父ID，查找子菜单
                if (let Some(mpid) <- menuParentId) {
                    // 比较时去除空白字符
                    let trimmedMpid = mpid.trimAscii()
                    let trimmedPid = pid.trimAscii()
                    let isFound = trimmedMpid == trimmedPid && !trimmedMpid.isEmpty()
                    if (isFound) {
                        LogUtils.info("PermissionsController", "=== buildTree: Found child menu ${menu.permissionName} with parentId=${mpid} ===")
                    }
                    isFound
                } else {
                    false
                }
            } else {
                // 无父ID，查找根菜单
                // 根菜单的条件：parentId 为 None 或空字符串
                let isRoot = if (let Some(mpid) <- menuParentId) {
                    mpid.trimAscii().isEmpty()
                } else {
                    true
                }
                if (isRoot) {
                    LogUtils.info("PermissionsController", "=== buildTree: Found root menu ${menu.permissionName} ===")
                }
                isRoot
            }
            
            if (isMatch) {
                result.add(menu)
            }
        }
        
        LogUtils.info("PermissionsController", "=== buildTree: Found ${result.size} menus for parentId=${parentId} ===")
        return result
    }
    
    /**
     * 转换为前端格式并递归构建children
     */
    private func convertToFrontendFormatWithChildren(menu: PermissionsPO, allMenus: ArrayList<PermissionsPO>): String {
        let sb = StringBuilder()
        sb.append("{")
        
        // id
        sb.append("\"id\":\"${menu.id}\",")
        
        // label - 使用 title 或 permissionName
        let label = if (let Some(t) <- menu.title) { t } else { menu.permissionName }
        sb.append("\"label\":\"${label}\",")
        
        // url - 使用 path
        let pathStr = if (let Some(p) <- menu.path) { p } else { "" }
        sb.append("\"url\":\"${pathStr}\",")
        
        // component
        let component = if (let Some(c) <- menu.component) { c } else { "" }
        sb.append("\"component\":\"${component}\",")
        
        // customIcon - 使用 icon
        let icon = if (let Some(i) <- menu.icon) { i } else { "" }
        sb.append("\"customIcon\":\"${icon}\",")
        
        // menuType
        let menuType = if (let Some(mt) <- menu.menuType) { mt } else { "normal" }
        sb.append("\"menuType\":\"${menuType}\",")
        
        // parentId
        let parentIdStr = if (let Some(pid) <- menu.parentId) { pid } else { "" }
        sb.append("\"parentId\":\"${parentIdStr}\",")
        
        // order - 使用 weight
        let order = menu.weight
        sb.append("\"order\":${order},")
        
        // locale
        let locale = if (let Some(l) <- menu.locale) { l } else { "" }
        sb.append("\"locale\":\"${locale}\",")
        
        // children - 递归构建子菜单
        let children = buildTree(allMenus, Some<String>(menu.id))
        if (children.size > 0) {
            sb.append("\"children\":[")
            for (i in 0..children.size) {
                sb.append(convertToFrontendFormatWithChildren(children[i], allMenus))
                if (i < children.size - 1) {
                    sb.append(",")
                }
            }
            sb.append("]")
        } else {
            sb.append("\"children\":[]")
        }
        
        sb.append("}")
        return sb.toString()
    }
    
    /**
     * 直接使用数据库字段名并递归构建children
     */
    private func convertToDatabaseFormatWithChildren(menu: PermissionsPO, allMenus: ArrayList<PermissionsPO>): String {
        let sb = StringBuilder()
        sb.append("{")
        
        // id
        sb.append("\"id\":\"${menu.id}\",")
        
        // permission_name
        sb.append("\"permission_name\":\"${menu.permissionName}\",")
        
        // path
        let pathStr = if (let Some(p) <- menu.path) { p } else { "" }
        sb.append("\"path\":\"${pathStr}\",")
        
        // component
        let component = if (let Some(c) <- menu.component) { c } else { "" }
        sb.append("\"component\":\"${component}\",")
        
        // icon
        let icon = if (let Some(i) <- menu.icon) { i } else { "" }
        sb.append("\"icon\":\"${icon}\",")
        
        // menu_type
        let menuType = if (let Some(mt) <- menu.menuType) { mt } else { "normal" }
        sb.append("\"menu_type\":\"${menuType}\",")
        
        // parent_id
        let parentIdStr = if (let Some(pid) <- menu.parentId) { pid } else { "" }
        sb.append("\"parent_id\":\"${parentIdStr}\",")
        
        // weight
        let weight = menu.weight
        sb.append("\"weight\":${weight},")
        
        // locale
        let locale = if (let Some(l) <- menu.locale) { l } else { "" }
        sb.append("\"locale\":\"${locale}\",")
        
        // title
        let title = if (let Some(t) <- menu.title) { t } else { "" }
        sb.append("\"title\":\"${title}\",")
        
        // type
        let typeVal = menu.typeVal
        sb.append("\"type\":${typeVal},")
        
        // hidden
        let hidden = menu.hidden
        sb.append("\"hidden\":${hidden},")
        
        // keepalive
        let keepalive = menu.keepalive
        sb.append("\"keepalive\":${keepalive},")
        
        // children - 递归构建子菜单
        let children = buildTree(allMenus, Some<String>(menu.id))
        if (children.size > 0) {
            sb.append("\"children\":[")
            for (i in 0..children.size) {
                sb.append(convertToDatabaseFormatWithChildren(children[i], allMenus))
                if (i < children.size - 1) {
                    sb.append(",")
                }
            }
            sb.append("]")
        } else {
            sb.append("\"children\":[]")
        }
        
        sb.append("}")
        return sb.toString()
    }
    
    /**
     * 将 PermissionsPO 转换为前端期望的 JSON 格式
     */
    private func convertToFrontendFormat(menu: PermissionsPO): String {
        let sb = StringBuilder()
        sb.append("{")
        
        // id
        sb.append("\"id\":\"${menu.id}\",")
        
        // label - 使用 title 或 permissionName
        let label = if (let Some(t) <- menu.title) { t } else { menu.permissionName }
        sb.append("\"label\":\"${label}\",")
        
        // url - 使用 path
        let pathStr = if (let Some(p) <- menu.path) { p } else { "" }
        sb.append("\"url\":\"${pathStr}\",")
        
        // component
        let component = if (let Some(c) <- menu.component) { c } else { "" }
        sb.append("\"component\":\"${component}\",")
        
        // customIcon - 使用 icon
        let icon = if (let Some(i) <- menu.icon) { i } else { "" }
        sb.append("\"customIcon\":\"${icon}\",")
        
        // menuType
        let menuType = if (let Some(mt) <- menu.menuType) { mt } else { "normal" }
        sb.append("\"menuType\":\"${menuType}\",")
        
        // parentId
        let parentIdStr = if (let Some(pid) <- menu.parentId) { pid } else { "" }
        sb.append("\"parentId\":\"${parentIdStr}\",")
        
        // order - 使用 weight
        let order = menu.weight
        sb.append("\"order\":${order},")
        
        // locale
        let locale = if (let Some(l) <- menu.locale) { l } else { "" }
        sb.append("\"locale\":\"${locale}\",")
        
        // children - 空数组，由前端构建树形结构
        sb.append("\"children\":[]")
        
        sb.append("}")
        return sb.toString()
    }
    
    /**
     * 获取用户所有权限 - 不区分权限类型
     * POST /api/v1/uctoo/permissions/user/all
     * 
     * 实现逻辑：
     * 1. 从 user_has_roles 获取用户所有角色
     * 2. 从 role_has_permission 获取角色所有权限名称
     * 3. 从 permissions 获取所有权限详情（不区分类型）
     * 4. 返回权限列表
     */
    public func getUserAllPermissions(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== getUserAllPermissions() called ===")
            
            // 获取用户ID（从请求体或token）
            let userId = extractUserId(req)
            
            if (let Some(uid) <- userId) {
                LogUtils.info("PermissionsController", "=== Getting all permissions for user: ${uid} ===")
                
                // 获取用户所有权限
                let permissions = service.getUserAllPermissions(uid)
                
                let permissionsJson = buildAllPermissionsJson(permissions)
                let totalCount = permissions.size
                let totalPage = if (totalCount > 0) { 1 } else { 0 }
                res.status(200).json("{\"currentPage\":1,\"totalCount\":${totalCount},\"totalPage\":${totalPage},\"permissionss\":${permissionsJson}}")
                
                LogUtils.info("PermissionsController", "=== getUserAllPermissions() completed ===")
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== getUserAllPermissions() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 构建权限列表JSON
     */
    private func buildPermissionsListJson(permissions: ArrayList<PermissionsPO>): String {
        let sb = StringBuilder()
        sb.append("[")
        
        let size = permissions.size
        for (i in 0..size) {
            let perm = permissions[i]
            let permType = perm.typeVal
            let desc = if (let Some(t) <- perm.title) { t } else { perm.permissionName }
            
            sb.append("{")
            sb.append("\"id\":\"${perm.id}\",")
            sb.append("\"name\":\"${perm.permissionName}\",")
            sb.append("\"desc\":\"${desc}\",")
            sb.append("\"type\":${permType}")
            sb.append("}")
            
            if (i < size - 1) {
                sb.append(",")
            }
        }
        
        sb.append("]")
        return sb.toString()
    }

    /**
     * 获取所有权限节点（超级管理员专用）
     * GET /api/v1/uctoo/permissions/all
     * 
     * 仅持有 "*" 权限的超级管理员可调用
     * 返回 permissions 表中 deleted_at 为空的所有记录
     */
    public func getAllPermissions(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== getAllPermissions() called ===")
            
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let userIdStr = userId.getOrThrow() as String
            if (let Some(uid) <- userIdStr) {
                if (uid.isEmpty()) {
                    res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                    return
                }
                
                let allPermissions = service.getAllPermissions()
                let permissionsJson = buildAllPermissionsJson(allPermissions)
                let totalCount = allPermissions.size
                let totalPage = if (totalCount > 0) { 1 } else { 0 }
                res.status(200).json("{\"currentPage\":1,\"totalCount\":${totalCount},\"totalPage\":${totalPage},\"permissionss\":${permissionsJson}}")
                
                LogUtils.info("PermissionsController", "=== getAllPermissions() returned ${allPermissions.size} records ===")
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== getAllPermissions() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 批量授权：将权限节点授权给用户角色
     * POST /api/v1/uctoo/permissions/authorize
     * 
     * 请求体: { permission_names: string[], role_ids: string[], creator?: string }
     * 仅超级管理员可调用
     * 利用 (role_id, permission_name) 联合主键保证幂等性
     */
    public func batchAuthorize(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== batchAuthorize() called ===")
            
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let userIdStr = userId.getOrThrow() as String
            if (let Some(uid) <- userIdStr) {
                if (uid.isEmpty()) {
                    res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                    return
                }
                
                if (!service.checkUserHasWildcardPermission(uid)) {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"权限不足，仅超级管理员可操作\"}")
                    return
                }
                
                let body = parseBody(req)
                if (let Some(b) <- body) {
                    let permissionNames = extractStringArray(b, "permission_names")
                    let roleIds = extractStringArray(b, "role_ids")
                    
                    if (permissionNames.size == 0 || roleIds.size == 0) {
                        res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"permission_names和role_ids不能为空\"}")
                        return
                    }
                    
                    if (permissionNames.size > 100 || roleIds.size > 100) {
                        res.status(400).json("{\"errno\":\"40004\",\"errmsg\":\"单次授权数量不能超过100\"}")
                        return
                    }
                    
                    let creatorOpt = b.get("creator")
                    let creator = if (let Some(c) <- creatorOpt) {
                        let cs = c as String
                        if (let Some(s) <- cs) { s } else { uid }
                    } else {
                        uid
                    }
                    
                    let result = service.batchAuthorize(permissionNames, roleIds, creator)
                    if (result.success) {
                        let dataJson = result.data.getOrThrow()
                        res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":${dataJson}}")
                    } else {
                        let reason = result.reason ?? "授权失败"
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                }
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== batchAuthorize() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 批量取消授权接口
     * POST /api/v1/uctoo/permissions/revoke
     * 
     * 请求体:
     * {
     *   "permission_names": ["permission1", "permission2"],
     *   "role_ids": ["role1", "role2"]
     * }
     * 
     * 利用 (role_id, permission_name) 联合主键保证幂等性
     */
    public func batchRevoke(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== batchRevoke() called ===")
            
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }
            let userIdStr = userId.getOrThrow() as String
            if (let Some(uid) <- userIdStr) {
                if (uid.isEmpty()) {
                    res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                    return
                }
                
                if (!service.checkUserHasWildcardPermission(uid)) {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"权限不足，仅超级管理员可操作\"}")
                    return
                }
                
                let body = parseBody(req)
                if (let Some(b) <- body) {
                    let permissionNames = extractStringArray(b, "permission_names")
                    let roleIds = extractStringArray(b, "role_ids")
                    
                    if (permissionNames.size == 0 || roleIds.size == 0) {
                        res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"permission_names和role_ids不能为空\"}")
                        return
                    }
                    
                    if (permissionNames.size > 100 || roleIds.size > 100) {
                        res.status(400).json("{\"errno\":\"40004\",\"errmsg\":\"单次取消授权数量不能超过100\"}")
                        return
                    }
                    
                    let result = service.batchRevoke(permissionNames, roleIds)
                    if (result.success) {
                        let dataJson = result.data.getOrThrow()
                        res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":${dataJson}}")
                    } else {
                        let reason = result.reason ?? "取消授权失败"
                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                    }
                } else {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
                }
            } else {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== batchRevoke() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 构建全量权限列表JSON（包含完整字段信息）
     */
    private func buildAllPermissionsJson(permissions: ArrayList<PermissionsPO>): String {
        let sb = StringBuilder()
        sb.append("[")
        
        let size = permissions.size
        for (i in 0..size) {
            let perm = permissions[i]
            sb.append(perm.toJson())
            if (i < size - 1) {
                sb.append(",")
            }
        }
        
        sb.append("]")
        return sb.toString()
    }

    /**
     * 从请求体Map中提取字符串数组
     */
    private func extractStringArray(body: Map<String, Any>, key: String): ArrayList<String> {
        let result = ArrayList<String>()
        let val = body.get(key)
        if (let Some(v) <- val) {
            let arrList = v as ArrayList<Any>
            if (let Some(al) <- arrList) {
                for (item in al) {
                    let s = item as String
                    if (let Some(str) <- s) {
                        if (!str.isEmpty()) {
                            result.add(str)
                        }
                    }
                }
            } else {
                let arrStr = v as String
                if (let Some(s) <- arrStr) {
                    if (s.startsWith("[") && s.endsWith("]")) {
                        let content = s[1..(s.size - 1)]
                        if (!content.isEmpty()) {
                            let parts = content.split(",")
                            for (part in parts) {
                                var item = part.trimAscii()
                                if (item.startsWith("\"") && item.endsWith("\"")) {
                                    item = item[1..(item.size - 1)]
                                }
                                if (!item.isEmpty()) {
                                    result.add(item)
                                }
                            }
                        }
                    }
                }
            }
        }
        return result
    }
}
