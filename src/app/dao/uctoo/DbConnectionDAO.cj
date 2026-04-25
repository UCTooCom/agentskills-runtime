/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.DbConnectionPO
import magic.log.LogUtils

/**
 * DbConnectionDAO - db_connection数据访问接口
 *
 * 提供db_connection表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface DbConnectionDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入db_connection（id由数据库自动生成UUID）
     * @param entity DbConnectionPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertDbConnection(entity: DbConnectionPO): String {
        executor.setSql('''
            insert into db_connection(
                user,
                password,
                host,
                port,
                database_name,
                ssl,
                creator,
                created_at,
                updated_at,
                deleted_at,
                provider,
                type
            ) values(
${arg(entity.user)},
                ${arg(entity.password)},
                ${arg(entity.host)},
                ${arg(entity.port)},
                ${arg(entity.databaseName)},
                ${arg(entity.ssl)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.provider)},
                ${arg(entity.typeVal)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询db_connection
     * @param id db_connectionID
     * @return db_connection对象（Option类型）
     */
    func findDbConnectionById(id: String): Option<DbConnectionPO> {
        executor.setSql('''
            select * from db_connection where id = ${arg(id)}
        ''').first<DbConnectionPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新db_connection
     * @param entity db_connection对象
     * @return 影响行数
     */
    func updateDbConnection(entity: DbConnectionPO): Int64 {
        executor.setSql('''
            update db_connection set
                user = ${arg(entity.user)},
                password = ${arg(entity.password)},
                host = ${arg(entity.host)},
                port = ${arg(entity.port)},
                database_name = ${arg(entity.databaseName)},
                ssl = ${arg(entity.ssl)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                provider = ${arg(entity.provider)},
                type = ${arg(entity.typeVal)}
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除db_connection
     * @param id db_connectionID
     * @return 影响行数
     */
    func softDeleteDbConnectionById(id: String): Int64 {
        executor.setSql('''
            update db_connection set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的db_connection
     * @param id db_connectionID
     * @return 影响行数
     */
    func restoreDbConnectionById(id: String): Int64 {
        executor.setSql('''
            update db_connection set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除db_connection
     * @param id db_connectionID
     * @return 影响行数
     */
    func deleteDbConnectionById(id: String): Int64 {
        executor.setSql('''
            delete from db_connection where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有db_connection
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllDbConnectionPage(page: Int64, size: Int64): Pagination<DbConnectionPO> {
        executor.page<DbConnectionPO>('''
            select * from db_connection order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询db_connection列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDbConnectionByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<DbConnectionPO> {
        executor.page<DbConnectionPO>('''
            select * from db_connection where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有db_connection（不分页）
     * @return db_connection列表
     */
    func listAllDbConnection(): ArrayList<DbConnectionPO> {
        executor.setSql('''
            select * from db_connection order by created_at desc
        ''').list<DbConnectionPO>()
    }

    /**
     * 批量查询db_connection
     * @param ids ID列表
     * @return db_connection列表
     */
    func findDbConnectionByIds(ids: ArrayList<String>): ArrayList<DbConnectionPO> {
        executor.setSql('''
            select * from db_connection where id ${IN(ids)}
        ''').list<DbConnectionPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的db_connection数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countDbConnectionByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from db_connection where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有db_connection数量
     * @return 数量
     */
    func countAllDbConnection(): Int64 {
        executor.setSql('''
            select count(*) from db_connection
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询db_connection列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDbConnectionByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<DbConnectionPO> {
        let sql = StringBuilder()
        sql.append("select * from db_connection where 1=1")

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

        executor.page<DbConnectionPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除db_connection
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteDbConnection(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            update db_connection set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除db_connection
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteDbConnection(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            delete from db_connection where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询db_connection（支持完整查询操作符）
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
    func findDbConnectionByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<DbConnectionPO> {
        let sql = StringBuilder()
        sql.append("select * from db_connection")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<DbConnectionPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询db_connection
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDbConnectionByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<DbConnectionPO> {
        let fromClause = executor.FROM<DbConnectionPO>()

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
        fromClause.page<DbConnectionPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的db_connection）
     * @return 影响行数
     */
    func emptyRecycleBinDbConnection(): Int64 {
        executor.setSql('''
            delete from db_connection where deleted_at is not null
        ''').delete
    }

    //#endregion AutoCreateCode

    // ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 根据数据库名称查询db_connection
     * @param databaseName 数据库名称
     * @return db_connection列表
     */
    func findByDatabaseName(databaseName: String): ArrayList<DbConnectionPO> {
        executor.setSql('''
            select * from db_connection where database_name = ${arg(databaseName)} and deleted_at is null order by created_at desc
        ''').list<DbConnectionPO>()
    }
}
