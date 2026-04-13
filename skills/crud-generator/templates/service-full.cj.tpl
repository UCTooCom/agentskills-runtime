/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.{DATABASE_NAME}

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.{DATABASE_NAME}.{TABLE_NAME_PASCAL}PO
import magic.app.dao.{DATABASE_NAME}.{TABLE_NAME_PASCAL}DAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * {TABLE_NAME_PASCAL}Service - {TABLE_NAME}服务类
 * 
 * 提供{TABLE_NAME}相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class {TABLE_NAME_PASCAL}Service {
    
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建{TABLE_NAME_CAMEL}
     * @param entity {TABLE_NAME_CAMEL}对象
     * @return 创建结果
     */
    public func create(entity: {TABLE_NAME_PASCAL}PO): APIResult<{TABLE_NAME_PASCAL}PO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insert{TABLE_NAME_PASCAL}(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<{TABLE_NAME_PASCAL}PO>(entity)
            } else {
                return APIResult<{TABLE_NAME_PASCAL}PO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<{TABLE_NAME_PASCAL}PO>(false, e.message)
        }
    }
    
    /**
     * 更新{TABLE_NAME_CAMEL}
     * @param entityId {TABLE_NAME_CAMEL}ID
     * @param entity {TABLE_NAME_CAMEL}对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: {TABLE_NAME_PASCAL}PO): APIResult<{TABLE_NAME_PASCAL}PO> {
        try {
            let existing = getExecutor().find{TABLE_NAME_PASCAL}ById(entityId)
            
            if (existing.isNone()) {
                return APIResult<{TABLE_NAME_PASCAL}PO>(false, "{TABLE_NAME_CAMEL}不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
            {MERGE_FIELDS_LOGIC}
            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().update{TABLE_NAME_PASCAL}(existingEntity)
            
            if (rows > 0) {
                return APIResult<{TABLE_NAME_PASCAL}PO>(existingEntity)
            } else {
                return APIResult<{TABLE_NAME_PASCAL}PO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<{TABLE_NAME_PASCAL}PO>(false, e.message)
        }
    }
    
    /**
     * 批量更新{TABLE_NAME_CAMEL}
     * @param entities {TABLE_NAME_CAMEL}列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<{TABLE_NAME_PASCAL}PO>): APIResult<ArrayList<{TABLE_NAME_PASCAL}PO>> {
        try {
            let updatedEntities = ArrayList<{TABLE_NAME_PASCAL}PO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().update{TABLE_NAME_PASCAL}(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<{TABLE_NAME_PASCAL}PO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<{TABLE_NAME_PASCAL}PO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<{TABLE_NAME_PASCAL}PO>>(false, e.message)
        }
    }
    
    /**
     * 删除{TABLE_NAME_CAMEL}
     * @param entityId {TABLE_NAME_CAMEL}ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().find{TABLE_NAME_PASCAL}ById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "{TABLE_NAME_CAMEL}不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().delete{TABLE_NAME_PASCAL}ById(entityId)
            } else {
                rows = getExecutor().softDelete{TABLE_NAME_PASCAL}ById(entityId)
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
     * 批量删除{TABLE_NAME_CAMEL}
     * @param ids {TABLE_NAME_CAMEL}ID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().find{TABLE_NAME_PASCAL}ById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().delete{TABLE_NAME_PASCAL}ById(id)
                    } else {
                        rows = rows + getExecutor().softDelete{TABLE_NAME_PASCAL}ById(id)
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
     * 恢复软删除的{TABLE_NAME_CAMEL}
     * @param entityId {TABLE_NAME_CAMEL}ID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<{TABLE_NAME_PASCAL}PO> {
        try {
            let rows = getExecutor().restore{TABLE_NAME_PASCAL}ById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().find{TABLE_NAME_PASCAL}ById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<{TABLE_NAME_PASCAL}PO>(entity)
                } else {
                    return APIResult<{TABLE_NAME_PASCAL}PO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<{TABLE_NAME_PASCAL}PO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<{TABLE_NAME_PASCAL}PO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的{TABLE_NAME_CAMEL}
     * @param ids {TABLE_NAME_CAMEL}ID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restore{TABLE_NAME_PASCAL}ById(id)
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
     * 根据ID获取{TABLE_NAME_CAMEL}
     * 
     * 设计说明：
     * - 通过ID获取{TABLE_NAME_CAMEL}时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId {TABLE_NAME_CAMEL}ID
     * @return {TABLE_NAME_CAMEL}对象
     */
    public func getById(entityId: String): APIResult<{TABLE_NAME_PASCAL}PO> {
        try {
            LogUtils.info("{TABLE_NAME_PASCAL}Service", "=== {TABLE_NAME_PASCAL}Service.getById() called with id: ${entityId} ===")
            let result = getExecutor().find{TABLE_NAME_PASCAL}ById(entityId)
            LogUtils.info("{TABLE_NAME_PASCAL}Service", "=== find{TABLE_NAME_PASCAL}ById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("{TABLE_NAME_PASCAL}Service", "=== {TABLE_NAME_PASCAL} found, id: ${entity.id} ===")
                return APIResult<{TABLE_NAME_PASCAL}PO>(entity)
            } else {
                LogUtils.info("{TABLE_NAME_PASCAL}Service", "=== {TABLE_NAME_PASCAL} not found for id: ${entityId} ===")
                return APIResult<{TABLE_NAME_PASCAL}PO>(false, "未找到该{TABLE_NAME_CAMEL}")
            }
        } catch (e: Exception) {
            LogUtils.error("{TABLE_NAME_PASCAL}Service", "=== {TABLE_NAME_PASCAL}Service.getById() exception: ${e.message} ===")
            return APIResult<{TABLE_NAME_PASCAL}PO>(false, e.message)
        }
    }
    
    /**
     * 获取{TABLE_NAME_CAMEL}列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return {TABLE_NAME_CAMEL}列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<{TABLE_NAME_PASCAL}PO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAll{TABLE_NAME_PASCAL}Page(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取{TABLE_NAME_CAMEL}列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return {TABLE_NAME_CAMEL}列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<{TABLE_NAME_PASCAL}PO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAll{TABLE_NAME_PASCAL}Page(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有{TABLE_NAME_CAMEL}列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return {TABLE_NAME_CAMEL}列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<{TABLE_NAME_PASCAL}PO>, Int64) {
        let pagination = getExecutor().findAll{TABLE_NAME_PASCAL}Page(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取{TABLE_NAME_CAMEL}
     * @param ids ID列表
     * @return {TABLE_NAME_CAMEL}列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<{TABLE_NAME_PASCAL}PO> {
        getExecutor().find{TABLE_NAME_PASCAL}ByIds(ids)
    }
    
    /**
     * 统计用户的{TABLE_NAME_CAMEL}数量
     * @param userId 用户ID
     * @return {TABLE_NAME_CAMEL}数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().count{TABLE_NAME_PASCAL}ByCreator(userId)
    }
    
    /**
     * 统计所有{TABLE_NAME_CAMEL}数量
     * @return {TABLE_NAME_CAMEL}数量
     */
    public func countAll(): Int64 {
        getExecutor().countAll{TABLE_NAME_PASCAL}()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
