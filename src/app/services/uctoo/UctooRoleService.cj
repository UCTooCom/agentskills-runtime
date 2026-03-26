/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.UctooRolePO
import magic.app.dao.uctoo.UctooRoleDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * UctooRoleService - uctoo_role服务类
 * 
 * 提供uctoo_role相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class UctooRoleService {
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
     * 创建uctooRole
     * @param entity uctooRole对象
     * @return 创建结果
     */
    public func create(entity: UctooRolePO): APIResult<UctooRolePO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertUctooRole(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<UctooRolePO>(entity)
            } else {
                return APIResult<UctooRolePO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooRolePO>(false, e.message)
        }
    }
    
    /**
     * 更新uctooRole
     * @param entityId uctooRoleID
     * @param entity uctooRole对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: UctooRolePO): APIResult<UctooRolePO> {
        try {
            let existing = getExecutor().findUctooRoleById(entityId)
            
            if (existing.isNone()) {
                return APIResult<UctooRolePO>(false, "uctooRole不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.name.size > 0) {
                existingEntity.name = entity.name
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
            
            let rows = getExecutor().updateUctooRole(existingEntity)
            
            if (rows > 0) {
                return APIResult<UctooRolePO>(existingEntity)
            } else {
                return APIResult<UctooRolePO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooRolePO>(false, e.message)
        }
    }
    
    /**
     * 批量更新uctooRole
     * @param entities uctooRole列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<UctooRolePO>): APIResult<ArrayList<UctooRolePO>> {
        try {
            let updatedEntities = ArrayList<UctooRolePO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateUctooRole(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<UctooRolePO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<UctooRolePO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<UctooRolePO>>(false, e.message)
        }
    }
    
    /**
     * 删除uctooRole
     * @param entityId uctooRoleID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findUctooRoleById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "uctooRole不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteUctooRoleById(entityId)
            } else {
                rows = getExecutor().softDeleteUctooRoleById(entityId)
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
     * 批量删除uctooRole
     * @param ids uctooRoleID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findUctooRoleById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteUctooRoleById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteUctooRoleById(id)
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
     * 恢复软删除的uctooRole
     * @param entityId uctooRoleID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<UctooRolePO> {
        try {
            let rows = getExecutor().restoreUctooRoleById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findUctooRoleById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<UctooRolePO>(entity)
                } else {
                    return APIResult<UctooRolePO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<UctooRolePO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooRolePO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的uctooRole
     * @param ids uctooRoleID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreUctooRoleById(id)
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
     * 根据ID获取uctooRole
     * 
     * 设计说明：
     * - 通过ID获取uctooRole时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId uctooRoleID
     * @return uctooRole对象
     */
    public func getById(entityId: String): APIResult<UctooRolePO> {
        try {
            LogUtils.info("UctooRoleService", "=== UctooRoleService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findUctooRoleById(entityId)
            LogUtils.info("UctooRoleService", "=== findUctooRoleById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("UctooRoleService", "=== UctooRole found, id: ${entity.id} ===")
                return APIResult<UctooRolePO>(entity)
            } else {
                LogUtils.info("UctooRoleService", "=== UctooRole not found for id: ${entityId} ===")
                return APIResult<UctooRolePO>(false, "未找到该uctooRole")
            }
        } catch (e: Exception) {
            LogUtils.error("UctooRoleService", "=== UctooRoleService.getById() exception: ${e.message} ===")
            return APIResult<UctooRolePO>(false, e.message)
        }
    }
    
    /**
     * 获取uctooRole列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return uctooRole列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UctooRolePO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUctooRolePage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取uctooRole列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return uctooRole列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UctooRolePO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUctooRolePage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有uctooRole列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return uctooRole列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<UctooRolePO>, Int64) {
        let pagination = getExecutor().findAllUctooRolePage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取uctooRole
     * @param ids ID列表
     * @return uctooRole列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<UctooRolePO> {
        getExecutor().findUctooRoleByIds(ids)
    }
    
    /**
     * 统计用户的uctooRole数量
     * @param userId 用户ID
     * @return uctooRole数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countUctooRoleByCreator(userId)
    }
    
    /**
     * 统计所有uctooRole数量
     * @return uctooRole数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllUctooRole()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
