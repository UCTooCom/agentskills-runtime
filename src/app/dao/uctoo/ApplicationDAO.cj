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
import magic.app.models.uctoo.ApplicationPO
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * 将 Any 类型转换为 SQL 字符串
 * 
 * @param value Any 类型的值
 * @return SQL 字符串表示
 */
public func convertToSqlString(value: Any): String {
    // 尝试转换为字符串类型
    let strValue = value as String
    if (let Some(s) <- strValue) {
        // 字符串类型需要加引号并转义单引号
        let escaped = s.replace("'", "''")
        return "'${escaped}'"
    }
    
    // 尝试转换为Int64类型
    let intValue = value as Int64
    if (let Some(i) <- intValue) {
        return "${i}"
    }
    
    // 尝试转换为Int32类型
    let int32Value = value as Int32
    if (let Some(i) <- int32Value) {
        return "${i}"
    }
    
    // 尝试转换为Float64类型
    let floatValue = value as Float64
    if (let Some(f) <- floatValue) {
        return "${f}"
    }
    
    // 尝试转换为Bool类型
    let boolValue = value as Bool
    if (let Some(b) <- boolValue) {
        return if (b) { "1" } else { "0" }
    }
    
    // 默认返回空字符串
    ""
}

/**
 * ApplicationDAO - application数据访问接口
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
public interface ApplicationDAO <: RootDAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入application（id由数据库自动生成UUID）
     * @param entity application对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertApplication(entity: ApplicationPO): String {
        executor.setSql('''
            insert into application(
                name,
                description,
                icon,
                tag,
                classify,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.name)},
                ${arg(entity.description)},
                ${arg(entity.icon)},
                ${arg(entity.tag)},
                ${arg(entity.classify)},
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
     * 根据ID查询application
     * @param id applicationID
     * @return application对象（Option类型）
     */
    func findApplicationById(id: String): Option<ApplicationPO> {
        executor.setSql('''
            select * from application where id = ${arg(id)}
        ''').first<ApplicationPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新application
     * @param entity application对象
     * @return 影响行数
     */
    func updateApplication(entity: ApplicationPO): Int64 {
        executor.setSql('''
            update application set
                name = ${arg(entity.name)},
                description = ${arg(entity.description)},
                icon = ${arg(entity.icon)},
                tag = ${arg(entity.tag)},
                classify = ${arg(entity.classify)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除application
     * @param id applicationID
     * @return 影响行数
     */
    func softDeleteApplicationById(id: String): Int64 {
        executor.setSql('''
            update application set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的application
     * @param id applicationID
     * @return 影响行数
     */
    func restoreApplicationById(id: String): Int64 {
        executor.setSql('''
            update application set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除application
     * @param id applicationID
     * @return 影响行数
     */
    func deleteApplicationById(id: String): Int64 {
        executor.setSql('''
            delete from application where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有application
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllApplicationPage(page: Int64, size: Int64): Pagination<ApplicationPO> {
        executor.page<ApplicationPO>('''
            select * from application order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 条件查询 application（支持动态 WHERE 和 ORDER BY）
     * 
     * @param whereClause WHERE 子句（不包含 WHERE 关键字）
     * @param orderByClause ORDER BY 子句（不包含 ORDER BY 关键字）
     * @param args SQL 参数列表
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     * 
     * 示例：
     * whereClause: "name like ? and classify = ?"
     * orderByClause: "created_at desc"
     * args: ["%管理%", "dev"]
     * 
     * 生成的 SQL: SELECT * FROM application WHERE name like ? and classify = ? ORDER BY created_at desc
     */
    func findApplicationByCondition(
        whereClause: String,
        orderByClause: String,
        args: ArrayList<Any>,
        page: Int64,
        size: Int64
    ): Pagination<ApplicationPO> {
        // 构建 SQL 字符串
        let whereSql = if (whereClause.isEmpty()) {
            ""
        } else {
            " where ${whereClause}"
        }
        
        let baseSql = "select * from application${whereSql} order by ${orderByClause}"
        let countSql = if (whereSql.isEmpty()) {
            "select count(*) from application"
        } else {
            "select count(*) from application${whereSql}"
        }
        
        LogUtils.info("ApplicationDAO", "Executing SQL: ${baseSql}")
        LogUtils.info("ApplicationDAO", "With args: ${args.size} parameters")
        
        // 手动实现分页查询，这样我们可以完全控制参数绑定
        // 1. 首先添加所有查询参数
        for (argValue in args) {
            executor.add(argValue)
        }
        
        // 2. 执行计数查询，设置 clearArgsAfterExec: false 以保留参数
        let total = executor.setSql(countSql, clearArgsAfterExec: false).first<Int64>() ?? 0
        
        if (total == 0) {
            // 没有数据，返回空结果
            return Pagination<ApplicationPO>(page: page, size: size, rows: total, list: ArrayList<ApplicationPO>())
        }
        
        // 3. 计算 offset 并添加分页参数
        let offset = (page - 1) * size
        executor.add(size)
        executor.add(offset)
        
        // 4. 构建最终的带分页的 SQL
        let finalSql = baseSql + " limit ? offset ?"
        
        // 5. 执行数据查询，设置 clearArgsAfterExec: true 以清空参数
        let list = executor.setSql(finalSql, clearArgsAfterExec: true).list<ApplicationPO>()
        
        // 6. 返回分页结果
        Pagination<ApplicationPO>(page: page, size: size, rows: total, list: list)
    }
    
    /**
     * 分页查询application列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findApplicationByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<ApplicationPO> {
        executor.page<ApplicationPO>('''
            select * from application where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有application（不分页）
     * @return application列表
     */
    func listAllApplication(): ArrayList<ApplicationPO> {
        executor.setSql('''
            select * from application order by created_at desc
        ''').list<ApplicationPO>()
    }
    
    /**
     * 批量查询application
     * @param ids ID列表
     * @return application列表
     */
    func findApplicationByIds(ids: ArrayList<String>): ArrayList<ApplicationPO> {
        executor.setSql('''
            select * from application where id ${IN(ids)}
        ''').list<ApplicationPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的application数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countApplicationByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from application where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有application数量
     * @return 数量
     */
    func countAllApplication(): Int64 {
        executor.setSql('''
            select count(*) from application
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
