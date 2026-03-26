/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.AgentSkillsPO
import magic.app.dao.uctoo.AgentSkillsDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * AgentSkillsService - agent_skills服务类
 * 
 * 提供agent_skills相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class AgentSkillsService {
    private var executor: ?SqlExecutor = None<SqlExecutor>
    
    private func getExecutor(): SqlExecutor {
        if (let Some(exe) <- executor) {
            return exe
        }
        let exe = ORM.executor()
        executor = Some<SqlExecutor>(exe)
        return exe
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建agentSkills
     * @param entity agentSkills对象
     * @return 创建结果
     */
    public func create(entity: AgentSkillsPO): APIResult<AgentSkillsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertAgentSkills(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<AgentSkillsPO>(entity)
            } else {
                return APIResult<AgentSkillsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }
    
    /**
     * 更新agentSkills
     * @param entityId agentSkillsID
     * @param entity agentSkills对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: AgentSkillsPO): APIResult<AgentSkillsPO> {
        try {
            let existing = getExecutor().findAgentSkillsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<AgentSkillsPO>(false, "agentSkills不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.name.size > 0) {
                existingEntity.name = entity.name
            }
            if (entity.description.isSome()) {
                existingEntity.description = entity.description
            }
            if (entity.source.isSome()) {
                existingEntity.source = entity.source
            }
            if (entity.sourceUrl.isSome()) {
                existingEntity.sourceUrl = entity.sourceUrl
            }
            if (entity.sourceType.isSome()) {
                existingEntity.sourceType = entity.sourceType
            }
            if (entity.branch.isSome()) {
                existingEntity.branch = entity.branch
            }
            if (entity.tag.isSome()) {
                existingEntity.tag = entity.tag
            }
            if (entity.commit.isSome()) {
                existingEntity.commit = entity.commit
            }
            if (entity.version.isSome()) {
                existingEntity.version = entity.version
            }
            if (entity.author.isSome()) {
                existingEntity.author = entity.author
            }
            if (entity.homepage.isSome()) {
                existingEntity.homepage = entity.homepage
            }
            if (entity.license.isSome()) {
                existingEntity.license = entity.license
            }
            if (entity.keywords.isSome()) {
                existingEntity.keywords = entity.keywords
            }
            if (entity.tags.isSome()) {
                existingEntity.tags = entity.tags
            }
            if (entity.categories.isSome()) {
                existingEntity.categories = entity.categories
            }
            if (entity.installPath.isSome()) {
                existingEntity.installPath = entity.installPath
            }
            if (entity.compatibility.isSome()) {
                existingEntity.compatibility = entity.compatibility
            }
            if (entity.allowedTools.isSome()) {
                existingEntity.allowedTools = entity.allowedTools
            }
            if (entity.dependencies.isSome()) {
                existingEntity.dependencies = entity.dependencies
            }
            if (entity.permissions.isSome()) {
                existingEntity.permissions = entity.permissions
            }
            if (entity.parameters.isSome()) {
                existingEntity.parameters = entity.parameters
            }
            if (entity.instructions.isSome()) {
                existingEntity.instructions = entity.instructions
            }
            if (entity.scriptsDirExists.isSome()) {
                existingEntity.scriptsDirExists = entity.scriptsDirExists
            }
            if (entity.referencesDirExists.isSome()) {
                existingEntity.referencesDirExists = entity.referencesDirExists
            }
            if (entity.assetsDirExists.isSome()) {
                existingEntity.assetsDirExists = entity.assetsDirExists
            }
            if (entity.status.isSome()) {
                existingEntity.status = entity.status
            }
            if (entity.runtimeStatus.isSome()) {
                existingEntity.runtimeStatus = entity.runtimeStatus
            }
            if (entity.validationStatus.isSome()) {
                existingEntity.validationStatus = entity.validationStatus
            }
            if (entity.validationErrors.isSome()) {
                existingEntity.validationErrors = entity.validationErrors
            }
            if (entity.lastValidatedAt.isSome()) {
                existingEntity.lastValidatedAt = entity.lastValidatedAt
            }
            if (entity.config.isSome()) {
                existingEntity.config = entity.config
            }
            if (entity.envVars.isSome()) {
                existingEntity.envVars = entity.envVars
            }
            if (entity.timeout.isSome()) {
                existingEntity.timeout = entity.timeout
            }
            if (entity.retryCount.isSome()) {
                existingEntity.retryCount = entity.retryCount
            }
            if (entity.runCount.isSome()) {
                existingEntity.runCount = entity.runCount
            }
            if (entity.successCount.isSome()) {
                existingEntity.successCount = entity.successCount
            }
            if (entity.errorCount.isSome()) {
                existingEntity.errorCount = entity.errorCount
            }
            if (entity.lastRunAt.isSome()) {
                existingEntity.lastRunAt = entity.lastRunAt
            }
            if (entity.lastError.isSome()) {
                existingEntity.lastError = entity.lastError
            }
            if (entity.avgExecutionTime.isSome()) {
                existingEntity.avgExecutionTime = entity.avgExecutionTime
            }
            if (entity.generationPrompt.isSome()) {
                existingEntity.generationPrompt = entity.generationPrompt
            }
            if (entity.generationModel.isSome()) {
                existingEntity.generationModel = entity.generationModel
            }
            if (entity.generationStatus.isSome()) {
                existingEntity.generationStatus = entity.generationStatus
            }
            if (entity.parentSkillId.isSome()) {
                existingEntity.parentSkillId = entity.parentSkillId
            }
            if (entity.extraMetadata.isSome()) {
                existingEntity.extraMetadata = entity.extraMetadata
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateAgentSkills(existingEntity)
            
            if (rows > 0) {
                return APIResult<AgentSkillsPO>(existingEntity)
            } else {
                return APIResult<AgentSkillsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新agentSkills
     * @param entities agentSkills列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<AgentSkillsPO>): APIResult<ArrayList<AgentSkillsPO>> {
        try {
            let updatedEntities = ArrayList<AgentSkillsPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateAgentSkills(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<AgentSkillsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<AgentSkillsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<AgentSkillsPO>>(false, e.message)
        }
    }
    
    /**
     * 删除agentSkills
     * @param entityId agentSkillsID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findAgentSkillsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "agentSkills不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteAgentSkillsById(entityId)
            } else {
                rows = getExecutor().softDeleteAgentSkillsById(entityId)
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
    
    /**
     * 批量删除agentSkills
     * @param ids agentSkillsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findAgentSkillsById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteAgentSkillsById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteAgentSkillsById(id)
                    }
                }
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "批量删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
    
    /**
     * 恢复软删除的agentSkills
     * @param entityId agentSkillsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<AgentSkillsPO> {
        try {
            let rows = getExecutor().restoreAgentSkillsById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findAgentSkillsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<AgentSkillsPO>(entity)
                } else {
                    return APIResult<AgentSkillsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<AgentSkillsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的agentSkills
     * @param ids agentSkillsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreAgentSkillsById(id)
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "批量恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
    
    /**
     * 根据ID获取agentSkills
     * 
     * 设计说明：
     * - 通过ID获取agentSkills时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId agentSkillsID
     * @return agentSkills对象
     */
    public func getById(entityId: String): APIResult<AgentSkillsPO> {
        try {
            LogUtils.info("AgentSkillsService", "=== AgentSkillsService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findAgentSkillsById(entityId)
            LogUtils.info("AgentSkillsService", "=== findAgentSkillsById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("AgentSkillsService", "=== AgentSkills found, id: ${entity.id} ===")
                return APIResult<AgentSkillsPO>(entity)
            } else {
                LogUtils.info("AgentSkillsService", "=== AgentSkills not found for id: ${entityId} ===")
                return APIResult<AgentSkillsPO>(false, "未找到该agentSkills")
            }
        } catch (e: Exception) {
            LogUtils.error("AgentSkillsService", "=== AgentSkillsService.getById() exception: ${e.message} ===")
            return APIResult<AgentSkillsPO>(false, e.message)
        }
    }
    
    /**
     * 获取agentSkills列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return agentSkills列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentSkillsPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllAgentSkillsPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取agentSkills列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return agentSkills列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentSkillsPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllAgentSkillsPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有agentSkills列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agentSkills列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<AgentSkillsPO>, Int64) {
        let pagination = getExecutor().findAllAgentSkillsPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取agentSkills
     * @param ids ID列表
     * @return agentSkills列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<AgentSkillsPO> {
        getExecutor().findAgentSkillsByIds(ids)
    }
    
    /**
     * 统计用户的agentSkills数量
     * @param userId 用户ID
     * @return agentSkills数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countAgentSkillsByCreator(userId)
    }
    
    /**
     * 统计所有agentSkills数量
     * @return agentSkills数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllAgentSkills()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
