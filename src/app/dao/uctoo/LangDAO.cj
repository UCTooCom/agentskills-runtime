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
import magic.app.models.uctoo.LangPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * LangDAO - lang数据访问接口
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
public interface LangDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入lang（id由数据库自动生成UUID）
     * @param entity lang对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLang(entity: LangPO): String {
        executor.setSql('''
            insert into lang(
                name,
                code,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.name)},
                ${arg(entity.code)},
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
     * 根据ID查询lang
     * @param id langID
     * @return lang对象（Option类型）
     */
    func findLangById(id: String): Option<LangPO> {
        executor.setSql('''
            select * from lang where id = ${arg(id)}
        ''').first<LangPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新lang
     * @param entity lang对象
     * @return 影响行数
     */
    func updateLang(entity: LangPO): Int64 {
        executor.setSql('''
            update lang set
                name = ${arg(entity.name)},
                code = ${arg(entity.code)},
                status = ${arg(entity.status)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除lang
     * @param id langID
     * @return 影响行数
     */
    func softDeleteLangById(id: String): Int64 {
        executor.setSql('''
            update lang set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的lang
     * @param id langID
     * @return 影响行数
     */
    func restoreLangById(id: String): Int64 {
        executor.setSql('''
            update lang set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除lang
     * @param id langID
     * @return 影响行数
     */
    func deleteLangById(id: String): Int64 {
        executor.setSql('''
            delete from lang where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有lang
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLangPage(page: Int64, size: Int64): Pagination<LangPO> {
        executor.page<LangPO>('''
            select * from lang order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 分页查询lang列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLangByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LangPO> {
        executor.page<LangPO>('''
            select * from lang where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有lang（不分页）
     * @return lang列表
     */
    func listAllLang(): ArrayList<LangPO> {
        executor.setSql('''
            select * from lang order by created_at desc
        ''').list<LangPO>()
    }
    
    /**
     * 批量查询lang
     * @param ids ID列表
     * @return lang列表
     */
    func findLangByIds(ids: ArrayList<String>): ArrayList<LangPO> {
        executor.setSql('''
            select * from lang where id ${IN(ids)}
        ''').list<LangPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的lang数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLangByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from lang where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有lang数量
     * @return 数量
     */
    func countAllLang(): Int64 {
        executor.setSql('''
            select count(*) from lang
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 查询所有语言
     * @return 语言列表
     */
    func findAllLang(): ArrayList<LangPO> {
        executor.setSql('''
            select * from lang where deleted_at is null
        ''').list<LangPO>()
    }
    
    /**
     * 根据名称查询语言
     * @param name 语言名称
     * @return 语言列表
     */
    func findLangByName(name: String): ArrayList<LangPO> {
        executor.setSql('''
            select * from lang where name = ${arg(name)} and deleted_at is null
        ''').list<LangPO>()
    }
}
