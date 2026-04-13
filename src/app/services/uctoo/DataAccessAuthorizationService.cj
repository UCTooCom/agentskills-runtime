/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.DataAccessAuthorizationPO
import magic.app.dao.uctoo.DataAccessAuthorizationDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * DataAccessAuthorizationService - data_access_authorization服务类
 * 
 * 提供data_access_authorization相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class DataAccessAuthorizationService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建dataAccessAuthorization
     * @param entity dataAccessAuthorization对象
     * @return 创建结果
     */
    public func create(entity: DataAccessAuthorizationPO): APIResult<DataAccessAuthorizationPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertDataAccessAuthorization(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<DataAccessAuthorizationPO>(entity)
            } else {
                return APIResult<DataAccessAuthorizationPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<DataAccessAuthorizationPO>(false, e.message)
        }
    }
    
    /**
     * 更新dataAccessAuthorization
     * @param entityId dataAccessAuthorizationID
     * @param entity dataAccessAuthorization对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: DataAccessAuthorizationPO): APIResult<DataAccessAuthorizationPO> {
        try {
            let existing = getExecutor().findDataAccessAuthorizationById(entityId)
            
            if (existing.isNone()) {
                return APIResult<DataAccessAuthorizationPO>(false, "dataAccessAuthorization不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.entityId.size > 0) {
                existingEntity.entityId = entity.entityId
            }
            if (entity.entityType.size > 0) {
                existingEntity.entityType = entity.entityType
            }
            if (entity.userId.size > 0) {
                existingEntity.userId = entity.userId
            }
            if (entity.permission.isSome()) {
                existingEntity.permission = entity.permission
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
            
            let rows = getExecutor().updateDataAccessAuthorization(existingEntity)
            
            if (rows > 0) {
                return APIResult<DataAccessAuthorizationPO>(existingEntity)
            } else {
                return APIResult<DataAccessAuthorizationPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<DataAccessAuthorizationPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新dataAccessAuthorization
     * @param entities dataAccessAuthorization列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<DataAccessAuthorizationPO>): APIResult<ArrayList<DataAccessAuthorizationPO>> {
        try {
            let updatedEntities = ArrayList<DataAccessAuthorizationPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateDataAccessAuthorization(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<DataAccessAuthorizationPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<DataAccessAuthorizationPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<DataAccessAuthorizationPO>>(false, e.message)
        }
    }
    
    /**
     * 删除dataAccessAuthorization
     * @param entityId dataAccessAuthorizationID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findDataAccessAuthorizationById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "dataAccessAuthorization不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteDataAccessAuthorizationById(entityId)
            } else {
                rows = getExecutor().softDeleteDataAccessAuthorizationById(entityId)
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
     * 批量删除dataAccessAuthorization
     * @param ids dataAccessAuthorizationID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findDataAccessAuthorizationById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteDataAccessAuthorizationById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteDataAccessAuthorizationById(id)
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
     * 恢复软删除的dataAccessAuthorization
     * @param entityId dataAccessAuthorizationID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<DataAccessAuthorizationPO> {
        try {
            let rows = getExecutor().restoreDataAccessAuthorizationById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findDataAccessAuthorizationById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<DataAccessAuthorizationPO>(entity)
                } else {
                    return APIResult<DataAccessAuthorizationPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<DataAccessAuthorizationPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<DataAccessAuthorizationPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的dataAccessAuthorization
     * @param ids dataAccessAuthorizationID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreDataAccessAuthorizationById(id)
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
     * 根据ID获取dataAccessAuthorization
     * 
     * 设计说明：
     * - 通过ID获取dataAccessAuthorization时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId dataAccessAuthorizationID
     * @return dataAccessAuthorization对象
     */
    public func getById(entityId: String): APIResult<DataAccessAuthorizationPO> {
        try {
            LogUtils.info("DataAccessAuthorizationService", "=== DataAccessAuthorizationService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findDataAccessAuthorizationById(entityId)
            LogUtils.info("DataAccessAuthorizationService", "=== findDataAccessAuthorizationById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("DataAccessAuthorizationService", "=== DataAccessAuthorization found, id: ${entity.id} ===")
                return APIResult<DataAccessAuthorizationPO>(entity)
            } else {
                LogUtils.info("DataAccessAuthorizationService", "=== DataAccessAuthorization not found for id: ${entityId} ===")
                return APIResult<DataAccessAuthorizationPO>(false, "未找到该dataAccessAuthorization")
            }
        } catch (e: Exception) {
            LogUtils.error("DataAccessAuthorizationService", "=== DataAccessAuthorizationService.getById() exception: ${e.message} ===")
            return APIResult<DataAccessAuthorizationPO>(false, e.message)
        }
    }
    
    /**
     * 获取dataAccessAuthorization列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return dataAccessAuthorization列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DataAccessAuthorizationPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllDataAccessAuthorizationPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取dataAccessAuthorization列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return dataAccessAuthorization列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DataAccessAuthorizationPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllDataAccessAuthorizationPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有dataAccessAuthorization列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return dataAccessAuthorization列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<DataAccessAuthorizationPO>, Int64) {
        let pagination = getExecutor().findAllDataAccessAuthorizationPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取dataAccessAuthorization
     * @param ids ID列表
     * @return dataAccessAuthorization列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<DataAccessAuthorizationPO> {
        getExecutor().findDataAccessAuthorizationByIds(ids)
    }
    
    /**
     * 统计用户的dataAccessAuthorization数量
     * @param userId 用户ID
     * @return dataAccessAuthorization数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countDataAccessAuthorizationByCreator(userId)
    }
    
    /**
     * 统计所有dataAccessAuthorization数量
     * @return dataAccessAuthorization数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllDataAccessAuthorization()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
