/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.RoleHasPermissionPO
import magic.app.dao.uctoo.RoleHasPermissionDAO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * RoleHasPermissionService - 角色权限关联服务
 * 
 * 提供role_has_permission表的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 
 * 注意: 此表使用复合主键 (role_id, permission_name)
 */
public class RoleHasPermissionService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    // ==================== 创建操作 ====================
    
    /**
     * 创建角色权限关联
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @param creator 创建者（可选）
     * @return 创建成功返回对象，失败返回None
     */
    public func create(roleId: String, permissionName: String, creator: ?String): Option<RoleHasPermissionPO> {
        // 检查是否已存在
        if (getExecutor().existsRoleHasPermission(roleId, permissionName)) {
            LogUtils.info("RoleHasPermission already exists: roleId=${roleId}, permissionName=${permissionName}")
            return None<RoleHasPermissionPO>
        }
        
        let roleHasPermission = RoleHasPermissionPO(
            roleId, 
            permissionName, 
            Some<Int32>(0), 
            creator, 
            DateTime.now(), 
            DateTime.now(), 
            None<DateTime>
        )
        
        if (getExecutor().insertRoleHasPermission(roleHasPermission)) {
            Some<RoleHasPermissionPO>(roleHasPermission)
        } else {
            None<RoleHasPermissionPO>
        }
    }
    
    // ==================== 查询操作 ====================
    
    /**
     * 根据复合主键查询
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return roleHasPermission对象（Option类型）
     */
    public func findById(roleId: String, permissionName: String): Option<RoleHasPermissionPO> {
        getExecutor().findRoleHasPermissionById(roleId, permissionName)
    }
    
    /**
     * 查询角色拥有的所有权限
     * @param roleId 角色ID
     * @return roleHasPermission列表
     */
    public func findByRoleId(roleId: String): ArrayList<RoleHasPermissionPO> {
        getExecutor().findRoleHasPermissionsByRoleId(roleId)
    }
    
    /**
     * 查询使用某权限的所有角色
     * @param permissionName 权限名称
     * @return roleHasPermission列表
     */
    public func findByPermissionName(permissionName: String): ArrayList<RoleHasPermissionPO> {
        getExecutor().findRoleHasPermissionsByPermissionName(permissionName)
    }
    
    /**
     * 查询多个角色拥有的所有权限
     * @param roleIds 角色ID列表
     * @return roleHasPermission列表
     */
    public func findByRoleIds(roleIds: ArrayList<String>): ArrayList<RoleHasPermissionPO> {
        getExecutor().findRoleHasPermissionsByRoleIds(roleIds)
    }
    
    /**
     * 检查角色是否拥有权限
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return 存在返回true，不存在返回false
     */
    public func exists(roleId: String, permissionName: String): Bool {
        getExecutor().existsRoleHasPermission(roleId, permissionName)
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新状态
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @param status 新状态
     * @return 更新成功返回true，失败返回false
     */
    public func updateStatus(roleId: String, permissionName: String, status: Int32): Bool {
        getExecutor().updateRoleHasPermissionStatus(roleId, permissionName, status)
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 删除角色权限关联
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return 删除成功返回true，失败返回false
     */
    public func delete(roleId: String, permissionName: String): Bool {
        getExecutor().deleteRoleHasPermission(roleId, permissionName)
    }
    
    /**
     * 软删除角色权限关联
     * @param roleId 角色ID
     * @param permissionName 权限名称
     * @return 软删除成功返回true，失败返回false
     */
    public func softDelete(roleId: String, permissionName: String): Bool {
        getExecutor().softDeleteRoleHasPermission(roleId, permissionName)
    }
    
    /**
     * 删除角色的所有权限关联
     * @param roleId 角色ID
     * @return 删除成功返回true，失败返回false
     */
    public func deleteByRoleId(roleId: String): Bool {
        getExecutor().deleteRoleHasPermissionsByRoleId(roleId)
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计角色拥有的权限数量
     * @param roleId 角色ID
     * @return 权限数量
     */
    public func countByRoleId(roleId: String): Int64 {
        getExecutor().countRoleHasPermissionsByRoleId(roleId)
    }
    
    /**
     * 统计权限被多少角色使用
     * @param permissionName 权限名称
     * @return 角色数量
     */
    public func countByPermissionName(permissionName: String): Int64 {
        getExecutor().countRoleHasPermissionsByPermissionName(permissionName)
    }
    
    //#endregion AutoCreateCode
}
