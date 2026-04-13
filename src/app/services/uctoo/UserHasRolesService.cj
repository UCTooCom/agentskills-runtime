/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.UserHasRolesPO
import magic.app.dao.uctoo.UserHasRolesDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * UserHasRolesService - user_has_roles服务类
 * 
 * 提供user_has_roles相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class UserHasRolesService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建userHasRoles
     * @param entity userHasRoles对象
     * @return 创建结果
     */
    public func create(entity: UserHasRolesPO): APIResult<UserHasRolesPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertUserHasRoles(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<UserHasRolesPO>(entity)
            } else {
                return APIResult<UserHasRolesPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasRolesPO>(false, e.message)
        }
    }
    
    /**
     * 更新userHasRoles
     * @param entityId userHasRolesID
     * @param entity userHasRoles对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: UserHasRolesPO): APIResult<UserHasRolesPO> {
        try {
            let existing = getExecutor().findUserHasRolesById(entityId)
            
            if (existing.isNone()) {
                return APIResult<UserHasRolesPO>(false, "userHasRoles不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.userId.size > 0) {
                existingEntity.userId = entity.userId
            }
            if (entity.roleId.size > 0) {
                existingEntity.roleId = entity.roleId
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
            
            let rows = getExecutor().updateUserHasRoles(existingEntity)
            
            if (rows > 0) {
                return APIResult<UserHasRolesPO>(existingEntity)
            } else {
                return APIResult<UserHasRolesPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasRolesPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新userHasRoles
     * @param entities userHasRoles列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<UserHasRolesPO>): APIResult<ArrayList<UserHasRolesPO>> {
        try {
            let updatedEntities = ArrayList<UserHasRolesPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateUserHasRoles(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<UserHasRolesPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<UserHasRolesPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<UserHasRolesPO>>(false, e.message)
        }
    }
    
    /**
     * 删除userHasRoles
     * @param entityId userHasRolesID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findUserHasRolesById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "userHasRoles不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteUserHasRolesById(entityId)
            } else {
                rows = getExecutor().softDeleteUserHasRolesById(entityId)
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
     * 批量删除userHasRoles
     * @param ids userHasRolesID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findUserHasRolesById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteUserHasRolesById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteUserHasRolesById(id)
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
     * 恢复软删除的userHasRoles
     * @param entityId userHasRolesID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<UserHasRolesPO> {
        try {
            let rows = getExecutor().restoreUserHasRolesById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findUserHasRolesById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<UserHasRolesPO>(entity)
                } else {
                    return APIResult<UserHasRolesPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<UserHasRolesPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<UserHasRolesPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的userHasRoles
     * @param ids userHasRolesID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreUserHasRolesById(id)
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
     * 根据ID获取userHasRoles
     * 
     * 设计说明：
     * - 通过ID获取userHasRoles时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId userHasRolesID
     * @return userHasRoles对象
     */
    public func getById(entityId: String): APIResult<UserHasRolesPO> {
        try {
            LogUtils.info("UserHasRolesService", "=== UserHasRolesService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findUserHasRolesById(entityId)
            LogUtils.info("UserHasRolesService", "=== findUserHasRolesById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("UserHasRolesService", "=== UserHasRoles found, id: ${entity.id} ===")
                return APIResult<UserHasRolesPO>(entity)
            } else {
                LogUtils.info("UserHasRolesService", "=== UserHasRoles not found for id: ${entityId} ===")
                return APIResult<UserHasRolesPO>(false, "未找到该userHasRoles")
            }
        } catch (e: Exception) {
            LogUtils.error("UserHasRolesService", "=== UserHasRolesService.getById() exception: ${e.message} ===")
            return APIResult<UserHasRolesPO>(false, e.message)
        }
    }
    
    /**
     * 获取userHasRoles列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return userHasRoles列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UserHasRolesPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUserHasRolesPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取userHasRoles列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return userHasRoles列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UserHasRolesPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUserHasRolesPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有userHasRoles列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return userHasRoles列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<UserHasRolesPO>, Int64) {
        let pagination = getExecutor().findAllUserHasRolesPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取userHasRoles
     * @param ids ID列表
     * @return userHasRoles列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<UserHasRolesPO> {
        getExecutor().findUserHasRolesByIds(ids)
    }
    
    /**
     * 统计用户的userHasRoles数量
     * @param userId 用户ID
     * @return userHasRoles数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countUserHasRolesByCreator(userId)
    }
    
    /**
     * 统计所有userHasRoles数量
     * @return userHasRoles数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllUserHasRoles()
    }

    //#endregion AutoCreateCode

    // ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 根据用户ID查询用户角色关联
     * @param userId 用户ID
     * @return 用户角色关联列表
     */
    public func findByUserId(userId: String): ArrayList<UserHasRolesPO> {
        try {
            getExecutor().findUserHasRolesByUserId(userId)
        } catch (e: Exception) {
            ArrayList<UserHasRolesPO>()
        }
    }
}
