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
import magic.app.models.uctoo.CrontabPO
import magic.log.LogUtils

/**
 * CrontabDAO - crontab数据访问接口
 *
 * 提供crontab表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface CrontabDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入crontab（id由数据库自动生成UUID）
     * @param entity CrontabPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertCrontab(entity: CrontabPO): String {
        executor.setSql('''
            insert into crontab(
                name,
                group_name,
                task,
                cron,
                tactics,
                remark,
                creator,
                created_at,
                updated_at,
                deleted_at,
                status,
                timeout,
                max_retries,
                retry_count,
                concurrentable,
                once,
                priority,
                parameters,
                misfire_threshold,
                last_executed_at,
                next_executed_at,
                exec_count
            ) values(
                ${arg(entity.name)},
                ${arg(entity.groupName)},
                ${arg(entity.task)},
                ${arg(entity.cron)},
                ${arg(entity.tactics)},
                ${arg(entity.remark)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.status)},
                ${arg(entity.timeout)},
                ${arg(entity.maxRetries)},
                ${arg(entity.retryCount)},
                ${arg(entity.concurrentable)},
                ${arg(entity.once)},
                ${arg(entity.priority)},
                ${arg(entity.parameters)},
                ${arg(entity.misfireThreshold)},
                ${arg(entity.lastExecutedAt)},
                ${arg(entity.nextExecutedAt)},
                ${arg(entity.execCount)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询crontab
     * @param id crontabID
     * @return crontab对象（Option类型）
     */
    func findCrontabById(id: String): Option<CrontabPO> {
        executor.setSql('''
            select id, name, group_name, task, cron, tactics, remark, creator, created_at, updated_at, deleted_at, status, timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count from crontab where id = ${arg(id)}
        ''').first<CrontabPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新crontab
     * @param entity crontab对象
     * @return 影响行数
     */
    func updateCrontab(entity: CrontabPO): Int64 {
        executor.setSql('''
            update crontab set
                name = ${arg(entity.name)},
                group_name = ${arg(entity.groupName)},
                task = ${arg(entity.task)},
                cron = ${arg(entity.cron)},
                tactics = ${arg(entity.tactics)},
                remark = ${arg(entity.remark)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                status = ${arg(entity.status)},
                timeout = ${arg(entity.timeout)},
                max_retries = ${arg(entity.maxRetries)},
                retry_count = ${arg(entity.retryCount)},
                concurrentable = ${arg(entity.concurrentable)},
                once = ${arg(entity.once)},
                priority = ${arg(entity.priority)},
                parameters = ${arg(entity.parameters)},
                misfire_threshold = ${arg(entity.misfireThreshold)},
                last_executed_at = ${arg(entity.lastExecutedAt)},
                next_executed_at = ${arg(entity.nextExecutedAt)},
                exec_count = ${arg(entity.execCount)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除crontab
     * @param id crontabID
     * @return 影响行数
     */
    func softDeleteCrontabById(id: String): Int64 {
        executor.setSql('''
            update crontab set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的crontab
     * @param id crontabID
     * @return 影响行数
     */
    func restoreCrontabById(id: String): Int64 {
        executor.setSql('''
            update crontab set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除crontab
     * @param id crontabID
     * @return 影响行数
     */
    func deleteCrontabById(id: String): Int64 {
        executor.setSql('''
            delete from crontab where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有crontab
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllCrontabPage(page: Int64, size: Int64): Pagination<CrontabPO> {
        executor.page<CrontabPO>('''
            select id, name, group_name, task, cron, tactics, remark, creator, created_at, updated_at, deleted_at, status, timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count from crontab order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询crontab列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCrontabByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<CrontabPO> {
        executor.page<CrontabPO>('''
            select id, name, group_name, task, cron, tactics, remark, creator, created_at, updated_at, deleted_at, status, timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count from crontab where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有crontab（不分页）
     * @return crontab列表
     */
    func listAllCrontab(): ArrayList<CrontabPO> {
        executor.setSql('''
            select id, name, group_name, task, cron, tactics, remark, creator, created_at, updated_at, deleted_at, status, timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count from crontab order by created_at desc
        ''').list<CrontabPO>()
    }

    /**
     * 批量查询crontab
     * @param ids ID列表
     * @return crontab列表
     */
    func findCrontabByIds(ids: ArrayList<String>): ArrayList<CrontabPO> {
        if (ids.isEmpty()) {
            return ArrayList<CrontabPO>()
        }
        executor.setSql('''
            select id, name, group_name, task, cron, tactics, remark, creator, created_at, updated_at, deleted_at, status, timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count from crontab where id ${IN(ids)}
        ''').list<CrontabPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的crontab数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countCrontabByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from crontab where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有crontab数量
     * @return 数量
     */
    func countAllCrontab(): Int64 {
        executor.setSql('''
            select count(*) from crontab
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询crontab列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCrontabByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<CrontabPO> {
        let sql = StringBuilder()
        sql.append("select id, name, group_name, task, cron, tactics, remark, creator, created_at, updated_at, deleted_at, status, timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count from crontab where 1=1")

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

        executor.page<CrontabPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除crontab
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteCrontab(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update crontab set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除crontab
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteCrontab(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from crontab where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询crontab（支持完整查询操作符）
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
    func findCrontabByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<CrontabPO> {
        let sql = StringBuilder()
        sql.append("select id, name, group_name, task, cron, tactics, remark, creator, created_at, updated_at, deleted_at, status, timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count from crontab")
        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<CrontabPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询crontab
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCrontabByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<CrontabPO> {
        let sql = StringBuilder()
        sql.append("select id, name, group_name, task, cron, tactics, remark, creator, created_at, updated_at, deleted_at, status, timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count from crontab")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at DESC")
        }

        executor.page<CrontabPO>(sql.toString(), size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的crontab）
     * @return 影响行数
     */
    func emptyRecycleBinCrontab(): Int64 {
        executor.setSql('''
            delete from crontab where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}