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
import magic.app.models.uctoo.LlmRouteRulePO
import magic.log.LogUtils

/**
 * LlmRouteRuleDAO - llm_route_rule数据访问接口
 *
 * 提供llm_route_rule表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface LlmRouteRuleDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入llm_route_rule（id由数据库自动生成UUID）
     * @param entity LlmRouteRulePO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLlmRouteRule(entity: LlmRouteRulePO): String {
        executor.setSql('''
            insert into llm_route_rule(
                scope,
                require_capabilities,
                channel_chain,
                fallback_chain,
                strategy,
                shadow_percent,
                enabled,
                priority,
                revision,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.scope)},
                ${arg(entity.requireCapabilities)},
                ${arg(entity.channelChain)},
                ${arg(entity.fallbackChain)},
                ${arg(entity.strategy)},
                ${arg(entity.shadowPercent)},
                ${arg(entity.enabled)},
                ${arg(entity.priority)},
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
     * 根据ID查询llm_route_rule
     * @param id llm_route_ruleID
     * @return llm_route_rule对象（Option类型）
     */
    func findLlmRouteRuleById(id: String): Option<LlmRouteRulePO> {
        executor.setSql('''
            select id, scope, require_capabilities, channel_chain, fallback_chain, strategy, shadow_percent, enabled, priority, revision, creator, created_at, updated_at, deleted_at from llm_route_rule where id = ${arg(id)}
        ''').first<LlmRouteRulePO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新llm_route_rule
     * @param entity llm_route_rule对象
     * @return 影响行数
     */
    func updateLlmRouteRule(entity: LlmRouteRulePO): Int64 {
        executor.setSql('''
            update llm_route_rule set
                scope = ${arg(entity.scope)},
                require_capabilities = ${arg(entity.requireCapabilities)},
                channel_chain = ${arg(entity.channelChain)},
                fallback_chain = ${arg(entity.fallbackChain)},
                strategy = ${arg(entity.strategy)},
                shadow_percent = ${arg(entity.shadowPercent)},
                enabled = ${arg(entity.enabled)},
                priority = ${arg(entity.priority)},
                revision = ${arg(entity.revision)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除llm_route_rule
     * @param id llm_route_ruleID
     * @return 影响行数
     */
    func softDeleteLlmRouteRuleById(id: String): Int64 {
        executor.setSql('''
            update llm_route_rule set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的llm_route_rule
     * @param id llm_route_ruleID
     * @return 影响行数
     */
    func restoreLlmRouteRuleById(id: String): Int64 {
        executor.setSql('''
            update llm_route_rule set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除llm_route_rule
     * @param id llm_route_ruleID
     * @return 影响行数
     */
    func deleteLlmRouteRuleById(id: String): Int64 {
        executor.setSql('''
            delete from llm_route_rule where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有llm_route_rule
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLlmRouteRulePage(page: Int64, size: Int64): Pagination<LlmRouteRulePO> {
        executor.page<LlmRouteRulePO>('''
            select id, scope, require_capabilities, channel_chain, fallback_chain, strategy, shadow_percent, enabled, priority, revision, creator, created_at, updated_at, deleted_at from llm_route_rule order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询llm_route_rule列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmRouteRuleByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LlmRouteRulePO> {
        executor.page<LlmRouteRulePO>('''
            select id, scope, require_capabilities, channel_chain, fallback_chain, strategy, shadow_percent, enabled, priority, revision, creator, created_at, updated_at, deleted_at from llm_route_rule where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有llm_route_rule（不分页）
     * @return llm_route_rule列表
     */
    func listAllLlmRouteRule(): ArrayList<LlmRouteRulePO> {
        executor.setSql('''
            select id, scope, require_capabilities, channel_chain, fallback_chain, strategy, shadow_percent, enabled, priority, revision, creator, created_at, updated_at, deleted_at from llm_route_rule order by created_at desc
        ''').list<LlmRouteRulePO>()
    }

    /**
     * 批量查询llm_route_rule
     * @param ids ID列表
     * @return llm_route_rule列表
     */
    func findLlmRouteRuleByIds(ids: ArrayList<String>): ArrayList<LlmRouteRulePO> {
        if (ids.isEmpty()) {
            return ArrayList<LlmRouteRulePO>()
        }
        executor.setSql('''
            select id, scope, require_capabilities, channel_chain, fallback_chain, strategy, shadow_percent, enabled, priority, revision, creator, created_at, updated_at, deleted_at from llm_route_rule where id ${IN(ids)}
        ''').list<LlmRouteRulePO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的llm_route_rule数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLlmRouteRuleByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from llm_route_rule where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有llm_route_rule数量
     * @return 数量
     */
    func countAllLlmRouteRule(): Int64 {
        executor.setSql('''
            select count(*) from llm_route_rule
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询llm_route_rule列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmRouteRuleByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LlmRouteRulePO> {
        let sql = StringBuilder()
        sql.append("select id, scope, require_capabilities, channel_chain, fallback_chain, strategy, shadow_percent, enabled, priority, revision, creator, created_at, updated_at, deleted_at from llm_route_rule where 1=1")

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

        executor.page<LlmRouteRulePO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除llm_route_rule
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLlmRouteRule(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update llm_route_rule set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除llm_route_rule
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLlmRouteRule(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from llm_route_rule where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询llm_route_rule（支持完整查询操作符）
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
    func findLlmRouteRuleByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmRouteRulePO> {
        let sql = StringBuilder()
        sql.append("select id, scope, require_capabilities, channel_chain, fallback_chain, strategy, shadow_percent, enabled, priority, revision, creator, created_at, updated_at, deleted_at from llm_route_rule")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LlmRouteRulePO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询llm_route_rule
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLlmRouteRuleByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LlmRouteRulePO> {
        let fromClause = executor.FROM<LlmRouteRulePO>()

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
        fromClause.page<LlmRouteRulePO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的llm_route_rule）
     * @return 影响行数
     */
    func emptyRecycleBinLlmRouteRule(): Int64 {
        executor.setSql('''
            delete from llm_route_rule where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
// ==================== 通道路由规则业务自定义方法（手写，搬自 ModelRouteRuleDAO，方法名保持不变） ====================

    func insertModelRouteRule(entity: LlmRouteRulePO): String {
        executor.setSql('''
            insert into llm_route_rule(
                scope,
                require_capabilities,
                channel_chain,
                fallback_chain,
                strategy,
                shadow_percent,
                enabled,
                priority,
                revision,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
                ${arg(entity.scope)},
                ${arg(entity.requireCapabilities)},
                ${arg(entity.channelChain)},
                ${arg(entity.fallbackChain)},
                ${arg(entity.strategy)},
                ${arg(entity.shadowPercent)},
                ${arg(entity.enabled)},
                ${arg(entity.priority)},
                ${arg(entity.revision)},
                ${arg(entity.creator)},
                ${arg(DateTime.now())},
                ${arg(DateTime.now())},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    func findModelRouteRuleById(id: String): Option<LlmRouteRulePO> {
        executor.setSql('''
            select * from llm_route_rule where id = ${arg(id)}
        ''').first<LlmRouteRulePO>()
    }

    func findAllModelRouteRules(): ArrayList<LlmRouteRulePO> {
        executor.setSql('''
            select * from llm_route_rule where deleted_at is null order by priority desc, created_at asc
        ''').list<LlmRouteRulePO>()
    }

    func countModelRouteRules(): Int64 {
        executor.setSql('''
            select count(*) from llm_route_rule where deleted_at is null
        ''').singleFirst<Int64>() ?? 0
    }

    func updateModelRouteRule(entity: LlmRouteRulePO): Int64 {
        executor.setSql('''
            update llm_route_rule set
                scope = ${arg(entity.scope)},
                require_capabilities = ${arg(entity.requireCapabilities)},
                channel_chain = ${arg(entity.channelChain)},
                fallback_chain = ${arg(entity.fallbackChain)},
                strategy = ${arg(entity.strategy)},
                shadow_percent = ${arg(entity.shadowPercent)},
                enabled = ${arg(entity.enabled)},
                priority = ${arg(entity.priority)},
                revision = ${arg(entity.revision)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    func softDeleteModelRouteRuleById(id: String): Int64 {
        executor.setSql('''
            update llm_route_rule set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
}
