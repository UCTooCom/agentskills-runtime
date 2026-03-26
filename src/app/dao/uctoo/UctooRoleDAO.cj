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
import magic.app.models.uctoo.UctooRolePO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * UctooRoleDAO - uctoo_role数据访问接口
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
public interface UctooRoleDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入uctooRole（id由数据库自动生成UUID）
     * @param entity uctooRole对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUctooRole(entity: UctooRolePO): String {
        executor.setSql('''
            insert into uctoo_role(
                name,
                created_at,
                creator,
                deleted_at,
                updated_at
            ) values(
                ${arg(entity.name)},
                ${arg(entity.createdAt)},
                ${arg(entity.creator)},
                ${arg(entity.deletedAt)},
                ${arg(entity.updatedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询uctooRole
     * @param id uctooRoleID
     * @return uctooRole对象（Option类型）
     */
    func findUctooRoleById(id: String): Option<UctooRolePO> {
        executor.setSql('''
            select * from uctoo_role where id = ${arg(id)}
        ''').first<UctooRolePO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新uctooRole
     * @param entity uctooRole对象
     * @return 影响行数
     */
    func updateUctooRole(entity: UctooRolePO): Int64 {
        executor.setSql('''
            update uctoo_role set
                name = ${arg(entity.name)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除uctooRole
     * @param id uctooRoleID
     * @return 影响行数
     */
    func softDeleteUctooRoleById(id: String): Int64 {
        executor.setSql('''
            update uctoo_role set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的uctooRole
     * @param id uctooRoleID
     * @return 影响行数
     */
    func restoreUctooRoleById(id: String): Int64 {
        executor.setSql('''
            update uctoo_role set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除uctooRole
     * @param id uctooRoleID
     * @return 影响行数
     */
    func deleteUctooRoleById(id: String): Int64 {
        executor.setSql('''
            delete from uctoo_role where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有uctooRole
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUctooRolePage(page: Int64, size: Int64): Pagination<UctooRolePO> {
        executor.page<UctooRolePO>('''
            select * from uctoo_role order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询uctooRole列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUctooRoleByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UctooRolePO> {
        executor.page<UctooRolePO>('''
            select * from uctoo_role where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有uctooRole（不分页）
     * @return uctooRole列表
     */
    func listAllUctooRole(): ArrayList<UctooRolePO> {
        executor.setSql('''
            select * from uctoo_role order by created_at desc
        ''').list<UctooRolePO>()
    }
    
    /**
     * 批量查询uctooRole
     * @param ids ID列表
     * @return uctooRole列表
     */
    func findUctooRoleByIds(ids: ArrayList<String>): ArrayList<UctooRolePO> {
        executor.setSql('''
            select * from uctoo_role where id ${IN(ids)}
        ''').list<UctooRolePO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的uctooRole数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUctooRoleByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from uctoo_role where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有uctooRole数量
     * @return 数量
     */
    func countAllUctooRole(): Int64 {
        executor.setSql('''
            select count(*) from uctoo_role
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
