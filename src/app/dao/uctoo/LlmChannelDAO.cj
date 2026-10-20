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
import magic.app.models.uctoo.LlmChannelPO
import magic.log.LogUtils

/**
 * LlmChannelDAO - llm_channel数据访问接口
 *
 * 提供llm_channel表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface LlmChannelDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入llm_channel（id由数据库自动生成UUID）
     * @param entity LlmChannelPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLlmChannel(entity: LlmChannelPO): String {
        executor.setSql('''
            insert into llm_channel(
                code,
                display_name,
                protocol,
                base_url,
                secret_ref,
                default_model,
                capabilities,
                scopes,
                priority,
                status,
                is_default,
                health,
                probe_at,
                config,
                revision,
                creator,
                created_at,
                updated_at,
                deleted_at,
                api_key
            ) values(
${arg(entity.code)},
                ${arg(entity.displayName)},
                ${arg(entity.protocol)},
                ${arg(entity.baseUrl)},
                ${arg(entity.secretRef)},
                ${arg(entity.defaultModel)},
                ${arg(entity.capabilities)},
                ${arg(entity.scopes)},
                ${arg(entity.priority)},
                ${arg(entity.status)},
                ${arg(entity.isDefault)},
                ${arg(entity.health)},
                ${arg(entity.probeAt)},
                ${arg(entity.config)},
                ${arg(entity.revision)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.apiKey)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询llm_channel
     * @param id llm_channelID
     * @return llm_channel对象（Option类型）
     */
    func findLlmChannelById(id: String): Option<LlmChannelPO> {
        executor.setSql('''
            select id, code, display_name, protocol, base_url, secret_ref, default_model, capabilities, scopes, priority, status, is_default, health, probe_at, config, revision, creator, created_at, updated_at, deleted_at, api_key from llm_channel where id = ${arg(id)}
        ''').first<LlmChannelPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新llm_channel
     * @param entity llm_channel对象
     * @return 影响行数
     */
    func updateLlmChannel(entity: LlmChannelPO): Int64 {
        executor.setSql('''
            update llm_channel set
                code = ${arg(entity.code)},
                display_name = ${arg(entity.displayName)},
                protocol = ${arg(entity.protocol)},
                base_url = ${arg(entity.baseUrl)},
                secret_ref = ${arg(entity.secretRef)},
                default_model = ${arg(entity.defaultModel)},
                capabilities = ${arg(entity.capabilities)},
                scopes = ${arg(entity.scopes)},
                priority = ${arg(entity.priority)},
                status = ${arg(entity.status)},
                is_default = ${arg(entity.isDefault)},
                health = ${arg(entity.health)},
                probe_at = ${arg(entity.probeAt)},
                config = ${arg(entity.config)},
                revision = ${arg(entity.revision)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                api_key = ${arg(entity.apiKey)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除llm_channel
     * @param id llm_channelID
     * @return 影响行数
     */
    func softDeleteLlmChannelById(id: String): Int64 {
        executor.setSql('''
            update llm_channel set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的llm_channel
     * @param id llm_channelID
     * @return 影响行数
     */
    func restoreLlmChannelById(id: String): Int64 {
        executor.setSql('''
            update llm_channel set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除llm_channel
     * @param id llm_channelID
     * @return 影响行数
     */
    func deleteLlmChannelById(id: String): Int64 {
        executor.setSql('''
            delete from llm_channel where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有llm_channel
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLlmChannelPage(page: Int64, size: Int64): Pagination<LlmChannelPO> {
        executor.page<LlmChannelPO>('''
            select id, code, display_name, protocol, base_url, secret_ref, default_model, capabilities, scopes, priority, status, is_default, health, probe_at, config, revision, creator, created_at, updated_at, deleted_at, api_key from llm_channel order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询llm_channel列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LlmChannelPO> {
        executor.page<LlmChannelPO>('''
            select id, code, display_name, protocol, base_url, secret_ref, default_model, capabilities, scopes, priority, status, is_default, health, probe_at, config, revision, creator, created_at, updated_at, deleted_at, api_key from llm_channel where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有llm_channel（不分页）
     * @return llm_channel列表
     */
    func listAllLlmChannel(): ArrayList<LlmChannelPO> {
        executor.setSql('''
            select id, code, display_name, protocol, base_url, secret_ref, default_model, capabilities, scopes, priority, status, is_default, health, probe_at, config, revision, creator, created_at, updated_at, deleted_at, api_key from llm_channel order by created_at desc
        ''').list<LlmChannelPO>()
    }

    /**
     * 批量查询llm_channel
     * @param ids ID列表
     * @return llm_channel列表
     */
    func findLlmChannelByIds(ids: ArrayList<String>): ArrayList<LlmChannelPO> {
        if (ids.isEmpty()) {
            return ArrayList<LlmChannelPO>()
        }
        executor.setSql('''
            select id, code, display_name, protocol, base_url, secret_ref, default_model, capabilities, scopes, priority, status, is_default, health, probe_at, config, revision, creator, created_at, updated_at, deleted_at, api_key from llm_channel where id ${IN(ids)}
        ''').list<LlmChannelPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的llm_channel数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLlmChannelByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from llm_channel where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有llm_channel数量
     * @return 数量
     */
    func countAllLlmChannel(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询llm_channel列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LlmChannelPO> {
        let sql = StringBuilder()
        sql.append("select id, code, display_name, protocol, base_url, secret_ref, default_model, capabilities, scopes, priority, status, is_default, health, probe_at, config, revision, creator, created_at, updated_at, deleted_at, api_key from llm_channel where 1=1")

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

        executor.page<LlmChannelPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除llm_channel
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLlmChannel(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update llm_channel set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除llm_channel
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLlmChannel(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from llm_channel where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询llm_channel（支持完整查询操作符）
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
    func findLlmChannelByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmChannelPO> {
        let sql = StringBuilder()
        sql.append("select id, code, display_name, protocol, base_url, secret_ref, default_model, capabilities, scopes, priority, status, is_default, health, probe_at, config, revision, creator, created_at, updated_at, deleted_at, api_key from llm_channel")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LlmChannelPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询llm_channel
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmChannelByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmChannelPO> {
        let fromClause = executor.FROM<LlmChannelPO>()

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
        fromClause.page<LlmChannelPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的llm_channel）
     * @return 影响行数
     */
    func emptyRecycleBinLlmChannel(): Int64 {
        executor.setSql('''
            delete from llm_channel where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
// ==================== 动态通道业务自定义方法（手写，搬自 ModelChannelDAO，方法名保持不变） ====================

    func insertModelChannel(entity: LlmChannelPO): String {
        executor.setSql('''
            insert into llm_channel(
                code,
                display_name,
                protocol,
                base_url,
                secret_ref,
                api_key,
                default_model,
                capabilities,
                scopes,
                priority,
                status,
                is_default,
                health,
                probe_at,
                config,
                revision,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.code)},
                ${arg(entity.displayName)},
                ${arg(entity.protocol)},
                ${arg(entity.baseUrl)},
                ${arg(entity.secretRef)},
                ${arg(entity.apiKey)},
                ${arg(entity.defaultModel)},
                ${arg(entity.capabilities)},
                ${arg(entity.scopes)},
                ${arg(entity.priority)},
                ${arg(entity.status)},
                ${arg(entity.isDefault)},
                ${arg(entity.health)},
                ${arg(entity.probeAt)},
                ${arg(entity.config)},
                ${arg(entity.revision)},
                ${arg(entity.creator)},
                ${arg(DateTime.now())},
                ${arg(DateTime.now())},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    func findModelChannelById(id: String): Option<LlmChannelPO> {
        executor.setSql('''
            select * from llm_channel where id = ${arg(id)}
        ''').first<LlmChannelPO>()
    }

    func findModelChannelByCode(code: String): Option<LlmChannelPO> {
        executor.setSql('''
            select * from llm_channel where code = ${arg(code)} and deleted_at is null
        ''').first<LlmChannelPO>()
    }

    func findAllModelChannels(): ArrayList<LlmChannelPO> {
        executor.setSql('''
            select * from llm_channel where deleted_at is null order by priority desc, created_at asc
        ''').list<LlmChannelPO>()
    }

    func countModelChannels(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel where deleted_at is null
        ''').singleFirst<Int64>() ?? 0
    }

    func updateModelChannel(entity: LlmChannelPO): Int64 {
        executor.setSql('''
            update llm_channel set
                display_name = ${arg(entity.displayName)},
                protocol = ${arg(entity.protocol)},
                base_url = ${arg(entity.baseUrl)},
                secret_ref = ${arg(entity.secretRef)},
                api_key = ${arg(entity.apiKey)},
                default_model = ${arg(entity.defaultModel)},
                capabilities = ${arg(entity.capabilities)},
                scopes = ${arg(entity.scopes)},
                priority = ${arg(entity.priority)},
                status = ${arg(entity.status)},
                is_default = ${arg(entity.isDefault)},
                health = ${arg(entity.health)},
                probe_at = ${arg(entity.probeAt)},
                config = ${arg(entity.config)},
                revision = ${arg(entity.revision)},
                creator = ${arg(entity.creator)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    func unsetDefaultExcept(code: String): Int64 {
        executor.setSql('''
            update llm_channel set is_default = false, updated_at = ${arg(DateTime.now())}
             where code != ${arg(code)} and is_default = true
        ''').update
    }

    func setDefaultByCode(code: String): Int64 {
        executor.setSql('''
            update llm_channel set is_default = true, updated_at = ${arg(DateTime.now())}
             where code = ${arg(code)}
        ''').update
    }

    func updateChannelProbe(code: String, capabilities: String, health: String, probeAt: DateTime): Int64 {
        executor.setSql('''
            update llm_channel set
                capabilities = ${arg(capabilities)},
                health = ${arg(health)},
                probe_at = ${arg(probeAt)}
            where code = ${arg(code)} and deleted_at is null
        ''').update
    }

    func updateChannelStatusOnly(code: String, status: String, probeAt: DateTime): Int64 {
        executor.setSql('''
            update llm_channel set
                status = ${arg(status)},
                probe_at = ${arg(probeAt)}
            where code = ${arg(code)} and deleted_at is null
        ''').update
    }

    func softDeleteModelChannelById(id: String): Int64 {
        executor.setSql('''
            update llm_channel set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
}
