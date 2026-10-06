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
import magic.app.models.uctoo.ModelRouteRulePO
import magic.log.LogUtils

/**
 * ModelRouteRuleDAO - llm_route_rule数据访问接口
 *
 * 提供llm_route_rule表的标准CRUD操作，遵循UCTOO V4 ORM规范。
 * 手写DAO（运行时内部路由规则表，不由crudgen生成）。
 */
@DAO
public interface ModelRouteRuleDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    func insertModelRouteRule(entity: ModelRouteRulePO): String {
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

    // ==================== 单条查询 ====================

    func findModelRouteRuleById(id: String): Option<ModelRouteRulePO> {
        executor.setSql('''
            select * from llm_route_rule where id = ${arg(id)}
        ''').first<ModelRouteRulePO>()
    }

    // ==================== 列表查询 ====================

    func findAllModelRouteRules(): ArrayList<ModelRouteRulePO> {
        executor.setSql('''
            select * from llm_route_rule where deleted_at is null order by priority desc, created_at asc
        ''').list<ModelRouteRulePO>()
    }

    func countModelRouteRules(): Int64 {
        executor.setSql('''
            select count(*) from llm_route_rule where deleted_at is null
        ''').singleFirst<Int64>() ?? 0
    }

    // ==================== 更新操作 ====================

    func updateModelRouteRule(entity: ModelRouteRulePO): Int64 {
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

    // ==================== 删除操作 ====================

    func softDeleteModelRouteRuleById(id: String): Int64 {
        executor.setSql('''
            update llm_route_rule set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
}

//#endregion AutoCreateCode
