/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.role_has_permission

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.uctoo.RoleHasPermissionPO
import magic.app.services.uctoo.RoleHasPermissionService
import magic.log.LogUtils
import std.collection.{HashMap, Map, ArrayList}
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * RoleHasPermissionController - 角色权限关联控制器
 * 
 * 提供role_has_permission表的HTTP接口，遵循UCTOO V4 API规范
 * 
 * 注意: 此表使用复合主键 (role_id, permission_name)
 */
public class RoleHasPermissionController {
    private var service: RoleHasPermissionService
    
    public init(service: RoleHasPermissionService) {
        this.service = service
    }
    
    //#region AutoCreateCode
    
    /**
     * 添加权限到角色
     * POST /api/v1/uctoo/role_has_permission/add
     */
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let roleIdOpt = b.get("role_id")
                let permissionNameOpt = b.get("permission_name")
                
                let roleId = if (let Some(rid) <- roleIdOpt) {
                    let ridStr = rid as String
                    if (let Some(s) <- ridStr) { s } else { "" }
                } else { "" }
                
                let permissionName = if (let Some(pn) <- permissionNameOpt) {
                    let pnStr = pn as String
                    if (let Some(s) <- pnStr) { s } else { "" }
                } else { "" }
                
                if (roleId.isEmpty() || permissionName.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"role_id和permission_name不能为空\"}")
                    return
                }
                
                let creatorOpt = b.get("creator")
                let creator = if (let Some(c) <- creatorOpt) {
                    let cStr = c as String
                    if (let Some(s) <- cStr) { Some<String>(s) } else { None<String> }
                } else { None<String> }
                
                let result = service.create(roleId, permissionName, creator)
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
     * 删除角色权限关联
     * POST /api/v1/uctoo/role_has_permission/del
     */
    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let roleIdOpt = b.get("role_id")
                let permissionNameOpt = b.get("permission_name")
                
                let roleId = if (let Some(rid) <- roleIdOpt) {
                    let ridStr = rid as String
                    if (let Some(s) <- ridStr) { s } else { "" }
                } else { "" }
                
                let permissionName = if (let Some(pn) <- permissionNameOpt) {
                    let pnStr = pn as String
                    if (let Some(s) <- pnStr) { s } else { "" }
                } else { "" }
                
                if (roleId.isEmpty() || permissionName.isEmpty()) {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"role_id和permission_name不能为空\"}")
                    return
                }
                
                if (service.delete(roleId, permissionName)) {
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
     * 查询单个角色权限关联
     * GET /api/v1/uctoo/role_has_permission/:roleId/:permissionName
     */
    public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let roleId = req.pathParam("roleId") ?? ""
            let permissionName = req.pathParam("permissionName") ?? ""
            
            if (roleId.isEmpty() || permissionName.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"role_id和permission_name不能为空\"}")
                return
            }
            
            let result = service.findById(roleId, permissionName)
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
     * 查询角色拥有的所有权限
     * GET /api/v1/uctoo/role_has_permission/byRoleId/:roleId
     */
    public func getByRoleId(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let roleId = req.pathParam("roleId") ?? ""
            
            if (roleId.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"role_id不能为空\"}")
                return
            }
            
            let list = service.findByRoleId(roleId)
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
     * 查询使用某权限的所有角色
     * GET /api/v1/uctoo/role_has_permission/byPermissionName/:permissionName
     */
    public func getByPermissionName(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let permissionName = req.pathParam("permissionName") ?? ""
            
            if (permissionName.isEmpty()) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"permission_name不能为空\"}")
                return
            }
            
            let list = service.findByPermissionName(permissionName)
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
