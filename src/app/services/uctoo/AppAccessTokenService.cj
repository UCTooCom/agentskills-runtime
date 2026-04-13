/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.AppAccessTokenPO
import magic.app.dao.uctoo.AppAccessTokenDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * AppAccessTokenService - app_access_token服务类
 * 
 * 提供app_access_token相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class AppAccessTokenService {
    
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建appAccessToken
     * @param entity appAccessToken对象
     * @return 创建结果
     */
    public func create(entity: AppAccessTokenPO): APIResult<AppAccessTokenPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertAppAccessToken(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<AppAccessTokenPO>(entity)
            } else {
                return APIResult<AppAccessTokenPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<AppAccessTokenPO>(false, e.message)
        }
    }
    
    /**
     * 更新appAccessToken
     * @param entityId appAccessTokenID
     * @param entity appAccessToken对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: AppAccessTokenPO): APIResult<AppAccessTokenPO> {
        try {
            let existing = getExecutor().findAppAccessTokenById(entityId)
            
            if (existing.isNone()) {
                return APIResult<AppAccessTokenPO>(false, "appAccessToken不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.accessToken.isSome()) {
                existingEntity.accessToken = entity.accessToken
            }
            if (entity.tokenOvertime.isSome()) {
                existingEntity.tokenOvertime = entity.tokenOvertime
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
            
            let rows = getExecutor().updateAppAccessToken(existingEntity)
            
            if (rows > 0) {
                return APIResult<AppAccessTokenPO>(existingEntity)
            } else {
                return APIResult<AppAccessTokenPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<AppAccessTokenPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新appAccessToken
     * @param entities appAccessToken列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<AppAccessTokenPO>): APIResult<ArrayList<AppAccessTokenPO>> {
        try {
            let updatedEntities = ArrayList<AppAccessTokenPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateAppAccessToken(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<AppAccessTokenPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<AppAccessTokenPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<AppAccessTokenPO>>(false, e.message)
        }
    }
    
    /**
     * 删除appAccessToken
     * @param entityId appAccessTokenID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findAppAccessTokenById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "appAccessToken不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteAppAccessTokenById(entityId)
            } else {
                rows = getExecutor().softDeleteAppAccessTokenById(entityId)
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
     * 批量删除appAccessToken
     * @param ids appAccessTokenID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findAppAccessTokenById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteAppAccessTokenById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteAppAccessTokenById(id)
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
     * 恢复软删除的appAccessToken
     * @param entityId appAccessTokenID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<AppAccessTokenPO> {
        try {
            let rows = getExecutor().restoreAppAccessTokenById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findAppAccessTokenById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<AppAccessTokenPO>(entity)
                } else {
                    return APIResult<AppAccessTokenPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<AppAccessTokenPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<AppAccessTokenPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的appAccessToken
     * @param ids appAccessTokenID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreAppAccessTokenById(id)
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
     * 根据ID获取appAccessToken
     * 
     * 设计说明：
     * - 通过ID获取appAccessToken时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId appAccessTokenID
     * @return appAccessToken对象
     */
    public func getById(entityId: String): APIResult<AppAccessTokenPO> {
        try {
            LogUtils.info("AppAccessTokenService", "=== AppAccessTokenService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findAppAccessTokenById(entityId)
            LogUtils.info("AppAccessTokenService", "=== findAppAccessTokenById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("AppAccessTokenService", "=== AppAccessToken found, id: ${entity.id} ===")
                return APIResult<AppAccessTokenPO>(entity)
            } else {
                LogUtils.info("AppAccessTokenService", "=== AppAccessToken not found for id: ${entityId} ===")
                return APIResult<AppAccessTokenPO>(false, "未找到该appAccessToken")
            }
        } catch (e: Exception) {
            LogUtils.error("AppAccessTokenService", "=== AppAccessTokenService.getById() exception: ${e.message} ===")
            return APIResult<AppAccessTokenPO>(false, e.message)
        }
    }
    
    /**
     * 获取appAccessToken列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return appAccessToken列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AppAccessTokenPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllAppAccessTokenPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取appAccessToken列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return appAccessToken列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AppAccessTokenPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllAppAccessTokenPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有appAccessToken列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return appAccessToken列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<AppAccessTokenPO>, Int64) {
        let pagination = getExecutor().findAllAppAccessTokenPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取appAccessToken
     * @param ids ID列表
     * @return appAccessToken列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<AppAccessTokenPO> {
        getExecutor().findAppAccessTokenByIds(ids)
    }
    
    /**
     * 统计用户的appAccessToken数量
     * @param userId 用户ID
     * @return appAccessToken数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countAppAccessTokenByCreator(userId)
    }
    
    /**
     * 统计所有appAccessToken数量
     * @return appAccessToken数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllAppAccessToken()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
