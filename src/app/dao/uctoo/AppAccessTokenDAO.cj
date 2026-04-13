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
import magic.app.models.uctoo.AppAccessTokenPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * AppAccessTokenDAO - app_access_token数据访问接口
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
public interface AppAccessTokenDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入appAccessToken（id由数据库自动生成UUID）
     * @param entity appAccessToken对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAppAccessToken(entity: AppAccessTokenPO): String {
        executor.setSql('''
            insert into app_access_token(
                access_token,
                token_overtime,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.accessToken)},
                ${arg(entity.tokenOvertime)},
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
     * 根据ID查询appAccessToken
     * @param id appAccessTokenID
     * @return appAccessToken对象（Option类型）
     */
    func findAppAccessTokenById(id: String): Option<AppAccessTokenPO> {
        executor.setSql('''
            select * from app_access_token where id = ${arg(id)}
        ''').first<AppAccessTokenPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新appAccessToken
     * @param entity appAccessToken对象
     * @return 影响行数
     */
    func updateAppAccessToken(entity: AppAccessTokenPO): Int64 {
        executor.setSql('''
            update app_access_token set
                access_token = ${arg(entity.accessToken)},
                token_overtime = ${arg(entity.tokenOvertime)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除appAccessToken
     * @param id appAccessTokenID
     * @return 影响行数
     */
    func softDeleteAppAccessTokenById(id: String): Int64 {
        executor.setSql('''
            update app_access_token set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的appAccessToken
     * @param id appAccessTokenID
     * @return 影响行数
     */
    func restoreAppAccessTokenById(id: String): Int64 {
        executor.setSql('''
            update app_access_token set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除appAccessToken
     * @param id appAccessTokenID
     * @return 影响行数
     */
    func deleteAppAccessTokenById(id: String): Int64 {
        executor.setSql('''
            delete from app_access_token where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有appAccessToken
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAppAccessTokenPage(page: Int64, size: Int64): Pagination<AppAccessTokenPO> {
        executor.page<AppAccessTokenPO>('''
            select * from app_access_token order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询appAccessToken列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAppAccessTokenByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AppAccessTokenPO> {
        executor.page<AppAccessTokenPO>('''
            select * from app_access_token where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有appAccessToken（不分页）
     * @return appAccessToken列表
     */
    func listAllAppAccessToken(): ArrayList<AppAccessTokenPO> {
        executor.setSql('''
            select * from app_access_token order by created_at desc
        ''').list<AppAccessTokenPO>()
    }
    
    /**
     * 批量查询appAccessToken
     * @param ids ID列表
     * @return appAccessToken列表
     */
    func findAppAccessTokenByIds(ids: ArrayList<String>): ArrayList<AppAccessTokenPO> {
        executor.setSql('''
            select * from app_access_token where id ${IN(ids)}
        ''').list<AppAccessTokenPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的appAccessToken数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAppAccessTokenByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from app_access_token where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有appAccessToken数量
     * @return 数量
     */
    func countAllAppAccessToken(): Int64 {
        executor.setSql('''
            select count(*) from app_access_token
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
