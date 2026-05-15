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
import magic.app.models.uctoo.I18PO
import magic.log.LogUtils

/**
 * I18DAO - i18数据访问接口
 *
 * 提供i18表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface I18DAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入i18（id由数据库自动生成UUID）
     * @param entity I18PO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertI18(entity: I18PO): String {
        executor.setSql('''
            insert into i18(
                key,
                content,
                lang_id,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.key)},
                ${arg(entity.content)},
                ${arg(entity.langId)},
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
     * 根据ID查询i18
     * @param id i18ID
     * @return i18对象（Option类型）
     */
    func findI18ById(id: String): Option<I18PO> {
        executor.setSql('''
            select * from i18 where id = ${arg(id)}
        ''').first<I18PO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新i18
     * @param entity i18对象
     * @return 影响行数
     */
    func updateI18(entity: I18PO): Int64 {
        executor.setSql('''
            update i18 set
                key = ${arg(entity.key)},
                content = ${arg(entity.content)},
                lang_id = ${arg(entity.langId)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除i18
     * @param id i18ID
     * @return 影响行数
     */
    func softDeleteI18ById(id: String): Int64 {
        executor.setSql('''
            update i18 set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的i18
     * @param id i18ID
     * @return 影响行数
     */
    func restoreI18ById(id: String): Int64 {
        executor.setSql('''
            update i18 set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除i18
     * @param id i18ID
     * @return 影响行数
     */
    func deleteI18ById(id: String): Int64 {
        executor.setSql('''
            delete from i18 where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有i18
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllI18Page(page: Int64, size: Int64): Pagination<I18PO> {
        executor.page<I18PO>('''
            select * from i18 order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询i18列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findI18ByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<I18PO> {
        executor.page<I18PO>('''
            select * from i18 where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有i18（不分页）
     * @return i18列表
     */
    func listAllI18(): ArrayList<I18PO> {
        executor.setSql('''
            select * from i18 order by created_at desc
        ''').list<I18PO>()
    }

    /**
     * 批量查询i18
     * @param ids ID列表
     * @return i18列表
     */
    func findI18ByIds(ids: ArrayList<String>): ArrayList<I18PO> {
        executor.setSql('''
            select * from i18 where id ${IN(ids)}
        ''').list<I18PO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的i18数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countI18ByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from i18 where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有i18数量
     * @return 数量
     */
    func countAllI18(): Int64 {
        executor.setSql('''
            select count(*) from i18
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询i18列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findI18ByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<I18PO> {
        let sql = StringBuilder()
        sql.append("select * from i18 where 1=1")

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

        executor.page<I18PO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除i18
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteI18(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            update i18 set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除i18
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteI18(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            delete from i18 where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询i18（支持完整查询操作符）
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
    func findI18ByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<I18PO> {
        let sql = StringBuilder()
        sql.append("select * from i18")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<I18PO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询i18
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findI18ByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<I18PO> {
        let fromClause = executor.FROM<I18PO>()

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
        fromClause.page<I18PO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的i18）
     * @return 影响行数
     */
    func emptyRecycleBinI18(): Int64 {
        executor.setSql('''
            delete from i18 where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 根据语言ID查询i18条目
     * @param langId 语言ID
     * @return i18条目列表
     */
    func findI18ByLangId(langId: String): ArrayList<I18PO> {
        executor.setSql('''
            select * from i18 where lang_id = ${arg(langId)} and deleted_at is null
        ''').list<I18PO>()
    }
}
