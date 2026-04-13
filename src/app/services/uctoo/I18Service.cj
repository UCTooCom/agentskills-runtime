/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.I18PO
import magic.app.models.uctoo.LangPO
import magic.app.dao.uctoo.I18DAO
import magic.app.dao.uctoo.LangDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * I18Service - i18服务类
 * 
 * 提供i18相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class I18Service {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建i18
     * @param entity i18对象
     * @return 创建结果
     */
    public func create(entity: I18PO): APIResult<I18PO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertI18(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<I18PO>(entity)
            } else {
                return APIResult<I18PO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<I18PO>(false, e.message)
        }
    }
    
    /**
     * 更新i18
     * @param entityId i18ID
     * @param entity i18对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: I18PO): APIResult<I18PO> {
        try {
            let existing = getExecutor().findI18ById(entityId)
            
            if (existing.isNone()) {
                return APIResult<I18PO>(false, "i18不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.key.size > 0) {
                existingEntity.key = entity.key
            }
            if (entity.content.size > 0) {
                existingEntity.content = entity.content
            }
            if (entity.langId.isSome()) {
                existingEntity.langId = entity.langId
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
            
            let rows = getExecutor().updateI18(existingEntity)
            
            if (rows > 0) {
                return APIResult<I18PO>(existingEntity)
            } else {
                return APIResult<I18PO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<I18PO>(false, e.message)
        }
    }
    
    /**
     * 批量更新i18
     * @param entities i18列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<I18PO>): APIResult<ArrayList<I18PO>> {
        try {
            let updatedEntities = ArrayList<I18PO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateI18(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<I18PO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<I18PO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<I18PO>>(false, e.message)
        }
    }
    
    /**
     * 删除i18
     * @param entityId i18ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findI18ById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "i18不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteI18ById(entityId)
            } else {
                rows = getExecutor().softDeleteI18ById(entityId)
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
     * 批量删除i18
     * @param ids i18ID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findI18ById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteI18ById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteI18ById(id)
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
     * 恢复软删除的i18
     * @param entityId i18ID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<I18PO> {
        try {
            let rows = getExecutor().restoreI18ById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findI18ById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<I18PO>(entity)
                } else {
                    return APIResult<I18PO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<I18PO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<I18PO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的i18
     * @param ids i18ID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreI18ById(id)
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
     * 根据ID获取i18
     * 
     * 设计说明：
     * - 通过ID获取i18时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId i18ID
     * @return i18对象
     */
    public func getById(entityId: String): APIResult<I18PO> {
        try {
            LogUtils.info("I18Service", "=== I18Service.getById() called with id: ${entityId} ===")
            let result = getExecutor().findI18ById(entityId)
            LogUtils.info("I18Service", "=== findI18ById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("I18Service", "=== I18 found, id: ${entity.id} ===")
                return APIResult<I18PO>(entity)
            } else {
                LogUtils.info("I18Service", "=== I18 not found for id: ${entityId} ===")
                return APIResult<I18PO>(false, "未找到该i18")
            }
        } catch (e: Exception) {
            LogUtils.error("I18Service", "=== I18Service.getById() exception: ${e.message} ===")
            return APIResult<I18PO>(false, e.message)
        }
    }
    
    /**
     * 获取i18列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return i18列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<I18PO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllI18Page(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取i18列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return i18列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<I18PO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllI18Page(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有i18列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return i18列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<I18PO>, Int64) {
        let pagination = getExecutor().findAllI18Page(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取i18
     * @param ids ID列表
     * @return i18列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<I18PO> {
        getExecutor().findI18ByIds(ids)
    }
    
    /**
     * 统计用户的i18数量
     * @param userId 用户ID
     * @return i18数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countI18ByCreator(userId)
    }
    
    /**
     * 统计所有i18数量
     * @return i18数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllI18()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 获取格式化后的国际化词条树
     * @param lang 语言名称（可选）
     * @return 格式化后的国际化数据 Record<lang_name, Record<i18_key, i18_content>>
     */
    public func getFormat(lang: String): HashMap<String, HashMap<String, String>> {
        try {
            let result = HashMap<String, HashMap<String, String>>()
            
            // 查询语言列表
            let langs = if (lang.isEmpty()) {
                getExecutor().findAllLang()
            } else {
                getExecutor().findLangByName(lang)
            }
            
            // 遍历每个语言
            for (langItem in langs) {
                let langName = langItem.name
                let i18Map = HashMap<String, String>()
                
                // 查询该语言下的所有i18条目
                let i18Items = getExecutor().findI18ByLangId(langItem.id)
                
                // 遍历i18条目，构建key-content映射
                for (i18Item in i18Items) {
                    i18Map[i18Item.key] = i18Item.content
                }
                
                result[langName] = i18Map
            }
            
            result
        } catch (e: Exception) {
            LogUtils.error("getFormat failed: ${e.message}")
            HashMap<String, HashMap<String, String>>()
        }
    }
}
