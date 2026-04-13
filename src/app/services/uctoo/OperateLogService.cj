/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.OperateLogPO
import magic.app.dao.uctoo.OperateLogDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * OperateLogService - operate_log服务类
 * 
 * 提供operate_log相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class OperateLogService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建operateLog
     * @param entity operateLog对象
     * @return 创建结果
     */
    public func create(entity: OperateLogPO): APIResult<OperateLogPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertOperateLog(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<OperateLogPO>(entity)
            } else {
                return APIResult<OperateLogPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }
    
    /**
     * 更新operateLog
     * @param entityId operateLogID
     * @param entity operateLog对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: OperateLogPO): APIResult<OperateLogPO> {
        try {
            let existing = getExecutor().findOperateLogById(entityId)
            
            if (existing.isNone()) {
                return APIResult<OperateLogPO>(false, "operateLog不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.module.size > 0) {
                existingEntity.module = entity.module
            }
            if (entity.operate.size > 0) {
                existingEntity.operate = entity.operate
            }
            if (entity.route.size > 0) {
                existingEntity.route = entity.route
            }
            if (entity.params.size > 0) {
                existingEntity.params = entity.params
            }
            if (entity.ip.size > 0) {
                existingEntity.ip = entity.ip
            }
            if (entity.method.size > 0) {
                existingEntity.method = entity.method
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
            
            let rows = getExecutor().updateOperateLog(existingEntity)
            
            if (rows > 0) {
                return APIResult<OperateLogPO>(existingEntity)
            } else {
                return APIResult<OperateLogPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新operateLog
     * @param entities operateLog列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<OperateLogPO>): APIResult<ArrayList<OperateLogPO>> {
        try {
            let updatedEntities = ArrayList<OperateLogPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateOperateLog(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<OperateLogPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<OperateLogPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<OperateLogPO>>(false, e.message)
        }
    }
    
    /**
     * 删除operateLog
     * @param entityId operateLogID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findOperateLogById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "operateLog不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteOperateLogById(entityId)
            } else {
                rows = getExecutor().softDeleteOperateLogById(entityId)
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
     * 批量删除operateLog
     * @param ids operateLogID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findOperateLogById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteOperateLogById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteOperateLogById(id)
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
     * 恢复软删除的operateLog
     * @param entityId operateLogID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<OperateLogPO> {
        try {
            let rows = getExecutor().restoreOperateLogById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findOperateLogById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<OperateLogPO>(entity)
                } else {
                    return APIResult<OperateLogPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<OperateLogPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<OperateLogPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的operateLog
     * @param ids operateLogID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreOperateLogById(id)
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
     * 根据ID获取operateLog
     * 
     * 设计说明：
     * - 通过ID获取operateLog时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId operateLogID
     * @return operateLog对象
     */
    public func getById(entityId: String): APIResult<OperateLogPO> {
        try {
            LogUtils.info("OperateLogService", "=== OperateLogService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findOperateLogById(entityId)
            LogUtils.info("OperateLogService", "=== findOperateLogById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("OperateLogService", "=== OperateLog found, id: ${entity.id} ===")
                return APIResult<OperateLogPO>(entity)
            } else {
                LogUtils.info("OperateLogService", "=== OperateLog not found for id: ${entityId} ===")
                return APIResult<OperateLogPO>(false, "未找到该operateLog")
            }
        } catch (e: Exception) {
            LogUtils.error("OperateLogService", "=== OperateLogService.getById() exception: ${e.message} ===")
            return APIResult<OperateLogPO>(false, e.message)
        }
    }
    
    /**
     * 获取operateLog列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return operateLog列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<OperateLogPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllOperateLogPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取operateLog列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return operateLog列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<OperateLogPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllOperateLogPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有operateLog列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return operateLog列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<OperateLogPO>, Int64) {
        let pagination = getExecutor().findAllOperateLogPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取operateLog
     * @param ids ID列表
     * @return operateLog列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<OperateLogPO> {
        getExecutor().findOperateLogByIds(ids)
    }
    
    /**
     * 统计用户的operateLog数量
     * @param userId 用户ID
     * @return operateLog数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countOperateLogByCreator(userId)
    }
    
    /**
     * 统计所有operateLog数量
     * @return operateLog数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllOperateLog()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
