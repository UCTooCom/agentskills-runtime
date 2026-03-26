/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.user_has_group

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.UserHasGroupPO
import magic.app.services.uctoo.UserHasGroupService
import magic.log.LogUtils
import std.collection.{HashMap, Map, ArrayList}
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * UserHasGroupController - 用户组关联控制器
 * 
 * 提供user_has_group表的HTTP接口，遵循UCTOO V4 API规范
 * 
 * 注意: 此表使用复合主键 (groupable_id, group_id)
 */
public class UserHasGroupController {
    private var service: UserHasGroupService
    
    public init(service: UserHasGroupService) {
        this.service = service
    }
    
    //#region AutoCreateCode
    
    /**
     * 添加用户到组
     * POST /api/v1/uctoo/user_has_group/add
     */
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let groupableIdOpt = b.get("groupable_id")
                let groupIdOpt = b.get("group_id")
                
                let groupableId = if (let Some(gid) <- groupableIdOpt) {
                    let gidStr = gid as String
                    if (let Some(s) <- gidStr) { s } else { "" }
                } else { "" }
                
                let groupId = if (let Some(gid) <- groupIdOpt) {
                    let gidStr = gid as String
                    if (let Some(s) <- gidStr) { s } else { "" }
                } else { "" }
                
                if (groupableId.isEmpty() || groupId.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"groupable_id和group_id不能为空\"}")
                    return
                }
                
                let groupableTypeOpt = b.get("groupable_type")
                let groupableType = if (let Some(gt) <- groupableTypeOpt) {
                    let gtStr = gt as String
                    if (let Some(s) <- gtStr) { Some<String>(s) } else { None<String> }
                } else { None<String> }
                
                let creatorOpt = b.get("creator")
                let creator = if (let Some(c) <- creatorOpt) {
                    let cStr = c as String
                    if (let Some(s) <- cStr) { Some<String>(s) } else { None<String> }
                } else { None<String> }
                
                let result = service.create(groupableId, groupId, groupableType, creator)
                if (let Some(data) <- result) {
                    res.status(200).json(data.toJson())
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"创建失败或已存在\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 删除用户组关联
     * POST /api/v1/uctoo/user_has_group/del
     */
    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let groupableIdOpt = b.get("groupable_id")
                let groupIdOpt = b.get("group_id")
                
                let groupableId = if (let Some(gid) <- groupableIdOpt) {
                    let gidStr = gid as String
                    if (let Some(s) <- gidStr) { s } else { "" }
                } else { "" }
                
                let groupId = if (let Some(gid) <- groupIdOpt) {
                    let gidStr = gid as String
                    if (let Some(s) <- gidStr) { s } else { "" }
                } else { "" }
                
                if (groupableId.isEmpty() || groupId.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"groupable_id和group_id不能为空\"}")
                    return
                }
                
                if (service.delete(groupableId, groupId)) {
                    res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"删除成功\"}")
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"删除失败\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"提交数据格式错误\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 查询单个用户组关联
     * GET /api/v1/uctoo/user_has_group/:groupableId/:groupId
     */
    public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let groupableId = req.pathParam("groupableId") ?? ""
            let groupId = req.pathParam("groupId") ?? ""
            
            if (groupableId.isEmpty() || groupId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"groupable_id和group_id不能为空\"}")
                return
            }
            
            let result = service.findById(groupableId, groupId)
            if (let Some(data) <- result) {
                res.status(200).json(data.toJson())
            } else {
                res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到记录\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 查询用户所属的所有组
     * GET /api/v1/uctoo/user_has_group/byGroupableId/:groupableId
     */
    public func getByGroupableId(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let groupableId = req.pathParam("groupableId") ?? ""
            
            if (groupableId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"groupable_id不能为空\"}")
                return
            }
            
            let list = service.findByGroupableId(groupableId)
            let sb = StringBuilder()
            sb.append("[")
            let size = list.size
            for (i in 0..size) {
                sb.append(list[i].toJson())
                if (i < size - 1) {
                    sb.append(",")
                }
            }
            sb.append("]")
            
            res.status(200).json(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 查询组内的所有成员
     * GET /api/v1/uctoo/user_has_group/byGroupId/:groupId
     */
    public func getByGroupId(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let groupId = req.pathParam("groupId") ?? ""
            
            if (groupId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"group_id不能为空\"}")
                return
            }
            
            let list = service.findByGroupId(groupId)
            let sb = StringBuilder()
            sb.append("[")
            let size = list.size
            for (i in 0..size) {
                sb.append(list[i].toJson())
                if (i < size - 1) {
                    sb.append(",")
                }
            }
            sb.append("]")
            
            res.status(200).json(sb.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    // ==================== 辅助方法 ====================
    
    private func parseBody(req: HttpRequest): Option<Map<String, Any>> {
        try {
            let body = req.body
            if (body.isEmpty()) {
                return None<Map<String, Any>>
            }
            
            let jsonValue = JsonValue.fromStr(body)
            if (jsonValue is JsonObject) {
                let obj = jsonValue.asObject()
                let map = HashMap<String, Any>()
                
                for ((key, value) in obj.getFields()) {
                    let anyValue = jsonValueToAny(value)
                    map.add(key, anyValue)
                }
                
                return Some<Map<String, Any>>(map)
            }
            
            None<Map<String, Any>>
        } catch (e: Exception) {
            None<Map<String, Any>>
        }
    }
    
    private func jsonValueToAny(jsonValue: JsonValue): Any {
        if (jsonValue is JsonString) {
            jsonValue.asString().getValue()
        } else if (jsonValue is JsonInt) {
            jsonValue.asInt().getValue()
        } else if (jsonValue is JsonFloat) {
            jsonValue.asFloat().getValue()
        } else if (jsonValue is JsonBool) {
            jsonValue.asBool().getValue()
        } else {
            ""
        }
    }
    
    //#endregion AutoCreateCode
}
