/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.UserGroupPO
import magic.app.dao.uctoo.UserGroupDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * UserGroupService - user_group服务类
 * 
 * 提供user_group相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class UserGroupService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建userGroup
     * @param entity userGroup对象
     * @return 创建结果
     */
    public func create(entity: UserGroupPO): APIResult<UserGroupPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertUserGroup(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<UserGroupPO>(entity)
            } else {
                return APIResult<UserGroupPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<UserGroupPO>(false, e.message)
        }
    }
    
    /**
     * 更新userGroup
     * @param entityId userGroupID
     * @param entity userGroup对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: UserGroupPO): APIResult<UserGroupPO> {
        try {
            let existing = getExecutor().findUserGroupById(entityId)
            
            if (existing.isNone()) {
                return APIResult<UserGroupPO>(false, "userGroup不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.groupName.size > 0) {
                existingEntity.groupName = entity.groupName
            }
            if (entity.parentId.isSome()) {
                existingEntity.parentId = entity.parentId
            }
            if (entity.code.size > 0) {
                existingEntity.code = entity.code
            }
            if (entity.intro.isSome()) {
                existingEntity.intro = entity.intro
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
            
            let rows = getExecutor().updateUserGroup(existingEntity)
            
            if (rows > 0) {
                return APIResult<UserGroupPO>(existingEntity)
            } else {
                return APIResult<UserGroupPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<UserGroupPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新userGroup
     * @param entities userGroup列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<UserGroupPO>): APIResult<ArrayList<UserGroupPO>> {
        try {
            let updatedEntities = ArrayList<UserGroupPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateUserGroup(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<UserGroupPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<UserGroupPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<UserGroupPO>>(false, e.message)
        }
    }
    
    /**
     * 删除userGroup
     * @param entityId userGroupID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findUserGroupById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "userGroup不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteUserGroupById(entityId)
            } else {
                rows = getExecutor().softDeleteUserGroupById(entityId)
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
     * 批量删除userGroup
     * @param ids userGroupID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findUserGroupById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteUserGroupById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteUserGroupById(id)
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
     * 恢复软删除的userGroup
     * @param entityId userGroupID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<UserGroupPO> {
        try {
            let rows = getExecutor().restoreUserGroupById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findUserGroupById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<UserGroupPO>(entity)
                } else {
                    return APIResult<UserGroupPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<UserGroupPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<UserGroupPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的userGroup
     * @param ids userGroupID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreUserGroupById(id)
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
     * 根据ID获取userGroup
     * 
     * 设计说明：
     * - 通过ID获取userGroup时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId userGroupID
     * @return userGroup对象
     */
    public func getById(entityId: String): APIResult<UserGroupPO> {
        try {
            LogUtils.info("UserGroupService", "=== UserGroupService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findUserGroupById(entityId)
            LogUtils.info("UserGroupService", "=== findUserGroupById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("UserGroupService", "=== UserGroup found, id: ${entity.id} ===")
                return APIResult<UserGroupPO>(entity)
            } else {
                LogUtils.info("UserGroupService", "=== UserGroup not found for id: ${entityId} ===")
                return APIResult<UserGroupPO>(false, "未找到该userGroup")
            }
        } catch (e: Exception) {
            LogUtils.error("UserGroupService", "=== UserGroupService.getById() exception: ${e.message} ===")
            return APIResult<UserGroupPO>(false, e.message)
        }
    }
    
    /**
     * 获取userGroup列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return userGroup列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UserGroupPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUserGroupPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取userGroup列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return userGroup列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UserGroupPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUserGroupPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有userGroup列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return userGroup列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<UserGroupPO>, Int64) {
        let pagination = getExecutor().findAllUserGroupPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取userGroup
     * @param ids ID列表
     * @return userGroup列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<UserGroupPO> {
        getExecutor().findUserGroupByIds(ids)
    }
    
    /**
     * 统计用户的userGroup数量
     * @param userId 用户ID
     * @return userGroup数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countUserGroupByCreator(userId)
    }
    
    /**
     * 统计所有userGroup数量
     * @return userGroup数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllUserGroup()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
