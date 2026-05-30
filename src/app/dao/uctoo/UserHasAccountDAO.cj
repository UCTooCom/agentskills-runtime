/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

    //#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.UserHasAccountPO
import magic.log.LogUtils

/**
 * UserHasAccountDAO - user_has_account数据访问接口
 *
 * 提供user_has_account表的标准CRUD操作，遵循UCTOO V4 ORM规范
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

    // ==================== 插入操作 ====================

    /**
     * 插入user_has_account（id由数据库自动生成UUID）
     * @param entity UserHasAccountPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserHasAccount(entity: UserHasAccountPO): String {
        executor.setSql('''
            insert into user_has_account(
                user_id,
                account_type,
                account_id,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.userId)},
                ${arg(entity.accountType)},
                ${arg(entity.accountId)},
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
     * 根据ID查询user_has_account
     * @param id user_has_accountID
     * @return user_has_account对象（Option类型）
     */
    func findUserHasAccountById(id: String): Option<UserHasAccountPO> {
        executor.setSql('''
            select * from user_has_account where id = ${arg(id)}
        ''').first<UserHasAccountPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新user_has_account
     * @param entity user_has_account对象
     * @return 影响行数
     */
    func updateUserHasAccount(entity: UserHasAccountPO): Int64 {
        executor.setSql('''
            update user_has_account set
                user_id = ${arg(entity.userId)},
                account_type = ${arg(entity.accountType)},
                account_id = ${arg(entity.accountId)},
                status = ${arg(entity.status)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除user_has_account
     * @param id user_has_accountID
     * @return 影响行数
     */
    func softDeleteUserHasAccountById(id: String): Int64 {
        executor.setSql('''
            update user_has_account set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的user_has_account
     * @param id user_has_accountID
     * @return 影响行数
     */
    func restoreUserHasAccountById(id: String): Int64 {
        executor.setSql('''
            update user_has_account set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除user_has_account
     * @param id user_has_accountID
     * @return 影响行数
     */
    func deleteUserHasAccountById(id: String): Int64 {
        executor.setSql('''
            delete from user_has_account where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有user_has_account
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
     * 分页查询user_has_account列表（按创建者）
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
     * 查询所有user_has_account（不分页）
     * @return user_has_account列表
     */
    func listAllUserHasAccount(): ArrayList<UserHasAccountPO> {
        executor.setSql('''
            select * from user_has_account order by created_at desc
        ''').list<UserHasAccountPO>()
    }

    /**
     * 批量查询user_has_account
     * @param ids ID列表
     * @return user_has_account列表
     */
    func findUserHasAccountByIds(ids: ArrayList<String>): ArrayList<UserHasAccountPO> {
        executor.setSql('''
            select * from user_has_account where id ${IN(ids)}
        ''').list<UserHasAccountPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的user_has_account数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserHasAccountByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_account where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有user_has_account数量
     * @return 数量
     */
    func countAllUserHasAccount(): Int64 {
        executor.setSql('''
            select count(*) from user_has_account
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询user_has_account列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasAccountByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UserHasAccountPO> {
        let sql = StringBuilder()
        sql.append("select * from user_has_account where 1=1")

        if (let Some(linkVal) <- link) {
            if (linkVal != "") {
                sql.append(" and link like ${arg('%' + linkVal + '%')}")
            }
        }

        if (let Some(descVal) <- description) {
            if (descVal != "") {
                sql.append(" and description like ${arg('%' + descVal + '%')}")
            }
        }

        // 处理 deleted_at 筛选
        if (let Some(deletedAtVal) <- deletedAt) {
            if (deletedAtVal == "null") {
                // 未删除的数据
                sql.append(" and deleted_at is null")
            } else if (deletedAtVal == "not_null") {
                // 已删除的数据（回收站）
                sql.append(" and deleted_at is not null")
            }
        }

        sql.append(" order by created_at desc")

        executor.page<UserHasAccountPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除user_has_account
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUserHasAccount(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update user_has_account set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除user_has_account
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUserHasAccount(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from user_has_account where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询user_has_account（支持完整查询操作符）
     *
     * @param whereClause WHERE 子句字符串（不包含 WHERE 关键字）
     * @param orderByClause ORDER BY 子句字符串（不包含 ORDER BY 关键字）
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     *
     * 使用示例：
     * - whereClause: "name LIKE '%test%' AND status = 'active'"
     * - orderByClause: "created_at DESC, name ASC"
     */
    func findUserHasAccountByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasAccountPO> {
        let sql = StringBuilder()
        sql.append("select * from user_has_account")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UserHasAccountPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询user_has_account
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasAccountByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasAccountPO> {
        let fromClause = executor.FROM<UserHasAccountPO>()

        // 应用 WHERE 条件
        if (!whereClause.isEmpty()) {
            fromClause.WHERE(whereClause)
        }

        // 应用 ORDER BY
        if (!orderByClause.isEmpty()) {
            fromClause.ORDER_BY { => orderByClause }
        } else {
            fromClause.ORDER_BY { => "created_at DESC" }
        }

        // 执行分页查询
        fromClause.page<UserHasAccountPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的user_has_account）
     * @return 影响行数
     */
    func emptyRecycleBinUserHasAccount(): Int64 {
        executor.setSql('''
            delete from user_has_account where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
