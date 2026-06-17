/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.agents

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.AgentsPO
import magic.app.services.uctoo.AgentsService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class AgentsController {
    private var service: AgentsService

    public init(service: AgentsService) {
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
                            let entities = ArrayList<AgentsPO>()
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
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该agents\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该agents\"}")
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
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"agentss\":[${entitiesJson}]}")
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"agentss\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinAgents(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinAgents()
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

    private func mapToEntity(map: Map<String, Any>): AgentsPO {
        let entity = AgentsPO()
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
        if (let Some(agentType) <- map.get("agent_type")) {
            let agentTypeStr = agentType as String
            if (let Some(s) <- agentTypeStr) {
                entity.agentType = s
            }
        }
        if (let Some(description) <- map.get("description")) {
            let descriptionStr = description as String
            if (let Some(s) <- descriptionStr) {
                entity.description = Some<String>(s)
            }
        }
        if (let Some(status) <- map.get("status")) {
            let statusInt = status as Int64
            if (let Some(v) <- statusInt) {
                entity.status = Some<Int32>(Int32(v))
            }
        }
        if (let Some(config) <- map.get("config")) {
            let configStr = config as String
            if (let Some(s) <- configStr) {
                entity.config = Some<String>(s)
            }
        }
        if (let Some(systemPrompt) <- map.get("system_prompt")) {
            let systemPromptStr = systemPrompt as String
            if (let Some(s) <- systemPromptStr) {
                entity.systemPrompt = Some<String>(s)
            }
        }
        if (let Some(tools) <- map.get("tools")) {
            let toolsStr = tools as String
            if (let Some(s) <- toolsStr) {
                entity.tools = Some<String>(s)
            }
        }
        if (let Some(model) <- map.get("model")) {
            let modelStr = model as String
            if (let Some(s) <- modelStr) {
                entity.model = Some<String>(s)
            }
        }
        if (let Some(parentId) <- map.get("parent_id")) {
            let parentIdStr = parentId as String
            if (let Some(s) <- parentIdStr) {
                entity.parentId = Some<String>(s)
            }
        }
        if (let Some(userId) <- map.get("user_id")) {
            let userIdStr = userId as String
            if (let Some(s) <- userIdStr) {
                entity.userId = Some<String>(s)
            }
        }
        if (let Some(color) <- map.get("color")) {
            let colorStr = color as String
            if (let Some(s) <- colorStr) {
                entity.color = Some<String>(s)
            }
        }
        if (let Some(background) <- map.get("background")) {
            let backgroundBool = background as Bool
            if (let Some(v) <- backgroundBool) {
                entity.background = Some<Bool>(v)
            }
        }
        if (let Some(memoryScope) <- map.get("memory_scope")) {
            let memoryScopeStr = memoryScope as String
            if (let Some(s) <- memoryScopeStr) {
                entity.memoryScope = Some<String>(s)
            }
        }
        if (let Some(isolationMode) <- map.get("isolation_mode")) {
            let isolationModeStr = isolationMode as String
            if (let Some(s) <- isolationModeStr) {
                entity.isolationMode = Some<String>(s)
            }
        }
        if (let Some(maxTurns) <- map.get("max_turns")) {
            let maxTurnsInt = maxTurns as Int64
            if (let Some(v) <- maxTurnsInt) {
                entity.maxTurns = Some<Int32>(Int32(v))
            }
        }
        if (let Some(initialPrompt) <- map.get("initial_prompt")) {
            let initialPromptStr = initialPrompt as String
            if (let Some(s) <- initialPromptStr) {
                entity.initialPrompt = Some<String>(s)
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
        if (let Some(version) <- map.get("version")) {
            let versionStr = version as String
            if (let Some(s) <- versionStr) {
                entity.version = Some<String>(s)
            }
        }
        if (let Some(author) <- map.get("author")) {
            let authorStr = author as String
            if (let Some(s) <- authorStr) {
                entity.author = Some<String>(s)
            }
        }
        if (let Some(permissions) <- map.get("permissions")) {
            let permissionsStr = permissions as String
            if (let Some(s) <- permissionsStr) {
                entity.permissions = Some<String>(s)
            }
        }
        if (let Some(sourcePath) <- map.get("source_path")) {
            let sourcePathStr = sourcePath as String
            if (let Some(s) <- sourcePathStr) {
                entity.sourcePath = Some<String>(s)
            }
        }
        if (let Some(syncStatus) <- map.get("sync_status")) {
            let syncStatusStr = syncStatus as String
            if (let Some(s) <- syncStatusStr) {
                entity.syncStatus = Some<String>(s)
            }
        }
        if (let Some(lastSyncAt) <- map.get("last_sync_at")) {
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
            // 获取所有agents数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,name,agent_type,description,status,config,system_prompt,tools,model,parent_id,user_id,color,background,memory_scope,isolation_mode,max_turns,initial_prompt,creator,created_at,updated_at,deleted_at,version,author,permissions,source_path,sync_status,last_sync_at\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.name}" + ",")
                sb.append("\"" + "${entity.agentType}" + ",")
                sb.append(if (let Some(v) <- entity.description) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.status) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.config) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.systemPrompt) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.tools) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.model) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.parentId) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.userId) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.color) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.background) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.memoryScope) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.isolationMode) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.maxTurns) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.initialPrompt) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.version) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.author) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.permissions) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.sourcePath) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.syncStatus) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.lastSyncAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=agents_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }

    /**
     * 获取主 Agent 信息
     * GET /api/v1/uctoo/agents/main
     * 返回主 Agent 的完整信息，包括 systemPrompt、tools、model 等
     */
    public func getMainAgent(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 查询 agent_type 为 MAIN 的 Agent
            let (entities, _) = service.getListWithFilter(1, 1, "", "{\"agent_type\":{\"equals\":\"MAIN\"}}")
            
            if (entities.size == 0) {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到主 Agent\"}")
                return
            }
            
            let mainAgent = entities[0]
            
            // 构建返回的 JSON 对象
            let result = JsonObject()
            result.put("id", JsonString(mainAgent.id))
            result.put("name", JsonString(mainAgent.name))
            result.put("agent_type", JsonString(mainAgent.agentType))
            
            if (let Some(desc) <- mainAgent.description) {
                result.put("description", JsonString(desc))
            }
            
            if (let Some(status) <- mainAgent.status) {
                result.put("status", JsonInt(Int64(status)))
            }
            
            if (let Some(config) <- mainAgent.config) {
                result.put("config", JsonString(config))
            }
            
            if (let Some(systemPrompt) <- mainAgent.systemPrompt) {
                result.put("system_prompt", JsonString(systemPrompt))
            }
            
            if (let Some(tools) <- mainAgent.tools) {
                result.put("tools", JsonString(tools))
            }
            
            if (let Some(model) <- mainAgent.model) {
                result.put("model", JsonString(model))
            }
            
            if (let Some(parentId) <- mainAgent.parentId) {
                result.put("parent_id", JsonString(parentId))
            }
            
            if (let Some(maxTurns) <- mainAgent.maxTurns) {
                result.put("max_turns", JsonInt(Int64(maxTurns)))
            }
            
            if (let Some(memoryScope) <- mainAgent.memoryScope) {
                result.put("memory_scope", JsonString(memoryScope))
            }
            
            if (let Some(version) <- mainAgent.version) {
                result.put("version", JsonString(version))
            }
            
            if (let Some(author) <- mainAgent.author) {
                result.put("author", JsonString(author))
            }
            
            if (let Some(permissions) <- mainAgent.permissions) {
                result.put("permissions", JsonString(permissions))
            }
            
            LogUtils.info("AgentsController: getMainAgent success, id=${mainAgent.id}, name=${mainAgent.name}")
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("AgentsController: getMainAgent error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    /**
     * 获取 Agent 可用的技能列表
     * GET /api/v1/uctoo/agents/:id/skills
     */
    public func getAgentSkills(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let agentIdOpt = req.pathParam("id")
            
            if (agentIdOpt.isNone()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"缺少 agent id\"}")
                return
            }
            
            let idStr = agentIdOpt.getOrThrow()
            
            // 查询 Agent
            let result = service.getById(idStr)
            if (!result.success) {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"Agent 不存在\"}")
                return
            }
            
            let agentDataOpt = result.data
            match (agentDataOpt) {
                case Some(agentData) => 
                    // 解析 tools 字段（JSON 数组格式）
                    let skillsArray = JsonArray()
                    
                    match (agentData.tools) {
                        case Some(tools) =>
                            // tools 字段可能是 JSON 数组字符串，如 "[\"file_read\",\"file_write\"]"
                            try {
                                let toolsJson = JsonValue.fromStr(tools)
                                if (toolsJson is JsonArray) {
                                    let arr = toolsJson.asArray()
                                    for (item in arr.getItems()) {
                                        skillsArray.add(item)
                                    }
                                } else {
                                    // 如果不是数组，尝试按逗号分隔的字符串处理
                                    let toolList = tools.split(",")
                                    for (tool in toolList) {
                                        let trimmed = tool.trimAscii()
                                        if (!trimmed.isEmpty()) {
                                            skillsArray.add(JsonString(trimmed))
                                        }
                                    }
                                }
                            } catch (_: Exception) {
                                // 如果解析失败，尝试按逗号分隔的字符串处理
                                let toolList = tools.split(",")
                                for (tool in toolList) {
                                    let trimmed = tool.trimAscii()
                                    if (!trimmed.isEmpty()) {
                                        skillsArray.add(JsonString(trimmed))
                                    }
                                }
                            }
                        case None => ()
                    }
                    
                    // 构建返回结果
                    let respResult = JsonObject()
                    respResult.put("agent_id", JsonString(idStr))
                    respResult.put("agent_name", JsonString(agentData.name))
                    respResult.put("skills", skillsArray)
                    respResult.put("total", JsonInt(Int64(skillsArray.size())))
                    
                    res.status(200).json(respResult.toString())
                case None =>
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"Agent 不存在\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AgentsController: getAgentSkills error: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }


//#endregion AutoCreateCode
}
