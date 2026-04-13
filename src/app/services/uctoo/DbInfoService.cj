/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.DbInfoPO
import magic.app.dao.uctoo.DbInfoDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * DbInfoService - db_info服务类
 * 
 * 提供db_info相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class DbInfoService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建dbInfo
     * @param entity dbInfo对象
     * @return 创建结果
     */
    public func create(entity: DbInfoPO): APIResult<DbInfoPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertDbInfo(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<DbInfoPO>(entity)
            } else {
                return APIResult<DbInfoPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<DbInfoPO>(false, e.message)
        }
    }
    
    /**
     * 更新dbInfo
     * @param entityId dbInfoID
     * @param entity dbInfo对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: DbInfoPO): APIResult<DbInfoPO> {
        try {
            let existing = getExecutor().findDbInfoById(entityId)
            
            if (existing.isNone()) {
                return APIResult<DbInfoPO>(false, "dbInfo不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.tableCatalog.size > 0) {
                existingEntity.tableCatalog = entity.tableCatalog
            }
            if (entity.tableSchema.isSome()) {
                existingEntity.tableSchema = entity.tableSchema
            }
            if (entity.dbTableName.size > 0) {
                existingEntity.dbTableName = entity.dbTableName
            }
            if (entity.columnName.size > 0) {
                existingEntity.columnName = entity.columnName
            }
            if (entity.columnDefault.isSome()) {
                existingEntity.columnDefault = entity.columnDefault
            }
            if (entity.isNullable.size > 0) {
                existingEntity.isNullable = entity.isNullable
            }
            if (entity.dataType.isSome()) {
                existingEntity.dataType = entity.dataType
            }
            if (entity.vueComponentType.isSome()) {
                existingEntity.vueComponentType = entity.vueComponentType
            }
            if (entity.reactComponentType.isSome()) {
                existingEntity.reactComponentType = entity.reactComponentType
            }
            if (entity.arkuiComponentType.isSome()) {
                existingEntity.arkuiComponentType = entity.arkuiComponentType
            }
            if (entity.uniappComponentType.isSome()) {
                existingEntity.uniappComponentType = entity.uniappComponentType
            }
            if (entity.rules.isSome()) {
                existingEntity.rules = entity.rules
            }
            if (entity.pattern.isSome()) {
                existingEntity.pattern = entity.pattern
            }
            if (entity.weight.isSome()) {
                existingEntity.weight = entity.weight
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.placeholder.isSome()) {
                existingEntity.placeholder = entity.placeholder
            }
            if (entity.isColumnHidden.size > 0) {
                existingEntity.isColumnHidden = entity.isColumnHidden
            }
            if (entity.isTableHidden.size > 0) {
                existingEntity.isTableHidden = entity.isTableHidden
            }
            if (entity.columnComment.isSome()) {
                existingEntity.columnComment = entity.columnComment
            }
            if (entity.ordinalPosition.isSome()) {
                existingEntity.ordinalPosition = entity.ordinalPosition
            }
            if (entity.migrationId.isSome()) {
                existingEntity.migrationId = entity.migrationId
            }
            if (entity.characterMaximumLength.isSome()) {
                existingEntity.characterMaximumLength = entity.characterMaximumLength
            }
            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateDbInfo(existingEntity)
            
            if (rows > 0) {
                return APIResult<DbInfoPO>(existingEntity)
            } else {
                return APIResult<DbInfoPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<DbInfoPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新dbInfo
     * @param entities dbInfo列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<DbInfoPO>): APIResult<ArrayList<DbInfoPO>> {
        try {
            let updatedEntities = ArrayList<DbInfoPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateDbInfo(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<DbInfoPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<DbInfoPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<DbInfoPO>>(false, e.message)
        }
    }
    
    /**
     * 删除dbInfo
     * @param entityId dbInfoID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findDbInfoById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "dbInfo不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteDbInfoById(entityId)
            } else {
                rows = getExecutor().softDeleteDbInfoById(entityId)
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
     * 批量删除dbInfo
     * @param ids dbInfoID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findDbInfoById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteDbInfoById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteDbInfoById(id)
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
     * 恢复软删除的dbInfo
     * @param entityId dbInfoID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<DbInfoPO> {
        try {
            let rows = getExecutor().restoreDbInfoById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findDbInfoById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<DbInfoPO>(entity)
                } else {
                    return APIResult<DbInfoPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<DbInfoPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<DbInfoPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的dbInfo
     * @param ids dbInfoID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreDbInfoById(id)
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
     * 根据ID获取dbInfo
     * 
     * 设计说明：
     * - 通过ID获取dbInfo时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId dbInfoID
     * @return dbInfo对象
     */
    public func getById(entityId: String): APIResult<DbInfoPO> {
        try {
            LogUtils.info("DbInfoService", "=== DbInfoService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findDbInfoById(entityId)
            LogUtils.info("DbInfoService", "=== findDbInfoById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("DbInfoService", "=== DbInfo found, id: ${entity.id} ===")
                return APIResult<DbInfoPO>(entity)
            } else {
                LogUtils.info("DbInfoService", "=== DbInfo not found for id: ${entityId} ===")
                return APIResult<DbInfoPO>(false, "未找到该dbInfo")
            }
        } catch (e: Exception) {
            LogUtils.error("DbInfoService", "=== DbInfoService.getById() exception: ${e.message} ===")
            return APIResult<DbInfoPO>(false, e.message)
        }
    }
    
    /**
     * 获取dbInfo列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return dbInfo列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DbInfoPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllDbInfoPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取dbInfo列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return dbInfo列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DbInfoPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllDbInfoPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有dbInfo列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return dbInfo列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<DbInfoPO>, Int64) {
        let pagination = getExecutor().findAllDbInfoPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取dbInfo
     * @param ids ID列表
     * @return dbInfo列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<DbInfoPO> {
        getExecutor().findDbInfoByIds(ids)
    }
    
    /**
     * 统计用户的dbInfo数量
     * @param userId 用户ID
     * @return dbInfo数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countDbInfoByCreator(userId)
    }
    
    /**
     * 统计所有dbInfo数量
     * @return dbInfo数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllDbInfo()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
