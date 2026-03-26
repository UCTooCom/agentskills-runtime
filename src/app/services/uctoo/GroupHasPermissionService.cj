/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.GroupHasPermissionPO
import magic.app.dao.uctoo.GroupHasPermissionDAO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * GroupHasPermissionService - 组权限关联服务
 * 
 * 提供group_has_permission表的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 
 * 注意: 此表使用复合主键 (group_id, permission_name)
 */
public class GroupHasPermissionService {
    private var executor: ?SqlExecutor = None<SqlExecutor>
    
    private func getExecutor(): SqlExecutor {
        if (let Some(exe) <- executor) {
            return exe
        }
        let exe = ORM.executor()
        executor = Some<SqlExecutor>(exe)
        return exe
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    // ==================== 创建操作 ====================
    
    /**
     * 创建组权限关联
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @param creator 创建者（可选）
     * @return 创建成功返回对象，失败返回None
     */
    public func create(groupId: String, permissionName: String, creator: ?String): Option<GroupHasPermissionPO> {
        // 检查是否已存在
        if (getExecutor().existsGroupHasPermission(groupId, permissionName)) {
            LogUtils.info("GroupHasPermission already exists: groupId=${groupId}, permissionName=${permissionName}")
            return None<GroupHasPermissionPO>
        }
        
        let groupHasPermission = GroupHasPermissionPO(groupId, permissionName)
        groupHasPermission.creatorProp = creator
        groupHasPermission.createdAtProp = DateTime.now()
        
        if (getExecutor().insertGroupHasPermission(groupHasPermission)) {
            Some<GroupHasPermissionPO>(groupHasPermission)
        } else {
            None<GroupHasPermissionPO>
        }
    }
    
    // ==================== 查询操作 ====================
    
    /**
     * 根据复合主键查询
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @return groupHasPermission对象（Option类型）
     */
    public func findById(groupId: String, permissionName: String): Option<GroupHasPermissionPO> {
        getExecutor().findGroupHasPermissionById(groupId, permissionName)
    }
    
    /**
     * 查询组拥有的所有权限
     * @param groupId 组ID
     * @return groupHasPermission列表
     */
    public func findByGroupId(groupId: String): ArrayList<GroupHasPermissionPO> {
        getExecutor().findGroupHasPermissionsByGroupId(groupId)
    }
    
    /**
     * 查询使用某权限的所有组
     * @param permissionName 权限名称
     * @return groupHasPermission列表
     */
    public func findByPermissionName(permissionName: String): ArrayList<GroupHasPermissionPO> {
        getExecutor().findGroupHasPermissionsByPermissionName(permissionName)
    }
    
    /**
     * 查询多个组拥有的所有权限
     * @param groupIds 组ID列表
     * @return groupHasPermission列表
     */
    public func findByGroupIds(groupIds: ArrayList<String>): ArrayList<GroupHasPermissionPO> {
        getExecutor().findGroupHasPermissionsByGroupIds(groupIds)
    }
    
    /**
     * 检查组是否拥有权限
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @return 存在返回true，不存在返回false
     */
    public func exists(groupId: String, permissionName: String): Bool {
        getExecutor().existsGroupHasPermission(groupId, permissionName)
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新状态
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @param status 新状态
     * @return 更新成功返回true，失败返回false
     */
    public func updateStatus(groupId: String, permissionName: String, status: Int32): Bool {
        getExecutor().updateGroupHasPermissionStatus(groupId, permissionName, status)
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 删除组权限关联
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @return 删除成功返回true，失败返回false
     */
    public func delete(groupId: String, permissionName: String): Bool {
        getExecutor().deleteGroupHasPermission(groupId, permissionName)
    }
    
    /**
     * 软删除组权限关联
     * @param groupId 组ID
     * @param permissionName 权限名称
     * @return 软删除成功返回true，失败返回false
     */
    public func softDelete(groupId: String, permissionName: String): Bool {
        getExecutor().softDeleteGroupHasPermission(groupId, permissionName)
    }
    
    /**
     * 删除组的所有权限关联
     * @param groupId 组ID
     * @return 删除成功返回true，失败返回false
     */
    public func deleteByGroupId(groupId: String): Bool {
        getExecutor().deleteGroupHasPermissionsByGroupId(groupId)
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计组拥有的权限数量
     * @param groupId 组ID
     * @return 权限数量
     */
    public func countByGroupId(groupId: String): Int64 {
        getExecutor().countGroupHasPermissionsByGroupId(groupId)
    }
    
    /**
     * 统计权限被多少组使用
     * @param permissionName 权限名称
     * @return 组数量
     */
    public func countByPermissionName(permissionName: String): Int64 {
        getExecutor().countGroupHasPermissionsByPermissionName(permissionName)
    }
    
    //#endregion AutoCreateCode
}
