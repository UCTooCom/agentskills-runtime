/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.ApplicationPO
import magic.app.dao.uctoo.ApplicationDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery}
import magic.log.LogUtils

/**
 * ApplicationService - application服务类
 * 
 * 提供application相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class ApplicationService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    // 查询解析服务
    private let requestParser = RequestParserService()
    
    public init() {}
    
    
    
    /**
     * 创建application
     * @param entity application对象
     * @return 创建结果
     */
    public func create(entity: ApplicationPO): APIResult<ApplicationPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertApplication(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<ApplicationPO>(entity)
            } else {
                return APIResult<ApplicationPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<ApplicationPO>(false, e.message)
        }
    }
    
    /**
     * 更新application
     * @param entityId applicationID
     * @param entity application对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: ApplicationPO): APIResult<ApplicationPO> {
        try {
            let existing = getExecutor().findApplicationById(entityId)
            
            if (existing.isNone()) {
                return APIResult<ApplicationPO>(false, "application不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.name.size > 0) {
                existingEntity.name = entity.name
            }
            if (entity.description.size > 0) {
                existingEntity.description = entity.description
            }
            if (entity.icon.size > 0) {
                existingEntity.icon = entity.icon
            }
            if (entity.tag.size > 0) {
                existingEntity.tag = entity.tag
            }
            if (entity.classify.size > 0) {
                existingEntity.classify = entity.classify
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
            
            let rows = getExecutor().updateApplication(existingEntity)
            
            if (rows > 0) {
                return APIResult<ApplicationPO>(existingEntity)
            } else {
                return APIResult<ApplicationPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ApplicationPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新application
     * @param entities application列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<ApplicationPO>): APIResult<ArrayList<ApplicationPO>> {
        try {
            let updatedEntities = ArrayList<ApplicationPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateApplication(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<ApplicationPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<ApplicationPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<ApplicationPO>>(false, e.message)
        }
    }
    
    /**
     * 删除application
     * @param entityId applicationID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findApplicationById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "application不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteApplicationById(entityId)
            } else {
                rows = getExecutor().softDeleteApplicationById(entityId)
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
     * 批量删除application
     * @param ids applicationID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findApplicationById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteApplicationById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteApplicationById(id)
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
     * 恢复软删除的application
     * @param entityId applicationID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<ApplicationPO> {
        try {
            let rows = getExecutor().restoreApplicationById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findApplicationById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<ApplicationPO>(entity)
                } else {
                    return APIResult<ApplicationPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<ApplicationPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<ApplicationPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的application
     * @param ids applicationID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreApplicationById(id)
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
     * 根据ID获取application
     * 
     * 设计说明：
     * - 通过ID获取application时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId applicationID
     * @return application对象
     */
    public func getById(entityId: String): APIResult<ApplicationPO> {
        try {
            LogUtils.info("ApplicationService", "=== ApplicationService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findApplicationById(entityId)
            LogUtils.info("ApplicationService", "=== findApplicationById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("ApplicationService", "=== Application found, id: ${entity.id} ===")
                return APIResult<ApplicationPO>(entity)
            } else {
                LogUtils.info("ApplicationService", "=== Application not found for id: ${entityId} ===")
                return APIResult<ApplicationPO>(false, "未找到该application")
            }
        } catch (e: Exception) {
            LogUtils.error("ApplicationService", "=== ApplicationService.getById() exception: ${e.message} ===")
            return APIResult<ApplicationPO>(false, e.message)
        }
    }
    
    /**
     * 获取application列表（分页）
     * 
     * 支持动态查询：
     * - filter: JSON 格式的过滤条件，如 {"classify":{"equals":"dev"}}
     * - sort: 排序条件，如 "-created_at,name"
     * 
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return application列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<ApplicationPO>, Int64) {
        try {
            LogUtils.info("ApplicationService", "=== getList called ===")
            LogUtils.info("ApplicationService", "Page: ${page}, PageSize: ${pageSize}")
            LogUtils.info("ApplicationService", "Sort: ${sort}")
            LogUtils.info("ApplicationService", "Filter: ${filter}")
            
            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page + 1), Int64(pageSize))
            
            // 2. 构建 SQL 子句
            let args = ArrayList<Any>()
            var whereClause = ""
            var orderByClause = "created_at desc"
            
            let filterCondition = parsedQuery.filter
            if (filterCondition.isSome()) {
                // TODO: 实现 WHERE 子句构建
                // whereClause = queryBuilder.buildWhereClause(filterCondition.getOrThrow(), args)
                LogUtils.info("ApplicationService", "WHERE clause: ${whereClause}")
                LogUtils.info("ApplicationService", "Args count: ${args.size}")
            }
            
            if (!parsedQuery.sort.isEmpty()) {
                // TODO: 实现 ORDER BY 子句构建
                // orderByClause = queryBuilder.buildOrderByClause(parsedQuery.sort)
                LogUtils.info("ApplicationService", "ORDER BY clause: ${orderByClause}")
            }
            
            // 3. 执行查询
            let pagination = getExecutor().findApplicationByCondition(
                whereClause,
                orderByClause,
                args,
                Int64(parsedQuery.page),
                Int64(parsedQuery.pageSize)
            )
            
            LogUtils.info("ApplicationService", "Query returned ${pagination.list.size} records, total ${pagination.rows}")
            
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("ApplicationService", "Failed to get list: ${e.message}")
            return (ArrayList<ApplicationPO>(), 0)
        }
    }
    
    /**
     * 获取application列表（带跳过参数）
     * 
     * 支持动态查询：
     * - filter: JSON 格式的过滤条件
     * - sort: 排序条件
     * 
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return application列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<ApplicationPO>, Int64) {
        try {
            LogUtils.info("ApplicationService", "=== getListWithSkip called ===")
            LogUtils.info("ApplicationService", "Page: ${page}, PageSize: ${pageSize}, Skip: ${skip}")
            
            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page + 1), Int64(pageSize))
            
            // 2. 构建 SQL 子句
            let args = ArrayList<Any>()
            var whereClause = ""
            var orderByClause = "created_at desc"
            
            let filterCondition = parsedQuery.filter
            if (filterCondition.isSome()) {
                // TODO: 实现 WHERE 子句构建
                // whereClause = queryBuilder.buildWhereClause(filterCondition.getOrThrow(), args)
            }
            
            if (!parsedQuery.sort.isEmpty()) {
                // TODO: 实现 ORDER BY 子句构建
                // orderByClause = queryBuilder.buildOrderByClause(parsedQuery.sort)
            }
            
            // 3. 执行查询（带 skip）
            // 注意：skip 参数需要额外处理
            let pagination = getExecutor().findApplicationByCondition(
                whereClause,
                orderByClause,
                args,
                Int64(parsedQuery.page),
                Int64(parsedQuery.pageSize)
            )
            
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("ApplicationService", "Failed to get list with skip: ${e.message}")
            return (ArrayList<ApplicationPO>(), 0)
        }
    }
    
    /**
     * 获取所有application列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return application列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<ApplicationPO>, Int64) {
        let pagination = getExecutor().findAllApplicationPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取application
     * @param ids ID列表
     * @return application列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<ApplicationPO> {
        getExecutor().findApplicationByIds(ids)
    }
    
    /**
     * 统计用户的application数量
     * @param userId 用户ID
     * @return application数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countApplicationByCreator(userId)
    }
    
    /**
     * 统计所有application数量
     * @return application数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllApplication()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
