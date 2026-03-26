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
import magic.app.models.uctoo.UserGroupPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * UserGroupDAO - user_group数据访问接口
 * 
 * 提供标准CRUD操作，遵循UCTOO V4 ORM规范
 * 
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UserGroupDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入userGroup（id由数据库自动生成UUID）
     * @param entity userGroup对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserGroup(entity: UserGroupPO): String {
        executor.setSql('''
            insert into user_group(
                group_name,
                parent_id,
                code,
                intro,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.groupName)},
                ${arg(entity.parentId)},
                ${arg(entity.code)},
                ${arg(entity.intro)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询userGroup
     * @param id userGroupID
     * @return userGroup对象（Option类型）
     */
    func findUserGroupById(id: String): Option<UserGroupPO> {
        executor.setSql('''
            select * from user_group where id = ${arg(id)}
        ''').first<UserGroupPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新userGroup
     * @param entity userGroup对象
     * @return 影响行数
     */
    func updateUserGroup(entity: UserGroupPO): Int64 {
        executor.setSql('''
            update user_group set
                group_name = ${arg(entity.groupName)},
                parent_id = ${arg(entity.parentId)},
                code = ${arg(entity.code)},
                intro = ${arg(entity.intro)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除userGroup
     * @param id userGroupID
     * @return 影响行数
     */
    func softDeleteUserGroupById(id: String): Int64 {
        executor.setSql('''
            update user_group set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的userGroup
     * @param id userGroupID
     * @return 影响行数
     */
    func restoreUserGroupById(id: String): Int64 {
        executor.setSql('''
            update user_group set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除userGroup
     * @param id userGroupID
     * @return 影响行数
     */
    func deleteUserGroupById(id: String): Int64 {
        executor.setSql('''
            delete from user_group where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有userGroup
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserGroupPage(page: Int64, size: Int64): Pagination<UserGroupPO> {
        executor.page<UserGroupPO>('''
            select * from user_group order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询userGroup列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserGroupByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserGroupPO> {
        executor.page<UserGroupPO>('''
            select * from user_group where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有userGroup（不分页）
     * @return userGroup列表
     */
    func listAllUserGroup(): ArrayList<UserGroupPO> {
        executor.setSql('''
            select * from user_group order by created_at desc
        ''').list<UserGroupPO>()
    }
    
    /**
     * 批量查询userGroup
     * @param ids ID列表
     * @return userGroup列表
     */
    func findUserGroupByIds(ids: ArrayList<String>): ArrayList<UserGroupPO> {
        executor.setSql('''
            select * from user_group where id ${IN(ids)}
        ''').list<UserGroupPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的userGroup数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserGroupByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_group where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有userGroup数量
     * @return 数量
     */
    func countAllUserGroup(): Int64 {
        executor.setSql('''
            select count(*) from user_group
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
