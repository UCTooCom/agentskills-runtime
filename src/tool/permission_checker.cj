/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.JsonValue

public class PermissionChecker {
    private let permissionProvider: PermissionProvider
    
    public init(permissionProvider: PermissionProvider) {
        this.permissionProvider = permissionProvider
    }
    
    public func checkPermission(
        userId: String,
        toolName: String,
        args: HashMap<String, JsonValue>
    ): PermissionResult {
        LogUtils.info("[PermissionChecker] Checking permission for user=${userId}, tool=${toolName}")
        
        let permissionOpt = ToolPermissionRegistry.getPermission(toolName)
        if (let Some(permission) <- permissionOpt) {
            LogUtils.info("[PermissionChecker] Tool permission found: ${permission.permissionPath}")
            
            if (hasPermission(userId, permission.permissionPath)) {
                LogUtils.info("[PermissionChecker] Permission granted")
                return PermissionResult(true, "Permission granted", permission.permissionPath)
            }
            
            LogUtils.info("[PermissionChecker] No matching permission found")
            return PermissionResult(false, "No permission for tool: ${toolName}", permission.permissionPath)
        }
        
        LogUtils.info("[PermissionChecker] Tool not registered in permission system: ${toolName}")
        return PermissionResult(false, "Tool not registered: ${toolName}", "")
    }
    
    public func isSensitiveOperation(
        toolName: String,
        args: HashMap<String, JsonValue>
    ): Bool {
        let sensitiveLevel = ToolPermissionRegistry.getSensitiveLevel(toolName)
        return sensitiveLevel >= 3
    }
    
    public func requiresConfirmation(toolName: String): Bool {
        ToolPermissionRegistry.requiresConfirmation(toolName)
    }
    
    public func getUserPermissions(userId: String): ArrayList<String> {
        let roleIds = permissionProvider.findRoleIdsByUserId(userId)
        if (roleIds.isEmpty()) {
            return ArrayList<String>()
        }
        permissionProvider.findPermissionNamesByRoleIds(roleIds)
    }
    
    public func hasPermission(userId: String, permissionPath: String): Bool {
        if (hasWildcardPermission(userId)) {
            return true
        }
        
        let roleIds = permissionProvider.findRoleIdsByUserId(userId)
        if (roleIds.isEmpty()) {
            return false
        }
        
        let permissions = permissionProvider.findPermissionNamesByRoleIds(roleIds)
        for (p in permissions) {
            if (matchPermission(p, permissionPath)) {
                return true
            }
        }
        
        return false
    }
    
    private func hasWildcardPermission(userId: String): Bool {
        let roleIds = permissionProvider.findRoleIdsByUserId(userId)
        if (roleIds.isEmpty()) {
            return false
        }
        
        let permissions = permissionProvider.findPermissionNamesByRoleIds(roleIds)
        for (p in permissions) {
            // 支持 * 和 /* 两种通配符
            if (p == "*" || p == "/*") {
                return true
            }
        }
        
        return false
    }
    
    private func matchPermission(permissionName: String, permissionPath: String): Bool {
        if (permissionName == permissionPath) {
            return true
        }
        
        // 支持 * 通配符，匹配所有权限
        if (permissionName == "*") {
            return true
        }
        
        // 支持 /* 通配符，匹配所有权限
        if (permissionName == "/*") {
            return true
        }
        
        // 支持 /api/v1/tools/* 等前缀通配符
        if (permissionName.endsWith("/*")) {
            let prefix = permissionName[0..(permissionName.size - 2)]
            if (permissionPath.startsWith(prefix)) {
                return true
            }
        }
        
        return false
    }
}
