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
import magic.app.models.uctoo.LlmChannelModelPO
import magic.log.LogUtils

/**
 * LlmChannelModelDAO - llm_channel_model数据访问接口
 *
 * 提供llm_channel_model表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface LlmChannelModelDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入llm_channel_model（id由数据库自动生成UUID）
     * @param entity LlmChannelModelPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLlmChannelModel(entity: LlmChannelModelPO): String {
        executor.setSql('''
            insert into llm_channel_model(
                channel_id,
                model_id,
                display_name,
                capabilities,
                context_len,
                max_output,
                pricing_ref,
                status,
                probed_at,
                revision,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.channelId)},
                ${arg(entity.modelId)},
                ${arg(entity.displayName)},
                ${arg(entity.capabilities)},
                ${arg(entity.contextLen)},
                ${arg(entity.maxOutput)},
                ${arg(entity.pricingRef)},
                ${arg(entity.status)},
                ${arg(entity.probedAt)},
                ${arg(entity.revision)},
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
     * 根据ID查询llm_channel_model
     * @param id llm_channel_modelID
     * @return llm_channel_model对象（Option类型）
     */
    func findLlmChannelModelById(id: String): Option<LlmChannelModelPO> {
        executor.setSql('''
            select id, channel_id, model_id, display_name, capabilities, context_len, max_output, pricing_ref, status, probed_at, revision, creator, created_at, updated_at, deleted_at from llm_channel_model where id = ${arg(id)}
        ''').first<LlmChannelModelPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新llm_channel_model
     * @param entity llm_channel_model对象
     * @return 影响行数
     */
    func updateLlmChannelModel(entity: LlmChannelModelPO): Int64 {
        executor.setSql('''
            update llm_channel_model set
                channel_id = ${arg(entity.channelId)},
                model_id = ${arg(entity.modelId)},
                display_name = ${arg(entity.displayName)},
                capabilities = ${arg(entity.capabilities)},
                context_len = ${arg(entity.contextLen)},
                max_output = ${arg(entity.maxOutput)},
                pricing_ref = ${arg(entity.pricingRef)},
                status = ${arg(entity.status)},
                probed_at = ${arg(entity.probedAt)},
                revision = ${arg(entity.revision)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除llm_channel_model
     * @param id llm_channel_modelID
     * @return 影响行数
     */
    func softDeleteLlmChannelModelById(id: String): Int64 {
        executor.setSql('''
            update llm_channel_model set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的llm_channel_model
     * @param id llm_channel_modelID
     * @return 影响行数
     */
    func restoreLlmChannelModelById(id: String): Int64 {
        executor.setSql('''
            update llm_channel_model set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除llm_channel_model
     * @param id llm_channel_modelID
     * @return 影响行数
     */
    func deleteLlmChannelModelById(id: String): Int64 {
        executor.setSql('''
            delete from llm_channel_model where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有llm_channel_model
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLlmChannelModelPage(page: Int64, size: Int64): Pagination<LlmChannelModelPO> {
        executor.page<LlmChannelModelPO>('''
            select id, channel_id, model_id, display_name, capabilities, context_len, max_output, pricing_ref, status, probed_at, revision, creator, created_at, updated_at, deleted_at from llm_channel_model order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询llm_channel_model列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelModelByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LlmChannelModelPO> {
        executor.page<LlmChannelModelPO>('''
            select id, channel_id, model_id, display_name, capabilities, context_len, max_output, pricing_ref, status, probed_at, revision, creator, created_at, updated_at, deleted_at from llm_channel_model where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有llm_channel_model（不分页）
     * @return llm_channel_model列表
     */
    func listAllLlmChannelModel(): ArrayList<LlmChannelModelPO> {
        executor.setSql('''
            select id, channel_id, model_id, display_name, capabilities, context_len, max_output, pricing_ref, status, probed_at, revision, creator, created_at, updated_at, deleted_at from llm_channel_model order by created_at desc
        ''').list<LlmChannelModelPO>()
    }

    /**
     * 批量查询llm_channel_model
     * @param ids ID列表
     * @return llm_channel_model列表
     */
    func findLlmChannelModelByIds(ids: ArrayList<String>): ArrayList<LlmChannelModelPO> {
        if (ids.isEmpty()) {
            return ArrayList<LlmChannelModelPO>()
        }
        executor.setSql('''
            select id, channel_id, model_id, display_name, capabilities, context_len, max_output, pricing_ref, status, probed_at, revision, creator, created_at, updated_at, deleted_at from llm_channel_model where id ${IN(ids)}
        ''').list<LlmChannelModelPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的llm_channel_model数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLlmChannelModelByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_model where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有llm_channel_model数量
     * @return 数量
     */
    func countAllLlmChannelModel(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_model
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询llm_channel_model列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelModelByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LlmChannelModelPO> {
        let sql = StringBuilder()
        sql.append("select id, channel_id, model_id, display_name, capabilities, context_len, max_output, pricing_ref, status, probed_at, revision, creator, created_at, updated_at, deleted_at from llm_channel_model where 1=1")

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

        executor.page<LlmChannelModelPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除llm_channel_model
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLlmChannelModel(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update llm_channel_model set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除llm_channel_model
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLlmChannelModel(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from llm_channel_model where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询llm_channel_model（支持完整查询操作符）
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
    func findLlmChannelModelByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmChannelModelPO> {
        let sql = StringBuilder()
        sql.append("select id, channel_id, model_id, display_name, capabilities, context_len, max_output, pricing_ref, status, probed_at, revision, creator, created_at, updated_at, deleted_at from llm_channel_model")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LlmChannelModelPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询llm_channel_model
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelModelByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmChannelModelPO> {
        let fromClause = executor.FROM<LlmChannelModelPO>()

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
        fromClause.page<LlmChannelModelPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的llm_channel_model）
     * @return 影响行数
     */
    func emptyRecycleBinLlmChannelModel(): Int64 {
        executor.setSql('''
            delete from llm_channel_model where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
// ==================== 动态通道模型业务自定义方法（手写，搬自 ModelChannelModelDAO，方法名保持不变） ====================

    func insertModelChannelModel(entity: LlmChannelModelPO): String {
        executor.setSql('''
            insert into llm_channel_model(
                channel_id,
                model_id,
                display_name,
                capabilities,
                context_len,
                max_output,
                pricing_ref,
                status,
                probed_at,
                revision,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.channelId)},
                ${arg(entity.modelId)},
                ${arg(entity.displayName)},
                ${arg(entity.capabilities)},
                ${arg(entity.contextLen)},
                ${arg(entity.maxOutput)},
                ${arg(entity.pricingRef)},
                ${arg(entity.status)},
                ${arg(entity.probedAt)},
                ${arg(entity.revision)},
                ${arg(entity.creator)},
                ${arg(DateTime.now())},
                ${arg(DateTime.now())},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    func findModelChannelModelById(id: String): Option<LlmChannelModelPO> {
        executor.setSql('''
            select * from llm_channel_model where id = ${arg(id)}
        ''').first<LlmChannelModelPO>()
    }

    func findModelChannelModelsByChannelId(channelId: String): ArrayList<LlmChannelModelPO> {
        executor.setSql('''
            select * from llm_channel_model where channel_id = ${arg(channelId)} and deleted_at is null order by created_at asc
        ''').list<LlmChannelModelPO>()
    }

    func findModelChannelModelByChannelAndModel(channelId: String, modelId: String): Option<LlmChannelModelPO> {
        executor.setSql('''
            select * from llm_channel_model where channel_id = ${arg(channelId)} and model_id = ${arg(modelId)} and deleted_at is null
        ''').first<LlmChannelModelPO>()
    }

    func updateModelChannelModelCapabilities(entity: LlmChannelModelPO): Int64 {
        executor.setSql('''
            update llm_channel_model set
                capabilities = ${arg(entity.capabilities)},
                status = ${arg(entity.status)},
                probed_at = ${arg(entity.probedAt)},
                revision = ${arg(entity.revision)}
            where id = ${arg(entity.id)}
        ''').update
    }
}
