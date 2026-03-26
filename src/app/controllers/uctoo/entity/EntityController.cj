/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.entity

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.EntityPO
import magic.app.services.uctoo.EntityService
import magic.log.LogUtils
import std.collection.{HashMap, Map, ArrayList}
import std.convert
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}

public class EntityController {
    private var service: EntityService
    
    public init(service: EntityService) {
        this.service = service
    }
    
    //#region AutoCreateCode
    
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let entity = mapToEntity(b)
                let result = service.create(entity)
                if (result.success) {
                    if (let Some(data) <- result.data) {
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
                
                // 检查是否是恢复软删除数据 (deleted_at === "0")
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
                    // 批量编辑
                    let idsStrOpt = idsVal as String
                    if (let Some(idsStr) <- idsStrOpt) {
                        // 使用JSON.parse解析ids数组，与backend保持一致
                        let idArray = parseIdsArray(idsStr)
                        
                        if (isRestore) {
                            // 批量恢复软删除数据
                            let result = service.restoreMultiple(idArray)
                            if (result.success) {
                                res.status(200).json("{\"desc\":\"恢复成功\"}")
                            } else {
                                let reason = result.reason ?? "批量恢复失败"
                                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
                            }
                        } else {
                            let entities = ArrayList<EntityPO>()
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
                    // 单个编辑
                    if (let Some(idVal) <- id) {
                        let idStrOpt = idVal as String
                        if (let Some(idStr) <- idStrOpt) {
                            if (isRestore) {
                                // 恢复软删除数据
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
                                let result = service.update(idStr, entity)
                                if (result.success) {
                                    if (let Some(data) <- result.data) {
                                        res.status(200).json(data.toJson())
                                    } else {
                                        res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"更新失败\"}")
                                    }
                                } else {
                                    let reason = result.reason ?? "更新失败"
                                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
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
                    // 批量删除
                    let idsStrOpt = idsVal as String
                    if (let Some(idsStr) <- idsStrOpt) {
                        // 使用JSON.parse解析ids数组，与backend保持一致
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
                    // 单个删除
                    let idStrOpt = idVal as String
                    if (let Some(idStr) <- idStrOpt) {
                        let result = service.delete(idStr, force)
                        if (result.success) {
                            res.status(200).json("{\"desc\":\"删除成功\"}")
                        } else {
                            let reason = result.reason ?? "删除失败"
                            res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
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
            LogUtils.info("EntityController", "=== EntityController.getSingle() called ===")
            LogUtils.info("EntityController", "=== Request path: ${req.uri.path} ===")
            let id = req.pathParam("id")
            
            if (let Some(idVal) <- id) {
                LogUtils.info("EntityController", "=== Got id value: ${idVal} ===")
                let result = service.getById(idVal)
                let reasonStr = result.reason ?? "none"
                LogUtils.info("EntityController", "=== service.getById result - success: ${result.success}, reason: ${reasonStr} ===")
                
                if (result.success) {
                    if (let Some(data) <- result.data) {
                        LogUtils.info("EntityController", "=== Entity found, returning data ===")
                        // 与backend保持一致，直接返回实体对象，不包装在data中
                        res.status(200).json(data.toJson())
                    } else {
                        LogUtils.info("EntityController", "=== result.data is None ===")
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该entity或您没有权限访问\"}")
                    }
                } else {
                    LogUtils.info("EntityController", "=== result.success is false ===")
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该entity\"}")
                }
            } else {
                LogUtils.info("EntityController", "=== id pathParam is None ===")
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("EntityController", "=== EntityController.getSingle() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 按照 backend 规范：/api/uctoo/entity/:limit/:page
            // 页码从1开始，1表示第一页（符合业界最佳实践）
            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")
            
            let limitNum = if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }
            
            let pageNum = if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)  // 默认第一页
            }
            
            if (limitNum > 100) {
                res.status(400).json(APIError("40004", "请求数量不能超过100条").toJson())
                return
            }
            
            // 解析查询参数中的 sort 和 filter
            let sortParam = req.queryParam("sort")
            let filterParam = req.queryParam("filter")
            
            let sortStr = if (let Some(s) <- sortParam) { s } else { "" }
            let filterStr = if (let Some(f) <- filterParam) { f } else { "" }
            
            // 页码从1开始，转换为内部页码（从0开始）
            let (entities, total) = service.getList(pageNum - 1, limitNum, sortStr, filterStr)
            
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"entitys\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }
    
    public func getManyWithSkip(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 按照 backend 规范：/api/uctoo/entity/:limit/:page/:skip
            // 页码从1开始，1表示第一页（符合业界最佳实践）
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
                Int32(1)  // 默认第一页
            }
            
            let skipNum = if (let Some(s) <- skipParam) {
                Int32.parse(s)
            } else {
                Int32(0)
            }
            
            if (limitNum > 100) {
                res.status(400).json(APIError("40004", "请求数量不能超过100条").toJson())
                return
            }
            
            // 解析查询参数中的 sort 和 filter
            let sortParam = req.queryParam("sort")
            let filterParam = req.queryParam("filter")
            
            let sortStr = if (let Some(s) <- sortParam) { s } else { "" }
            let filterStr = if (let Some(f) <- filterParam) { f } else { "" }
            
            // 页码从1开始，转换为内部页码（从0开始）
            let (entities, total) = service.getListWithSkip(pageNum - 1, limitNum, skipNum, sortStr, filterStr)
            
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"entitys\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
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
    
    private func mapToEntity(map: Map<String, Any>): EntityPO {
        let entity = EntityPO()
                if (let Some(id) <- map.get("id")) {
            let idStr = id as String
            if (let Some(s) <- idStr) {
                entity.id = s
            }
        }
        if (let Some(link) <- map.get("link")) {
            let linkStr = link as String
            if (let Some(s) <- linkStr) {
                entity.link = s
            }
        }
        if (let Some(privacyLevel) <- map.get("privacy_level")) {
            let privacyLevelInt64 = privacyLevel as Int64
            if (let Some(s) <- privacyLevelInt64) {
                entity.privacyLevel = Some<Int32>(Int32(s))
            }
        }
        if (let Some(stars) <- map.get("stars")) {
            let starsFloat64 = stars as Float64
            if (let Some(s) <- starsFloat64) {
                entity.stars = Some<Float64>(s)
            }
        }
        if (let Some(description) <- map.get("description")) {
            let descriptionStr = description as String
            if (let Some(s) <- descriptionStr) {
                entity.description = Some<String>(s)
            }
        }
        if (let Some(groupId) <- map.get("group_id")) {
            let groupIdStr = groupId as String
            if (let Some(s) <- groupIdStr) {
                entity.groupId = Some<String>(s)
            }
        }
        if (let Some(picture) <- map.get("picture")) {
            let pictureStr = picture as String
            if (let Some(s) <- pictureStr) {
                entity.picture = Some<String>(s)
            }
        }
        if (let Some(images) <- map.get("images")) {
            let imagesStr = images as String
            if (let Some(s) <- imagesStr) {
                entity.images = Some<String>(s)
            }
        }
        if (let Some(content) <- map.get("content")) {
            let contentStr = content as String
            if (let Some(s) <- contentStr) {
                entity.content = Some<String>(s)
            }
        }
        if (let Some(json) <- map.get("json")) {
            let jsonStr = json as String
            if (let Some(s) <- jsonStr) {
                entity.json = Some<String>(s)
            }
        }
        if (let Some(city) <- map.get("city")) {
            let cityStr = city as String
            if (let Some(s) <- cityStr) {
                entity.city = Some<String>(s)
            }
        }
        if (let Some(price) <- map.get("price")) {
            let priceFloat64 = price as Float64
            if (let Some(s) <- priceFloat64) {
                entity.price = Some<Float64>(s)
            }
        }
        // birthday is DateTime type, handled by database
        if (let Some(owner) <- map.get("owner")) {
            let ownerStr = owner as String
            if (let Some(s) <- ownerStr) {
                entity.owner = Some<String>(s)
            }
        }
        if (let Some(creator) <- map.get("creator")) {
            let creatorStr = creator as String
            if (let Some(s) <- creatorStr) {
                entity.creator = s
            }
        }
        // createdAt is DateTime type, handled by database
        // updatedAt is DateTime type, handled by database
        // deletedAt is DateTime type, handled by database
        // endTime is DateTime type, handled by database
        // startTime is DateTime type, handled by database
        if (let Some(status) <- map.get("status")) {
            let statusStr = status as String
            if (let Some(s) <- statusStr) {
                entity.status = Some<String>(s)
            }
        }
        return entity
    }
    
    private func parseForce(forceOpt: ?Any): Bool {
        if (let Some(f) <- forceOpt) {
            // 支持数字1或字符串"true"作为硬删除标志，与backend保持一致
            // 先尝试转换为Int64（因为jsonValueToAny返回Int64）
            let fInt64 = f as Int64
            if (let Some(v) <- fInt64) {
                v == 1
            } else {
                // 再尝试Int32
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
    
    /**
     * 解析JSON格式的ids数组
     * 支持格式: "[\"uuid1\",\"uuid2\"]" 或 "[\"uuid1\", \"uuid2\"]"
     */
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
            // 如果JSON解析失败，尝试逗号分隔格式
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
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
