/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.middlewares.auth

import magic.app.core.http.{HttpRequest, HttpResponse, HttpMethod}
import magic.app.core.middleware.Middleware
import magic.app.services.uctoo.{PermissionsService, UserHasRolesService, RoleHasPermissionService}
import magic.log.LogUtils
import std.collection.ArrayList

/**
 * RequirePermissionMiddleware - V4标准RBAC权限检查中间件
 *
 * 实现标准RBAC权限检查: 用户 → 角色 → 权限
 * 使用 user_has_roles 和 role_has_permission 表
 */
public class RequirePermissionMiddleware <: Middleware {
    private let permissionsService: PermissionsService
    private let userHasRolesService: UserHasRolesService
    private let roleHasPermissionService: RoleHasPermissionService

    public init(
        permissionsService: PermissionsService,
        userHasRolesService: UserHasRolesService,
        roleHasPermissionService: RoleHasPermissionService
    ) {
        this.permissionsService = permissionsService
        this.userHasRolesService = userHasRolesService
        this.roleHasPermissionService = roleHasPermissionService
    }

    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        LogUtils.info("RequirePermissionMiddleware", "=== handle() called ===")

        try {
            // 0. 检查是否是公开路由(不需要权限)
            let routePattern = getRoutePattern(req)
            if (isPublicRoute(routePattern)) {
                LogUtils.info("RequirePermissionMiddleware", "=== Public route, skipping permission check ===")
                next()
                return
            }

            // 1. 获取用户ID
            LogUtils.info("RequirePermissionMiddleware", "=== Getting userId from locals ===")
            let userId = req.getLocals("userId")
            LogUtils.info("RequirePermissionMiddleware", "=== userId obtained ===")

            // 使用if-let处理Option
            if (let Some(uid) <- userId) {
                LogUtils.info("RequirePermissionMiddleware", "=== User found in locals ===")
                let uidStr = uid as String
                if (let Some(userIdStr) <- uidStr) {
                    // 2. 获取当前路由路径
                    let httpMethod = httpMethodToString(req.method)

                    LogUtils.info("RequirePermissionMiddleware", "=== Checking permission for user=${userIdStr}, route=${routePattern}, method=${httpMethod} ===")

                    // 3. 检查权限
                    if (checkPermission(userIdStr, routePattern, httpMethod)) {
                        LogUtils.info("RequirePermissionMiddleware", "=== Permission granted ===")
                        next()
                    } else {
                        LogUtils.info("RequirePermissionMiddleware", "=== Permission denied ===")
                        res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"no permission\"}")
                    }
                } else {
                    LogUtils.info("RequirePermissionMiddleware", "=== Invalid user info format ===")
                    res.status(403).json("{\"errno\":\"40302\",\"errmsg\":\"invalid user info\"}")
                }
            } else {
                LogUtils.info("RequirePermissionMiddleware", "=== User not authenticated (None) ===")
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"not login\"}")
                LogUtils.info("RequirePermissionMiddleware", "=== Response set, returning ===")
            }
        } catch (e: Exception) {
            LogUtils.info("RequirePermissionMiddleware", "=== Exception: ${e.message} ===")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"internal error: ${e.message}\"}")
        }
    }

    /**
     * 检查是否是公开路由
     */
    private func isPublicRoute(route: String): Bool {
        // 登录相关路由
        if (route.contains("/login") || route.contains("/logout")) {
            return true
        }
        // 用户认证相关路由(signin, signup)
        if (route.contains("/signin") || route.contains("/signup")) {
            return true
        }
        // 公开API
        if (route.contains("/public/")) {
            return true
        }
        // 健康检查
        if (route == "/health" || route == "/") {
            return true
        }
        false
    }

    // ==================== 辅助方法 ====================

    /**
     * 获取路由模式
     */
    private func getRoutePattern(req: HttpRequest): String {
        // 从请求中获取路由模式
        req.uri.path
    }

    /**
     * HttpMethod 转字符串
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
     * 检查权限 - V4标准RBAC实现
     */
    private func checkPermission(userId: String, routePattern: String, httpMethod: String): Bool {
        // 1. 查询用户所属角色 (使用 user_has_roles 表)
        let userRoles = userHasRolesService.findByUserId(userId)
        if (userRoles.isEmpty()) {
            LogUtils.info("RequirePermissionMiddleware", "=== User has no roles ===")
            return false
        }

        // 2. 收集角色ID
        let roleIds = ArrayList<String>()
        for (ur in userRoles) {
            roleIds.add(ur.roleId)
        }

        LogUtils.info("RequirePermissionMiddleware", "=== User has ${roleIds.size} roles ===")

        // 3. 检查是否有全部权限（/*）
        if (hasWildcardPermission(roleIds)) {
            LogUtils.info("RequirePermissionMiddleware", "=== User has wildcard permission (/*) ===")
            return true
        }

        // 4. 检查是否有特定路由权限
        if (hasRoutePermission(roleIds, routePattern, httpMethod)) {
            return true
        }

        false
    }

    /**
     * 检查是否有通配符权限
     * 
     * 支持所有类型的通配符权限:
     * -  : 全局通配符,拥有所有权限(超级管理员)
     * -  : API通配符,拥有所有API权限(type=3)
     * - menu: : 菜单通配符,拥有所有菜单权限(type=1)
     * - button: : 按钮通配符,拥有所有按钮权限(type=2)
     * - tool: : 工具通配符,拥有所有工具权限(type=4)
     * 
     * 对于API权限中间件,主要检查 全局通配符 和  API通配符
     * 但为了兼容性和灵活性,也支持其他类型通配符
     */
    private func hasWildcardPermission(roleIds: ArrayList<String>): Bool {
        // 查询角色是否有通配符权限 (使用 role_has_permission 表)
        let permissions = roleHasPermissionService.findByRoleIds(roleIds)
        for (p in permissions) {
            let permName = p.permissionName
            
            // 检查全局通配符 - 最高优先级,拥有所有权限
            if (permName == "*") {
                LogUtils.info("RequirePermissionMiddleware", "=== Found global wildcard permission: * ===")
                return true
            }
            
            // 检查API通配符 - 拥有所有API权限
            if (permName == "/*") {
                LogUtils.info("RequirePermissionMiddleware", "=== Found API wildcard permission: /* ===")
                return true
            }
            
            // 检查菜单通配符 - 虽然API中间件主要检查API权限,但菜单通配符也可能隐含API访问权限
            if (permName == "menu:*") {
                LogUtils.info("RequirePermissionMiddleware", "=== Found menu wildcard permission: menu:* ===")
                return true
            }
            
            // 检查按钮通配符 - 按钮操作通常对应API调用
            if (permName == "button:*") {
                LogUtils.info("RequirePermissionMiddleware", "=== Found button wildcard permission: button:* ===")
                return true
            }
            
            // 检查工具通配符 - 工具可能需要调用API
            if (permName == "tool:*") {
                LogUtils.info("RequirePermissionMiddleware", "=== Found tool wildcard permission: tool:* ===")
                return true
            }
        }
        false
    }

    /**
     * 检查是否有路由权限
     */
    private func hasRoutePermission(roleIds: ArrayList<String>, routePattern: String, httpMethod: String): Bool {
        // 检查角色是否有此权限 (使用 role_has_permission 表)
        let permissions = roleHasPermissionService.findByRoleIds(roleIds)
        for (rp in permissions) {
            let permName = rp.permissionName
            
            // 精确匹配
            if (permName == routePattern) {
                return true
            }

            // 路由参数匹配
            if (matchRoutePattern(permName, routePattern)) {
                return true
            }
            
            // 三段式权限名称匹配
            if (matchThreePartPermission(permName, routePattern)) {
                return true
            }
            
            // 通配符匹配
            if (matchWildcardPermission(permName, routePattern)) {
                return true
            }
        }
        false
    }
    
    /**
     * 三段式权限名称匹配
     * 支持 uctoo:module:action 格式的权限名称
     */
    private func matchThreePartPermission(permName: String, routePattern: String): Bool {
        // 检查是否是三段式权限名称
        if (permName.contains(":")) {
            let parts = permName.split(":")
            if (parts.size == 3) {
                let module = parts[1]
                let action = parts[2]
                
                // 检查路由是否包含模块名
                if (routePattern.contains("/" + module + "/")) {
                    // 检查是否是对应操作
                    if (routePattern.contains("/" + action) || action == "*") {
                        return true
                    }
                }
            }
        }
        false
    }
    
    /**
     * 通配符权限匹配
     * 支持 uctoo:* 和 uctoo:i18:* 格式的通配符
     */
    private func matchWildcardPermission(permName: String, routePattern: String): Bool {
        // 检查是否是通配符权限
        if (permName.endsWith("*")) {
            let prefix = permName[0..(permName.size - 1)]
            // 检查路由是否以通配符前缀开头
            if (routePattern.startsWith(prefix) || routePattern.contains(prefix)) {
                return true
            }
        }
        false
    }

    /**
     * 路由模式匹配
     * 支持路由参数匹配(如 :id, :limit, :page等)
     */
    private func matchRoutePattern(permissionPath: String, requestPath: String): Bool {
        let permissionParts = permissionPath.split("/")
        let requestParts = requestPath.split("/")

        if (permissionParts.size != requestParts.size) {
            return false
        }

        for (i in 0..permissionParts.size) {
            let permPart = permissionParts[i]
            let reqPart = requestParts[i]

            // 如果是路由参数(以:开头),则匹配任意值
            if (permPart.startsWith(":")) {
                continue
            }

            // 否则必须精确匹配
            if (permPart != reqPart) {
                return false
            }
        }

        return true
    }
}
