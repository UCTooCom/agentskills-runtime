/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.AgentSkillsPO

/**
 * AgentSkillsDAO - agent_skills数据访问接口
 *
 * 提供agent_skills表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AgentSkillsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入agent_skills（id由数据库自动生成UUID）
     * @param entity AgentSkillsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAgentSkills(entity: AgentSkillsPO): String {
        executor.setSql('''
            insert into agent_skills(
                name,
                description,
                source,
                source_url,
                source_type,
                branch,
                tag,
                commit,
                version,
                author,
                homepage,
                license,
                keywords,
                install_path,
                status,
                runtime_status,
                last_run_at,
                run_count,
                config,
                creator,
                created_at,
                updated_at,
                deleted_at,
                allowed_tools,
                assets_dir_exists,
                avg_execution_time,
                categories,
                compatibility,
                dependencies,
                env_vars,
                error_count,
                extra_metadata,
                generation_model,
                generation_prompt,
                generation_status,
                instructions,
                last_error,
                last_validated_at,
                parameters,
                parent_skill_id,
                permissions,
                references_dir_exists,
                retry_count,
                scripts_dir_exists,
                success_count,
                tags,
                timeout,
                validation_errors,
                validation_status
            ) values(
${arg(entity.name)},
                ${arg(entity.description)},
                ${arg(entity.source)},
                ${arg(entity.sourceUrl)},
                ${arg(entity.sourceType)},
                ${arg(entity.branch)},
                ${arg(entity.tag)},
                ${arg(entity.commit)},
                ${arg(entity.version)},
                ${arg(entity.author)},
                ${arg(entity.homepage)},
                ${arg(entity.license)},
                ${arg(entity.keywords)},
                ${arg(entity.installPath)},
                ${arg(entity.status)},
                ${arg(entity.runtimeStatus)},
                ${arg(entity.lastRunAt)},
                ${arg(entity.runCount)},
                ${arg(entity.config)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.allowedTools)},
                ${arg(entity.assetsDirExists)},
                ${arg(entity.avgExecutionTime)},
                ${arg(entity.categories)},
                ${arg(entity.compatibility)},
                ${arg(entity.dependencies)},
                ${arg(entity.envVars)},
                ${arg(entity.errorCount)},
                ${arg(entity.extraMetadata)},
                ${arg(entity.generationModel)},
                ${arg(entity.generationPrompt)},
                ${arg(entity.generationStatus)},
                ${arg(entity.instructions)},
                ${arg(entity.lastError)},
                ${arg(entity.lastValidatedAt)},
                ${arg(entity.parameters)},
                ${arg(entity.parentSkillId)},
                ${arg(entity.permissions)},
                ${arg(entity.referencesDirExists)},
                ${arg(entity.retryCount)},
                ${arg(entity.scriptsDirExists)},
                ${arg(entity.successCount)},
                ${arg(entity.tags)},
                ${arg(entity.timeout)},
                ${arg(entity.validationErrors)},
                ${arg(entity.validationStatus)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询agent_skills
     * @param id agent_skillsID
     * @return agent_skills对象（Option类型）
     */
    func findAgentSkillsById(id: String): Option<AgentSkillsPO> {
        executor.setSql('''
            select * from agent_skills where id = ${arg(id)}
        ''').first<AgentSkillsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新agent_skills
     * @param entity agent_skills对象
     * @return 影响行数
     */
    func updateAgentSkills(entity: AgentSkillsPO): Int64 {
        executor.setSql('''
            update agent_skills set
                name = ${arg(entity.name)},
                description = ${arg(entity.description)},
                source = ${arg(entity.source)},
                source_url = ${arg(entity.sourceUrl)},
                source_type = ${arg(entity.sourceType)},
                branch = ${arg(entity.branch)},
                tag = ${arg(entity.tag)},
                commit = ${arg(entity.commit)},
                version = ${arg(entity.version)},
                author = ${arg(entity.author)},
                homepage = ${arg(entity.homepage)},
                license = ${arg(entity.license)},
                keywords = ${arg(entity.keywords)},
                install_path = ${arg(entity.installPath)},
                status = ${arg(entity.status)},
                runtime_status = ${arg(entity.runtimeStatus)},
                last_run_at = ${arg(entity.lastRunAt)},
                run_count = ${arg(entity.runCount)},
                config = ${arg(entity.config)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                allowed_tools = ${arg(entity.allowedTools)},
                assets_dir_exists = ${arg(entity.assetsDirExists)},
                avg_execution_time = ${arg(entity.avgExecutionTime)},
                categories = ${arg(entity.categories)},
                compatibility = ${arg(entity.compatibility)},
                dependencies = ${arg(entity.dependencies)},
                env_vars = ${arg(entity.envVars)},
                error_count = ${arg(entity.errorCount)},
                extra_metadata = ${arg(entity.extraMetadata)},
                generation_model = ${arg(entity.generationModel)},
                generation_prompt = ${arg(entity.generationPrompt)},
                generation_status = ${arg(entity.generationStatus)},
                instructions = ${arg(entity.instructions)},
                last_error = ${arg(entity.lastError)},
                last_validated_at = ${arg(entity.lastValidatedAt)},
                parameters = ${arg(entity.parameters)},
                parent_skill_id = ${arg(entity.parentSkillId)},
                permissions = ${arg(entity.permissions)},
                references_dir_exists = ${arg(entity.referencesDirExists)},
                retry_count = ${arg(entity.retryCount)},
                scripts_dir_exists = ${arg(entity.scriptsDirExists)},
                success_count = ${arg(entity.successCount)},
                tags = ${arg(entity.tags)},
                timeout = ${arg(entity.timeout)},
                validation_errors = ${arg(entity.validationErrors)},
                validation_status = ${arg(entity.validationStatus)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除agent_skills
     * @param id agent_skillsID
     * @return 影响行数
     */
    func softDeleteAgentSkillsById(id: String): Int64 {
        executor.setSql('''
            update agent_skills set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的agent_skills
     * @param id agent_skillsID
     * @return 影响行数
     */
    func restoreAgentSkillsById(id: String): Int64 {
        executor.setSql('''
            update agent_skills set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除agent_skills
     * @param id agent_skillsID
     * @return 影响行数
     */
    func deleteAgentSkillsById(id: String): Int64 {
        executor.setSql('''
            delete from agent_skills where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有agent_skills
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAgentSkillsPage(page: Int64, size: Int64): Pagination<AgentSkillsPO> {
        executor.page<AgentSkillsPO>('''
            select * from agent_skills order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询agent_skills列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentSkillsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AgentSkillsPO> {
        executor.page<AgentSkillsPO>('''
            select * from agent_skills where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有agent_skills（不分页）
     * @return agent_skills列表
     */
    func listAllAgentSkills(): ArrayList<AgentSkillsPO> {
        executor.setSql('''
            select * from agent_skills order by created_at desc
        ''').list<AgentSkillsPO>()
    }

    /**
     * 批量查询agent_skills
     * @param ids ID列表
     * @return agent_skills列表
     */
    func findAgentSkillsByIds(ids: ArrayList<String>): ArrayList<AgentSkillsPO> {
        executor.setSql('''
            select * from agent_skills where id ${IN(ids)}
        ''').list<AgentSkillsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的agent_skills数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAgentSkillsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from agent_skills where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有agent_skills数量
     * @return 数量
     */
    func countAllAgentSkills(): Int64 {
        executor.setSql('''
            select count(*) from agent_skills
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询agent_skills列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentSkillsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AgentSkillsPO> {
        let sql = StringBuilder()
        sql.append("select * from agent_skills where 1=1")

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

        executor.page<AgentSkillsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除agent_skills
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAgentSkills(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update agent_skills set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除agent_skills
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAgentSkills(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from agent_skills where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询agent_skills（支持完整查询操作符）
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
    func findAgentSkillsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentSkillsPO> {
        let sql = StringBuilder()
        sql.append("select * from agent_skills")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AgentSkillsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询agent_skills
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAgentSkillsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AgentSkillsPO> {
        let fromClause = executor.FROM<AgentSkillsPO>()

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
        fromClause.page<AgentSkillsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_skills）
     * @return 影响行数
     */
    func emptyRecycleBinAgentSkills(): Int64 {
        executor.setSql('''
            delete from agent_skills where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
}
