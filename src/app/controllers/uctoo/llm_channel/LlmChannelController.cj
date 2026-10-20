/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.llm_channel

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.model.channel.{ChannelService, ChannelProbe}
import magic.utils.SecretCrypto
import std.convert.Parsable

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.LlmChannelPO
import magic.app.services.uctoo.LlmChannelService
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.app.core.PermissionLevel
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

public class LlmChannelController {
    private var service: LlmChannelService

    public init(service: LlmChannelService) {
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
                            let entities = ArrayList<LlmChannelPO>()
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
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该llm_channel\"}")
                    }
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"您没有权限访问该llm_channel\"}")
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
            res.status(200).json("{\"currentPage\":${currentPage},\"totalCount\":${total},\"totalPage\":${totalPage},\"llm_channels\":[${entitiesJson}]}")
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"llm_channels\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func emptyRecycleBinLlmChannel(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let result = service.emptyRecycleBinLlmChannel()
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

    private func mapToEntity(map: Map<String, Any>): LlmChannelPO {
        let entity = LlmChannelPO()
        if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(code) <- map.get("code")) {
            let codeStr = code as String
            if (let Some(s) <- codeStr) {
                entity.code = s
            }
        }
        if (let Some(displayName) <- map.get("display_name")) {
            let displayNameStr = displayName as String
            if (let Some(s) <- displayNameStr) {
                entity.displayName = Some<String>(s)
            }
        }
        if (let Some(protocol) <- map.get("protocol")) {
            let protocolStr = protocol as String
            if (let Some(s) <- protocolStr) {
                entity.protocol = s
            }
        }
        if (let Some(baseUrl) <- map.get("base_url")) {
            let baseUrlStr = baseUrl as String
            if (let Some(s) <- baseUrlStr) {
                entity.baseUrl = Some<String>(s)
            }
        }
        if (let Some(secretRef) <- map.get("secret_ref")) {
            let secretRefStr = secretRef as String
            if (let Some(s) <- secretRefStr) {
                entity.secretRef = Some<String>(s)
            }
        }
        if (let Some(defaultModel) <- map.get("default_model")) {
            let defaultModelStr = defaultModel as String
            if (let Some(s) <- defaultModelStr) {
                entity.defaultModel = Some<String>(s)
            }
        }
        if (let Some(capabilities) <- map.get("capabilities")) {
            let capabilitiesStr = capabilities as String
            if (let Some(s) <- capabilitiesStr) {
                entity.capabilities = s
            }
        }
        if (let Some(scopes) <- map.get("scopes")) {
            let scopesStr = scopes as String
            if (let Some(s) <- scopesStr) {
                entity.scopes = s
            }
        }
        if (let Some(priority) <- map.get("priority")) {
            let priorityInt = priority as Int64
            if (let Some(v) <- priorityInt) {
                entity.priority = Int32(v)
            }
        }
        if (let Some(status) <- map.get("status")) {
            let statusStr = status as String
            if (let Some(s) <- statusStr) {
                entity.status = s
            }
        }
        if (let Some(isDefault) <- map.get("is_default")) {
            let isDefaultBool = isDefault as Bool
            if (let Some(v) <- isDefaultBool) {
                entity.isDefault = v
            }
        }
        if (let Some(health) <- map.get("health")) {
            let healthStr = health as String
            if (let Some(s) <- healthStr) {
                entity.health = s
            }
        }
        if (let Some(probeAt) <- map.get("probe_at")) {
            // DateTime类型, 由数据库处理
        }
        if (let Some(config) <- map.get("config")) {
            let configStr = config as String
            if (let Some(s) <- configStr) {
                entity.config = s
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
        if (let Some(apiKey) <- map.get("api_key")) {
            let apiKeyStr = apiKey as String
            if (let Some(s) <- apiKeyStr) {
                entity.apiKey = Some<String>(s)
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
            // 获取所有llm_channel数据
            let (entities, _) = service.getList(1, 1000)

            // 构建CSV内容
            let sb = StringBuilder()
            // 写入CSV头部
            sb.append("id,code,display_name,protocol,base_url,secret_ref,default_model,capabilities,scopes,priority,status,is_default,health,probe_at,config,revision,creator,created_at,updated_at,deleted_at,api_key\n")

            // 写入数据行
            for (entity in entities) {
                sb.append("\"" + "${entity.id}" + ",")
                sb.append("\"" + "${entity.code}" + ",")
                sb.append(if (let Some(v) <- entity.displayName) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.protocol}" + ",")
                sb.append(if (let Some(v) <- entity.baseUrl) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.secretRef) { "\"" + v + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.defaultModel) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.capabilities}" + ",")
                sb.append("\"" + "${entity.scopes}" + ",")
                sb.append("${entity.priority}")
                sb.append(",")
                sb.append("\"" + "${entity.status}" + ",")
                sb.append("${entity.isDefault}")
                sb.append(",")
                sb.append("\"" + "${entity.health}" + ",")
                sb.append(if (let Some(v) <- entity.probeAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append("\"" + "${entity.config}" + ",")
                sb.append("${entity.revision}")
                sb.append(",")
                sb.append(if (let Some(v) <- entity.creator) { "\"" + v + "\"," } else { "" })
                sb.append("\"" + "${entity.createdAt.toString()}" + ",")
                sb.append("\"" + "${entity.updatedAt.toString()}" + ",")
                sb.append(if (let Some(v) <- entity.deletedAt) { "\"" + v.toString() + "\"," } else { "" })
                sb.append(if (let Some(v) <- entity.apiKey) { "\"" + v + "\"," } else { "" })
                sb.append("\n")
            }

            // 设置响应头
            res.header("Content-Type", "text/csv")
            res.header("Content-Disposition", "attachment; filename=llm_channel_export.csv")
            res.status(200).send(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"" + e.message + "\"}")
        }
    }


//#endregion AutoCreateCode

    // ==================== 动态通道业务端点（手写，委托 ChannelService / ChannelProbe；方法名以 Channel 后缀避免与标准 CRUD 重名） ====================

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
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
            let channels = svc.listChannels()
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

    public func detail(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let poOpt = svc.getChannelByCode(code)
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

    public func catalog(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let list = ChannelService.shared().listUserCatalog()
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
                item.add("api_key_set", JsonBool(!po.apiKey.getOrDefault({ => "" }).isEmpty()))
                item.add("status", JsonString(po.status))
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

    public func addChannel(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let po = mapToChannelPO(b)
                let resultOpt = svc.addChannel(po, currentOperator(req))
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

    public func editChannel(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let po = mapToChannelPO(b)
                let ok = svc.updateChannel(po, currentOperator(req))
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

    public func delChannel(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let code = optStr(b, "code")
                if (code.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
                    return
                }
                let ok = svc.deleteChannel(code, currentOperator(req))
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

    public func toggle(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let body = parseBody(req)
                let enabled = if (let Some(b) <- body) { optBool(b, "enabled") } else { true }
                let ok = svc.toggleChannel(code, enabled, currentOperator(req))
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

    public func setDefault(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let ok = svc.setDefault(code)
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

    public func test(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let (ok, detail) = svc.testChannel(code)
                let payload = HashMap<String, JsonValue>()
                payload.add("ok", JsonBool(ok))
                payload.add("detail", JsonString(detail))
                res.status(200).json(JsonObject(payload).toJsonString())
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func reload(req: HttpRequest, res: HttpResponse): Unit {
        try {
            ChannelService.shared().reloadRegistry()
            res.status(200).json("{\"desc\":\"ok\"}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func models(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            var statusFilter = ""
            let stOpt = req.queryParam("status")
            if (stOpt.isSome()) { statusFilter = stOpt.getOrThrow() }
            var channelFilter = ""
            let chOpt = req.queryParam("channel")
            if (chOpt.isSome()) { channelFilter = chOpt.getOrThrow() }

            let all = svc.listAllModels()
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
                        let ch = svc.getChannelByCode(channelFilter)
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

    public func syncModels(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let codeOpt = req.pathParam("code")
            if (let Some(code) <- codeOpt) {
                let (added, detail) = ChannelProbe.shared().syncModels(code)
                let payload = HashMap<String, JsonValue>()
                payload.add("added", JsonInt(added))
                payload.add("detail", JsonString(detail))
                payload.add("ok", JsonBool(detail == "ok" || added > 0))
                res.status(200).json(JsonObject(payload).toJsonString())
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少通道编码\"}")
            }
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

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

    public func health(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            let channels = svc.listChannels()
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

    public func audit(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let svc = ChannelService.shared()
            var limit: Int64 = 50
            let lpOpt = req.queryParam("limit")
            if (lpOpt.isSome()) { limit = Int64.parse(lpOpt.getOrThrow()) }
            if (limit <= 0) { limit = 50 }
            if (limit > 200) { limit = 200 }

            var code = ""
            let cOpt = req.queryParam("code")
            if (cOpt.isSome()) { code = cOpt.getOrThrow() }

            let list = svc.listAudits(code, limit)
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

    public func exportConfig(req: HttpRequest, res: HttpResponse): Unit {
        try {
            res.status(200).json(ChannelService.shared().exportConfig())
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

    public func importConfig(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"导入内容为空\"}")
                return
            }
            res.status(200).json(ChannelService.shared().importConfig(body))
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }

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

    private func mapToChannelPO(map: Map<String, Any>): LlmChannelPO {
        let po = LlmChannelPO()
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
        if (let Some(apiKey) <- map.get("api_key")) {
            let sOpt = apiKey as String
            if (let Some(s) <- sOpt) {
                if (!s.isEmpty() && s != "***") {
                    po.apiKey = Some<String>(SecretCrypto.encrypt(s))
                }
            }
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
