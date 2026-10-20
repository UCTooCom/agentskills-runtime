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
import magic.app.models.uctoo.LlmChannelHealthPO
import magic.log.LogUtils

/**
 * LlmChannelHealthDAO - llm_channel_health数据访问接口
 *
 * 提供llm_channel_health表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface LlmChannelHealthDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入llm_channel_health（id由数据库自动生成UUID）
     * @param entity LlmChannelHealthPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLlmChannelHealth(entity: LlmChannelHealthPO): String {
        executor.setSql('''
            insert into llm_channel_health(
                channel_id,
                model_id,
                ok,
                latency_ms,
                error_code,
                error_message,
                checked_at
            ) values(
${arg(entity.channelId)},
                ${arg(entity.modelId)},
                ${arg(entity.ok)},
                ${arg(entity.latencyMs)},
                ${arg(entity.errorCode)},
                ${arg(entity.errorMessage)},
                ${arg(entity.checkedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询llm_channel_health
     * @param id llm_channel_healthID
     * @return llm_channel_health对象（Option类型）
     */
    func findLlmChannelHealthById(id: String): Option<LlmChannelHealthPO> {
        executor.setSql('''
            select id, channel_id, model_id, ok, latency_ms, error_code, error_message, checked_at from llm_channel_health where id = ${arg(id)}
        ''').first<LlmChannelHealthPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新llm_channel_health
     * @param entity llm_channel_health对象
     * @return 影响行数
     */
    func updateLlmChannelHealth(entity: LlmChannelHealthPO): Int64 {
        executor.setSql('''
            update llm_channel_health set
                channel_id = ${arg(entity.channelId)},
                model_id = ${arg(entity.modelId)},
                ok = ${arg(entity.ok)},
                latency_ms = ${arg(entity.latencyMs)},
                error_code = ${arg(entity.errorCode)},
                error_message = ${arg(entity.errorMessage)},
                checked_at = ${arg(entity.checkedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除llm_channel_health
     * @param id llm_channel_healthID
     * @return 影响行数
     */
    func softDeleteLlmChannelHealthById(id: String): Int64 {
        executor.setSql('''
            update llm_channel_health set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的llm_channel_health
     * @param id llm_channel_healthID
     * @return 影响行数
     */
    func restoreLlmChannelHealthById(id: String): Int64 {
        executor.setSql('''
            update llm_channel_health set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除llm_channel_health
     * @param id llm_channel_healthID
     * @return 影响行数
     */
    func deleteLlmChannelHealthById(id: String): Int64 {
        executor.setSql('''
            delete from llm_channel_health where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有llm_channel_health
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLlmChannelHealthPage(page: Int64, size: Int64): Pagination<LlmChannelHealthPO> {
        executor.page<LlmChannelHealthPO>('''
            select id, channel_id, model_id, ok, latency_ms, error_code, error_message, checked_at from llm_channel_health order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询llm_channel_health列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelHealthByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LlmChannelHealthPO> {
        executor.page<LlmChannelHealthPO>('''
            select id, channel_id, model_id, ok, latency_ms, error_code, error_message, checked_at from llm_channel_health where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有llm_channel_health（不分页）
     * @return llm_channel_health列表
     */
    func listAllLlmChannelHealth(): ArrayList<LlmChannelHealthPO> {
        executor.setSql('''
            select id, channel_id, model_id, ok, latency_ms, error_code, error_message, checked_at from llm_channel_health order by created_at desc
        ''').list<LlmChannelHealthPO>()
    }

    /**
     * 批量查询llm_channel_health
     * @param ids ID列表
     * @return llm_channel_health列表
     */
    func findLlmChannelHealthByIds(ids: ArrayList<String>): ArrayList<LlmChannelHealthPO> {
        if (ids.isEmpty()) {
            return ArrayList<LlmChannelHealthPO>()
        }
        executor.setSql('''
            select id, channel_id, model_id, ok, latency_ms, error_code, error_message, checked_at from llm_channel_health where id ${IN(ids)}
        ''').list<LlmChannelHealthPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的llm_channel_health数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLlmChannelHealthByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_health where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有llm_channel_health数量
     * @return 数量
     */
    func countAllLlmChannelHealth(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_health
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询llm_channel_health列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelHealthByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LlmChannelHealthPO> {
        let sql = StringBuilder()
        sql.append("select id, channel_id, model_id, ok, latency_ms, error_code, error_message, checked_at from llm_channel_health where 1=1")

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

        executor.page<LlmChannelHealthPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除llm_channel_health
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLlmChannelHealth(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update llm_channel_health set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除llm_channel_health
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLlmChannelHealth(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from llm_channel_health where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询llm_channel_health（支持完整查询操作符）
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
    func findLlmChannelHealthByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmChannelHealthPO> {
        let sql = StringBuilder()
        sql.append("select id, channel_id, model_id, ok, latency_ms, error_code, error_message, checked_at from llm_channel_health")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LlmChannelHealthPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询llm_channel_health
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelHealthByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmChannelHealthPO> {
        let fromClause = executor.FROM<LlmChannelHealthPO>()

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
        fromClause.page<LlmChannelHealthPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的llm_channel_health）
     * @return 影响行数
     */
    func emptyRecycleBinLlmChannelHealth(): Int64 {
        executor.setSql('''
            delete from llm_channel_health where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
// ==================== 动态通道健康业务自定义方法（手写，搬自 ModelChannelHealthDAO，方法名保持不变） ====================

    func insertModelChannelHealth(entity: LlmChannelHealthPO): String {
        executor.setSql('''
            insert into llm_channel_health(
                channel_id,
                model_id,
                ok,
                latency_ms,
                error_code,
                error_message,
                checked_at
            ) values(
                ${arg(entity.channelId)},
                ${arg(entity.modelId)},
                ${arg(entity.ok)},
                ${arg(entity.latencyMs)},
                ${arg(entity.errorCode)},
                ${arg(entity.errorMessage)},
                ${arg(entity.checkedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    func countModelChannelHealth(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_health
        ''').singleFirst<Int64>() ?? 0
    }
}
