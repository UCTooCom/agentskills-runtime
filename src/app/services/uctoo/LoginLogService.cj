/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.LoginLogPO
import magic.app.dao.uctoo.LoginLogDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * LoginLogService - login_log服务类
 * 
 * 提供login_log相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class LoginLogService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建loginLog
     * @param entity loginLog对象
     * @return 创建结果
     */
    public func create(entity: LoginLogPO): APIResult<LoginLogPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertLoginLog(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<LoginLogPO>(entity)
            } else {
                return APIResult<LoginLogPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<LoginLogPO>(false, e.message)
        }
    }
    
    /**
     * 更新loginLog
     * @param entityId loginLogID
     * @param entity loginLog对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: LoginLogPO): APIResult<LoginLogPO> {
        try {
            let existing = getExecutor().findLoginLogById(entityId)
            
            if (existing.isNone()) {
                return APIResult<LoginLogPO>(false, "loginLog不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.loginName.size > 0) {
                existingEntity.loginName = entity.loginName
            }
            if (entity.loginIp.size > 0) {
                existingEntity.loginIp = entity.loginIp
            }
            if (entity.browser.size > 0) {
                existingEntity.browser = entity.browser
            }
            if (entity.os.size > 0) {
                existingEntity.os = entity.os
            }
            if (entity.status.isSome()) {
                existingEntity.status = entity.status
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
            
            let rows = getExecutor().updateLoginLog(existingEntity)
            
            if (rows > 0) {
                return APIResult<LoginLogPO>(existingEntity)
            } else {
                return APIResult<LoginLogPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<LoginLogPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新loginLog
     * @param entities loginLog列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<LoginLogPO>): APIResult<ArrayList<LoginLogPO>> {
        try {
            let updatedEntities = ArrayList<LoginLogPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateLoginLog(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<LoginLogPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<LoginLogPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<LoginLogPO>>(false, e.message)
        }
    }
    
    /**
     * 删除loginLog
     * @param entityId loginLogID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findLoginLogById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "loginLog不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteLoginLogById(entityId)
            } else {
                rows = getExecutor().softDeleteLoginLogById(entityId)
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
     * 批量删除loginLog
     * @param ids loginLogID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findLoginLogById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteLoginLogById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteLoginLogById(id)
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
     * 恢复软删除的loginLog
     * @param entityId loginLogID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<LoginLogPO> {
        try {
            let rows = getExecutor().restoreLoginLogById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findLoginLogById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<LoginLogPO>(entity)
                } else {
                    return APIResult<LoginLogPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<LoginLogPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<LoginLogPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的loginLog
     * @param ids loginLogID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreLoginLogById(id)
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
     * 根据ID获取loginLog
     * 
     * 设计说明：
     * - 通过ID获取loginLog时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId loginLogID
     * @return loginLog对象
     */
    public func getById(entityId: String): APIResult<LoginLogPO> {
        try {
            LogUtils.info("LoginLogService", "=== LoginLogService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findLoginLogById(entityId)
            LogUtils.info("LoginLogService", "=== findLoginLogById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("LoginLogService", "=== LoginLog found, id: ${entity.id} ===")
                return APIResult<LoginLogPO>(entity)
            } else {
                LogUtils.info("LoginLogService", "=== LoginLog not found for id: ${entityId} ===")
                return APIResult<LoginLogPO>(false, "未找到该loginLog")
            }
        } catch (e: Exception) {
            LogUtils.error("LoginLogService", "=== LoginLogService.getById() exception: ${e.message} ===")
            return APIResult<LoginLogPO>(false, e.message)
        }
    }
    
    /**
     * 获取loginLog列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return loginLog列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<LoginLogPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllLoginLogPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取loginLog列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return loginLog列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<LoginLogPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllLoginLogPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有loginLog列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return loginLog列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<LoginLogPO>, Int64) {
        let pagination = getExecutor().findAllLoginLogPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取loginLog
     * @param ids ID列表
     * @return loginLog列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<LoginLogPO> {
        getExecutor().findLoginLogByIds(ids)
    }
    
    /**
     * 统计用户的loginLog数量
     * @param userId 用户ID
     * @return loginLog数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countLoginLogByCreator(userId)
    }
    
    /**
     * 统计所有loginLog数量
     * @return loginLog数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllLoginLog()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
