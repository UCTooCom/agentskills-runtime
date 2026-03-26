/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.app.services.uctoo.{UserHasRolesService, RoleHasPermissionService}
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.JsonValue

/**
 * PermissionChecker - 工具权限检查器
 * 
 * 负责检查用户是否有权限调用指定工具
 * 直接依赖 UserHasRolesService 和 RoleHasPermissionService
 */
public class PermissionChecker {
    private let userHasRolesService: UserHasRolesService
    private let roleHasPermissionService: RoleHasPermissionService
    
    public init(
        userHasRolesService: UserHasRolesService,
        roleHasPermissionService: RoleHasPermissionService
    ) {
        this.userHasRolesService = userHasRolesService
        this.roleHasPermissionService = roleHasPermissionService
    }
    
    /**
     * 检查工具调用权限
     * 
     * @param userId 用户ID
     * @param toolName 工具名称
     * @param args 工具参数
     * @return 权限检查结果
     */
    public func checkPermission(
        userId: String,
        toolName: String,
        args: HashMap<String, JsonValue>
    ): PermissionResult {
        LogUtils.info("[PermissionChecker] Checking permission for user=${userId}, tool=${toolName}")
        
        // 1. 获取工具权限定义
        let permissionOpt = ToolPermissionRegistry.getPermission(toolName)
        if (let Some(permission) <- permissionOpt) {
            LogUtils.info("[PermissionChecker] Tool permission found: ${permission.permissionPath}")
            
            // 2. 直接使用权限服务检查权限
            if (hasPermission(userId, permission.permissionPath)) {
                LogUtils.info("[PermissionChecker] Permission granted")
                return PermissionResult(true, "Permission granted", permission.permissionPath)
            }
            
            LogUtils.info("[PermissionChecker] No matching permission found")
            return PermissionResult(false, "No permission for tool: ${toolName}", permission.permissionPath)
        }
        
        // 工具未注册权限，默认拒绝
        LogUtils.info("[PermissionChecker] Tool not registered in permission system: ${toolName}")
        return PermissionResult(false, "Tool not registered: ${toolName}", "")
    }
    
    /**
     * 检查是否是敏感操作
     * 
     * @param toolName 工具名称
     * @param args 工具参数
     * @return 是否是敏感操作
     */
    public func isSensitiveOperation(
        toolName: String,
        args: HashMap<String, JsonValue>
    ): Bool {
        let sensitiveLevel = ToolPermissionRegistry.getSensitiveLevel(toolName)
        return sensitiveLevel >= 3  // 高敏感级别
    }
    
    /**
     * 检查是否需要二次确认
     * 
     * @param toolName 工具名称
     * @return 是否需要确认
     */
    public func requiresConfirmation(toolName: String): Bool {
        ToolPermissionRegistry.requiresConfirmation(toolName)
    }
    
    /**
     * 获取用户的所有权限
     * 
     * @param userId 用户ID
     * @return 权限列表
     */
    public func getUserPermissions(userId: String): ArrayList<String> {
        let result = ArrayList<String>()
        
        // 获取用户角色
        let userRoles = userHasRolesService.findByUserId(userId)
        if (userRoles.isEmpty()) {
            return result
        }
        
        // 收集角色ID
        let roleIds = ArrayList<String>()
        for (ur in userRoles) {
            roleIds.add(ur.roleId)
        }
        
        // 获取每个角色的权限
        let permissions = roleHasPermissionService.findByRoleIds(roleIds)
        for (p in permissions) {
            result.add(p.permissionName)
        }
        
        return result
    }
    
    /**
     * 检查用户是否有特定权限
     * 
     * @param userId 用户ID
     * @param permissionPath 权限路径
     * @return 是否有权限
     */
    public func hasPermission(userId: String, permissionPath: String): Bool {
        // 1. 检查通配符权限
        if (hasWildcardPermission(userId)) {
            return true
        }
        
        // 2. 获取用户角色
        let userRoles = userHasRolesService.findByUserId(userId)
        if (userRoles.isEmpty()) {
            return false
        }
        
        // 3. 收集角色ID
        let roleIds = ArrayList<String>()
        for (ur in userRoles) {
            roleIds.add(ur.roleId)
        }
        
        // 4. 检查角色权限
        let permissions = roleHasPermissionService.findByRoleIds(roleIds)
        for (p in permissions) {
            if (matchPermission(p.permissionName, permissionPath)) {
                return true
            }
        }
        
        return false
    }
    
    /**
     * 检查用户是否有通配符权限
     * 
     * @param userId 用户ID
     * @return 是否有通配符权限
     */
    private func hasWildcardPermission(userId: String): Bool {
        let userRoles = userHasRolesService.findByUserId(userId)
        if (userRoles.isEmpty()) {
            return false
        }
        
        let roleIds = ArrayList<String>()
        for (ur in userRoles) {
            roleIds.add(ur.roleId)
        }
        
        let permissions = roleHasPermissionService.findByRoleIds(roleIds)
        for (p in permissions) {
            if (p.permissionName == "/*") {
                return true
            }
        }
        
        return false
    }
    
    /**
     * 权限匹配逻辑
     * 
     * @param permissionName 权限名称
     * @param permissionPath 权限路径
     * @return 是否匹配
     */
    private func matchPermission(permissionName: String, permissionPath: String): Bool {
        // 完全匹配
        if (permissionName == permissionPath) {
            return true
        }
        
        // 通配符匹配
        if (permissionName == "/*") {
            return true
        }
        
        // 前缀匹配 (例如: /tool/* 匹配 /tool/execute)
        if (permissionName.endsWith("/*")) {
            let prefix = permissionName[0..(permissionName.size - 2)]
            if (permissionPath.startsWith(prefix)) {
                return true
            }
        }
        
        return false
    }
}
