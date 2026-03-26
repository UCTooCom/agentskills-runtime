/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.{DATABASE_NAME}

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.{DATABASE_NAME}.{TABLE_NAME_PASCAL}PO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

/**
 * {TABLE_NAME_PASCAL}DAO - {TABLE_NAME}数据访问接口
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
public interface {TABLE_NAME_PASCAL}DAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入{TABLE_NAME_CAMEL}（id由数据库自动生成UUID）
     * @param entity {TABLE_NAME_CAMEL}对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insert{TABLE_NAME_PASCAL}(entity: {TABLE_NAME_PASCAL}PO): String {
        executor.setSql('''
            insert into {TABLE_NAME}(
                {INSERT_FIELDS}
            ) values(
                {INSERT_VALUES}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询{TABLE_NAME_CAMEL}
     * @param id {TABLE_NAME_CAMEL}ID
     * @return {TABLE_NAME_CAMEL}对象（Option类型）
     */
    func find{TABLE_NAME_PASCAL}ById(id: String): Option<{TABLE_NAME_PASCAL}PO> {
        executor.setSql('''
            select * from {TABLE_NAME} where id = ${arg(id)}
        ''').first<{TABLE_NAME_PASCAL}PO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新{TABLE_NAME_CAMEL}
     * @param entity {TABLE_NAME_CAMEL}对象
     * @return 影响行数
     */
    func update{TABLE_NAME_PASCAL}(entity: {TABLE_NAME_PASCAL}PO): Int64 {
        executor.setSql('''
            update {TABLE_NAME} set
                {UPDATE_SETS},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除{TABLE_NAME_CAMEL}
     * @param id {TABLE_NAME_CAMEL}ID
     * @return 影响行数
     */
    func softDelete{TABLE_NAME_PASCAL}ById(id: String): Int64 {
        executor.setSql('''
            update {TABLE_NAME} set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的{TABLE_NAME_CAMEL}
     * @param id {TABLE_NAME_CAMEL}ID
     * @return 影响行数
     */
    func restore{TABLE_NAME_PASCAL}ById(id: String): Int64 {
        executor.setSql('''
            update {TABLE_NAME} set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除{TABLE_NAME_CAMEL}
     * @param id {TABLE_NAME_CAMEL}ID
     * @return 影响行数
     */
    func delete{TABLE_NAME_PASCAL}ById(id: String): Int64 {
        executor.setSql('''
            delete from {TABLE_NAME} where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有{TABLE_NAME_CAMEL}
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAll{TABLE_NAME_PASCAL}Page(page: Int64, size: Int64): Pagination<{TABLE_NAME_PASCAL}PO> {
        executor.page<{TABLE_NAME_PASCAL}PO>('''
            select * from {TABLE_NAME} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询{TABLE_NAME_CAMEL}列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func find{TABLE_NAME_PASCAL}ByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<{TABLE_NAME_PASCAL}PO> {
        executor.page<{TABLE_NAME_PASCAL}PO>('''
            select * from {TABLE_NAME} where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有{TABLE_NAME_CAMEL}（不分页）
     * @return {TABLE_NAME_CAMEL}列表
     */
    func listAll{TABLE_NAME_PASCAL}(): ArrayList<{TABLE_NAME_PASCAL}PO> {
        executor.setSql('''
            select * from {TABLE_NAME} order by created_at desc
        ''').list<{TABLE_NAME_PASCAL}PO>()
    }
    
    /**
     * 批量查询{TABLE_NAME_CAMEL}
     * @param ids ID列表
     * @return {TABLE_NAME_CAMEL}列表
     */
    func find{TABLE_NAME_PASCAL}ByIds(ids: ArrayList<String>): ArrayList<{TABLE_NAME_PASCAL}PO> {
        executor.setSql('''
            select * from {TABLE_NAME} where id ${IN(ids)}
        ''').list<{TABLE_NAME_PASCAL}PO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的{TABLE_NAME_CAMEL}数量
     * @param creator 创建者ID
     * @return 数量
     */
    func count{TABLE_NAME_PASCAL}ByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from {TABLE_NAME} where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有{TABLE_NAME_CAMEL}数量
     * @return 数量
     */
    func countAll{TABLE_NAME_PASCAL}(): Int64 {
        executor.setSql('''
            select count(*) from {TABLE_NAME}
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
