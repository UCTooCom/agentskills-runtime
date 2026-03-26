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
import magic.app.models.uctoo.UserHasRolesPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * UserHasRolesDAO - user_has_roles数据访问接口
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
public interface UserHasRolesDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入userHasRoles（id由数据库自动生成UUID）
     * @param entity userHasRoles对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserHasRoles(entity: UserHasRolesPO): String {
        executor.setSql('''
            insert into user_has_roles(
                user_id,
                role_id,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.userId)},
                ${arg(entity.roleId)},
                ${arg(entity.status)},
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
     * 根据ID查询userHasRoles
     * @param id userHasRolesID
     * @return userHasRoles对象（Option类型）
     */
    func findUserHasRolesById(id: String): Option<UserHasRolesPO> {
        executor.setSql('''
            select * from user_has_roles where id = ${arg(id)}
        ''').first<UserHasRolesPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新userHasRoles
     * @param entity userHasRoles对象
     * @return 影响行数
     */
    func updateUserHasRoles(entity: UserHasRolesPO): Int64 {
        executor.setSql('''
            update user_has_roles set
                user_id = ${arg(entity.userId)},
                role_id = ${arg(entity.roleId)},
                status = ${arg(entity.status)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除userHasRoles
     * @param id userHasRolesID
     * @return 影响行数
     */
    func softDeleteUserHasRolesById(id: String): Int64 {
        executor.setSql('''
            update user_has_roles set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的userHasRoles
     * @param id userHasRolesID
     * @return 影响行数
     */
    func restoreUserHasRolesById(id: String): Int64 {
        executor.setSql('''
            update user_has_roles set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除userHasRoles
     * @param id userHasRolesID
     * @return 影响行数
     */
    func deleteUserHasRolesById(id: String): Int64 {
        executor.setSql('''
            delete from user_has_roles where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有userHasRoles
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserHasRolesPage(page: Int64, size: Int64): Pagination<UserHasRolesPO> {
        executor.page<UserHasRolesPO>('''
            select * from user_has_roles order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询userHasRoles列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasRolesByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserHasRolesPO> {
        executor.page<UserHasRolesPO>('''
            select * from user_has_roles where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有userHasRoles（不分页）
     * @return userHasRoles列表
     */
    func listAllUserHasRoles(): ArrayList<UserHasRolesPO> {
        executor.setSql('''
            select * from user_has_roles order by created_at desc
        ''').list<UserHasRolesPO>()
    }
    
    /**
     * 批量查询userHasRoles
     * @param ids ID列表
     * @return userHasRoles列表
     */
    func findUserHasRolesByIds(ids: ArrayList<String>): ArrayList<UserHasRolesPO> {
        executor.setSql('''
            select * from user_has_roles where id ${IN(ids)}
        ''').list<UserHasRolesPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的userHasRoles数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserHasRolesByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_roles where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有userHasRoles数量
     * @return 数量
     */
    func countAllUserHasRoles(): Int64 {
        executor.setSql('''
            select count(*) from user_has_roles
        ''').first<Int64>() ?? 0
    }

    //#endregion AutoCreateCode

    // ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 根据用户ID查询用户角色关联
     * @param userId 用户ID
     * @return 用户角色关联列表
     */
    func findUserHasRolesByUserId(userId: String): ArrayList<UserHasRolesPO> {
        executor.setSql('''
            SELECT * FROM user_has_roles
            WHERE user_id = ${arg(userId)} AND deleted_at IS NULL
        ''').list<UserHasRolesPO>()
    }
}
