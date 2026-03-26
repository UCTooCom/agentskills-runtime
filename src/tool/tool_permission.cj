/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import std.collection.HashMap

/**
 * ToolPermission - 工具权限定义
 * 
 * 定义每个工具的权限要求、敏感级别和审计配置
 */
public class ToolPermission {
    public let toolName: String              // 工具名称
    public let permissionPath: String        // 权限路径
    public let sensitiveLevel: Int           // 敏感级别: 1=低, 2=中, 3=高
    public let requiresConfirmation: Bool    // 是否需要二次确认
    public let auditEnabled: Bool            // 是否启用审计日志
    
    public init(
        toolName: String,
        permissionPath: String,
        sensitiveLevel: Int,
        requiresConfirmation: Bool,
        auditEnabled: Bool
    ) {
        this.toolName = toolName
        this.permissionPath = permissionPath
        this.sensitiveLevel = sensitiveLevel
        this.requiresConfirmation = requiresConfirmation
        this.auditEnabled = auditEnabled
    }
    
    /**
     * 创建工具权限（使用默认值）
     * requiresConfirmation: false
     * auditEnabled: true
     */
    public static func create(
        toolName: String,
        permissionPath: String,
        sensitiveLevel: Int
    ): ToolPermission {
        ToolPermission(
            toolName,
            permissionPath,
            sensitiveLevel,
            false,
            true
        )
    }
}

/**
 * PermissionResult - 权限检查结果
 */
public struct PermissionResult {
    public let allowed: Bool              // 是否允许
    public let reason: String             // 原因说明
    public let requiredPermission: String // 需要的权限
    
    public init(allowed: Bool, reason: String, requiredPermission: String) {
        this.allowed = allowed
        this.reason = reason
        this.requiredPermission = requiredPermission
    }
}

/**
 * ToolPermissionRegistry - 工具权限注册表
 * 
 * 管理所有工具的权限定义
 */
public class ToolPermissionRegistry {
    // 工具权限映射表
    private static let _permissions = HashMap<String, ToolPermission>([
        // ==================== 文件系统工具组 (fs) ====================
        ("file_read", ToolPermission(
            "file_read", 
            "/api/v1/tools/fs/read", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("file_write", ToolPermission(
            "file_write", 
            "/api/v1/tools/fs/write", 
            2,  // 中敏感级别
            false, 
            true
        )),
        ("file_edit", ToolPermission(
            "file_edit", 
            "/api/v1/tools/fs/edit", 
            2,  // 中敏感级别
            false, 
            true
        )),
        ("file_delete", ToolPermission(
            "file_delete", 
            "/api/v1/tools/fs/delete", 
            3,  // 高敏感级别
            true,  // 需要二次确认
            true
        )),
        ("file_copy", ToolPermission(
            "file_copy", 
            "/api/v1/tools/fs/copy", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("file_move", ToolPermission(
            "file_move", 
            "/api/v1/tools/fs/move", 
            2,  // 中敏感级别
            false, 
            true
        )),
        ("file_search", ToolPermission(
            "file_search", 
            "/api/v1/tools/fs/search", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("directory_list", ToolPermission(
            "directory_list", 
            "/api/v1/tools/fs/list", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("directory_create", ToolPermission(
            "directory_create", 
            "/api/v1/tools/fs/create", 
            2,  // 中敏感级别
            false, 
            true
        )),
        
        // ==================== 网络工具组 (web) ====================
        ("http_request", ToolPermission(
            "http_request", 
            "/api/v1/tools/web/http", 
            2,  // 中敏感级别
            false, 
            true
        )),
        ("web_fetch", ToolPermission(
            "web_fetch", 
            "/api/v1/tools/web/fetch", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("firecrawl", ToolPermission(
            "firecrawl", 
            "/api/v1/tools/web/firecrawl", 
            2,  // 中敏感级别
            false, 
            true
        )),
        
        // ==================== 技能工具组 (skill) ====================
        ("skill_search", ToolPermission(
            "skill_search", 
            "/api/v1/tools/skill/search", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("skill_install", ToolPermission(
            "skill_install", 
            "/api/v1/tools/skill/install", 
            3,  // 高敏感级别
            true,  // 需要二次确认
            true
        )),
        ("skill_validate", ToolPermission(
            "skill_validate", 
            "/api/v1/tools/skill/validate", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("skill_initializer", ToolPermission(
            "skill_initializer", 
            "/api/v1/tools/skill/init", 
            2,  // 中敏感级别
            false, 
            true
        )),
        ("skill_packager", ToolPermission(
            "skill_packager", 
            "/api/v1/tools/skill/package", 
            2,  // 中敏感级别
            false, 
            true
        )),
        
        // ==================== 代码生成工具组 (code) ====================
        ("template_engine", ToolPermission(
            "template_engine", 
            "/api/v1/tools/code/template", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("code_snippet_generator", ToolPermission(
            "code_snippet_generator", 
            "/api/v1/tools/code/generate", 
            1,  // 低敏感级别
            false, 
            true
        )),
        
        // ==================== CLI工具组 (cli) ====================
        ("cli_execute", ToolPermission(
            "cli_execute", 
            "/api/v1/tools/cli/execute", 
            3,  // 高敏感级别
            true,  // 需要二次确认
            true
        )),
        
        // ==================== 其他工具 ====================
        ("browser_open", ToolPermission(
            "browser_open", 
            "/api/v1/tools/browser/open", 
            1,  // 低敏感级别
            false, 
            true
        )),
        ("python_execute", ToolPermission(
            "python_execute", 
            "/api/v1/tools/python/execute", 
            3,  // 高敏感级别
            true,  // 需要二次确认
            true
        ))
    ])
    
    /**
     * 获取工具权限定义
     */
    public static func getPermission(toolName: String): ?ToolPermission {
        _permissions.get(toolName)
    }
    
    /**
     * 检查工具是否已注册权限
     */
    public static func hasPermission(toolName: String): Bool {
        _permissions.contains(toolName)
    }
    
    /**
     * 获取所有工具权限定义
     */
    public static func getAllPermissions(): HashMap<String, ToolPermission> {
        _permissions
    }
    
    /**
     * 注册新的工具权限
     */
    public static func registerPermission(permission: ToolPermission): Unit {
        _permissions.add(permission.toolName, permission)
    }
    
    /**
     * 获取工具敏感级别
     */
    public static func getSensitiveLevel(toolName: String): Int {
        if (let Some(permission) <- _permissions.get(toolName)) {
            return permission.sensitiveLevel
        }
        return 3  // 未注册的工具默认为高敏感级别
    }
    
    /**
     * 检查工具是否需要二次确认
     */
    public static func requiresConfirmation(toolName: String): Bool {
        if (let Some(permission) <- _permissions.get(toolName)) {
            return permission.requiresConfirmation
        }
        return true  // 未注册的工具默认需要确认
    }
    
    /**
     * 检查工具是否启用审计
     */
    public static func isAuditEnabled(toolName: String): Bool {
        if (let Some(permission) <- _permissions.get(toolName)) {
            return permission.auditEnabled
        }
        return true  // 未注册的工具默认启用审计
    }
}
