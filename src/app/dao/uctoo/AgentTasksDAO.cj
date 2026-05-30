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
import magic.app.models.uctoo.AgentTasksPO
import magic.log.LogUtils

/**
 * AgentTasksDAO - agent_tasks数据访问接口
 *
 * 提供agent_tasks表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AgentTasksDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入agent_tasks（id由数据库自动生成UUID）
     * @param entity AgentTasksPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAgentTasks(entity: AgentTasksPO): String {
        executor.setSql('''
            insert into agent_tasks(
                agent_id,
                parent_task_id,
                status,
                priority,
                payload,
                result,
                error_message,
                creator,
                created_at,
                updated_at,
                completed_at,
                deleted_at
            ) values(
${arg(entity.agentId)},
                ${arg(entity.parentTaskId)},
                ${arg(entity.status)},
                ${arg(entity.priority)},
                ${arg(entity.payload)},
                ${arg(entity.result)},
                ${arg(entity.errorMessage)},
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
     * 根据ID查询agent_tasks
     * @param id agent_tasksID
     * @return agent_tasks对象（Option类型）
     */
    func findAgentTasksById(id: String): Option<AgentTasksPO> {
        executor.setSql('''
            select id, agent_id, parent_task_id, status, priority, payload, result, error_message, creator, created_at, updated_at, completed_at, deleted_at from agent_tasks where id = ${arg(id)}
        ''').first<AgentTasksPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新agent_tasks
     * @param entity agent_tasks对象
     * @return 影响行数
     */
    func updateAgentTasks(entity: AgentTasksPO): Int64 {
        executor.setSql('''
            update agent_tasks set
                agent_id = ${arg(entity.agentId)},
                parent_task_id = ${arg(entity.parentTaskId)},
                status = ${arg(entity.status)},
                priority = ${arg(entity.priority)},
                payload = ${arg(entity.payload)},
                result = ${arg(entity.result)},
                error_message = ${arg(entity.errorMessage)},
                creator = ${arg(entity.creator)},
                completed_at = ${arg(entity.completedAt)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除agent_tasks
     * @param id agent_tasksID
     * @return 影响行数
     */
    func softDeleteAgentTasksById(id: String): Int64 {
        executor.setSql('''
            update agent_tasks set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的agent_tasks
     * @param id agent_tasksID
     * @return 影响行数
     */
    func restoreAgentTasksById(id: String): Int64 {
        executor.setSql('''
            update agent_tasks set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除agent_tasks
     * @param id agent_tasksID
     * @return 影响行数
     */
    func deleteAgentTasksById(id: String): Int64 {
        executor.setSql('''
            delete from agent_tasks where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有agent_tasks
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAgentTasksPage(page: Int64, size: Int64): Pagination<AgentTasksPO> {
        executor.page<AgentTasksPO>('''
            select id, agent_id, parent_task_id, status, priority, payload, result, error_message, creator, created_at, updated_at, completed_at, deleted_at from agent_tasks order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询agent_tasks列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentTasksByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AgentTasksPO> {
        executor.page<AgentTasksPO>('''
            select id, agent_id, parent_task_id, status, priority, payload, result, error_message, creator, created_at, updated_at, completed_at, deleted_at from agent_tasks where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有agent_tasks（不分页）
     * @return agent_tasks列表
     */
    func listAllAgentTasks(): ArrayList<AgentTasksPO> {
        executor.setSql('''
            select id, agent_id, parent_task_id, status, priority, payload, result, error_message, creator, created_at, updated_at, completed_at, deleted_at from agent_tasks order by created_at desc
        ''').list<AgentTasksPO>()
    }

    /**
     * 批量查询agent_tasks
     * @param ids ID列表
     * @return agent_tasks列表
     */
    func findAgentTasksByIds(ids: ArrayList<String>): ArrayList<AgentTasksPO> {
        if (ids.isEmpty()) {
            return ArrayList<AgentTasksPO>()
        }
        executor.setSql('''
            select id, agent_id, parent_task_id, status, priority, payload, result, error_message, creator, created_at, updated_at, completed_at, deleted_at from agent_tasks where id ${IN(ids)}
        ''').list<AgentTasksPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的agent_tasks数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAgentTasksByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from agent_tasks where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有agent_tasks数量
     * @return 数量
     */
    func countAllAgentTasks(): Int64 {
        executor.setSql('''
            select count(*) from agent_tasks
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询agent_tasks列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentTasksByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AgentTasksPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, parent_task_id, status, priority, payload, result, error_message, creator, created_at, updated_at, completed_at, deleted_at from agent_tasks where 1=1")

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

        executor.page<AgentTasksPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除agent_tasks
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAgentTasks(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update agent_tasks set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除agent_tasks
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAgentTasks(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from agent_tasks where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询agent_tasks（支持完整查询操作符）
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
    func findAgentTasksByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentTasksPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, parent_task_id, status, priority, payload, result, error_message, creator, created_at, updated_at, completed_at, deleted_at from agent_tasks")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AgentTasksPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询agent_tasks
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentTasksByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentTasksPO> {
        let fromClause = executor.FROM<AgentTasksPO>()

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
        fromClause.page<AgentTasksPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_tasks）
     * @return 影响行数
     */
    func emptyRecycleBinAgentTasks(): Int64 {
        executor.setSql('''
            delete from agent_tasks where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
