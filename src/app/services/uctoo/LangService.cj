/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.LangPO
import magic.app.dao.uctoo.LangDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * LangService - lang服务类
 * 
 * 提供lang相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class LangService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建lang
     * @param entity lang对象
     * @return 创建结果
     */
    public func create(entity: LangPO): APIResult<LangPO> {
        try {
            entity.createdAt = Some<DateTime>(DateTime.now())
            entity.updatedAt = Some<DateTime>(DateTime.now())
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertLang(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<LangPO>(entity)
            } else {
                return APIResult<LangPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<LangPO>(false, e.message)
        }
    }
    
    /**
     * 更新lang
     * @param entityId langID
     * @param entity lang对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: LangPO): APIResult<LangPO> {
        try {
            let existing = getExecutor().findLangById(entityId)
            
            if (existing.isNone()) {
                return APIResult<LangPO>(false, "lang不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.name.size > 0) {
                existingEntity.name = entity.name
            }
            if (entity.code.size > 0) {
                existingEntity.code = entity.code
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
            existingEntity.updatedAt = Some<DateTime>(DateTime.now())
            existingEntity.id = entityId
            
            let rows = getExecutor().updateLang(existingEntity)
            
            if (rows > 0) {
                return APIResult<LangPO>(existingEntity)
            } else {
                return APIResult<LangPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<LangPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新lang
     * @param entities lang列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<LangPO>): APIResult<ArrayList<LangPO>> {
        try {
            let updatedEntities = ArrayList<LangPO>()
            
            for (entity in entities) {
                entity.updatedAt = Some<DateTime>(DateTime.now())
                let rows = getExecutor().updateLang(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<LangPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<LangPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<LangPO>>(false, e.message)
        }
    }
    
    /**
     * 删除lang
     * @param entityId langID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findLangById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "lang不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteLangById(entityId)
            } else {
                rows = getExecutor().softDeleteLangById(entityId)
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
     * 批量删除lang
     * @param ids langID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findLangById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteLangById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteLangById(id)
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
     * 恢复软删除的lang
     * @param entityId langID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<LangPO> {
        try {
            let rows = getExecutor().restoreLangById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findLangById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<LangPO>(entity)
                } else {
                    return APIResult<LangPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<LangPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<LangPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的lang
     * @param ids langID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreLangById(id)
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
     * 根据ID获取lang
     * 
     * 设计说明：
     * - 通过ID获取lang时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId langID
     * @return lang对象
     */
    public func getById(entityId: String): APIResult<LangPO> {
        try {
            LogUtils.info("LangService", "=== LangService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findLangById(entityId)
            LogUtils.info("LangService", "=== findLangById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("LangService", "=== Lang found, id: ${entity.id} ===")
                return APIResult<LangPO>(entity)
            } else {
                LogUtils.info("LangService", "=== Lang not found for id: ${entityId} ===")
                return APIResult<LangPO>(false, "未找到该lang")
            }
        } catch (e: Exception) {
            LogUtils.error("LangService", "=== LangService.getById() exception: ${e.message} ===")
            return APIResult<LangPO>(false, e.message)
        }
    }
    
    /**
     * 获取lang列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return lang列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<LangPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllLangPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取lang列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return lang列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<LangPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllLangPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有lang列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return lang列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<LangPO>, Int64) {
        let pagination = getExecutor().findAllLangPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取lang
     * @param ids ID列表
     * @return lang列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<LangPO> {
        getExecutor().findLangByIds(ids)
    }
    
    /**
     * 统计用户的lang数量
     * @param userId 用户ID
     * @return lang数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countLangByCreator(userId)
    }
    
    /**
     * 统计所有lang数量
     * @return lang数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllLang()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
