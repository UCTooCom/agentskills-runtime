/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.permissions

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.app.core.response.{APIError, APIResult}
import magic.app.core.router.Router
import magic.app.models.uctoo.PermissionsPO
import magic.app.services.uctoo.PermissionsService
import magic.log.LogUtils
import std.collection.{HashMap, Map, ArrayList}
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


public class PermissionsController {
    private var service: PermissionsService
    private var router: ?Router = None<Router>

    public init(service: PermissionsService) {
        this.service = service
    }

    public func setRouter(router: Router): Unit {
        this.router = Some<Router>(router)
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
            LogUtils.info("PermissionsController", "=== PermissionsController.getSingle() called ===")
            LogUtils.info("PermissionsController", "=== Request path: ${req.uri.path} ===")
            let id = req.pathParam("id")
            
            if (let Some(idVal) <- id) {
                LogUtils.info("PermissionsController", "=== Got id value: ${idVal} ===")
                let result = service.getById(idVal)
                let reasonStr = result.reason ?? "none"
                LogUtils.info("PermissionsController", "=== service.getById result - success: ${result.success}, reason: ${reasonStr} ===")
                
                if (result.success) {
                    if (let Some(data) <- result.data) {
                        LogUtils.info("PermissionsController", "=== Permissions found, returning data ===")
                        // 与backend保持一致，直接返回实体对象，不包装在data中
                        res.status(200).json(data.toJson())
                    } else {
                        LogUtils.info("PermissionsController", "=== result.data is None ===")
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该permissions或您没有权限访问\"}")
                    }
                } else {
                    LogUtils.info("PermissionsController", "=== result.success is false ===")
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到该permissions\"}")
                }
            } else {
                LogUtils.info("PermissionsController", "=== id pathParam is None ===")
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少ID参数\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== PermissionsController.getSingle() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 按照 backend 规范：/api/uctoo/permissions/:limit/:page
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"permissionss\":[${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json(APIError("50000", e.message).toJson())
        }
    }
    
    public func getManyWithSkip(req: HttpRequest, res: HttpResponse): Unit {
        try {
            // 按照 backend 规范：/api/uctoo/permissions/:limit/:page/:skip
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
            res.status(200).json("{\"currentPage\":${pageNum},\"totalCount\":${total},\"totalPage\":${totalPage},\"skip\":${skipNum},\"permissionss\":[${entitiesJson}]}")
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
        if (let Some(typeValue) <- map.get("type")) {
            let typeValueInt64 = typeValue as Int64
            if (let Some(s) <- typeValueInt64) {
                entity.permissionType = Some<Int32>(Int32(s))
            }
        }
        if (let Some(hidden) <- map.get("hidden")) {
            let hiddenInt64 = hidden as Int64
            if (let Some(s) <- hiddenInt64) {
                entity.hidden = Some<Int32>(Int32(s))
            }
        }
        if (let Some(weight) <- map.get("weight")) {
            let weightInt64 = weight as Int64
            if (let Some(s) <- weightInt64) {
                entity.weight = Some<Int32>(Int32(s))
            }
        }
        if (let Some(creator) <- map.get("creator")) {
            let creatorStr = creator as String
            if (let Some(s) <- creatorStr) {
                entity.creator = Some<String>(s)
            }
        }
        // createdAt is DateTime type, handled by database
        // updatedAt is DateTime type, handled by database
        // deletedAt is DateTime type, handled by database
        if (let Some(keepalive) <- map.get("keepalive")) {
            let keepaliveInt64 = keepalive as Int64
            if (let Some(s) <- keepaliveInt64) {
                entity.keepalive = Some<Int32>(Int32(s))
            }
        }
        if (let Some(path) <- map.get("path")) {
            let pathStr = path as String
            if (let Some(s) <- pathStr) {
                entity.path = s
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
    
    /**
     * 从应用中加载路由到permissions表
     * 参考 backend 的 refreshRoutes 方法实现
     * 
     * 实现逻辑：
     * 1. 查询或创建API父菜单
     * 2. 从应用路由中获取所有路由
     * 3. 将路由转换为权限节点
     * 4. 批量插入到permissions表（跳过重复）
     */
    public func loadRouteFromApp(req: HttpRequest, res: HttpResponse): Unit {
        try {
            LogUtils.info("PermissionsController", "=== loadRouteFromApp() called ===")
            
            // 1. 查询或创建API父菜单
            let apiParentMenu = getOrCreateAPIParentMenu()
            
            // 2. 从应用路由中获取所有路由
            let appRoutes = collectAppRoutes(apiParentMenu.id)
            
            // 3. 批量插入到permissions表（跳过重复）
            let insertedCount = insertRoutesToPermissions(appRoutes)
            
            // 4. 返回结果
            let resultJson = buildRoutesJson(appRoutes)
            res.status(200).json(resultJson)
            
            LogUtils.info("PermissionsController", "=== loadRouteFromApp() completed, inserted ${insertedCount} routes ===")
        } catch (e: Exception) {
            LogUtils.error("PermissionsController", "=== loadRouteFromApp() exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
    
    /**
     * 获取或创建API父菜单
     */
    private func getOrCreateAPIParentMenu(): PermissionsPO {
        // 查询API父菜单
        let existingMenu = service.findByPermissionName("API")
        
        if (let Some(menu) <- existingMenu) {
            return menu
        }
        
        // 没有API父级菜单，创建一个
        let apiMenu = PermissionsPO()
        apiMenu.permissionName = "API"
        apiMenu.permissionType = Some<Int32>(1)  // 菜单类型
        apiMenu.level = Some<String>("0")
        apiMenu.component = Some<String>("BasicLayout")
        apiMenu.redirect = Some<String>("/API")
        apiMenu.path = "/API"
        apiMenu.meta = Some<String>("{\"icon\":\"mdi:database-sync\",\"order\":9999,\"title\":\"page.dashboard.API\",\"keepAlive\":true}")
        
        let result = service.create(apiMenu)
        if (result.success) {
            if (let Some(data) <- result.data) {
                return data
            }
        }
        
        // 如果创建失败，返回一个默认的
        throw Exception("Failed to create API parent menu")
    }
    
    /**
     * 收集应用路由
     */
    private func collectAppRoutes(parentId: String): ArrayList<PermissionsPO> {
        let routes = ArrayList<PermissionsPO>()

        // 添加全部权限节点
        let allPermission = PermissionsPO()
        allPermission.permissionName = "/*"
        allPermission.permissionType = Some<Int32>(3)  // API权限类型
        allPermission.method = Some<String>("ANY")
        allPermission.path = "/*"
        allPermission.parentId = Some<String>(parentId)
        routes.add(allPermission)

        // 从Router实例获取所有路由
        if (let Some(r) <- router) {
            let appRoutes = r.getRoutes()
            LogUtils.info("PermissionsController", "=== Found ${appRoutes.size} routes in router ===")

            for (route in appRoutes) {
                // 跳过非API路由
                if (!route.path.startsWith("/api")) {
                    continue
                }

                // 跳过公开路由(如登录、注册等)
                if (isPublicRoute(route.path)) {
                    continue
                }

                // 创建权限节点
                let permission = PermissionsPO()
                permission.permissionName = route.path
                permission.permissionType = Some<Int32>(3)  // API权限类型
                permission.method = Some<String>(httpMethodToString(route.method))
                permission.path = route.path
                permission.parentId = Some<String>(parentId)

                routes.add(permission)
                LogUtils.info("PermissionsController", "=== Added route: ${route.path} (${httpMethodToString(route.method)}) ===")
            }
        } else {
            LogUtils.info("PermissionsController", "=== Router instance not set, cannot collect routes ===")
        }

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
     * 批量插入路由到permissions表
     */
    private func insertRoutesToPermissions(routes: ArrayList<PermissionsPO>): Int64 {
        var count: Int64 = 0
        
        for (route in routes) {
            // 检查是否已存在
            let existing = service.findByPermissionName(route.permissionName)
            
            if (existing.isNone()) {
                // 不存在，创建新的权限节点
                let result = service.create(route)
                if (result.success) {
                    count++
                }
            }
        }
        
        return count
    }
    
    /**
     * 构建路由JSON响应
     */
    private func buildRoutesJson(routes: ArrayList<PermissionsPO>): String {
        let sb = StringBuilder()
        sb.append("[")

        let size = routes.size
        for (i in 0..size) {
            let route = routes[i]
            let method = if (let Some(m) <- route.method) { m } else { "GET" }
            let permType = if (let Some(t) <- route.permissionType) { t } else { Int32(3) }
            let parentId = if (let Some(p) <- route.parentId) { p } else { "" }

            sb.append("{\"name\":\"${route.permissionName}\",")
            sb.append("\"method\":\"${method}\",")
            sb.append("\"path\":\"${route.path}\",")
            sb.append("\"type\":${permType},")
            sb.append("\"parent_id\":\"${parentId}\"}")

            if (i < size - 1) {
                sb.append(",")
            }
        }

        sb.append("]")
        return sb.toString()
    }
}
