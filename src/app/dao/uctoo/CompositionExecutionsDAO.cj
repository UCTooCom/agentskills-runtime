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
import magic.app.models.uctoo.CompositionExecutionsPO
import magic.log.LogUtils

/**
 * CompositionExecutionsDAO - composition_executions数据访问接口
 *
 * 提供composition_executions表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface CompositionExecutionsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入composition_executions（id由数据库自动生成UUID）
     * @param entity CompositionExecutionsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertCompositionExecutions(entity: CompositionExecutionsPO): String {
        executor.setSql('''
            insert into composition_executions(
                composition_id,
                status,
                step_results,
                final_output,
                cache_hits,
                duration_ms,
                creator,
                created_at,
                updated_at,
                completed_at,
                deleted_at
            ) values(
${arg(entity.compositionId)},
                ${arg(entity.status)},
                ${arg(entity.stepResults)},
                ${arg(entity.finalOutput)},
                ${arg(entity.cacheHits)},
                ${arg(entity.durationMs)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.completedAt)},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询composition_executions
     * @param id composition_executionsID
     * @return composition_executions对象（Option类型）
     */
    func findCompositionExecutionsById(id: String): Option<CompositionExecutionsPO> {
        executor.setSql('''
            select id, composition_id, status, step_results, final_output, cache_hits, duration_ms, creator, created_at, updated_at, completed_at, deleted_at from composition_executions where id = ${arg(id)}
        ''').first<CompositionExecutionsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新composition_executions
     * @param entity composition_executions对象
     * @return 影响行数
     */
    func updateCompositionExecutions(entity: CompositionExecutionsPO): Int64 {
        executor.setSql('''
            update composition_executions set
                composition_id = ${arg(entity.compositionId)},
                status = ${arg(entity.status)},
                step_results = ${arg(entity.stepResults)},
                final_output = ${arg(entity.finalOutput)},
                cache_hits = ${arg(entity.cacheHits)},
                duration_ms = ${arg(entity.durationMs)},
                creator = ${arg(entity.creator)},
                completed_at = ${arg(entity.completedAt)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除composition_executions
     * @param id composition_executionsID
     * @return 影响行数
     */
    func softDeleteCompositionExecutionsById(id: String): Int64 {
        executor.setSql('''
            update composition_executions set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的composition_executions
     * @param id composition_executionsID
     * @return 影响行数
     */
    func restoreCompositionExecutionsById(id: String): Int64 {
        executor.setSql('''
            update composition_executions set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除composition_executions
     * @param id composition_executionsID
     * @return 影响行数
     */
    func deleteCompositionExecutionsById(id: String): Int64 {
        executor.setSql('''
            delete from composition_executions where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有composition_executions
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllCompositionExecutionsPage(page: Int64, size: Int64): Pagination<CompositionExecutionsPO> {
        executor.page<CompositionExecutionsPO>('''
            select id, composition_id, status, step_results, final_output, cache_hits, duration_ms, creator, created_at, updated_at, completed_at, deleted_at from composition_executions order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询composition_executions列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCompositionExecutionsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<CompositionExecutionsPO> {
        executor.page<CompositionExecutionsPO>('''
            select id, composition_id, status, step_results, final_output, cache_hits, duration_ms, creator, created_at, updated_at, completed_at, deleted_at from composition_executions where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有composition_executions（不分页）
     * @return composition_executions列表
     */
    func listAllCompositionExecutions(): ArrayList<CompositionExecutionsPO> {
        executor.setSql('''
            select id, composition_id, status, step_results, final_output, cache_hits, duration_ms, creator, created_at, updated_at, completed_at, deleted_at from composition_executions order by created_at desc
        ''').list<CompositionExecutionsPO>()
    }

    /**
     * 批量查询composition_executions
     * @param ids ID列表
     * @return composition_executions列表
     */
    func findCompositionExecutionsByIds(ids: ArrayList<String>): ArrayList<CompositionExecutionsPO> {
        if (ids.isEmpty()) {
            return ArrayList<CompositionExecutionsPO>()
        }
        executor.setSql('''
            select id, composition_id, status, step_results, final_output, cache_hits, duration_ms, creator, created_at, updated_at, completed_at, deleted_at from composition_executions where id ${IN(ids)}
        ''').list<CompositionExecutionsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的composition_executions数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countCompositionExecutionsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from composition_executions where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有composition_executions数量
     * @return 数量
     */
    func countAllCompositionExecutions(): Int64 {
        executor.setSql('''
            select count(*) from composition_executions
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询composition_executions列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCompositionExecutionsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<CompositionExecutionsPO> {
        let sql = StringBuilder()
        sql.append("select id, composition_id, status, step_results, final_output, cache_hits, duration_ms, creator, created_at, updated_at, completed_at, deleted_at from composition_executions where 1=1")

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

        executor.page<CompositionExecutionsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除composition_executions
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteCompositionExecutions(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update composition_executions set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除composition_executions
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteCompositionExecutions(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from composition_executions where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询composition_executions（支持完整查询操作符）
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
    func findCompositionExecutionsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<CompositionExecutionsPO> {
        let sql = StringBuilder()
        sql.append("select id, composition_id, status, step_results, final_output, cache_hits, duration_ms, creator, created_at, updated_at, completed_at, deleted_at from composition_executions")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<CompositionExecutionsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询composition_executions
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCompositionExecutionsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<CompositionExecutionsPO> {
        let fromClause = executor.FROM<CompositionExecutionsPO>()

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
        fromClause.page<CompositionExecutionsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的composition_executions）
     * @return 影响行数
     */
    func emptyRecycleBinCompositionExecutions(): Int64 {
        executor.setSql('''
            delete from composition_executions where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
