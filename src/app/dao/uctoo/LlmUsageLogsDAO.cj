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
import magic.app.models.uctoo.LlmUsageLogsPO
import magic.log.LogUtils

/**
 * LlmUsageLogsDAO - llm_usage_logs数据访问接口
 *
 * 提供llm_usage_logs表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface LlmUsageLogsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入llm_usage_logs（id由数据库自动生成UUID）
     * @param entity LlmUsageLogsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLlmUsageLogs(entity: LlmUsageLogsPO): String {
        executor.setSql('''
            insert into llm_usage_logs(
                agent_id,
                task_id,
                provider,
                model,
                model_id,
                prompt_tokens,
                completion_tokens,
                total_tokens,
                time_cost_ms,
                request_type,
                is_streaming,
                tool_calls_count,
                user_id,
                session_id,
                cost_amount,
                cost_currency,
                rate_prompt,
                rate_completion,
                request_id,
                error_message,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.agentId)},
                ${arg(entity.taskId)},
                ${arg(entity.provider)},
                ${arg(entity.model)},
                ${arg(entity.modelId)},
                ${arg(entity.promptTokens)},
                ${arg(entity.completionTokens)},
                ${arg(entity.totalTokens)},
                ${arg(entity.timeCostMs)},
                ${arg(entity.requestType)},
                ${arg(entity.isStreaming)},
                ${arg(entity.toolCallsCount)},
                ${arg(entity.userId)},
                ${arg(entity.sessionId)},
                ${arg(entity.costAmount)},
                ${arg(entity.costCurrency)},
                ${arg(entity.ratePrompt)},
                ${arg(entity.rateCompletion)},
                ${arg(entity.requestId)},
                ${arg(entity.errorMessage)},
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
     * 根据ID查询llm_usage_logs
     * @param id llm_usage_logsID
     * @return llm_usage_logs对象（Option类型）
     */
    func findLlmUsageLogsById(id: String): Option<LlmUsageLogsPO> {
        executor.setSql('''
            select id, agent_id, task_id, provider, model, model_id, prompt_tokens, completion_tokens, total_tokens, time_cost_ms, request_type, is_streaming, tool_calls_count, user_id, session_id, cost_amount, cost_currency, rate_prompt, rate_completion, request_id, error_message, creator, created_at, updated_at, deleted_at from llm_usage_logs where id = ${arg(id)}
        ''').first<LlmUsageLogsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新llm_usage_logs
     * @param entity llm_usage_logs对象
     * @return 影响行数
     */
    func updateLlmUsageLogs(entity: LlmUsageLogsPO): Int64 {
        executor.setSql('''
            update llm_usage_logs set
                agent_id = ${arg(entity.agentId)},
                task_id = ${arg(entity.taskId)},
                provider = ${arg(entity.provider)},
                model = ${arg(entity.model)},
                model_id = ${arg(entity.modelId)},
                prompt_tokens = ${arg(entity.promptTokens)},
                completion_tokens = ${arg(entity.completionTokens)},
                total_tokens = ${arg(entity.totalTokens)},
                time_cost_ms = ${arg(entity.timeCostMs)},
                request_type = ${arg(entity.requestType)},
                is_streaming = ${arg(entity.isStreaming)},
                tool_calls_count = ${arg(entity.toolCallsCount)},
                user_id = ${arg(entity.userId)},
                session_id = ${arg(entity.sessionId)},
                cost_amount = ${arg(entity.costAmount)},
                cost_currency = ${arg(entity.costCurrency)},
                rate_prompt = ${arg(entity.ratePrompt)},
                rate_completion = ${arg(entity.rateCompletion)},
                request_id = ${arg(entity.requestId)},
                error_message = ${arg(entity.errorMessage)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除llm_usage_logs
     * @param id llm_usage_logsID
     * @return 影响行数
     */
    func softDeleteLlmUsageLogsById(id: String): Int64 {
        executor.setSql('''
            update llm_usage_logs set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的llm_usage_logs
     * @param id llm_usage_logsID
     * @return 影响行数
     */
    func restoreLlmUsageLogsById(id: String): Int64 {
        executor.setSql('''
            update llm_usage_logs set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除llm_usage_logs
     * @param id llm_usage_logsID
     * @return 影响行数
     */
    func deleteLlmUsageLogsById(id: String): Int64 {
        executor.setSql('''
            delete from llm_usage_logs where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有llm_usage_logs
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLlmUsageLogsPage(page: Int64, size: Int64): Pagination<LlmUsageLogsPO> {
        executor.page<LlmUsageLogsPO>('''
            select id, agent_id, task_id, provider, model, model_id, prompt_tokens, completion_tokens, total_tokens, time_cost_ms, request_type, is_streaming, tool_calls_count, user_id, session_id, cost_amount, cost_currency, rate_prompt, rate_completion, request_id, error_message, creator, created_at, updated_at, deleted_at from llm_usage_logs order by created_at desc
        ''', size, page: page)
    }

    /**
      * 分页查询llm_usage_logs列表（按创建者）
      * @param creator 创建者ID
      * @param page 页码（从1开始）
      * @param size 每页大小
      * @return 分页结果
      */
    func findLlmUsageLogsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LlmUsageLogsPO> {
        executor.page<LlmUsageLogsPO>('''
            select id, agent_id, task_id, provider, model, model_id, prompt_tokens, completion_tokens, total_tokens, time_cost_ms, request_type, is_streaming, tool_calls_count, user_id, session_id, cost_amount, cost_currency, rate_prompt, rate_completion, request_id, error_message, creator, created_at, updated_at, deleted_at from llm_usage_logs where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有llm_usage_logs（不分页）
     * @return llm_usage_logs列表
     */
    func listAllLlmUsageLogs(): ArrayList<LlmUsageLogsPO> {
        executor.setSql('''
            select id, agent_id, task_id, provider, model, model_id, prompt_tokens, completion_tokens, total_tokens, time_cost_ms, request_type, is_streaming, tool_calls_count, user_id, session_id, cost_amount, cost_currency, rate_prompt, rate_completion, request_id, error_message, creator, created_at, updated_at, deleted_at from llm_usage_logs order by created_at desc
        ''').list<LlmUsageLogsPO>()
    }

    /**
      * 批量查询llm_usage_logs
      * @param ids ID列表
      * @return llm_usage_logs列表
      */
    func findLlmUsageLogsByIds(ids: ArrayList<String>): ArrayList<LlmUsageLogsPO> {
        if (ids.isEmpty()) {
            return ArrayList<LlmUsageLogsPO>()
        }
        executor.setSql('''
            select id, agent_id, task_id, provider, model, model_id, prompt_tokens, completion_tokens, total_tokens, time_cost_ms, request_type, is_streaming, tool_calls_count, user_id, session_id, cost_amount, cost_currency, rate_prompt, rate_completion, request_id, error_message, creator, created_at, updated_at, deleted_at from llm_usage_logs where id ${IN(ids)}
        ''').list<LlmUsageLogsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的llm_usage_logs数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLlmUsageLogsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from llm_usage_logs where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有llm_usage_logs数量
     * @return 数量
     */
    func countAllLlmUsageLogs(): Int64 {
        executor.setSql('''
            select count(*) from llm_usage_logs
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询llm_usage_logs列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmUsageLogsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LlmUsageLogsPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, task_id, provider, model, model_id, prompt_tokens, completion_tokens, total_tokens, time_cost_ms, request_type, is_streaming, tool_calls_count, user_id, session_id, cost_amount, cost_currency, rate_prompt, rate_completion, request_id, error_message, creator, created_at, updated_at, deleted_at from llm_usage_logs where 1=1")

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

        executor.page<LlmUsageLogsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除llm_usage_logs
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLlmUsageLogs(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update llm_usage_logs set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除llm_usage_logs
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLlmUsageLogs(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from llm_usage_logs where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询llm_usage_logs（支持完整查询操作符）
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
    func findLlmUsageLogsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmUsageLogsPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, task_id, provider, model, model_id, prompt_tokens, completion_tokens, total_tokens, time_cost_ms, request_type, is_streaming, tool_calls_count, user_id, session_id, cost_amount, cost_currency, rate_prompt, rate_completion, request_id, error_message, creator, created_at, updated_at, deleted_at from llm_usage_logs")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LlmUsageLogsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询llm_usage_logs
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmUsageLogsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmUsageLogsPO> {
        let fromClause = executor.FROM<LlmUsageLogsPO>()

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
        fromClause.page<LlmUsageLogsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的llm_usage_logs）
     * @return 影响行数
     */
    func emptyRecycleBinLlmUsageLogs(): Int64 {
        executor.setSql('''
            delete from llm_usage_logs where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
