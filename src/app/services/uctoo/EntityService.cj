/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.EntityPO
import magic.app.dao.uctoo.EntityDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * EntityService - 实体服务类
 * 
 * 提供实体相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class EntityService {
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
     * 创建entity
     * @param entity entity对象
     * @return 创建结果
     */
    public func create(entity: EntityPO): APIResult<EntityPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertEntity(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<EntityPO>(entity)
            } else {
                return APIResult<EntityPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<EntityPO>(false, e.message)
        }
    }
    
    /**
     * 更新entity
     * @param entityId entityID
     * @param entity entity对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: EntityPO): APIResult<EntityPO> {
        try {
            let existing = getExecutor().findEntityById(entityId)
            
            if (existing.isNone()) {
                return APIResult<EntityPO>(false, "entity不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.link.size > 0) {
                existingEntity.link = entity.link
            }
            if (entity.privacyLevel.isSome()) {
                existingEntity.privacyLevel = entity.privacyLevel
            }
            if (entity.stars.isSome()) {
                existingEntity.stars = entity.stars
            }
            if (entity.description.isSome()) {
                existingEntity.description = entity.description
            }
            if (entity.groupId.isSome()) {
                existingEntity.groupId = entity.groupId
            }
            if (entity.picture.isSome()) {
                existingEntity.picture = entity.picture
            }
            if (entity.images.isSome()) {
                existingEntity.images = entity.images
            }
            if (entity.content.isSome()) {
                existingEntity.content = entity.content
            }
            if (entity.json.isSome()) {
                existingEntity.json = entity.json
            }
            if (entity.city.isSome()) {
                existingEntity.city = entity.city
            }
            if (entity.price.isSome()) {
                existingEntity.price = entity.price
            }
            if (entity.birthday.isSome()) {
                existingEntity.birthday = entity.birthday
            }
            if (entity.owner.isSome()) {
                existingEntity.owner = entity.owner
            }
            if (entity.creator.size > 0) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.endTime.isSome()) {
                existingEntity.endTime = entity.endTime
            }
            if (entity.startTime.isSome()) {
                existingEntity.startTime = entity.startTime
            }
            if (entity.status.isSome()) {
                existingEntity.status = entity.status
            }
            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateEntity(existingEntity)
            
            if (rows > 0) {
                return APIResult<EntityPO>(existingEntity)
            } else {
                return APIResult<EntityPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<EntityPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新entity
     * @param entities entity列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<EntityPO>): APIResult<ArrayList<EntityPO>> {
        try {
            let updatedEntities = ArrayList<EntityPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateEntity(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<EntityPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<EntityPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<EntityPO>>(false, e.message)
        }
    }
    
    /**
     * 删除entity
     * @param entityId entityID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findEntityById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "entity不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteEntityById(entityId)
            } else {
                rows = getExecutor().softDeleteEntityById(entityId)
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
     * 批量删除entity
     * @param ids entityID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findEntityById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteEntityById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteEntityById(id)
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
     * 恢复软删除的entity
     * @param entityId entityID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<EntityPO> {
        try {
            let rows = getExecutor().restoreEntityById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findEntityById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<EntityPO>(entity)
                } else {
                    return APIResult<EntityPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<EntityPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<EntityPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的entity
     * @param ids entityID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreEntityById(id)
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
     * 根据ID获取entity
     * 
     * 设计说明：
     * - 通过ID获取entity时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId entityID
     * @return entity对象
     */
    public func getById(entityId: String): APIResult<EntityPO> {
        try {
            LogUtils.info("EntityService", "=== EntityService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findEntityById(entityId)
            LogUtils.info("EntityService", "=== findEntityById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("EntityService", "=== Entity found, id: ${entity.id} ===")
                return APIResult<EntityPO>(entity)
            } else {
                LogUtils.info("EntityService", "=== Entity not found for id: ${entityId} ===")
                return APIResult<EntityPO>(false, "未找到该entity")
            }
        } catch (e: Exception) {
            LogUtils.error("EntityService", "=== EntityService.getById() exception: ${e.message} ===")
            return APIResult<EntityPO>(false, e.message)
        }
    }
    
    /**
     * 获取entity列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return entity列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<EntityPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllEntityPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取entity列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return entity列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<EntityPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllEntityPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有entity列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return entity列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<EntityPO>, Int64) {
        let pagination = getExecutor().findAllEntityPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取entity
     * @param ids ID列表
     * @return entity列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<EntityPO> {
        getExecutor().findEntityByIds(ids)
    }
    
    /**
     * 统计用户的entity数量
     * @param userId 用户ID
     * @return entity数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countEntityByCreator(userId)
    }
    
    /**
     * 统计所有entity数量
     * @return entity数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllEntity()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 生成UUID
     * @return UUID字符串
     */
    private func generateId(): String {
        let timestamp = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
        let random = (timestamp % 10000).toString()
        "entity-${timestamp}-${random}"
    }
}
