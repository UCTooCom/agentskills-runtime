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
import magic.app.models.uctoo.DataAccessAuthorizationPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * DataAccessAuthorizationDAO - data_access_authorization数据访问接口
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
public interface DataAccessAuthorizationDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入dataAccessAuthorization（id由数据库自动生成UUID）
     * @param entity dataAccessAuthorization对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertDataAccessAuthorization(entity: DataAccessAuthorizationPO): String {
        executor.setSql('''
            insert into data_access_authorization(
                entity_id,
                entity_type,
                user_id,
                permission,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.entityId)},
                ${arg(entity.entityType)},
                ${arg(entity.userId)},
                ${arg(entity.permission)},
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
     * 根据ID查询dataAccessAuthorization
     * @param id dataAccessAuthorizationID
     * @return dataAccessAuthorization对象（Option类型）
     */
    func findDataAccessAuthorizationById(id: String): Option<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization where id = ${arg(id)}
        ''').first<DataAccessAuthorizationPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新dataAccessAuthorization
     * @param entity dataAccessAuthorization对象
     * @return 影响行数
     */
    func updateDataAccessAuthorization(entity: DataAccessAuthorizationPO): Int64 {
        executor.setSql('''
            update data_access_authorization set
                entity_id = ${arg(entity.entityId)},
                entity_type = ${arg(entity.entityType)},
                user_id = ${arg(entity.userId)},
                permission = ${arg(entity.permission)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除dataAccessAuthorization
     * @param id dataAccessAuthorizationID
     * @return 影响行数
     */
    func softDeleteDataAccessAuthorizationById(id: String): Int64 {
        executor.setSql('''
            update data_access_authorization set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的dataAccessAuthorization
     * @param id dataAccessAuthorizationID
     * @return 影响行数
     */
    func restoreDataAccessAuthorizationById(id: String): Int64 {
        executor.setSql('''
            update data_access_authorization set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除dataAccessAuthorization
     * @param id dataAccessAuthorizationID
     * @return 影响行数
     */
    func deleteDataAccessAuthorizationById(id: String): Int64 {
        executor.setSql('''
            delete from data_access_authorization where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有dataAccessAuthorization
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllDataAccessAuthorizationPage(page: Int64, size: Int64): Pagination<DataAccessAuthorizationPO> {
        executor.page<DataAccessAuthorizationPO>('''
            select * from data_access_authorization order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询dataAccessAuthorization列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDataAccessAuthorizationByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<DataAccessAuthorizationPO> {
        executor.page<DataAccessAuthorizationPO>('''
            select * from data_access_authorization where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有dataAccessAuthorization（不分页）
     * @return dataAccessAuthorization列表
     */
    func listAllDataAccessAuthorization(): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization order by created_at desc
        ''').list<DataAccessAuthorizationPO>()
    }
    
    /**
     * 批量查询dataAccessAuthorization
     * @param ids ID列表
     * @return dataAccessAuthorization列表
     */
    func findDataAccessAuthorizationByIds(ids: ArrayList<String>): ArrayList<DataAccessAuthorizationPO> {
        executor.setSql('''
            select * from data_access_authorization where id ${IN(ids)}
        ''').list<DataAccessAuthorizationPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的dataAccessAuthorization数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countDataAccessAuthorizationByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from data_access_authorization where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有dataAccessAuthorization数量
     * @return 数量
     */
    func countAllDataAccessAuthorization(): Int64 {
        executor.setSql('''
            select count(*) from data_access_authorization
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
