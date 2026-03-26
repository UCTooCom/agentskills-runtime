/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.UserHasAccountPO
import magic.app.dao.uctoo.UserHasAccountDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * UserHasAccountService - user_has_account服务类
 * 
 * 提供user_has_account相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class UserHasAccountService {
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
     * 创建userHasAccount
     * @param entity userHasAccount对象
     * @return 创建结果
     */
    public func create(entity: UserHasAccountPO): APIResult<UserHasAccountPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertUserHasAccount(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<UserHasAccountPO>(entity)
            } else {
                return APIResult<UserHasAccountPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasAccountPO>(false, e.message)
        }
    }
    
    /**
     * 更新userHasAccount
     * @param entityId userHasAccountID
     * @param entity userHasAccount对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: UserHasAccountPO): APIResult<UserHasAccountPO> {
        try {
            let existing = getExecutor().findUserHasAccountById(entityId)
            
            if (existing.isNone()) {
                return APIResult<UserHasAccountPO>(false, "userHasAccount不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.userId.size > 0) {
                existingEntity.userId = entity.userId
            }
            if (entity.accountId.size > 0) {
                existingEntity.accountId = entity.accountId
            }
            if (entity.accountType.size > 0) {
                existingEntity.accountType = entity.accountType
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
            
            let rows = getExecutor().updateUserHasAccount(existingEntity)
            
            if (rows > 0) {
                return APIResult<UserHasAccountPO>(existingEntity)
            } else {
                return APIResult<UserHasAccountPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasAccountPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新userHasAccount
     * @param entities userHasAccount列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<UserHasAccountPO>): APIResult<ArrayList<UserHasAccountPO>> {
        try {
            let updatedEntities = ArrayList<UserHasAccountPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateUserHasAccount(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<UserHasAccountPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<UserHasAccountPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<UserHasAccountPO>>(false, e.message)
        }
    }
    
    /**
     * 删除userHasAccount
     * @param entityId userHasAccountID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findUserHasAccountById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "userHasAccount不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteUserHasAccountById(entityId)
            } else {
                rows = getExecutor().softDeleteUserHasAccountById(entityId)
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
     * 批量删除userHasAccount
     * @param ids userHasAccountID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findUserHasAccountById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteUserHasAccountById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteUserHasAccountById(id)
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
     * 恢复软删除的userHasAccount
     * @param entityId userHasAccountID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<UserHasAccountPO> {
        try {
            let rows = getExecutor().restoreUserHasAccountById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findUserHasAccountById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<UserHasAccountPO>(entity)
                } else {
                    return APIResult<UserHasAccountPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<UserHasAccountPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasAccountPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的userHasAccount
     * @param ids userHasAccountID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreUserHasAccountById(id)
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
     * 根据ID获取userHasAccount
     * 
     * 设计说明：
     * - 通过ID获取userHasAccount时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId userHasAccountID
     * @return userHasAccount对象
     */
    public func getById(entityId: String): APIResult<UserHasAccountPO> {
        try {
            LogUtils.info("UserHasAccountService", "=== UserHasAccountService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findUserHasAccountById(entityId)
            LogUtils.info("UserHasAccountService", "=== findUserHasAccountById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("UserHasAccountService", "=== UserHasAccount found, id: ${entity.id} ===")
                return APIResult<UserHasAccountPO>(entity)
            } else {
                LogUtils.info("UserHasAccountService", "=== UserHasAccount not found for id: ${entityId} ===")
                return APIResult<UserHasAccountPO>(false, "未找到该userHasAccount")
            }
        } catch (e: Exception) {
            LogUtils.error("UserHasAccountService", "=== UserHasAccountService.getById() exception: ${e.message} ===")
            return APIResult<UserHasAccountPO>(false, e.message)
        }
    }
    
    /**
     * 获取userHasAccount列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return userHasAccount列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UserHasAccountPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUserHasAccountPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取userHasAccount列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return userHasAccount列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UserHasAccountPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUserHasAccountPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有userHasAccount列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return userHasAccount列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<UserHasAccountPO>, Int64) {
        let pagination = getExecutor().findAllUserHasAccountPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取userHasAccount
     * @param ids ID列表
     * @return userHasAccount列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<UserHasAccountPO> {
        getExecutor().findUserHasAccountByIds(ids)
    }
    
    /**
     * 统计用户的userHasAccount数量
     * @param userId 用户ID
     * @return userHasAccount数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countUserHasAccountByCreator(userId)
    }
    
    /**
     * 统计所有userHasAccount数量
     * @return userHasAccount数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllUserHasAccount()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
