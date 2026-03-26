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
import magic.app.models.uctoo.UserHasAccountPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * UserHasAccountDAO - user_has_account数据访问接口
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
public interface UserHasAccountDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入userHasAccount（id由数据库自动生成UUID）
     * @param entity userHasAccount对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserHasAccount(entity: UserHasAccountPO): String {
        executor.setSql('''
            insert into user_has_account(
                user_id,
                account_id,
                account_type,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.userId)},
                ${arg(entity.accountId)},
                ${arg(entity.accountType)},
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
     * 根据ID查询userHasAccount
     * @param id userHasAccountID
     * @return userHasAccount对象（Option类型）
     */
    func findUserHasAccountById(id: String): Option<UserHasAccountPO> {
        executor.setSql('''
            select * from user_has_account where id = ${arg(id)}
        ''').first<UserHasAccountPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新userHasAccount
     * @param entity userHasAccount对象
     * @return 影响行数
     */
    func updateUserHasAccount(entity: UserHasAccountPO): Int64 {
        executor.setSql('''
            update user_has_account set
                user_id = ${arg(entity.userId)},
                account_id = ${arg(entity.accountId)},
                account_type = ${arg(entity.accountType)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除userHasAccount
     * @param id userHasAccountID
     * @return 影响行数
     */
    func softDeleteUserHasAccountById(id: String): Int64 {
        executor.setSql('''
            update user_has_account set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的userHasAccount
     * @param id userHasAccountID
     * @return 影响行数
     */
    func restoreUserHasAccountById(id: String): Int64 {
        executor.setSql('''
            update user_has_account set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除userHasAccount
     * @param id userHasAccountID
     * @return 影响行数
     */
    func deleteUserHasAccountById(id: String): Int64 {
        executor.setSql('''
            delete from user_has_account where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有userHasAccount
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserHasAccountPage(page: Int64, size: Int64): Pagination<UserHasAccountPO> {
        executor.page<UserHasAccountPO>('''
            select * from user_has_account order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询userHasAccount列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasAccountByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserHasAccountPO> {
        executor.page<UserHasAccountPO>('''
            select * from user_has_account where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有userHasAccount（不分页）
     * @return userHasAccount列表
     */
    func listAllUserHasAccount(): ArrayList<UserHasAccountPO> {
        executor.setSql('''
            select * from user_has_account order by created_at desc
        ''').list<UserHasAccountPO>()
    }
    
    /**
     * 批量查询userHasAccount
     * @param ids ID列表
     * @return userHasAccount列表
     */
    func findUserHasAccountByIds(ids: ArrayList<String>): ArrayList<UserHasAccountPO> {
        executor.setSql('''
            select * from user_has_account where id ${IN(ids)}
        ''').list<UserHasAccountPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的userHasAccount数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserHasAccountByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_account where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有userHasAccount数量
     * @return 数量
     */
    func countAllUserHasAccount(): Int64 {
        executor.setSql('''
            select count(*) from user_has_account
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
