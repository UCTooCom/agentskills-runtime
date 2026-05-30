/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========

    //#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.LoginLogPO

/**
 * LoginLogDAO - login_log数据访问接口
 *
 * 提供login_log表的标准CRUD操作，遵循UCTOO V4 ORM规范
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

    // ==================== 插入操作 ====================

    /**
     * 插入login_log（id由数据库自动生成UUID）
     * @param entity LoginLogPO对象
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
     * 根据ID查询login_log
     * @param id login_logID
     * @return login_log对象（Option类型）
     */
    func findLoginLogById(id: String): Option<LoginLogPO> {
        executor.setSql('''
            select * from login_log where id = ${arg(id)}
        ''').first<LoginLogPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新login_log
     * @param entity login_log对象
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
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除login_log
     * @param id login_logID
     * @return 影响行数
     */
    func softDeleteLoginLogById(id: String): Int64 {
        executor.setSql('''
            update login_log set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的login_log
     * @param id login_logID
     * @return 影响行数
     */
    func restoreLoginLogById(id: String): Int64 {
        executor.setSql('''
            update login_log set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除login_log
     * @param id login_logID
     * @return 影响行数
     */
    func deleteLoginLogById(id: String): Int64 {
        executor.setSql('''
            delete from login_log where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有login_log
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
     * 分页查询login_log列表（按创建者）
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
     * 查询所有login_log（不分页）
     * @return login_log列表
     */
    func listAllLoginLog(): ArrayList<LoginLogPO> {
        executor.setSql('''
            select * from login_log order by created_at desc
        ''').list<LoginLogPO>()
    }

    /**
     * 批量查询login_log
     * @param ids ID列表
     * @return login_log列表
     */
    func findLoginLogByIds(ids: ArrayList<String>): ArrayList<LoginLogPO> {
        executor.setSql('''
            select * from login_log where id ${IN(ids)}
        ''').list<LoginLogPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的login_log数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLoginLogByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from login_log where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有login_log数量
     * @return 数量
     */
    func countAllLoginLog(): Int64 {
        executor.setSql('''
            select count(*) from login_log
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询login_log列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLoginLogByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LoginLogPO> {
        let sql = StringBuilder()
        sql.append("select * from login_log where 1=1")

        if (let Some(linkVal) <- link) {
            if (linkVal != "") {
                sql.append(" and link like ${arg('%' + linkVal + '%')}")
            }
        }

        if (let Some(descVal) <- description) {
            if (descVal != "") {
                sql.append(" and description like ${arg('%' + descVal + '%')}")
            }
        }

        // 处理 deleted_at 筛选
        if (let Some(deletedAtVal) <- deletedAt) {
            if (deletedAtVal == "null") {
                // 未删除的数据
                sql.append(" and deleted_at is null")
            } else if (deletedAtVal == "not_null") {
                // 已删除的数据（回收站）
                sql.append(" and deleted_at is not null")
            }
        }

        sql.append(" order by created_at desc")

        executor.page<LoginLogPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除login_log
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLoginLog(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update login_log set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除login_log
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLoginLog(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from login_log where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询login_log（支持完整查询操作符）
     *
     * @param whereClause WHERE 子句字符串（不包含 WHERE 关键字）
     * @param orderByClause ORDER BY 子句字符串（不包含 ORDER BY 关键字）
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     *
     * 使用示例：
     * - whereClause: "name LIKE '%test%' AND status = 'active'"
     * - orderByClause: "created_at DESC, name ASC"
     */
    func findLoginLogByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LoginLogPO> {
        let sql = StringBuilder()
        sql.append("select * from login_log")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LoginLogPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询login_log
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLoginLogByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LoginLogPO> {
        let fromClause = executor.FROM<LoginLogPO>()

        // 应用 WHERE 条件
        if (!whereClause.isEmpty()) {
            fromClause.WHERE(whereClause)
        }

        // 应用 ORDER BY
        if (!orderByClause.isEmpty()) {
            fromClause.ORDER_BY { => orderByClause }
        } else {
            fromClause.ORDER_BY { => "created_at DESC" }
        }

        // 执行分页查询
        fromClause.page<LoginLogPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的login_log）
     * @return 影响行数
     */
    func emptyRecycleBinLoginLog(): Int64 {
        executor.setSql('''
            delete from login_log where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
