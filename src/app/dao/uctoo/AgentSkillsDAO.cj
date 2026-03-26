/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.AgentSkillsPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * AgentSkillsDAO - agent_skills数据访问接口
 * 
 * 提供标准CRUD操作，遵循UCTOO V4 ORM规范
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
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入agentSkills（id由数据库自动生成UUID）
     * @param entity agentSkills对象
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
                tags,
                categories,
                install_path,
                compatibility,
                allowed_tools,
                dependencies,
                permissions,
                parameters,
                instructions,
                scripts_dir_exists,
                references_dir_exists,
                assets_dir_exists,
                status,
                runtime_status,
                validation_status,
                validation_errors,
                last_validated_at,
                config,
                env_vars,
                timeout,
                retry_count,
                run_count,
                success_count,
                error_count,
                last_run_at,
                last_error,
                avg_execution_time,
                generation_prompt,
                generation_model,
                generation_status,
                parent_skill_id,
                extra_metadata,
                creator,
                created_at,
                updated_at,
                deleted_at
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
                ${arg(entity.tags)},
                ${arg(entity.categories)},
                ${arg(entity.installPath)},
                ${arg(entity.compatibility)},
                ${arg(entity.allowedTools)},
                ${arg(entity.dependencies)},
                ${arg(entity.permissions)},
                ${arg(entity.parameters)},
                ${arg(entity.instructions)},
                ${arg(entity.scriptsDirExists)},
                ${arg(entity.referencesDirExists)},
                ${arg(entity.assetsDirExists)},
                ${arg(entity.status)},
                ${arg(entity.runtimeStatus)},
                ${arg(entity.validationStatus)},
                ${arg(entity.validationErrors)},
                ${arg(entity.lastValidatedAt)},
                ${arg(entity.config)},
                ${arg(entity.envVars)},
                ${arg(entity.timeout)},
                ${arg(entity.retryCount)},
                ${arg(entity.runCount)},
                ${arg(entity.successCount)},
                ${arg(entity.errorCount)},
                ${arg(entity.lastRunAt)},
                ${arg(entity.lastError)},
                ${arg(entity.avgExecutionTime)},
                ${arg(entity.generationPrompt)},
                ${arg(entity.generationModel)},
                ${arg(entity.generationStatus)},
                ${arg(entity.parentSkillId)},
                ${arg(entity.extraMetadata)},
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
     * 根据ID查询agentSkills
     * @param id agentSkillsID
     * @return agentSkills对象（Option类型）
     */
    func findAgentSkillsById(id: String): Option<AgentSkillsPO> {
        executor.setSql('''
            select * from agent_skills where id = ${arg(id)}
        ''').first<AgentSkillsPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新agentSkills
     * @param entity agentSkills对象
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
                tags = ${arg(entity.tags)},
                categories = ${arg(entity.categories)},
                install_path = ${arg(entity.installPath)},
                compatibility = ${arg(entity.compatibility)},
                allowed_tools = ${arg(entity.allowedTools)},
                dependencies = ${arg(entity.dependencies)},
                permissions = ${arg(entity.permissions)},
                parameters = ${arg(entity.parameters)},
                instructions = ${arg(entity.instructions)},
                scripts_dir_exists = ${arg(entity.scriptsDirExists)},
                references_dir_exists = ${arg(entity.referencesDirExists)},
                assets_dir_exists = ${arg(entity.assetsDirExists)},
                status = ${arg(entity.status)},
                runtime_status = ${arg(entity.runtimeStatus)},
                validation_status = ${arg(entity.validationStatus)},
                validation_errors = ${arg(entity.validationErrors)},
                last_validated_at = ${arg(entity.lastValidatedAt)},
                config = ${arg(entity.config)},
                env_vars = ${arg(entity.envVars)},
                timeout = ${arg(entity.timeout)},
                retry_count = ${arg(entity.retryCount)},
                run_count = ${arg(entity.runCount)},
                success_count = ${arg(entity.successCount)},
                error_count = ${arg(entity.errorCount)},
                last_run_at = ${arg(entity.lastRunAt)},
                last_error = ${arg(entity.lastError)},
                avg_execution_time = ${arg(entity.avgExecutionTime)},
                generation_prompt = ${arg(entity.generationPrompt)},
                generation_model = ${arg(entity.generationModel)},
                generation_status = ${arg(entity.generationStatus)},
                parent_skill_id = ${arg(entity.parentSkillId)},
                extra_metadata = ${arg(entity.extraMetadata)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除agentSkills
     * @param id agentSkillsID
     * @return 影响行数
     */
    func softDeleteAgentSkillsById(id: String): Int64 {
        executor.setSql('''
            update agent_skills set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的agentSkills
     * @param id agentSkillsID
     * @return 影响行数
     */
    func restoreAgentSkillsById(id: String): Int64 {
        executor.setSql('''
            update agent_skills set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除agentSkills
     * @param id agentSkillsID
     * @return 影响行数
     */
    func deleteAgentSkillsById(id: String): Int64 {
        executor.setSql('''
            delete from agent_skills where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有agentSkills
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
     * 分页查询agentSkills列表（按创建者）
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
     * 查询所有agentSkills（不分页）
     * @return agentSkills列表
     */
    func listAllAgentSkills(): ArrayList<AgentSkillsPO> {
        executor.setSql('''
            select * from agent_skills order by created_at desc
        ''').list<AgentSkillsPO>()
    }
    
    /**
     * 批量查询agentSkills
     * @param ids ID列表
     * @return agentSkills列表
     */
    func findAgentSkillsByIds(ids: ArrayList<String>): ArrayList<AgentSkillsPO> {
        executor.setSql('''
            select * from agent_skills where id ${IN(ids)}
        ''').list<AgentSkillsPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的agentSkills数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAgentSkillsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from agent_skills where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有agentSkills数量
     * @return 数量
     */
    func countAllAgentSkills(): Int64 {
        executor.setSql('''
            select count(*) from agent_skills
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
