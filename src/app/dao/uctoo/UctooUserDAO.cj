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
import magic.app.models.uctoo.UctooUserPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * UctooUserDAO - uctoo_user数据访问接口
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
public interface UctooUserDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入uctooUser（id由数据库自动生成UUID）
     * @param entity uctooUser对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUctooUser(entity: UctooUserPO): String {
        executor.setSql('''
            insert into uctoo_user(
                name,
                username,
                email,
                password,
                avatar,
                created_at,
                last_login,
                auth_provider,
                creator,
                deleted_at,
                last_login_ip,
                last_login_time,
                remember_token,
                status,
                updated_at,
                access_token
            ) values(
                ${arg(entity.name)},
                ${arg(entity.username)},
                ${arg(entity.email)},
                ${arg(entity.password)},
                ${arg(entity.avatar)},
                ${arg(entity.createdAt)},
                ${arg(entity.lastLogin)},
                ${arg(entity.authProvider)},
                ${arg(entity.creator)},
                ${arg(entity.deletedAt)},
                ${arg(entity.lastLoginIp)},
                ${arg(entity.lastLoginTime)},
                ${arg(entity.rememberToken)},
                ${arg(entity.status)},
                ${arg(entity.updatedAt)},
                ${arg(entity.accessToken)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询uctooUser
     * @param id uctooUserID
     * @return uctooUser对象（Option类型）
     */
    func findUctooUserById(id: String): Option<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where id = ${arg(id)}
        ''').first<UctooUserPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新uctooUser
     * @param entity uctooUser对象
     * @return 影响行数
     */
    func updateUctooUser(entity: UctooUserPO): Int64 {
        executor.setSql('''
            update uctoo_user set
                name = ${arg(entity.name)},
                username = ${arg(entity.username)},
                email = ${arg(entity.email)},
                password = ${arg(entity.password)},
                avatar = ${arg(entity.avatar)},
                last_login = ${arg(entity.lastLogin)},
                auth_provider = ${arg(entity.authProvider)},
                deleted_at = ${arg(entity.deletedAt)},
                last_login_ip = ${arg(entity.lastLoginIp)},
                last_login_time = ${arg(entity.lastLoginTime)},
                remember_token = ${arg(entity.rememberToken)},
                status = ${arg(entity.status)},
                access_token = ${arg(entity.accessToken)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除uctooUser
     * @param id uctooUserID
     * @return 影响行数
     */
    func softDeleteUctooUserById(id: String): Int64 {
        executor.setSql('''
            update uctoo_user set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的uctooUser
     * @param id uctooUserID
     * @return 影响行数
     */
    func restoreUctooUserById(id: String): Int64 {
        executor.setSql('''
            update uctoo_user set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除uctooUser
     * @param id uctooUserID
     * @return 影响行数
     */
    func deleteUctooUserById(id: String): Int64 {
        executor.setSql('''
            delete from uctoo_user where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有uctooUser
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUctooUserPage(page: Int64, size: Int64): Pagination<UctooUserPO> {
        executor.page<UctooUserPO>('''
            select * from uctoo_user order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询uctooUser列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUctooUserByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UctooUserPO> {
        executor.page<UctooUserPO>('''
            select * from uctoo_user where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有uctooUser（不分页）
     * @return uctooUser列表
     */
    func listAllUctooUser(): ArrayList<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user order by created_at desc
        ''').list<UctooUserPO>()
    }
    
    /**
     * 批量查询uctooUser
     * @param ids ID列表
     * @return uctooUser列表
     */
    func findUctooUserByIds(ids: ArrayList<String>): ArrayList<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where id ${IN(ids)}
        ''').list<UctooUserPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的uctooUser数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUctooUserByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from uctoo_user where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有uctooUser数量
     * @return 数量
     */
    func countAllUctooUser(): Int64 {
        executor.setSql('''
            select count(*) from uctoo_user
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 根据用户名查询用户
     * @param username 用户名
     * @return 用户对象
     */
    func findUctooUserByUsername(username: String): Option<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where username = ${arg(username)}
        ''').first<UctooUserPO>()
    }
    
    /**
     * 根据邮箱查询用户
     * @param email 邮箱
     * @return 用户对象
     */
    func findUctooUserByEmail(email: String): Option<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where email = ${arg(email)}
        ''').first<UctooUserPO>()
    }
}
