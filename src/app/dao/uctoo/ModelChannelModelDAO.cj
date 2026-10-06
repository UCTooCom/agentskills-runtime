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
import magic.app.models.uctoo.ModelChannelModelPO
import magic.log.LogUtils

/**
 * ModelChannelModelDAO - llm_channel_model数据访问接口
 */
@DAO
public interface ModelChannelModelDAO <: RootDAO {
    prop executor: SqlExecutor

    func insertModelChannelModel(entity: ModelChannelModelPO): String {
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

    func findModelChannelModelById(id: String): Option<ModelChannelModelPO> {
        executor.setSql('''
            select * from llm_channel_model where id = ${arg(id)}
        ''').first<ModelChannelModelPO>()
    }

    func findModelChannelModelsByChannelId(channelId: String): ArrayList<ModelChannelModelPO> {
        executor.setSql('''
            select * from llm_channel_model where channel_id = ${arg(channelId)} and deleted_at is null order by created_at asc
        ''').list<ModelChannelModelPO>()
    }

    func findModelChannelModelByChannelAndModel(channelId: String, modelId: String): Option<ModelChannelModelPO> {
        executor.setSql('''
            select * from llm_channel_model where channel_id = ${arg(channelId)} and model_id = ${arg(modelId)} and deleted_at is null
        ''').first<ModelChannelModelPO>()
    }

    /**
     * 三枪探测后写回能力位 / 状态 / 探测时间（T017）。
     * 模型条目级 revision 自增，用于后续缓存/对账；不影响通道级 revision。
     */
    func updateModelChannelModelCapabilities(entity: ModelChannelModelPO): Int64 {
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

//#endregion AutoCreateCode
