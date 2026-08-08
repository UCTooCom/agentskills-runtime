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
import magic.app.models.uctoo.AgentLoopMetricsPO
import magic.log.LogUtils

/**
 * AgentLoopMetricsDAO - agent_loop_metrics数据访问接口
 *
 * 提供agent_loop_metrics表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AgentLoopMetricsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入agent_loop_metrics（id由数据库自动生成UUID）
     * @param entity AgentLoopMetricsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAgentLoopMetrics(entity: AgentLoopMetricsPO): String {
        executor.setSql('''
            insert into agent_loop_metrics(
                agent_id,
                session_id,
                evaluation_type,
                success_rate,
                avg_duration_ms,
                prompt_tokens,
                completion_tokens,
                total_tokens,
                tool_call_count,
                side_effect_count,
                metrics_detail,
                time_range_start,
                time_range_end,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.agentId)},
                ${arg(entity.sessionId)},
                ${arg(entity.evaluationType)},
                ${arg(entity.successRate)},
                ${arg(entity.avgDurationMs)},
                ${arg(entity.promptTokens)},
                ${arg(entity.completionTokens)},
                ${arg(entity.totalTokens)},
                ${arg(entity.toolCallCount)},
                ${arg(entity.sideEffectCount)},
                ${arg(entity.metricsDetail)},
                ${arg(entity.timeRangeStart)},
                ${arg(entity.timeRangeEnd)},
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
     * 根据ID查询agent_loop_metrics
     * @param id agent_loop_metricsID
     * @return agent_loop_metrics对象（Option类型）
     */
    func findAgentLoopMetricsById(id: String): Option<AgentLoopMetricsPO> {
        executor.setSql('''
            select id, agent_id, session_id, evaluation_type, success_rate, avg_duration_ms, prompt_tokens, completion_tokens, total_tokens, tool_call_count, side_effect_count, metrics_detail, time_range_start, time_range_end, creator, created_at, updated_at, deleted_at from agent_loop_metrics where id = ${arg(id)}
        ''').first<AgentLoopMetricsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新agent_loop_metrics
     * @param entity agent_loop_metrics对象
     * @return 影响行数
     */
    func updateAgentLoopMetrics(entity: AgentLoopMetricsPO): Int64 {
        executor.setSql('''
            update agent_loop_metrics set
                agent_id = ${arg(entity.agentId)},
                session_id = ${arg(entity.sessionId)},
                evaluation_type = ${arg(entity.evaluationType)},
                success_rate = ${arg(entity.successRate)},
                avg_duration_ms = ${arg(entity.avgDurationMs)},
                prompt_tokens = ${arg(entity.promptTokens)},
                completion_tokens = ${arg(entity.completionTokens)},
                total_tokens = ${arg(entity.totalTokens)},
                tool_call_count = ${arg(entity.toolCallCount)},
                side_effect_count = ${arg(entity.sideEffectCount)},
                metrics_detail = ${arg(entity.metricsDetail)},
                time_range_start = ${arg(entity.timeRangeStart)},
                time_range_end = ${arg(entity.timeRangeEnd)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除agent_loop_metrics
     * @param id agent_loop_metricsID
     * @return 影响行数
     */
    func softDeleteAgentLoopMetricsById(id: String): Int64 {
        executor.setSql('''
            update agent_loop_metrics set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的agent_loop_metrics
     * @param id agent_loop_metricsID
     * @return 影响行数
     */
    func restoreAgentLoopMetricsById(id: String): Int64 {
        executor.setSql('''
            update agent_loop_metrics set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除agent_loop_metrics
     * @param id agent_loop_metricsID
     * @return 影响行数
     */
    func deleteAgentLoopMetricsById(id: String): Int64 {
        executor.setSql('''
            delete from agent_loop_metrics where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有agent_loop_metrics
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAgentLoopMetricsPage(page: Int64, size: Int64): Pagination<AgentLoopMetricsPO> {
        executor.page<AgentLoopMetricsPO>('''
            select id, agent_id, session_id, evaluation_type, success_rate, avg_duration_ms, prompt_tokens, completion_tokens, total_tokens, tool_call_count, side_effect_count, metrics_detail, time_range_start, time_range_end, creator, created_at, updated_at, deleted_at from agent_loop_metrics order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询agent_loop_metrics列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentLoopMetricsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AgentLoopMetricsPO> {
        executor.page<AgentLoopMetricsPO>('''
            select id, agent_id, session_id, evaluation_type, success_rate, avg_duration_ms, prompt_tokens, completion_tokens, total_tokens, tool_call_count, side_effect_count, metrics_detail, time_range_start, time_range_end, creator, created_at, updated_at, deleted_at from agent_loop_metrics where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有agent_loop_metrics（不分页）
     * @return agent_loop_metrics列表
     */
    func listAllAgentLoopMetrics(): ArrayList<AgentLoopMetricsPO> {
        executor.setSql('''
            select id, agent_id, session_id, evaluation_type, success_rate, avg_duration_ms, prompt_tokens, completion_tokens, total_tokens, tool_call_count, side_effect_count, metrics_detail, time_range_start, time_range_end, creator, created_at, updated_at, deleted_at from agent_loop_metrics order by created_at desc
        ''').list<AgentLoopMetricsPO>()
    }

    /**
     * 批量查询agent_loop_metrics
     * @param ids ID列表
     * @return agent_loop_metrics列表
     */
    func findAgentLoopMetricsByIds(ids: ArrayList<String>): ArrayList<AgentLoopMetricsPO> {
        if (ids.isEmpty()) {
            return ArrayList<AgentLoopMetricsPO>()
        }
        executor.setSql('''
            select id, agent_id, session_id, evaluation_type, success_rate, avg_duration_ms, prompt_tokens, completion_tokens, total_tokens, tool_call_count, side_effect_count, metrics_detail, time_range_start, time_range_end, creator, created_at, updated_at, deleted_at from agent_loop_metrics where id ${IN(ids)}
        ''').list<AgentLoopMetricsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的agent_loop_metrics数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAgentLoopMetricsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from agent_loop_metrics where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有agent_loop_metrics数量
     * @return 数量
     */
    func countAllAgentLoopMetrics(): Int64 {
        executor.setSql('''
            select count(*) from agent_loop_metrics
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询agent_loop_metrics列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentLoopMetricsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AgentLoopMetricsPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, session_id, evaluation_type, success_rate, avg_duration_ms, prompt_tokens, completion_tokens, total_tokens, tool_call_count, side_effect_count, metrics_detail, time_range_start, time_range_end, creator, created_at, updated_at, deleted_at from agent_loop_metrics where 1=1")

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

        executor.page<AgentLoopMetricsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除agent_loop_metrics
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAgentLoopMetrics(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update agent_loop_metrics set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除agent_loop_metrics
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAgentLoopMetrics(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from agent_loop_metrics where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询agent_loop_metrics（支持完整查询操作符）
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
    func findAgentLoopMetricsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentLoopMetricsPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, session_id, evaluation_type, success_rate, avg_duration_ms, prompt_tokens, completion_tokens, total_tokens, tool_call_count, side_effect_count, metrics_detail, time_range_start, time_range_end, creator, created_at, updated_at, deleted_at from agent_loop_metrics")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AgentLoopMetricsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询agent_loop_metrics
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentLoopMetricsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentLoopMetricsPO> {
        let fromClause = executor.FROM<AgentLoopMetricsPO>()

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
        fromClause.page<AgentLoopMetricsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_loop_metrics）
     * @return 影响行数
     */
    func emptyRecycleBinAgentLoopMetrics(): Int64 {
        executor.setSql('''
            delete from agent_loop_metrics where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
