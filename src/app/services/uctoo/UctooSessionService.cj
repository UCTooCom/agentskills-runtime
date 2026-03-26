/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.UctooSessionPO
import magic.app.dao.uctoo.UctooSessionDAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * UctooSessionService - uctoo_session服务类
 * 
 * 提供uctoo_session相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class UctooSessionService {
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
     * 创建uctooSession
     * @param entity uctooSession对象
     * @return 创建结果
     */
    public func create(entity: UctooSessionPO): APIResult<UctooSessionPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertUctooSession(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<UctooSessionPO>(entity)
            } else {
                return APIResult<UctooSessionPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooSessionPO>(false, e.message)
        }
    }
    
    /**
     * 更新uctooSession
     * @param entityId uctooSessionID
     * @param entity uctooSession对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: UctooSessionPO): APIResult<UctooSessionPO> {
        try {
            let existing = getExecutor().findUctooSessionById(entityId)
            
            if (existing.isNone()) {
                return APIResult<UctooSessionPO>(false, "uctooSession不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.userId.size > 0) {
                existingEntity.userId = entity.userId
            }
            if (entity.userAgent.isSome()) {
                existingEntity.userAgent = entity.userAgent
            }
            if (entity.ip.size > 0) {
                existingEntity.ip = entity.ip
            }
            if (entity.authProvider.isSome()) {
                existingEntity.authProvider = entity.authProvider
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateUctooSession(existingEntity)
            
            if (rows > 0) {
                return APIResult<UctooSessionPO>(existingEntity)
            } else {
                return APIResult<UctooSessionPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooSessionPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新uctooSession
     * @param entities uctooSession列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<UctooSessionPO>): APIResult<ArrayList<UctooSessionPO>> {
        try {
            let updatedEntities = ArrayList<UctooSessionPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateUctooSession(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<UctooSessionPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<UctooSessionPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<UctooSessionPO>>(false, e.message)
        }
    }
    
    /**
     * 删除uctooSession
     * @param entityId uctooSessionID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findUctooSessionById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "uctooSession不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteUctooSessionById(entityId)
            } else {
                rows = getExecutor().softDeleteUctooSessionById(entityId)
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
     * 批量删除uctooSession
     * @param ids uctooSessionID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findUctooSessionById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteUctooSessionById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteUctooSessionById(id)
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
     * 恢复软删除的uctooSession
     * @param entityId uctooSessionID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<UctooSessionPO> {
        try {
            let rows = getExecutor().restoreUctooSessionById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findUctooSessionById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<UctooSessionPO>(entity)
                } else {
                    return APIResult<UctooSessionPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<UctooSessionPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<UctooSessionPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的uctooSession
     * @param ids uctooSessionID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreUctooSessionById(id)
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
     * 根据ID获取uctooSession
     * 
     * 设计说明：
     * - 通过ID获取uctooSession时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId uctooSessionID
     * @return uctooSession对象
     */
    public func getById(entityId: String): APIResult<UctooSessionPO> {
        try {
            LogUtils.info("UctooSessionService", "=== UctooSessionService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findUctooSessionById(entityId)
            LogUtils.info("UctooSessionService", "=== findUctooSessionById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("UctooSessionService", "=== UctooSession found, id: ${entity.id} ===")
                return APIResult<UctooSessionPO>(entity)
            } else {
                LogUtils.info("UctooSessionService", "=== UctooSession not found for id: ${entityId} ===")
                return APIResult<UctooSessionPO>(false, "未找到该uctooSession")
            }
        } catch (e: Exception) {
            LogUtils.error("UctooSessionService", "=== UctooSessionService.getById() exception: ${e.message} ===")
            return APIResult<UctooSessionPO>(false, e.message)
        }
    }
    
    /**
     * 获取uctooSession列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return uctooSession列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UctooSessionPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUctooSessionPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取uctooSession列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return uctooSession列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<UctooSessionPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllUctooSessionPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有uctooSession列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return uctooSession列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<UctooSessionPO>, Int64) {
        let pagination = getExecutor().findAllUctooSessionPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取uctooSession
     * @param ids ID列表
     * @return uctooSession列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<UctooSessionPO> {
        getExecutor().findUctooSessionByIds(ids)
    }
    
    /**
     * 统计用户的uctooSession数量
     * @param userId 用户ID
     * @return uctooSession数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countUctooSessionByCreator(userId)
    }
    
    /**
     * 统计所有uctooSession数量
     * @return uctooSession数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllUctooSession()
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 创建会话（简化版）
     * @param userId 用户ID
     * @param userAgent 用户代理
     * @param ip IP地址
     * @param authProvider 认证提供者
     * @return 会话对象
     */
    public func createSession(userId: String, userAgent: String, ip: String, authProvider: Int32): ?UctooSessionPO {
        try {
            LogUtils.info("createSession called: userId=${userId}, userAgent=${userAgent}, ip=${ip}, authProvider=${authProvider}")
            
            let now = DateTime.now()
            let session = UctooSessionPO()
            session.userId = userId
            session.valid = true
            session.userAgent = Some<String>(userAgent)
            session.ip = ip
            session.authProvider = Some<Int32>(authProvider)
            session.createdAt = now
            session.updatedAt = Some<DateTime>(now)  // 设置updatedAt字段,避免not-null约束错误
            
            LogUtils.info("Session object created, attempting to insert")
            let id = getExecutor().insertUctooSession(session)
            LogUtils.info("Insert result: id=${id}")
            
            if (!id.isEmpty()) {
                session.id = id
                LogUtils.info("Session created successfully with id: ${id}")
                return Some<UctooSessionPO>(session)
            }
            LogUtils.error("Insert returned empty id")
            None<UctooSessionPO>
        } catch (e: Exception) {
            LogUtils.error("createSession failed: ${e.message}")
            LogUtils.error("Exception stack trace: ${e}")
            None<UctooSessionPO>
        }
    }
    
    /**
     * 根据ID查找会话
     * @param sessionId 会话ID
     * @return 会话对象
     */
    public func findById(sessionId: String): ?UctooSessionPO {
        try {
            getExecutor().findUctooSessionById(sessionId)
        } catch (e: Exception) {
            LogUtils.error("findById failed: ${e.message}")
            None<UctooSessionPO>
        }
    }
    
    /**
     * 更新会话状态
     * @param sessionId 会话ID
     * @param valid 是否有效
     * @return 更新是否成功
     */
    public func updateStatus(sessionId: String, valid: Bool): Bool {
        try {
            let existing = getExecutor().findUctooSessionById(sessionId)
            if (let Some(session) <- existing) {
                session.valid = valid
                session.updatedAt = Some<DateTime>(DateTime.now())
                let rows = getExecutor().updateUctooSession(session)
                return rows > 0
            }
            false
        } catch (e: Exception) {
            LogUtils.error("updateStatus failed: ${e.message}")
            false
        }
    }
}
