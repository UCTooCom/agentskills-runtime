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
import magic.app.models.uctoo.AppAccessTokenPO
import magic.log.LogUtils

/**
 * AppAccessTokenDAO - app_access_token数据访问接口
 *
 * 提供app_access_token表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AppAccessTokenDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入app_access_token（id由数据库自动生成UUID）
     * @param entity AppAccessTokenPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAppAccessToken(entity: AppAccessTokenPO): String {
        executor.setSql('''
            insert into app_access_token(
                access_token,
                token_overtime,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.accessToken)},
                ${arg(entity.tokenOvertime)},
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
     * 根据ID查询app_access_token
     * @param id app_access_tokenID
     * @return app_access_token对象（Option类型）
     */
    func findAppAccessTokenById(id: String): Option<AppAccessTokenPO> {
        executor.setSql('''
            select * from app_access_token where id = ${arg(id)}
        ''').first<AppAccessTokenPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新app_access_token
     * @param entity app_access_token对象
     * @return 影响行数
     */
    func updateAppAccessToken(entity: AppAccessTokenPO): Int64 {
        executor.setSql('''
            update app_access_token set
                access_token = ${arg(entity.accessToken)},
                token_overtime = ${arg(entity.tokenOvertime)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除app_access_token
     * @param id app_access_tokenID
     * @return 影响行数
     */
    func softDeleteAppAccessTokenById(id: String): Int64 {
        executor.setSql('''
            update app_access_token set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的app_access_token
     * @param id app_access_tokenID
     * @return 影响行数
     */
    func restoreAppAccessTokenById(id: String): Int64 {
        executor.setSql('''
            update app_access_token set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除app_access_token
     * @param id app_access_tokenID
     * @return 影响行数
     */
    func deleteAppAccessTokenById(id: String): Int64 {
        executor.setSql('''
            delete from app_access_token where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有app_access_token
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAppAccessTokenPage(page: Int64, size: Int64): Pagination<AppAccessTokenPO> {
        executor.page<AppAccessTokenPO>('''
            select * from app_access_token order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询app_access_token列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAppAccessTokenByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AppAccessTokenPO> {
        executor.page<AppAccessTokenPO>('''
            select * from app_access_token where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有app_access_token（不分页）
     * @return app_access_token列表
     */
    func listAllAppAccessToken(): ArrayList<AppAccessTokenPO> {
        executor.setSql('''
            select * from app_access_token order by created_at desc
        ''').list<AppAccessTokenPO>()
    }

    /**
     * 批量查询app_access_token
     * @param ids ID列表
     * @return app_access_token列表
     */
    func findAppAccessTokenByIds(ids: ArrayList<String>): ArrayList<AppAccessTokenPO> {
        executor.setSql('''
            select * from app_access_token where id ${IN(ids)}
        ''').list<AppAccessTokenPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的app_access_token数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAppAccessTokenByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from app_access_token where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有app_access_token数量
     * @return 数量
     */
    func countAllAppAccessToken(): Int64 {
        executor.setSql('''
            select count(*) from app_access_token
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询app_access_token列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAppAccessTokenByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AppAccessTokenPO> {
        let sql = StringBuilder()
        sql.append("select * from app_access_token where 1=1")

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

        executor.page<AppAccessTokenPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除app_access_token
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAppAccessToken(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            update app_access_token set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除app_access_token
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAppAccessToken(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            delete from app_access_token where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询app_access_token（支持完整查询操作符）
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
    func findAppAccessTokenByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AppAccessTokenPO> {
        let sql = StringBuilder()
        sql.append("select * from app_access_token")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AppAccessTokenPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询app_access_token
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAppAccessTokenByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AppAccessTokenPO> {
        let fromClause = executor.FROM<AppAccessTokenPO>()

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
        fromClause.page<AppAccessTokenPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的app_access_token）
     * @return 影响行数
     */
    func emptyRecycleBinAppAccessToken(): Int64 {
        executor.setSql('''
            delete from app_access_token where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
