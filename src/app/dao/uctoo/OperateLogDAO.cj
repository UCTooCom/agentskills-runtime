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
import magic.app.models.uctoo.OperateLogPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * OperateLogDAO - operate_log数据访问接口
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
public interface OperateLogDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入operateLog（id由数据库自动生成UUID）
     * @param entity operateLog对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertOperateLog(entity: OperateLogPO): String {
        executor.setSql('''
            insert into operate_log(
                module,
                operate,
                route,
                params,
                ip,
                method,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.module)},
                ${arg(entity.operate)},
                ${arg(entity.route)},
                ${arg(entity.params)},
                ${arg(entity.ip)},
                ${arg(entity.method)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询operateLog
     * @param id operateLogID
     * @return operateLog对象（Option类型）
     */
    func findOperateLogById(id: String): Option<OperateLogPO> {
        executor.setSql('''
            select * from operate_log where id = ${arg(id)}
        ''').first<OperateLogPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新operateLog
     * @param entity operateLog对象
     * @return 影响行数
     */
    func updateOperateLog(entity: OperateLogPO): Int64 {
        executor.setSql('''
            update operate_log set
                module = ${arg(entity.module)},
                operate = ${arg(entity.operate)},
                route = ${arg(entity.route)},
                params = ${arg(entity.params)},
                ip = ${arg(entity.ip)},
                method = ${arg(entity.method)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除operateLog
     * @param id operateLogID
     * @return 影响行数
     */
    func softDeleteOperateLogById(id: String): Int64 {
        executor.setSql('''
            update operate_log set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的operateLog
     * @param id operateLogID
     * @return 影响行数
     */
    func restoreOperateLogById(id: String): Int64 {
        executor.setSql('''
            update operate_log set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除operateLog
     * @param id operateLogID
     * @return 影响行数
     */
    func deleteOperateLogById(id: String): Int64 {
        executor.setSql('''
            delete from operate_log where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有operateLog
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllOperateLogPage(page: Int64, size: Int64): Pagination<OperateLogPO> {
        executor.page<OperateLogPO>('''
            select * from operate_log order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询operateLog列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findOperateLogByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<OperateLogPO> {
        executor.page<OperateLogPO>('''
            select * from operate_log where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有operateLog（不分页）
     * @return operateLog列表
     */
    func listAllOperateLog(): ArrayList<OperateLogPO> {
        executor.setSql('''
            select * from operate_log order by created_at desc
        ''').list<OperateLogPO>()
    }
    
    /**
     * 批量查询operateLog
     * @param ids ID列表
     * @return operateLog列表
     */
    func findOperateLogByIds(ids: ArrayList<String>): ArrayList<OperateLogPO> {
        executor.setSql('''
            select * from operate_log where id ${IN(ids)}
        ''').list<OperateLogPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的operateLog数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countOperateLogByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from operate_log where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有operateLog数量
     * @return 数量
     */
    func countAllOperateLog(): Int64 {
        executor.setSql('''
            select count(*) from operate_log
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
