/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.{{dbName}}

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.{{dbName}}.{{className}}PO
import magic.log.LogUtils

/**
 * {{className}}DAO - {{tableName}}表数据访问接口
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
public interface {{className}}DAO <: RootDAO {
    prop executor: SqlExecutor
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入{{tableName}}（id由数据库自动生成UUID）
     * @param entity {{tableName}}对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insert{{className}}(entity: {{className}}PO): String {
        executor.setSql(''
            insert into {{tableName}}(
{{insertFields}}
            ) values(
{{insertValues}}
            )
            returning id
        '').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询{{tableName}}
     * @param id {{tableName}}ID
     * @return {{tableName}}对象（Option类型）
     */
    func find{{className}}ById(id: String): Option<{{className}}PO> {
        executor.setSql(''
            select * from {{tableName}} where id = ${arg(id)}
        '').first<{{className}}PO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新{{tableName}}
     * @param entity {{tableName}}对象
     * @return 影响行数
     */
    func update{{className}}(entity: {{className}}PO): Int64 {
        executor.setSql(''
            update {{tableName}} set
{{updateFields}}
            where id = ${arg(entity.id)}
        '').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除{{tableName}}
     * @param id {{tableName}}ID
     * @return 影响行数
     */
    func softDelete{{className}}ById(id: String): Int64 {
        executor.setSql(''
            update {{tableName}} set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        '').update
    }
    
    /**
     * 恢复软删除的{{tableName}}
     * @param id {{tableName}}ID
     * @return 影响行数
     */
    func restore{{className}}ById(id: String): Int64 {
        executor.setSql(''
            update {{tableName}} set deleted_at = null where id = ${arg(id)}
        '').update
    }
    
    /**
     * 硬删除{{tableName}}
     * @param id {{tableName}}ID
     * @return 影响行数
     */
    func delete{{className}}ById(id: String): Int64 {
        executor.setSql(''
            delete from {{tableName}} where id = ${arg(id)}
        '').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有{{tableName}}
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAll{{className}}Page(page: Int64, size: Int64): Pagination<{{className}}PO> {
        executor.page<{{className}}PO>(''
            select * from {{tableName}} order by created_at desc
        '', size, page: page)
    }
    
    /**
     * 分页查询{{tableName}}列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func find{{className}}ByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<{{className}}PO> {
        executor.page<{{className}}PO>(''
            select * from {{tableName}} where creator = ${arg(creator)} order by created_at desc
        '', size, page: page)
    }
    
    /**
     * 查询所有{{tableName}}（不分页）
     * @return {{tableName}}列表
     */
    func listAll{{className}}(): ArrayList<{{className}}PO> {
        executor.setSql(''
            select * from {{tableName}} order by created_at desc
        '').list<{{className}}PO>()
    }
    
    /**
     * 批量查询{{tableName}}
     * @param ids ID列表
     * @return {{tableName}}列表
     */
    func find{{className}}ByIds(ids: ArrayList<String>): ArrayList<{{className}}PO> {
        executor.setSql(''
            select * from {{tableName}} where id ${IN(ids)}
        '').list<{{className}}PO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的{{tableName}}数量
     * @param creator 创建者ID
     * @return 数量
     */
    func count{{className}}ByCreator(creator: String): Int64 {
        executor.setSql(''
            select count(*) from {{tableName}} where creator = ${arg(creator)}
        '').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有{{tableName}}数量
     * @return 数量
     */
    func countAll{{className}}(): Int64 {
        executor.setSql(''
            select count(*) from {{tableName}}
        '').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
}
