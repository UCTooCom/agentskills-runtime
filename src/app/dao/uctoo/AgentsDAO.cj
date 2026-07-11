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
import magic.app.models.uctoo.AgentsPO
import magic.log.LogUtils

/**
 * AgentsDAO - agents数据访问接口
 *
 * 提供agents表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AgentsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入agents（id由数据库自动生成UUID）
     * @param entity AgentsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAgents(entity: AgentsPO): String {
        executor.setSql('''
            insert into agents(
                name,
                agent_type,
                description,
                status,
                config,
                system_prompt,
                tools,
                model,
                parent_id,
                user_id,
                color,
                background,
                memory_scope,
                isolation_mode,
                max_turns,
                initial_prompt,
                creator,
                created_at,
                updated_at,
                deleted_at,
                version,
                author,
                permissions,
                source_path,
                sync_status,
                last_sync_at,
                aic,
                identity_status,
                aip_registered_at,
                capabilities,
                default_input_types,
                default_output_types,
                discoverable
            ) values(
${arg(entity.name)},
                ${arg(entity.agentType)},
                ${arg(entity.description)},
                ${arg(entity.status)},
                ${arg(entity.config)},
                ${arg(entity.systemPrompt)},
                ${arg(entity.tools)},
                ${arg(entity.model)},
                ${arg(entity.parentId)},
                ${arg(entity.userId)},
                ${arg(entity.color)},
                ${arg(entity.background)},
                ${arg(entity.memoryScope)},
                ${arg(entity.isolationMode)},
                ${arg(entity.maxTurns)},
                ${arg(entity.initialPrompt)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.version)},
                ${arg(entity.author)},
                ${arg(entity.permissions)},
                ${arg(entity.sourcePath)},
                ${arg(entity.syncStatus)},
                ${arg(entity.lastSyncAt)},
                ${arg(entity.aic)},
                ${arg(entity.identityStatus)},
                ${arg(entity.aipRegisteredAt)},
                ${arg(entity.capabilities)},
                ${arg(entity.defaultInputTypes)},
                ${arg(entity.defaultOutputTypes)},
                ${arg(entity.discoverable)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询agents
     * @param id agentsID
     * @return agents对象（Option类型）
     */
    func findAgentsById(id: String): Option<AgentsPO> {
        executor.setSql('''
            select * from agents where id = ${arg(id)}
        ''').first<AgentsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新agents
     * @param entity agents对象
     * @return 影响行数
     */
    func updateAgents(entity: AgentsPO): Int64 {
        executor.setSql('''
            update agents set
                name = ${arg(entity.name)},
                agent_type = ${arg(entity.agentType)},
                description = ${arg(entity.description)},
                status = ${arg(entity.status)},
                config = ${arg(entity.config)},
                system_prompt = ${arg(entity.systemPrompt)},
                tools = ${arg(entity.tools)},
                model = ${arg(entity.model)},
                parent_id = ${arg(entity.parentId)},
                user_id = ${arg(entity.userId)},
                color = ${arg(entity.color)},
                background = ${arg(entity.background)},
                memory_scope = ${arg(entity.memoryScope)},
                isolation_mode = ${arg(entity.isolationMode)},
                max_turns = ${arg(entity.maxTurns)},
                initial_prompt = ${arg(entity.initialPrompt)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                version = ${arg(entity.version)},
                author = ${arg(entity.author)},
                permissions = ${arg(entity.permissions)},
                source_path = ${arg(entity.sourcePath)},
                sync_status = ${arg(entity.syncStatus)},
                last_sync_at = ${arg(entity.lastSyncAt)},
                aic = ${arg(entity.aic)},
                identity_status = ${arg(entity.identityStatus)},
                aip_registered_at = ${arg(entity.aipRegisteredAt)},
                capabilities = ${arg(entity.capabilities)},
                default_input_types = ${arg(entity.defaultInputTypes)},
                default_output_types = ${arg(entity.defaultOutputTypes)},
                discoverable = ${arg(entity.discoverable)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除agents
     * @param id agentsID
     * @return 影响行数
     */
    func softDeleteAgentsById(id: String): Int64 {
        executor.setSql('''
            update agents set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的agents
     * @param id agentsID
     * @return 影响行数
     */
    func restoreAgentsById(id: String): Int64 {
        executor.setSql('''
            update agents set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除agents
     * @param id agentsID
     * @return 影响行数
     */
    func deleteAgentsById(id: String): Int64 {
        executor.setSql('''
            delete from agents where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有agents
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAgentsPage(page: Int64, size: Int64): Pagination<AgentsPO> {
        executor.page<AgentsPO>('''
            select id, name, agent_type, description, status, config, system_prompt, tools, model, parent_id, user_id, color, background, memory_scope, isolation_mode, max_turns, initial_prompt, creator, created_at, updated_at, deleted_at, version, author, permissions, source_path, sync_status, last_sync_at from agents order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询agents列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AgentsPO> {
        executor.page<AgentsPO>('''
            select id, name, agent_type, description, status, config, system_prompt, tools, model, parent_id, user_id, color, background, memory_scope, isolation_mode, max_turns, initial_prompt, creator, created_at, updated_at, deleted_at, version, author, permissions, source_path, sync_status, last_sync_at from agents where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有agents（不分页）
     * @return agents列表
     */
    func listAllAgents(): ArrayList<AgentsPO> {
        executor.setSql('''
            select id, name, agent_type, description, status, config, system_prompt, tools, model, parent_id, user_id, color, background, memory_scope, isolation_mode, max_turns, initial_prompt, creator, created_at, updated_at, deleted_at, version, author, permissions, source_path, sync_status, last_sync_at from agents order by created_at desc
        ''').list<AgentsPO>()
    }

    /**
     * 批量查询agents
     * @param ids ID列表
     * @return agents列表
     */
    func findAgentsByIds(ids: ArrayList<String>): ArrayList<AgentsPO> {
        if (ids.isEmpty()) {
            return ArrayList<AgentsPO>()
        }
        executor.setSql('''
            select id, name, agent_type, description, status, config, system_prompt, tools, model, parent_id, user_id, color, background, memory_scope, isolation_mode, max_turns, initial_prompt, creator, created_at, updated_at, deleted_at, version, author, permissions, source_path, sync_status, last_sync_at from agents where id ${IN(ids)}
        ''').list<AgentsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的agents数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAgentsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from agents where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有agents数量
     * @return 数量
     */
    func countAllAgents(): Int64 {
        executor.setSql('''
            select count(*) from agents
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询agents列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AgentsPO> {
        let sql = StringBuilder()
        sql.append("select id, name, agent_type, description, status, config, system_prompt, tools, model, parent_id, user_id, color, background, memory_scope, isolation_mode, max_turns, initial_prompt, creator, created_at, updated_at, deleted_at, version, author, permissions, source_path, sync_status, last_sync_at from agents where 1=1")

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

        executor.page<AgentsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除agents
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAgents(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update agents set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除agents
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAgents(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from agents where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询agents（支持完整查询操作符）
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
    func findAgentsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentsPO> {
        let sql = StringBuilder()
        sql.append("select id, name, agent_type, description, status, config, system_prompt, tools, model, parent_id, user_id, color, background, memory_scope, isolation_mode, max_turns, initial_prompt, creator, created_at, updated_at, deleted_at, version, author, permissions, source_path, sync_status, last_sync_at from agents")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AgentsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询agents
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentsPO> {
        let fromClause = executor.FROM<AgentsPO>()

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
        fromClause.page<AgentsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agents）
     * @return 影响行数
     */
    func emptyRecycleBinAgents(): Int64 {
        executor.setSql('''
            delete from agents where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    func findAgentsByAic(aic: String): Option<AgentsPO> {
        executor.setSql('''
            select * from agents where aic = ${arg(aic)} and deleted_at is null
        ''').first<AgentsPO>()
    }

    func findDiscoverableAgentsPage(page: Int64, size: Int64): Pagination<AgentsPO> {
        executor.page<AgentsPO>('''
            select * from agents where discoverable = true and deleted_at is null order by created_at desc
        ''', size, page: page)
    }

    func searchAgentsByNameOrDescription(keyword: String, page: Int64, size: Int64): Pagination<AgentsPO> {
        executor.page<AgentsPO>('''
            select * from agents where (name ilike ${arg('%' + keyword + '%')} or description ilike ${arg('%' + keyword + '%')}) and deleted_at is null order by created_at desc
        ''', size, page: page)
    }

    func searchAgentsBySkillKeyword(skillKeyword: String, page: Int64, size: Int64): Pagination<AgentsPO> {
        executor.page<AgentsPO>('''
            select a.* from agents a inner join agent_skills s on a.id = s.agent_id
            where (s.name ilike ${arg('%' + skillKeyword + '%')} or s.description ilike ${arg('%' + skillKeyword + '%')} or s.tags ilike ${arg('%' + skillKeyword + '%')})
            and a.deleted_at is null and s.deleted_at is null
            order by a.created_at desc
        ''', size, page: page)
    }

    func updateAgentsAic(agentId: String, aic: String, identityStatus: String): Int64 {
        executor.setSql('''
            update agents set aic = ${arg(aic)}, identity_status = ${arg(identityStatus)}, aip_registered_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())} where id = ${arg(agentId)}
        ''').update
    }

    func updateAgentsAcsFields(agentId: String, capabilities: Option<String>, inputTypes: Option<String>, outputTypes: Option<String>, discoverable: Bool): Int64 {
        executor.setSql('''
            update agents set capabilities = ${arg(capabilities)}, default_input_types = ${arg(inputTypes)}, default_output_types = ${arg(outputTypes)}, discoverable = ${arg(discoverable)}, updated_at = ${arg(DateTime.now())} where id = ${arg(agentId)}
        ''').update
    }
}
