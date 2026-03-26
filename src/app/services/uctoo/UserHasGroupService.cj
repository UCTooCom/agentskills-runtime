/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.UserHasGroupPO
import magic.app.dao.uctoo.UserHasGroupDAO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * UserHasGroupService - 用户组关联服务
 * 
 * 提供user_has_group表的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 
 * 注意: 此表使用复合主键 (groupable_id, group_id)
 */
public class UserHasGroupService {
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
     * 创建用户组关联
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @param groupableType 可分组对象类型（可选）
     * @param creator 创建者（可选）
     * @return 创建成功返回对象，失败返回None
     */
    public func create(groupableId: String, groupId: String, groupableType: ?String, creator: ?String): Option<UserHasGroupPO> {
        // 检查是否已存在
        if (getExecutor().existsUserHasGroup(groupableId, groupId)) {
            LogUtils.info("UserHasGroup already exists: groupableId=${groupableId}, groupId=${groupId}")
            return None<UserHasGroupPO>
        }
        
        let userHasGroup = UserHasGroupPO(groupableId, groupId)
        userHasGroup.groupableTypeProp = groupableType
        userHasGroup.creatorProp = creator
        userHasGroup.createdAtProp = DateTime.now()
        
        if (getExecutor().insertUserHasGroup(userHasGroup)) {
            Some<UserHasGroupPO>(userHasGroup)
        } else {
            None<UserHasGroupPO>
        }
    }
    
    // ==================== 查询操作 ====================
    
    /**
     * 根据复合主键查询
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @return userHasGroup对象（Option类型）
     */
    public func findById(groupableId: String, groupId: String): Option<UserHasGroupPO> {
        getExecutor().findUserHasGroupById(groupableId, groupId)
    }
    
    /**
     * 查询用户所属的所有组
     * @param groupableId 可分组对象ID
     * @return userHasGroup列表
     */
    public func findByGroupableId(groupableId: String): ArrayList<UserHasGroupPO> {
        getExecutor().findUserHasGroupsByGroupableId(groupableId)
    }
    
    /**
     * 查询组内的所有成员
     * @param groupId 组ID
     * @return userHasGroup列表
     */
    public func findByGroupId(groupId: String): ArrayList<UserHasGroupPO> {
        getExecutor().findUserHasGroupsByGroupId(groupId)
    }
    
    /**
     * 检查用户是否在组中
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @return 存在返回true，不存在返回false
     */
    public func exists(groupableId: String, groupId: String): Bool {
        getExecutor().existsUserHasGroup(groupableId, groupId)
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新状态
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @param status 新状态
     * @return 更新成功返回true，失败返回false
     */
    public func updateStatus(groupableId: String, groupId: String, status: Int32): Bool {
        getExecutor().updateUserHasGroupStatus(groupableId, groupId, status)
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 删除用户组关联
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @return 删除成功返回true，失败返回false
     */
    public func delete(groupableId: String, groupId: String): Bool {
        getExecutor().deleteUserHasGroup(groupableId, groupId)
    }
    
    /**
     * 软删除用户组关联
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @return 软删除成功返回true，失败返回false
     */
    public func softDelete(groupableId: String, groupId: String): Bool {
        getExecutor().softDeleteUserHasGroup(groupableId, groupId)
    }
    
    /**
     * 删除用户的所有组关联
     * @param groupableId 可分组对象ID
     * @return 删除成功返回true，失败返回false
     */
    public func deleteByGroupableId(groupableId: String): Bool {
        getExecutor().deleteUserHasGroupsByGroupableId(groupableId)
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计用户所属组数量
     * @param groupableId 可分组对象ID
     * @return 组数量
     */
    public func countByGroupableId(groupableId: String): Int64 {
        getExecutor().countUserHasGroupsByGroupableId(groupableId)
    }
    
    /**
     * 统计组内成员数量
     * @param groupId 组ID
     * @return 成员数量
     */
    public func countByGroupId(groupId: String): Int64 {
        getExecutor().countUserHasGroupsByGroupId(groupId)
    }
    
    //#endregion AutoCreateCode
}
