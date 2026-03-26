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
import magic.app.models.uctoo.LoginLogPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * LoginLogDAO - login_log数据访问接口
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
public interface LoginLogDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入loginLog（id由数据库自动生成UUID）
     * @param entity loginLog对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLoginLog(entity: LoginLogPO): String {
        executor.setSql('''
            insert into login_log(
                login_name,
                login_ip,
                browser,
                os,
                login_at,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.loginName)},
                ${arg(entity.loginIp)},
                ${arg(entity.browser)},
                ${arg(entity.os)},
                ${arg(entity.loginAt)},
                ${arg(entity.status)},
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
     * 根据ID查询loginLog
     * @param id loginLogID
     * @return loginLog对象（Option类型）
     */
    func findLoginLogById(id: String): Option<LoginLogPO> {
        executor.setSql('''
            select * from login_log where id = ${arg(id)}
        ''').first<LoginLogPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新loginLog
     * @param entity loginLog对象
     * @return 影响行数
     */
    func updateLoginLog(entity: LoginLogPO): Int64 {
        executor.setSql('''
            update login_log set
                login_name = ${arg(entity.loginName)},
                login_ip = ${arg(entity.loginIp)},
                browser = ${arg(entity.browser)},
                os = ${arg(entity.os)},
                login_at = ${arg(entity.loginAt)},
                status = ${arg(entity.status)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除loginLog
     * @param id loginLogID
     * @return 影响行数
     */
    func softDeleteLoginLogById(id: String): Int64 {
        executor.setSql('''
            update login_log set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的loginLog
     * @param id loginLogID
     * @return 影响行数
     */
    func restoreLoginLogById(id: String): Int64 {
        executor.setSql('''
            update login_log set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除loginLog
     * @param id loginLogID
     * @return 影响行数
     */
    func deleteLoginLogById(id: String): Int64 {
        executor.setSql('''
            delete from login_log where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有loginLog
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLoginLogPage(page: Int64, size: Int64): Pagination<LoginLogPO> {
        executor.page<LoginLogPO>('''
            select * from login_log order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询loginLog列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLoginLogByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LoginLogPO> {
        executor.page<LoginLogPO>('''
            select * from login_log where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有loginLog（不分页）
     * @return loginLog列表
     */
    func listAllLoginLog(): ArrayList<LoginLogPO> {
        executor.setSql('''
            select * from login_log order by created_at desc
        ''').list<LoginLogPO>()
    }
    
    /**
     * 批量查询loginLog
     * @param ids ID列表
     * @return loginLog列表
     */
    func findLoginLogByIds(ids: ArrayList<String>): ArrayList<LoginLogPO> {
        executor.setSql('''
            select * from login_log where id ${IN(ids)}
        ''').list<LoginLogPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的loginLog数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLoginLogByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from login_log where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有loginLog数量
     * @return 数量
     */
    func countAllLoginLog(): Int64 {
        executor.setSql('''
            select count(*) from login_log
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
