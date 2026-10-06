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
import magic.app.models.uctoo.ModelChannelAuditPO
import magic.log.LogUtils

/**
 * ModelChannelAuditDAO - llm_channel_audit数据访问接口
 *
 * 注意：审计表列名 `operator` 在 PG 非保留字，但为稳妥此处用双引号显式引用。
 */
@DAO
public interface ModelChannelAuditDAO <: RootDAO {
    prop executor: SqlExecutor

    func insertModelChannelAudit(entity: ModelChannelAuditPO): String {
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
                ${arg(entity.operatorUser)},
                ${arg(entity.source)},
                ${arg(DateTime.now())}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 查询操作（T019：变更审计 API） ====================

    /**
     * 最近 N 条审计（跨全部通道），按时间倒序。
     * 审计表只追加不修改，故无 updated_at/deleted_at 过滤。
     */
    func findRecentModelChannelAudits(limit: Int64): ArrayList<ModelChannelAuditPO> {
        executor.setSql('''
            select * from llm_channel_audit order by created_at desc limit ${arg(limit)}
        ''').list<ModelChannelAuditPO>()
    }

    /**
     * 按通道编码查审计：审计表存的是 channel_id，需 join llm_channel 反查 code。
     * 入参为空串时表示不过滤（查全部）。
     */
    func findModelChannelAuditsByCode(code: String, limit: Int64): ArrayList<ModelChannelAuditPO> {
        executor.setSql('''
            select a.* from llm_channel_audit a
            join llm_channel c on c.id = a.channel_id
            where c.code = ${arg(code)}
            order by a.created_at desc
            limit ${arg(limit)}
        ''').list<ModelChannelAuditPO>()
    }

    func countModelChannelAudits(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel_audit
        ''').singleFirst<Int64>() ?? 0
    }
}

//#endregion AutoCreateCode
