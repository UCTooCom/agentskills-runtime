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
import magic.app.models.uctoo.SubAgentInvocationsPO
import magic.log.LogUtils

/**
 * SubAgentInvocationsDAO - sub_agent_invocations数据访问接口
 *
 * 提供sub_agent_invocations表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface SubAgentInvocationsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入sub_agent_invocations（id由数据库自动生成UUID）
     * @param entity SubAgentInvocationsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertSubAgentInvocations(entity: SubAgentInvocationsPO): String {
        executor.setSql('''
            insert into sub_agent_invocations(
                parent_task_id,
                task_id,
                agent_id,
                skill_name,
                stage,
                mode,
                input_json,
                output_json,
                status,
                duration_ms,
                error_message,
                contract_type,
                verify_passed,
                verify_errors,
                attempt,
                prompt_tokens,
                completion_tokens,
                total_tokens,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.parentTaskId)},
                ${arg(entity.taskId)},
                ${arg(entity.agentId)},
                ${arg(entity.skillName)},
                ${arg(entity.stage)},
                ${arg(entity.mode)},
                ${arg(entity.inputJson)},
                ${arg(entity.outputJson)},
                ${arg(entity.status)},
                ${arg(entity.durationMs)},
                ${arg(entity.errorMessage)},
                ${arg(entity.contractType)},
                ${arg(entity.verifyPassed)},
                ${arg(entity.verifyErrors)},
                ${arg(entity.attempt)},
                ${arg(entity.promptTokens)},
                ${arg(entity.completionTokens)},
                ${arg(entity.totalTokens)},
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
     * 根据ID查询sub_agent_invocations
     * @param id sub_agent_invocationsID
     * @return sub_agent_invocations对象（Option类型）
     */
    func findSubAgentInvocationsById(id: String): Option<SubAgentInvocationsPO> {
        executor.setSql('''
            select id, parent_task_id, task_id, agent_id, skill_name, stage, mode, input_json, output_json, status, duration_ms, error_message, contract_type, verify_passed, verify_errors, attempt, prompt_tokens, completion_tokens, total_tokens, creator, created_at, updated_at, deleted_at from sub_agent_invocations where id = ${arg(id)}
        ''').first<SubAgentInvocationsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新sub_agent_invocations
     * @param entity sub_agent_invocations对象
     * @return 影响行数
     */
    func updateSubAgentInvocations(entity: SubAgentInvocationsPO): Int64 {
        executor.setSql('''
            update sub_agent_invocations set
                parent_task_id = ${arg(entity.parentTaskId)},
                task_id = ${arg(entity.taskId)},
                agent_id = ${arg(entity.agentId)},
                skill_name = ${arg(entity.skillName)},
                stage = ${arg(entity.stage)},
                mode = ${arg(entity.mode)},
                input_json = ${arg(entity.inputJson)},
                output_json = ${arg(entity.outputJson)},
                status = ${arg(entity.status)},
                duration_ms = ${arg(entity.durationMs)},
                error_message = ${arg(entity.errorMessage)},
                contract_type = ${arg(entity.contractType)},
                verify_passed = ${arg(entity.verifyPassed)},
                verify_errors = ${arg(entity.verifyErrors)},
                attempt = ${arg(entity.attempt)},
                prompt_tokens = ${arg(entity.promptTokens)},
                completion_tokens = ${arg(entity.completionTokens)},
                total_tokens = ${arg(entity.totalTokens)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除sub_agent_invocations
     * @param id sub_agent_invocationsID
     * @return 影响行数
     */
    func softDeleteSubAgentInvocationsById(id: String): Int64 {
        executor.setSql('''
            update sub_agent_invocations set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的sub_agent_invocations
     * @param id sub_agent_invocationsID
     * @return 影响行数
     */
    func restoreSubAgentInvocationsById(id: String): Int64 {
        executor.setSql('''
            update sub_agent_invocations set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除sub_agent_invocations
     * @param id sub_agent_invocationsID
     * @return 影响行数
     */
    func deleteSubAgentInvocationsById(id: String): Int64 {
        executor.setSql('''
            delete from sub_agent_invocations where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有sub_agent_invocations
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllSubAgentInvocationsPage(page: Int64, size: Int64): Pagination<SubAgentInvocationsPO> {
        executor.page<SubAgentInvocationsPO>('''
            select id, parent_task_id, task_id, agent_id, skill_name, stage, mode, input_json, output_json, status, duration_ms, error_message, contract_type, verify_passed, verify_errors, attempt, prompt_tokens, completion_tokens, total_tokens, creator, created_at, updated_at, deleted_at from sub_agent_invocations order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询sub_agent_invocations列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSubAgentInvocationsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<SubAgentInvocationsPO> {
        executor.page<SubAgentInvocationsPO>('''
            select id, parent_task_id, task_id, agent_id, skill_name, stage, mode, input_json, output_json, status, duration_ms, error_message, contract_type, verify_passed, verify_errors, attempt, prompt_tokens, completion_tokens, total_tokens, creator, created_at, updated_at, deleted_at from sub_agent_invocations where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有sub_agent_invocations（不分页）
     * @return sub_agent_invocations列表
     */
    func listAllSubAgentInvocations(): ArrayList<SubAgentInvocationsPO> {
        executor.setSql('''
            select id, parent_task_id, task_id, agent_id, skill_name, stage, mode, input_json, output_json, status, duration_ms, error_message, contract_type, verify_passed, verify_errors, attempt, prompt_tokens, completion_tokens, total_tokens, creator, created_at, updated_at, deleted_at from sub_agent_invocations order by created_at desc
        ''').list<SubAgentInvocationsPO>()
    }

    /**
     * 批量查询sub_agent_invocations
     * @param ids ID列表
     * @return sub_agent_invocations列表
     */
    func findSubAgentInvocationsByIds(ids: ArrayList<String>): ArrayList<SubAgentInvocationsPO> {
        if (ids.isEmpty()) {
            return ArrayList<SubAgentInvocationsPO>()
        }
        executor.setSql('''
            select id, parent_task_id, task_id, agent_id, skill_name, stage, mode, input_json, output_json, status, duration_ms, error_message, contract_type, verify_passed, verify_errors, attempt, prompt_tokens, completion_tokens, total_tokens, creator, created_at, updated_at, deleted_at from sub_agent_invocations where id ${IN(ids)}
        ''').list<SubAgentInvocationsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的sub_agent_invocations数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countSubAgentInvocationsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from sub_agent_invocations where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有sub_agent_invocations数量
     * @return 数量
     */
    func countAllSubAgentInvocations(): Int64 {
        executor.setSql('''
            select count(*) from sub_agent_invocations
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询sub_agent_invocations列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSubAgentInvocationsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<SubAgentInvocationsPO> {
        let sql = StringBuilder()
        sql.append("select id, parent_task_id, task_id, agent_id, skill_name, stage, mode, input_json, output_json, status, duration_ms, error_message, contract_type, verify_passed, verify_errors, attempt, prompt_tokens, completion_tokens, total_tokens, creator, created_at, updated_at, deleted_at from sub_agent_invocations where 1=1")

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

        executor.page<SubAgentInvocationsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除sub_agent_invocations
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteSubAgentInvocations(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update sub_agent_invocations set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除sub_agent_invocations
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteSubAgentInvocations(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from sub_agent_invocations where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询sub_agent_invocations（支持完整查询操作符）
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
    func findSubAgentInvocationsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SubAgentInvocationsPO> {
        let sql = StringBuilder()
        sql.append("select id, parent_task_id, task_id, agent_id, skill_name, stage, mode, input_json, output_json, status, duration_ms, error_message, contract_type, verify_passed, verify_errors, attempt, prompt_tokens, completion_tokens, total_tokens, creator, created_at, updated_at, deleted_at from sub_agent_invocations")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<SubAgentInvocationsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询sub_agent_invocations
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSubAgentInvocationsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SubAgentInvocationsPO> {
        let fromClause = executor.FROM<SubAgentInvocationsPO>()

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
        fromClause.page<SubAgentInvocationsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的sub_agent_invocations）
     * @return 影响行数
     */
    func emptyRecycleBinSubAgentInvocations(): Int64 {
        executor.setSql('''
            delete from sub_agent_invocations where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
