/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.UctooUserPO
import magic.app.dao.uctoo.UctooUserDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * UctooUserService - uctoo_user服务类
 * 
 * 提供uctoo_user相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class UctooUserService {
    // 不缓存 SqlExecutor，每次都获取新的实例
    // 缓存会导致连接被关闭后仍然被复用的问题
    
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建uctooUser
     * @param entity uctooUser对象
     * @return 创建结果
     */
    public func create(entity: UctooUserPO): APIResult<UctooUserPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertUctooUser(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<UctooUserPO>(entity)
            } else {
                return APIResult<UctooUserPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }
    
    /**
     * 更新uctooUser
     * @param entityId uctooUserID
     * @param entity uctooUser对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: UctooUserPO): APIResult<UctooUserPO> {
        try {
            let existing = getExecutor().findUctooUserById(entityId)
            
            if (existing.isNone()) {
                return APIResult<UctooUserPO>(false, "uctooUser不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.name.size > 0) {
                existingEntity.name = entity.name
            }
            if (entity.username.size > 0) {
                existingEntity.username = entity.username
            }
            if (entity.email.size > 0) {
                existingEntity.email = entity.email
            }
            if (entity.password.size > 0) {
                existingEntity.password = entity.password
            }
            if (entity.avatar.isSome()) {
                existingEntity.avatar = entity.avatar
            }
            if (entity.authProvider.isSome()) {
                existingEntity.authProvider = entity.authProvider
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.lastLoginIp.isSome()) {
                existingEntity.lastLoginIp = entity.lastLoginIp
            }
            if (entity.rememberToken.isSome()) {
                existingEntity.rememberToken = entity.rememberToken
            }
            if (entity.status.isSome()) {
                existingEntity.status = entity.status
            }
            if (entity.accessToken.isSome()) {
                existingEntity.accessToken = entity.accessToken
            }
            if (entity.refreshToken.isSome()) {
                existingEntity.refreshToken = entity.refreshToken
            }
            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateUctooUser(existingEntity)
            
            if (rows > 0) {
                return APIResult<UctooUserPO>(existingEntity)
            } else {
                return APIResult<UctooUserPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新uctooUser
     * @param entities uctooUser列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<UctooUserPO>): APIResult<ArrayList<UctooUserPO>> {
        try {
            let updatedEntities = ArrayList<UctooUserPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateUctooUser(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<UctooUserPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<UctooUserPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<UctooUserPO>>(false, e.message)
        }
    }
    
    /**
     * 删除uctooUser
     * @param entityId uctooUserID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findUctooUserById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "uctooUser不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteUctooUserById(entityId)
            } else {
                rows = getExecutor().softDeleteUctooUserById(entityId)
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
     * 批量删除uctooUser
     * @param ids uctooUserID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findUctooUserById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteUctooUserById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteUctooUserById(id)
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
     * 恢复软删除的uctooUser
     * @param entityId uctooUserID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<UctooUserPO> {
        try {
            let rows = getExecutor().restoreUctooUserById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findUctooUserById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<UctooUserPO>(entity)
                } else {
                    return APIResult<UctooUserPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<UctooUserPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooUserPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的uctooUser
     * @param ids uctooUserID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreUctooUserById(id)
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
     * 根据ID获取uctooUser
     * 
     * 设计说明：
     * - 通过ID获取uctooUser时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId uctooUserID
     * @return uctooUser对象
     */
    public func getById(entityId: String): APIResult<UctooUserPO> {
        try {
            LogUtils.info("UctooUserService", "=== UctooUserService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findUctooUserById(entityId)
            LogUtils.info("UctooUserService", "=== findUctooUserById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("UctooUserService", "=== UctooUser found, id: ${entity.id} ===")
                return APIResult<UctooUserPO>(entity)
            } else {
                LogUtils.info("UctooUserService", "=== UctooUser not found for id: ${entityId} ===")
                return APIResult<UctooUserPO>(false, "未找到该uctooUser")
            }
        } catch (e: Exception) {
            LogUtils.error("UctooUserService", "=== UctooUserService.getById() exception: ${e.message} ===")
            return APIResult<UctooUserPO>(false, e.message)
        }
    }
    
    /**
     * 获取uctooUser列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return uctooUser列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UctooUserPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUctooUserPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取uctooUser列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return uctooUser列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UctooUserPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUctooUserPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有uctooUser列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return uctooUser列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<UctooUserPO>, Int64) {
        let pagination = getExecutor().findAllUctooUserPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取uctooUser
     * @param ids ID列表
     * @return uctooUser列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<UctooUserPO> {
        getExecutor().findUctooUserByIds(ids)
    }
    
    /**
     * 统计用户的uctooUser数量
     * @param userId 用户ID
     * @return uctooUser数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countUctooUserByCreator(userId)
    }
    
    /**
     * 统计所有uctooUser数量
     * @return uctooUser数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllUctooUser()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 根据用户名查找用户
     * @param username 用户名
     * @return 用户对象
     */
    public func findByUsername(username: String): ?UctooUserPO {
        try {
            getExecutor().findUctooUserByUsername(username)
        } catch (e: Exception) {
            LogUtils.error("findByUsername failed: ${e.message}")
            None<UctooUserPO>
        }
    }
    
    /**
     * 根据邮箱查找用户
     * @param email 邮箱
     * @return 用户对象
     */
    public func findByEmail(email: String): ?UctooUserPO {
        try {
            getExecutor().findUctooUserByEmail(email)
        } catch (e: Exception) {
            LogUtils.error("findByEmail failed: ${e.message}")
            None<UctooUserPO>
        }
    }
    
    /**
     * 更新用户的access_token和refresh_token
     * @param userId 用户ID
     * @param accessToken access_token
     * @param refreshToken refresh_token
     * @return 更新是否成功
     */
    public func updateTokens(userId: String, accessToken: String, refreshToken: String): Bool {
        try {
            let existing = getExecutor().findUctooUserById(userId)
            if (let Some(user) <- existing) {
                user.accessToken = Some<String>(accessToken)
                user.refreshToken = Some<String>(refreshToken)
                user.updatedAt = DateTime.now()
                let rows = getExecutor().updateUctooUser(user)
                return rows > 0
            }
            false
        } catch (e: Exception) {
            LogUtils.error("updateTokens failed: ${e.message}")
            false
        }
    }
    
    /**
     * 更新用户access_token
     * @param userId 用户ID
     * @param accessToken access_token
     * @return 更新是否成功
     */
    public func updateAccessToken(userId: String, accessToken: String): Bool {
        try {
            let existing = getExecutor().findUctooUserById(userId)
            if (let Some(user) <- existing) {
                user.accessToken = Some<String>(accessToken)
                user.updatedAt = DateTime.now()
                let rows = getExecutor().updateUctooUser(user)
                return rows > 0
            }
            false
        } catch (e: Exception) {
            LogUtils.error("updateAccessToken failed: ${e.message}")
            false
        }
    }
}
