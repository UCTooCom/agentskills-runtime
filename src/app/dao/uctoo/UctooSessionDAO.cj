/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.UctooSessionPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * UctooSessionDAO - uctoo_session数据访问接口
 * 
 * 提供标准CRUD操作，遵循UCTOO V4 ORM规范
 * 
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UctooSessionDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入uctooSession（id由数据库自动生成UUID）
     * @param entity uctooSession对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUctooSession(entity: UctooSessionPO): String {
        executor.setSql('''
            insert into uctoo_session(
                user_id,
                valid,
                user_agent,
                ip,
                auth_provider,
                created_at,
                updated_at,
                deleted_at,
                creator
            ) values(
                ${arg(entity.userId)},
                ${arg(entity.valid)},
                ${arg(entity.userAgent)},
                ${arg(entity.ip)},
                ${arg(entity.authProvider)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.creator)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询uctooSession
     * @param id uctooSessionID
     * @return uctooSession对象（Option类型）
     */
    func findUctooSessionById(id: String): Option<UctooSessionPO> {
        executor.setSql('''
            select * from uctoo_session where id = ${arg(id)}
        ''').first<UctooSessionPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新uctooSession
     * @param entity uctooSession对象
     * @return 影响行数
     */
    func updateUctooSession(entity: UctooSessionPO): Int64 {
        executor.setSql('''
            update uctoo_session set
                user_id = ${arg(entity.userId)},
                valid = ${arg(entity.valid)},
                user_agent = ${arg(entity.userAgent)},
                ip = ${arg(entity.ip)},
                auth_provider = ${arg(entity.authProvider)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除uctooSession
     * @param id uctooSessionID
     * @return 影响行数
     */
    func softDeleteUctooSessionById(id: String): Int64 {
        executor.setSql('''
            update uctoo_session set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的uctooSession
     * @param id uctooSessionID
     * @return 影响行数
     */
    func restoreUctooSessionById(id: String): Int64 {
        executor.setSql('''
            update uctoo_session set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除uctooSession
     * @param id uctooSessionID
     * @return 影响行数
     */
    func deleteUctooSessionById(id: String): Int64 {
        executor.setSql('''
            delete from uctoo_session where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有uctooSession
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUctooSessionPage(page: Int64, size: Int64): Pagination<UctooSessionPO> {
        executor.page<UctooSessionPO>('''
            select * from uctoo_session order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询uctooSession列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUctooSessionByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UctooSessionPO> {
        executor.page<UctooSessionPO>('''
            select * from uctoo_session where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有uctooSession（不分页）
     * @return uctooSession列表
     */
    func listAllUctooSession(): ArrayList<UctooSessionPO> {
        executor.setSql('''
            select * from uctoo_session order by created_at desc
        ''').list<UctooSessionPO>()
    }
    
    /**
     * 批量查询uctooSession
     * @param ids ID列表
     * @return uctooSession列表
     */
    func findUctooSessionByIds(ids: ArrayList<String>): ArrayList<UctooSessionPO> {
        executor.setSql('''
            select * from uctoo_session where id ${IN(ids)}
        ''').list<UctooSessionPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的uctooSession数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUctooSessionByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from uctoo_session where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有uctooSession数量
     * @return 数量
     */
    func countAllUctooSession(): Int64 {
        executor.setSql('''
            select count(*) from uctoo_session
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
