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
import magic.app.models.uctoo.AgentMemoriesPO
import magic.log.LogUtils

/**
 * AgentMemoriesDAO - agent_memories数据访问接口
 *
 * 提供agent_memories表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AgentMemoriesDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入agent_memories（id由数据库自动生成UUID）
     * @param entity AgentMemoriesPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAgentMemories(entity: AgentMemoriesPO): String {
        executor.setSql('''
            insert into agent_memories(
                agent_id,
                content,
                embedding_vector,
                scope,
                weight,
                tags,
                metadata,
                task_id,
                session_id,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.agentId)},
                ${arg(entity.content)},
                ${arg(entity.embeddingVector)},
                ${arg(entity.scope)},
                ${arg(entity.weight)},
                ${arg(entity.tags)},
                ${arg(entity.metadata)},
                ${arg(entity.taskId)},
                ${arg(entity.sessionId)},
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
     * 根据ID查询agent_memories
     * @param id agent_memoriesID
     * @return agent_memories对象（Option类型）
     */
    func findAgentMemoriesById(id: String): Option<AgentMemoriesPO> {
        executor.setSql('''
            select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at from agent_memories where id = ${arg(id)}
        ''').first<AgentMemoriesPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新agent_memories
     * @param entity agent_memories对象
     * @return 影响行数
     */
    func updateAgentMemories(entity: AgentMemoriesPO): Int64 {
        executor.setSql('''
            update agent_memories set
                agent_id = ${arg(entity.agentId)},
                content = ${arg(entity.content)},
                embedding_vector = ${arg(entity.embeddingVector)},
                scope = ${arg(entity.scope)},
                weight = ${arg(entity.weight)},
                tags = ${arg(entity.tags)},
                metadata = ${arg(entity.metadata)},
                task_id = ${arg(entity.taskId)},
                session_id = ${arg(entity.sessionId)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除agent_memories
     * @param id agent_memoriesID
     * @return 影响行数
     */
    func softDeleteAgentMemoriesById(id: String): Int64 {
        executor.setSql('''
            update agent_memories set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的agent_memories
     * @param id agent_memoriesID
     * @return 影响行数
     */
    func restoreAgentMemoriesById(id: String): Int64 {
        executor.setSql('''
            update agent_memories set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除agent_memories
     * @param id agent_memoriesID
     * @return 影响行数
     */
    func deleteAgentMemoriesById(id: String): Int64 {
        executor.setSql('''
            delete from agent_memories where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有agent_memories
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAgentMemoriesPage(page: Int64, size: Int64): Pagination<AgentMemoriesPO> {
        executor.page<AgentMemoriesPO>('''
            select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at from agent_memories order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询agent_memories列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentMemoriesByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AgentMemoriesPO> {
        executor.page<AgentMemoriesPO>('''
            select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at from agent_memories where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有agent_memories（不分页）
     * @return agent_memories列表
     */
    func listAllAgentMemories(): ArrayList<AgentMemoriesPO> {
        executor.setSql('''
            select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at from agent_memories order by created_at desc
        ''').list<AgentMemoriesPO>()
    }

    /**
     * 批量查询agent_memories
     * @param ids ID列表
     * @return agent_memories列表
     */
    func findAgentMemoriesByIds(ids: ArrayList<String>): ArrayList<AgentMemoriesPO> {
        if (ids.isEmpty()) {
            return ArrayList<AgentMemoriesPO>()
        }
        executor.setSql('''
            select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at from agent_memories where id ${IN(ids)}
        ''').list<AgentMemoriesPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的agent_memories数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAgentMemoriesByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from agent_memories where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有agent_memories数量
     * @return 数量
     */
    func countAllAgentMemories(): Int64 {
        executor.setSql('''
            select count(*) from agent_memories
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询agent_memories列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentMemoriesByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AgentMemoriesPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at from agent_memories where 1=1")

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

        executor.page<AgentMemoriesPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除agent_memories
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAgentMemories(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update agent_memories set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除agent_memories
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAgentMemories(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from agent_memories where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询agent_memories（支持完整查询操作符）
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
    func findAgentMemoriesByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentMemoriesPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at from agent_memories")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AgentMemoriesPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询agent_memories
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentMemoriesByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentMemoriesPO> {
        let fromClause = executor.FROM<AgentMemoriesPO>()

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
        fromClause.page<AgentMemoriesPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_memories）
     * @return 影响行数
     */
    func emptyRecycleBinAgentMemories(): Int64 {
        executor.setSql('''
            delete from agent_memories where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    func findByAgentIdAndScope(agentId: String, scope: String, page: Int64, size: Int64): Pagination<AgentMemoriesPO> {
        executor.page<AgentMemoriesPO>('''
            select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at
            from agent_memories
            where agent_id = ${arg(agentId)} and scope = ${arg(scope)} and deleted_at is null
            order by created_at desc
        ''', size, page: page)
    }

    func searchByContent(agentId: String, scope: String, keyword: String, limit: Int64): ArrayList<AgentMemoriesPO> {
        executor.setSql('''
            select id, agent_id, content, embedding_vector, scope, weight, tags, metadata, task_id, session_id, creator, created_at, updated_at, deleted_at
            from agent_memories
            where agent_id = ${arg(agentId)} and scope = ${arg(scope)} and deleted_at is null
                and content like ${arg('%' + keyword + '%')}
            order by weight desc, created_at desc
            limit ${arg(limit)}
        ''').list<AgentMemoriesPO>()
    }

    func softDeleteByAgentIdAndScope(agentId: String, scope: String): Int64 {
        executor.setSql('''
            update agent_memories set deleted_at = ${arg(DateTime.now())}
            where agent_id = ${arg(agentId)} and scope = ${arg(scope)} and deleted_at is null
        ''').update
    }
}
