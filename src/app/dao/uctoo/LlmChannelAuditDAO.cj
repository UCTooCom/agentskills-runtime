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
import magic.app.models.uctoo.LlmChannelAuditPO
import magic.log.LogUtils

/**
 * LlmChannelAuditDAO - llm_channel_audit数据访问接口
 *
 * 提供llm_channel_audit表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface LlmChannelAuditDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入llm_channel_audit（id由数据库自动生成UUID）
     * @param entity LlmChannelAuditPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLlmChannelAudit(entity: LlmChannelAuditPO): String {
        executor.setSql('''
            insert into llm_channel_audit(
                channel_id,
                action,
                before,
                after,
                operator,
                source,
                created_at
            ) values(
${arg(entity.channelId)},
                ${arg(entity.action)},
                ${arg(entity.before)},
                ${arg(entity.after)},
                ${arg(entity.operatorVal)},
                ${arg(entity.source)},
                ${arg(entity.createdAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询llm_channel_audit
     * @param id llm_channel_auditID
     * @return llm_channel_audit对象（Option类型）
     */
    func findLlmChannelAuditById(id: String): Option<LlmChannelAuditPO> {
        executor.setSql('''
            select id, channel_id, action, before, after, operator, source, created_at from llm_channel_audit where id = ${arg(id)}
        ''').first<LlmChannelAuditPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新llm_channel_audit
     * @param entity llm_channel_audit对象
     * @return 影响行数
     */
    func updateLlmChannelAudit(entity: LlmChannelAuditPO): Int64 {
        executor.setSql('''
            update llm_channel_audit set
                channel_id = ${arg(entity.channelId)},
                action = ${arg(entity.action)},
                before = ${arg(entity.before)},
                after = ${arg(entity.after)},
                operator = ${arg(entity.operatorVal)},
                source = ${arg(entity.source)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除llm_channel_audit
     * @param id llm_channel_auditID
     * @return 影响行数
     */
    func softDeleteLlmChannelAuditById(id: String): Int64 {
        executor.setSql('''
            update llm_channel_audit set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的llm_channel_audit
     * @param id llm_channel_auditID
     * @return 影响行数
     */
    func restoreLlmChannelAuditById(id: String): Int64 {
        executor.setSql('''
            update llm_channel_audit set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除llm_channel_audit
     * @param id llm_channel_auditID
     * @return 影响行数
     */
    func deleteLlmChannelAuditById(id: String): Int64 {
        executor.setSql('''
            delete from llm_channel_audit where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有llm_channel_audit
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLlmChannelAuditPage(page: Int64, size: Int64): Pagination<LlmChannelAuditPO> {
        executor.page<LlmChannelAuditPO>('''
            select id, channel_id, action, before, after, operator, source, created_at from llm_channel_audit order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询llm_channel_audit列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelAuditByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LlmChannelAuditPO> {
        executor.page<LlmChannelAuditPO>('''
            select id, channel_id, action, before, after, operator, source, created_at from llm_channel_audit where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有llm_channel_audit（不分页）
     * @return llm_channel_audit列表
     */
    func listAllLlmChannelAudit(): ArrayList<LlmChannelAuditPO> {
        executor.setSql('''
            select id, channel_id, action, before, after, operator, source, created_at from llm_channel_audit order by created_at desc
        ''').list<LlmChannelAuditPO>()
    }

    /**
     * 批量查询llm_channel_audit
     * @param ids ID列表
     * @return llm_channel_audit列表
     */
    func findLlmChannelAuditByIds(ids: ArrayList<String>): ArrayList<LlmChannelAuditPO> {
        if (ids.isEmpty()) {
            return ArrayList<LlmChannelAuditPO>()
        }
        executor.setSql('''
            select id, channel_id, action, before, after, operator, source, created_at from llm_channel_audit where id ${IN(ids)}
        ''').list<LlmChannelAuditPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的llm_channel_audit数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLlmChannelAuditByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_audit where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有llm_channel_audit数量
     * @return 数量
     */
    func countAllLlmChannelAudit(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_audit
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询llm_channel_audit列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelAuditByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LlmChannelAuditPO> {
        let sql = StringBuilder()
        sql.append("select id, channel_id, action, before, after, operator, source, created_at from llm_channel_audit where 1=1")

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

        executor.page<LlmChannelAuditPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除llm_channel_audit
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLlmChannelAudit(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update llm_channel_audit set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除llm_channel_audit
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLlmChannelAudit(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from llm_channel_audit where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询llm_channel_audit（支持完整查询操作符）
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
    func findLlmChannelAuditByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmChannelAuditPO> {
        let sql = StringBuilder()
        sql.append("select id, channel_id, action, before, after, operator, source, created_at from llm_channel_audit")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LlmChannelAuditPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询llm_channel_audit
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelAuditByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmChannelAuditPO> {
        let fromClause = executor.FROM<LlmChannelAuditPO>()

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
        fromClause.page<LlmChannelAuditPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的llm_channel_audit）
     * @return 影响行数
     */
    func emptyRecycleBinLlmChannelAudit(): Int64 {
        executor.setSql('''
            delete from llm_channel_audit where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
// ==================== 动态通道审计业务自定义方法（手写，搬自 ModelChannelAuditDAO，方法名保持不变；operator 字段按新 PO 改名为 operatorVal） ====================

    func insertModelChannelAudit(entity: LlmChannelAuditPO): String {
        executor.setSql('''
            insert into llm_channel_audit(
                channel_id,
                action,
                "before",
                "after",
                "operator",
                source,
                created_at
            ) values(
                ${arg(entity.channelId)},
                ${arg(entity.action)},
                ${arg(entity.before)},
                ${arg(entity.after)},
                ${arg(entity.operatorVal)},
                ${arg(entity.source)},
                ${arg(DateTime.now())}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    func findRecentModelChannelAudits(limit: Int64): ArrayList<LlmChannelAuditPO> {
        executor.setSql('''
            select * from llm_channel_audit order by created_at desc limit ${arg(limit)}
        ''').list<LlmChannelAuditPO>()
    }

    func findModelChannelAuditsByCode(code: String, limit: Int64): ArrayList<LlmChannelAuditPO> {
        executor.setSql('''
            select a.* from llm_channel_audit a
            join llm_channel c on c.id = a.channel_id
            where c.code = ${arg(code)}
            order by a.created_at desc
            limit ${arg(limit)}
        ''').list<LlmChannelAuditPO>()
    }

    func countModelChannelAudits(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_audit
        ''').singleFirst<Int64>() ?? 0
    }
}
