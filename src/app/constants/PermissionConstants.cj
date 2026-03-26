/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.constants

/**
 * PermissionConstants - 权限常量定义
 * 
 * 定义系统中所有权限节点的常量,遵循V3命名规范:
 * - API权限(type=3): 使用路由路径
 * - 菜单权限(type=1): 使用database.{db}.{table}或自定义名称
 * - 按钮权限(type=2): 使用button.{module}.{action}
 */
public class PermissionConstants {
    // ========== 通配符权限 ==========
    
    /// 全部权限(超级管理员)
    public static let ALL = "/*"
    
    // ========== API权限 (type=3) ==========
    
    // 用户管理API
    public static let USER_API = "/api/v1/uctoo/user"
    public static let USER_SIGNIN_API = "/api/v1/uctoo/user/signin"
    public static let USER_SIGNUP_API = "/api/v1/uctoo/user/signup"
    public static let USER_ME_API = "/api/v1/uctoo/user/me"
    
    // 实体管理API
    public static let ENTITY_API = "/api/v1/uctoo/entity"
    public static let ENTITY_LIST_API = "/api/v1/uctoo/entity/:limit/:page"
    public static let ENTITY_DETAIL_API = "/api/v1/uctoo/entity/:id"
    
    // 会话管理API
    public static let SESSION_API = "/api/v1/uctoo/session"
    
    // 用户组管理API
    public static let GROUP_API = "/api/v1/uctoo/group"
    
    // 角色管理API
    public static let ROLE_API = "/api/v1/uctoo/role"
    
    // 权限管理API
    public static let PERMISSION_API = "/api/v1/uctoo/permission"
    
    // 技能管理API
    public static let SKILL_INSTALL_API = "/api/v1/skills/install"
    public static let SKILL_EXECUTE_API = "/api/v1/skills/execute"
    
    // MCP接口API
    public static let MCP_STREAM_API = "/api/v1/mcp/stream"
    
    // ========== 菜单权限 (type=1) ==========
    
    // 数据库菜单
    public static let USER_MENU = "database.uctoo.uctoo_user"
    public static let ENTITY_MENU = "database.uctoo.entity"
    public static let SESSION_MENU = "database.uctoo.uctoo_session"
    public static let GROUP_MENU = "database.uctoo.user_group"
    public static let ROLE_MENU = "database.uctoo.uctoo_role"
    public static let PERMISSION_MENU = "database.uctoo.permissions"
    public static let SKILL_MENU = "database.uctoo.agent_skills"
    
    // 普通菜单(V4建议使用menu.前缀)
    public static let DASHBOARD_MENU = "Dashboard"  // V3格式
    public static let WORKSPACE_MENU = "Workspace"  // V3格式
    public static let SETTINGS_MENU = "menu.settings"  // V4格式
    public static let PROFILE_MENU = "menu.profile"  // V4格式
    
    // ========== 按钮权限 (type=2) ==========
    
    // 实体管理按钮
    public static let ENTITY_CREATE_BUTTON = "button.entity.create"
    public static let ENTITY_EDIT_BUTTON = "button.entity.edit"
    public static let ENTITY_DELETE_BUTTON = "button.entity.delete"
    public static let ENTITY_VIEW_BUTTON = "button.entity.view"
    public static let ENTITY_EXPORT_BUTTON = "button.entity.export"
    
    // 用户管理按钮
    public static let USER_CREATE_BUTTON = "button.user.create"
    public static let USER_EDIT_BUTTON = "button.user.edit"
    public static let USER_DELETE_BUTTON = "button.user.delete"
    public static let USER_VIEW_BUTTON = "button.user.view"
    
    // 角色管理按钮
    public static let ROLE_CREATE_BUTTON = "button.role.create"
    public static let ROLE_EDIT_BUTTON = "button.role.edit"
    public static let ROLE_DELETE_BUTTON = "button.role.delete"
    public static let ROLE_ASSIGN_PERMISSION_BUTTON = "button.role.assignPermission"
    
    // 权限管理按钮
    public static let PERMISSION_CREATE_BUTTON = "button.permission.create"
    public static let PERMISSION_EDIT_BUTTON = "button.permission.edit"
    public static let PERMISSION_DELETE_BUTTON = "button.permission.delete"
    public static let PERMISSION_ASSIGN_BUTTON = "button.permission.assign"
    
    // ========== 辅助方法 ==========
    
    /// 根据路由路径生成API权限名称
    public static func getAPIPermission(routePath: String): String {
        return routePath
    }
    
    /// 根据数据库表名生成菜单权限名称
    public static func getDatabaseMenuPermission(databaseName: String, tableName: String): String {
        return "database.${databaseName}.${tableName}"
    }
    
    /// 根据模块和操作生成按钮权限名称
    public static func getButtonPermission(module: String, action: String): String {
        return "button.${module}.${action}"
    }
    
    /// 根据HTTP方法和路由生成完整的API权限
    public static func getAPIPermissionWithMethod(method: String, routePath: String): String {
        // 返回路由路径,method存储在permissions表的method字段中
        return routePath
    }
}
