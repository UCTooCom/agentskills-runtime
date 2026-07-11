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
import magic.app.models.uctoo.SmsLogPO
import magic.log.LogUtils

/**
 * SmsLogDAO - sms_log数据访问接口
 *
 * 提供sms_log表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface SmsLogDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入sms_log（id由数据库自动生成UUID）
     * @param entity SmsLogPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertSmsLog(entity: SmsLogPO): String {
        executor.setSql('''
            insert into sms_log(
                event,
                mobile,
                code,
                times,
                ip,
                creator,
                created_at,
                updated_at,
                deleted_at,
                email
            ) values(
                ${arg(entity.event)},
                ${arg(entity.mobile)},
                ${arg(entity.code)},
                ${arg(entity.times)},
                ${arg(entity.ip)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.email)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询sms_log
     * @param id sms_logID
     * @return sms_log对象（Option类型）
     */
    func findSmsLogById(id: String): Option<SmsLogPO> {
        executor.setSql('''
            select id, event, mobile, code, times, ip, creator, created_at, updated_at, deleted_at, email from sms_log where id = ${arg(id)}
        ''').first<SmsLogPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新sms_log
     * @param entity sms_log对象
     * @return 影响行数
     */
    func updateSmsLog(entity: SmsLogPO): Int64 {
        executor.setSql('''
            update sms_log set
                event = ${arg(entity.event)},
                mobile = ${arg(entity.mobile)},
                code = ${arg(entity.code)},
                times = ${arg(entity.times)},
                ip = ${arg(entity.ip)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                email = ${arg(entity.email)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除sms_log
     * @param id sms_logID
     * @return 影响行数
     */
    func softDeleteSmsLogById(id: String): Int64 {
        executor.setSql('''
            update sms_log set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的sms_log
     * @param id sms_logID
     * @return 影响行数
     */
    func restoreSmsLogById(id: String): Int64 {
        executor.setSql('''
            update sms_log set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除sms_log
     * @param id sms_logID
     * @return 影响行数
     */
    func deleteSmsLogById(id: String): Int64 {
        executor.setSql('''
            delete from sms_log where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有sms_log
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllSmsLogPage(page: Int64, size: Int64): Pagination<SmsLogPO> {
        executor.page<SmsLogPO>('''
            select id, event, mobile, code, times, ip, creator, created_at, updated_at, deleted_at, email from sms_log order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询sms_log列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSmsLogByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<SmsLogPO> {
        executor.page<SmsLogPO>('''
            select id, event, mobile, code, times, ip, creator, created_at, updated_at, deleted_at, email from sms_log where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有sms_log（不分页）
     * @return sms_log列表
     */
    func listAllSmsLog(): ArrayList<SmsLogPO> {
        executor.setSql('''
            select id, event, mobile, code, times, ip, creator, created_at, updated_at, deleted_at, email from sms_log order by created_at desc
        ''').list<SmsLogPO>()
    }

    /**
     * 批量查询sms_log
     * @param ids ID列表
     * @return sms_log列表
     */
    func findSmsLogByIds(ids: ArrayList<String>): ArrayList<SmsLogPO> {
        if (ids.isEmpty()) {
            return ArrayList<SmsLogPO>()
        }
        executor.setSql('''
            select id, event, mobile, code, times, ip, creator, created_at, updated_at, deleted_at, email from sms_log where id ${IN(ids)}
        ''').list<SmsLogPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的sms_log数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countSmsLogByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from sms_log where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有sms_log数量
     * @return 数量
     */
    func countAllSmsLog(): Int64 {
        executor.setSql('''
            select count(*) from sms_log
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询sms_log列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSmsLogByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<SmsLogPO> {
        let sql = StringBuilder()
        sql.append("select id, event, mobile, code, times, ip, creator, created_at, updated_at, deleted_at, email from sms_log where 1=1")

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

        executor.page<SmsLogPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除sms_log
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteSmsLog(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update sms_log set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除sms_log
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteSmsLog(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from sms_log where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询sms_log（支持完整查询操作符）
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
    func findSmsLogByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SmsLogPO> {
        let sql = StringBuilder()
        sql.append("select id, event, mobile, code, times, ip, creator, created_at, updated_at, deleted_at, email from sms_log")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<SmsLogPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询sms_log
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSmsLogByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SmsLogPO> {
        let fromClause = executor.FROM<SmsLogPO>()

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
        fromClause.page<SmsLogPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的sms_log）
     * @return 影响行数
     */
    func emptyRecycleBinSmsLog(): Int64 {
        executor.setSql('''
            delete from sms_log where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
    /**
     * 根据邮箱和事件类型查询验证码记录
     * 
     * @param email 邮箱
     * @param event 事件类型
     * @param expirationTime 过期时间阈值（只查询此时间之后创建的记录）
     * @return 验证码记录列表
     */
    func findSmsLogByEmailAndEvent(email: String, event: String, expirationTime: DateTime): ArrayList<SmsLogPO> {
        let fromClause = executor.FROM<SmsLogPO>()
        fromClause.WHERE("email = '${email}' AND event = '${event}' AND created_at >= '${expirationTime}'")
        fromClause.ORDER_BY { => "created_at DESC" }
        fromClause.LIMIT(10)
        let result = fromClause.list<SmsLogPO>()
        let list = ArrayList<SmsLogPO>()
        for (item in result) {
            list.add(item)
        }
        return list
    }
}
