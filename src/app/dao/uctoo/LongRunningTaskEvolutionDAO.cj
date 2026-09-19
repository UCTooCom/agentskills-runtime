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
import magic.app.models.uctoo.LongRunningTaskEvolutionPO
import magic.log.LogUtils

/**
 * LongRunningTaskEvolutionDAO - long_running_task_evolution数据访问接口
 *
 * 提供long_running_task_evolution表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface LongRunningTaskEvolutionDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入long_running_task_evolution（id由数据库自动生成UUID）
     * @param entity LongRunningTaskEvolutionPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLongRunningTaskEvolution(entity: LongRunningTaskEvolutionPO): String {
        executor.setSql('''
            insert into long_running_task_evolution(
                agent_id,
                round,
                root_cause,
                optimization_plan,
                anti_regression,
                skill_md_updates,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.agentId)},
                ${arg(entity.round)},
                ${arg(entity.rootCause)},
                ${arg(entity.optimizationPlan)},
                ${arg(entity.antiRegression)},
                ${arg(entity.skillMdUpdates)},
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
     * 根据ID查询long_running_task_evolution
     * @param id long_running_task_evolutionID
     * @return long_running_task_evolution对象（Option类型）
     */
    func findLongRunningTaskEvolutionById(id: String): Option<LongRunningTaskEvolutionPO> {
        executor.setSql('''
            select id, agent_id, round, root_cause, optimization_plan, anti_regression, skill_md_updates, creator, created_at, updated_at, deleted_at from long_running_task_evolution where id = ${arg(id)}
        ''').first<LongRunningTaskEvolutionPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新long_running_task_evolution
     * @param entity long_running_task_evolution对象
     * @return 影响行数
     */
    func updateLongRunningTaskEvolution(entity: LongRunningTaskEvolutionPO): Int64 {
        executor.setSql('''
            update long_running_task_evolution set
                agent_id = ${arg(entity.agentId)},
                round = ${arg(entity.round)},
                root_cause = ${arg(entity.rootCause)},
                optimization_plan = ${arg(entity.optimizationPlan)},
                anti_regression = ${arg(entity.antiRegression)},
                skill_md_updates = ${arg(entity.skillMdUpdates)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除long_running_task_evolution
     * @param id long_running_task_evolutionID
     * @return 影响行数
     */
    func softDeleteLongRunningTaskEvolutionById(id: String): Int64 {
        executor.setSql('''
            update long_running_task_evolution set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的long_running_task_evolution
     * @param id long_running_task_evolutionID
     * @return 影响行数
     */
    func restoreLongRunningTaskEvolutionById(id: String): Int64 {
        executor.setSql('''
            update long_running_task_evolution set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除long_running_task_evolution
     * @param id long_running_task_evolutionID
     * @return 影响行数
     */
    func deleteLongRunningTaskEvolutionById(id: String): Int64 {
        executor.setSql('''
            delete from long_running_task_evolution where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有long_running_task_evolution
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLongRunningTaskEvolutionPage(page: Int64, size: Int64): Pagination<LongRunningTaskEvolutionPO> {
        executor.page<LongRunningTaskEvolutionPO>('''
            select id, agent_id, round, root_cause, optimization_plan, anti_regression, skill_md_updates, creator, created_at, updated_at, deleted_at from long_running_task_evolution order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询long_running_task_evolution列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLongRunningTaskEvolutionByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LongRunningTaskEvolutionPO> {
        executor.page<LongRunningTaskEvolutionPO>('''
            select id, agent_id, round, root_cause, optimization_plan, anti_regression, skill_md_updates, creator, created_at, updated_at, deleted_at from long_running_task_evolution where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有long_running_task_evolution（不分页）
     * @return long_running_task_evolution列表
     */
    func listAllLongRunningTaskEvolution(): ArrayList<LongRunningTaskEvolutionPO> {
        executor.setSql('''
            select id, agent_id, round, root_cause, optimization_plan, anti_regression, skill_md_updates, creator, created_at, updated_at, deleted_at from long_running_task_evolution order by created_at desc
        ''').list<LongRunningTaskEvolutionPO>()
    }

    /**
     * 批量查询long_running_task_evolution
     * @param ids ID列表
     * @return long_running_task_evolution列表
     */
    func findLongRunningTaskEvolutionByIds(ids: ArrayList<String>): ArrayList<LongRunningTaskEvolutionPO> {
        if (ids.isEmpty()) {
            return ArrayList<LongRunningTaskEvolutionPO>()
        }
        executor.setSql('''
            select id, agent_id, round, root_cause, optimization_plan, anti_regression, skill_md_updates, creator, created_at, updated_at, deleted_at from long_running_task_evolution where id ${IN(ids)}
        ''').list<LongRunningTaskEvolutionPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的long_running_task_evolution数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLongRunningTaskEvolutionByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from long_running_task_evolution where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有long_running_task_evolution数量
     * @return 数量
     */
    func countAllLongRunningTaskEvolution(): Int64 {
        executor.setSql('''
            select count(*) from long_running_task_evolution
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询long_running_task_evolution列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLongRunningTaskEvolutionByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LongRunningTaskEvolutionPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, round, root_cause, optimization_plan, anti_regression, skill_md_updates, creator, created_at, updated_at, deleted_at from long_running_task_evolution where 1=1")

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

        executor.page<LongRunningTaskEvolutionPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除long_running_task_evolution
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLongRunningTaskEvolution(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update long_running_task_evolution set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除long_running_task_evolution
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLongRunningTaskEvolution(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from long_running_task_evolution where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询long_running_task_evolution（支持完整查询操作符）
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
    func findLongRunningTaskEvolutionByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LongRunningTaskEvolutionPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, round, root_cause, optimization_plan, anti_regression, skill_md_updates, creator, created_at, updated_at, deleted_at from long_running_task_evolution")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LongRunningTaskEvolutionPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询long_running_task_evolution
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLongRunningTaskEvolutionByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LongRunningTaskEvolutionPO> {
        let fromClause = executor.FROM<LongRunningTaskEvolutionPO>()

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
        fromClause.page<LongRunningTaskEvolutionPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的long_running_task_evolution）
     * @return 影响行数
     */
    func emptyRecycleBinLongRunningTaskEvolution(): Int64 {
        executor.setSql('''
            delete from long_running_task_evolution where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
