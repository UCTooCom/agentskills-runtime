/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.UserHasGroupPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * UserHasGroupDAO - 用户组关联数据访问接口
 * 
 * 提供user_has_group表的标准CRUD操作，遵循UCTOO V4 ORM规范
 * 
 * 注意: 此表使用复合主键 (groupable_id, group_id)
 * 
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UserHasGroupDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入userHasGroup（复合主键由调用方提供）
     * @param userHasGroup userHasGroup对象
     * @return 插入成功返回true，失败返回false
     */
    func insertUserHasGroup(userHasGroup: UserHasGroupPO): Bool {
        executor.setSql('''
            insert into user_has_group(
                groupable_id,
                group_id,
                groupable_type,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(userHasGroup.groupableIdProp)},
                ${arg(userHasGroup.groupIdProp)},
                ${arg(userHasGroup.groupableTypeProp)},
                ${arg(userHasGroup.statusProp)},
                ${arg(userHasGroup.creatorProp)},
                ${arg(userHasGroup.createdAtProp)},
                ${arg(userHasGroup.updatedAtProp)},
                ${arg(userHasGroup.deletedAtProp)}
            )
        ''').update > 0
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据复合主键查询userHasGroup
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @return userHasGroup对象（Option类型）
     */
    func findUserHasGroupById(groupableId: String, groupId: String): Option<UserHasGroupPO> {
        executor.setSql('''
            select * from user_has_group 
            where groupable_id = ${arg(groupableId)} 
            and group_id = ${arg(groupId)}
        ''').first<UserHasGroupPO>()
    }
    
    /**
     * 根据groupableId查询所有关联的组
     * @param groupableId 可分组对象ID
     * @return userHasGroup列表
     */
    func findUserHasGroupsByGroupableId(groupableId: String): ArrayList<UserHasGroupPO> {
        executor.setSql('''
            select * from user_has_group 
            where groupable_id = ${arg(groupableId)}
            order by created_at desc
        ''').list<UserHasGroupPO>()
    }
    
    /**
     * 根据groupId查询所有关联的对象
     * @param groupId 组ID
     * @return userHasGroup列表
     */
    func findUserHasGroupsByGroupId(groupId: String): ArrayList<UserHasGroupPO> {
        executor.setSql('''
            select * from user_has_group 
            where group_id = ${arg(groupId)}
            order by created_at desc
        ''').list<UserHasGroupPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新userHasGroup（根据复合主键）
     * @param userHasGroup userHasGroup对象
     * @return 更新成功返回true，失败返回false
     */
    func updateUserHasGroup(userHasGroup: UserHasGroupPO): Bool {
        executor.setSql('''
            update user_has_group set
                groupable_type = ${arg(userHasGroup.groupableTypeProp)},
                status = ${arg(userHasGroup.statusProp)},
                creator = ${arg(userHasGroup.creatorProp)},
                updated_at = ${arg(DateTime.now())},
                deleted_at = ${arg(userHasGroup.deletedAtProp)}
            where groupable_id = ${arg(userHasGroup.groupableIdProp)}
            and group_id = ${arg(userHasGroup.groupIdProp)}
        ''').update > 0
    }
    
    /**
     * 更新状态
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @param status 新状态
     * @return 更新成功返回true，失败返回false
     */
    func updateUserHasGroupStatus(groupableId: String, groupId: String, status: Int32): Bool {
        executor.setSql('''
            update user_has_group set
                status = ${arg(status)},
                updated_at = ${arg(DateTime.now())}
            where groupable_id = ${arg(groupableId)}
            and group_id = ${arg(groupId)}
        ''').update > 0
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 删除userHasGroup（根据复合主键）
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @return 删除成功返回true，失败返回false
     */
    func deleteUserHasGroup(groupableId: String, groupId: String): Bool {
        executor.setSql('''
            delete from user_has_group 
            where groupable_id = ${arg(groupableId)} 
            and group_id = ${arg(groupId)}
        ''').update > 0
    }
    
    /**
     * 软删除userHasGroup（根据复合主键）
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @return 软删除成功返回true，失败返回false
     */
    func softDeleteUserHasGroup(groupableId: String, groupId: String): Bool {
        executor.setSql('''
            update user_has_group set
                deleted_at = ${arg(DateTime.now())}
            where groupable_id = ${arg(groupableId)}
            and group_id = ${arg(groupId)}
        ''').update > 0
    }
    
    /**
     * 删除用户的所有组关联
     * @param groupableId 可分组对象ID
     * @return 删除成功返回true，失败返回false
     */
    func deleteUserHasGroupsByGroupableId(groupableId: String): Bool {
        executor.setSql('''
            delete from user_has_group 
            where groupable_id = ${arg(groupableId)}
        ''').update > 0
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计用户所属组数量
     * @param groupableId 可分组对象ID
     * @return 组数量
     */
    func countUserHasGroupsByGroupableId(groupableId: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_group 
            where groupable_id = ${arg(groupableId)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计组内成员数量
     * @param groupId 组ID
     * @return 成员数量
     */
    func countUserHasGroupsByGroupId(groupId: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_group 
            where group_id = ${arg(groupId)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 检查用户是否在组中
     * @param groupableId 可分组对象ID
     * @param groupId 组ID
     * @return 存在返回true，不存在返回false
     */
    func existsUserHasGroup(groupableId: String, groupId: String): Bool {
        let count = executor.setSql('''
            select count(*) from user_has_group 
            where groupable_id = ${arg(groupableId)} 
            and group_id = ${arg(groupId)}
        ''').first<Int64>() ?? 0
        count > 0
    }
    
    //#endregion AutoCreateCode
}
