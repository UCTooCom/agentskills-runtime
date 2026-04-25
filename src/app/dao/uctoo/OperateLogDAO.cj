/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.OperateLogPO
import magic.log.LogUtils

/**
 * OperateLogDAO - operate_log数据访问接口
 *
 * 提供operate_log表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface OperateLogDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入operate_log（id由数据库自动生成UUID）
     * @param entity OperateLogPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertOperateLog(entity: OperateLogPO): String {
        executor.setSql('''
            insert into operate_log(
                module,
                operate,
                route,
                params,
                ip,
                method,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.module)},
                ${arg(entity.operate)},
                ${arg(entity.route)},
                ${arg(entity.params)},
                ${arg(entity.ip)},
                ${arg(entity.method)},
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
     * 根据ID查询operate_log
     * @param id operate_logID
     * @return operate_log对象（Option类型）
     */
    func findOperateLogById(id: String): Option<OperateLogPO> {
        executor.setSql('''
            select * from operate_log where id = ${arg(id)}
        ''').first<OperateLogPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新operate_log
     * @param entity operate_log对象
     * @return 影响行数
     */
    func updateOperateLog(entity: OperateLogPO): Int64 {
        executor.setSql('''
            update operate_log set
                module = ${arg(entity.module)},
                operate = ${arg(entity.operate)},
                route = ${arg(entity.route)},
                params = ${arg(entity.params)},
                ip = ${arg(entity.ip)},
                method = ${arg(entity.method)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除operate_log
     * @param id operate_logID
     * @return 影响行数
     */
    func softDeleteOperateLogById(id: String): Int64 {
        executor.setSql('''
            update operate_log set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的operate_log
     * @param id operate_logID
     * @return 影响行数
     */
    func restoreOperateLogById(id: String): Int64 {
        executor.setSql('''
            update operate_log set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除operate_log
     * @param id operate_logID
     * @return 影响行数
     */
    func deleteOperateLogById(id: String): Int64 {
        executor.setSql('''
            delete from operate_log where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有operate_log
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllOperateLogPage(page: Int64, size: Int64): Pagination<OperateLogPO> {
        executor.page<OperateLogPO>('''
            select * from operate_log order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询operate_log列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findOperateLogByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<OperateLogPO> {
        executor.page<OperateLogPO>('''
            select * from operate_log where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有operate_log（不分页）
     * @return operate_log列表
     */
    func listAllOperateLog(): ArrayList<OperateLogPO> {
        executor.setSql('''
            select * from operate_log order by created_at desc
        ''').list<OperateLogPO>()
    }

    /**
     * 批量查询operate_log
     * @param ids ID列表
     * @return operate_log列表
     */
    func findOperateLogByIds(ids: ArrayList<String>): ArrayList<OperateLogPO> {
        executor.setSql('''
            select * from operate_log where id ${IN(ids)}
        ''').list<OperateLogPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的operate_log数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countOperateLogByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from operate_log where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有operate_log数量
     * @return 数量
     */
    func countAllOperateLog(): Int64 {
        executor.setSql('''
            select count(*) from operate_log
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询operate_log列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findOperateLogByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<OperateLogPO> {
        let sql = StringBuilder()
        sql.append("select * from operate_log where 1=1")

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

        executor.page<OperateLogPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除operate_log
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteOperateLog(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            update operate_log set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除operate_log
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteOperateLog(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            delete from operate_log where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询operate_log（支持完整查询操作符）
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
    func findOperateLogByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<OperateLogPO> {
        let sql = StringBuilder()
        sql.append("select * from operate_log")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<OperateLogPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询operate_log
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findOperateLogByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<OperateLogPO> {
        let fromClause = executor.FROM<OperateLogPO>()

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
        fromClause.page<OperateLogPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的operate_log）
     * @return 影响行数
     */
    func emptyRecycleBinOperateLog(): Int64 {
        executor.setSql('''
            delete from operate_log where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
}
