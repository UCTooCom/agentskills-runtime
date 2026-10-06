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
import magic.app.models.uctoo.ModelChannelHealthPO
import magic.log.LogUtils

/**
 * ModelChannelHealthDAO - llm_channel_health数据访问接口
 *
 * 探测与健康历史表（追加日志，无软删/updated_at）。T017/T026 的探测结果落库。
 */
@DAO
public interface ModelChannelHealthDAO <: RootDAO {
    prop executor: SqlExecutor

    func insertModelChannelHealth(entity: ModelChannelHealthPO): String {
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

//#endregion AutoCreateCode
