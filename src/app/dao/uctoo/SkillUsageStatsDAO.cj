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
import magic.app.models.uctoo.SkillUsageStatsPO
import magic.log.LogUtils

/**
 * SkillUsageStatsDAO - skill_usage_stats数据访问接口
 *
 * 提供skill_usage_stats表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface SkillUsageStatsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入skill_usage_stats（id由数据库自动生成UUID）
     * @param entity SkillUsageStatsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertSkillUsageStats(entity: SkillUsageStatsPO): String {
        executor.setSql('''
            insert into skill_usage_stats(
                skill_name,
                use_count,
                view_count,
                modify_count,
                success_count,
                failure_count,
                state,
                avg_execution_time_ms,
                user_rating,
                last_used_at,
                stats_detail,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.skillName)},
                ${arg(entity.useCount)},
                ${arg(entity.viewCount)},
                ${arg(entity.modifyCount)},
                ${arg(entity.successCount)},
                ${arg(entity.failureCount)},
                ${arg(entity.state)},
                ${arg(entity.avgExecutionTimeMs)},
                ${arg(entity.userRating)},
                ${arg(entity.lastUsedAt)},
                ${arg(entity.statsDetail)},
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
     * 根据ID查询skill_usage_stats
     * @param id skill_usage_statsID
     * @return skill_usage_stats对象（Option类型）
     */
    func findSkillUsageStatsById(id: String): Option<SkillUsageStatsPO> {
        executor.setSql('''
            select id, skill_name, use_count, view_count, modify_count, success_count, failure_count, state, avg_execution_time_ms, user_rating, last_used_at, stats_detail, creator, created_at, updated_at, deleted_at from skill_usage_stats where id = ${arg(id)}
        ''').first<SkillUsageStatsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新skill_usage_stats
     * @param entity skill_usage_stats对象
     * @return 影响行数
     */
    func updateSkillUsageStats(entity: SkillUsageStatsPO): Int64 {
        executor.setSql('''
            update skill_usage_stats set
                skill_name = ${arg(entity.skillName)},
                use_count = ${arg(entity.useCount)},
                view_count = ${arg(entity.viewCount)},
                modify_count = ${arg(entity.modifyCount)},
                success_count = ${arg(entity.successCount)},
                failure_count = ${arg(entity.failureCount)},
                state = ${arg(entity.state)},
                avg_execution_time_ms = ${arg(entity.avgExecutionTimeMs)},
                user_rating = ${arg(entity.userRating)},
                last_used_at = ${arg(entity.lastUsedAt)},
                stats_detail = ${arg(entity.statsDetail)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除skill_usage_stats
     * @param id skill_usage_statsID
     * @return 影响行数
     */
    func softDeleteSkillUsageStatsById(id: String): Int64 {
        executor.setSql('''
            update skill_usage_stats set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的skill_usage_stats
     * @param id skill_usage_statsID
     * @return 影响行数
     */
    func restoreSkillUsageStatsById(id: String): Int64 {
        executor.setSql('''
            update skill_usage_stats set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除skill_usage_stats
     * @param id skill_usage_statsID
     * @return 影响行数
     */
    func deleteSkillUsageStatsById(id: String): Int64 {
        executor.setSql('''
            delete from skill_usage_stats where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有skill_usage_stats
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllSkillUsageStatsPage(page: Int64, size: Int64): Pagination<SkillUsageStatsPO> {
        executor.page<SkillUsageStatsPO>('''
            select id, skill_name, use_count, view_count, modify_count, success_count, failure_count, state, avg_execution_time_ms, user_rating, last_used_at, stats_detail, creator, created_at, updated_at, deleted_at from skill_usage_stats order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询skill_usage_stats列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSkillUsageStatsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<SkillUsageStatsPO> {
        executor.page<SkillUsageStatsPO>('''
            select id, skill_name, use_count, view_count, modify_count, success_count, failure_count, state, avg_execution_time_ms, user_rating, last_used_at, stats_detail, creator, created_at, updated_at, deleted_at from skill_usage_stats where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有skill_usage_stats（不分页）
     * @return skill_usage_stats列表
     */
    func listAllSkillUsageStats(): ArrayList<SkillUsageStatsPO> {
        executor.setSql('''
            select id, skill_name, use_count, view_count, modify_count, success_count, failure_count, state, avg_execution_time_ms, user_rating, last_used_at, stats_detail, creator, created_at, updated_at, deleted_at from skill_usage_stats order by created_at desc
        ''').list<SkillUsageStatsPO>()
    }

    /**
     * 批量查询skill_usage_stats
     * @param ids ID列表
     * @return skill_usage_stats列表
     */
    func findSkillUsageStatsByIds(ids: ArrayList<String>): ArrayList<SkillUsageStatsPO> {
        if (ids.isEmpty()) {
            return ArrayList<SkillUsageStatsPO>()
        }
        executor.setSql('''
            select id, skill_name, use_count, view_count, modify_count, success_count, failure_count, state, avg_execution_time_ms, user_rating, last_used_at, stats_detail, creator, created_at, updated_at, deleted_at from skill_usage_stats where id ${IN(ids)}
        ''').list<SkillUsageStatsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的skill_usage_stats数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countSkillUsageStatsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from skill_usage_stats where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有skill_usage_stats数量
     * @return 数量
     */
    func countAllSkillUsageStats(): Int64 {
        executor.setSql('''
            select count(*) from skill_usage_stats
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询skill_usage_stats列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSkillUsageStatsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<SkillUsageStatsPO> {
        let sql = StringBuilder()
        sql.append("select id, skill_name, use_count, view_count, modify_count, success_count, failure_count, state, avg_execution_time_ms, user_rating, last_used_at, stats_detail, creator, created_at, updated_at, deleted_at from skill_usage_stats where 1=1")

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

        executor.page<SkillUsageStatsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除skill_usage_stats
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteSkillUsageStats(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update skill_usage_stats set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除skill_usage_stats
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteSkillUsageStats(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from skill_usage_stats where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询skill_usage_stats（支持完整查询操作符）
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
    func findSkillUsageStatsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SkillUsageStatsPO> {
        let sql = StringBuilder()
        sql.append("select id, skill_name, use_count, view_count, modify_count, success_count, failure_count, state, avg_execution_time_ms, user_rating, last_used_at, stats_detail, creator, created_at, updated_at, deleted_at from skill_usage_stats")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<SkillUsageStatsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询skill_usage_stats
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSkillUsageStatsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SkillUsageStatsPO> {
        let fromClause = executor.FROM<SkillUsageStatsPO>()

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
        fromClause.page<SkillUsageStatsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的skill_usage_stats）
     * @return 影响行数
     */
    func emptyRecycleBinSkillUsageStats(): Int64 {
        executor.setSql('''
            delete from skill_usage_stats where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
