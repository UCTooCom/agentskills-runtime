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
import magic.app.models.uctoo.ModelChannelPO
import magic.log.LogUtils

/**
 * ModelChannelDAO - llm_channel数据访问接口
 *
 * 提供llm_channel表的标准CRUD操作，遵循UCTOO V4 ORM规范。
 * 手写DAO（运行时内部通道表，不由crudgen生成）。
 */
@DAO
public interface ModelChannelDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    func insertModelChannel(entity: ModelChannelPO): String {
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
                deleted_at
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
                ${arg(DateTime.now())},
                ${arg(DateTime.now())},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    func findModelChannelById(id: String): Option<ModelChannelPO> {
        executor.setSql('''
            select * from llm_channel where id = ${arg(id)}
        ''').first<ModelChannelPO>()
    }

    func findModelChannelByCode(code: String): Option<ModelChannelPO> {
        executor.setSql('''
            select * from llm_channel where code = ${arg(code)} and deleted_at is null
        ''').first<ModelChannelPO>()
    }

    // ==================== 列表查询 ====================

    func findAllModelChannels(): ArrayList<ModelChannelPO> {
        executor.setSql('''
            select * from llm_channel where deleted_at is null order by priority desc, created_at asc
        ''').list<ModelChannelPO>()
    }

    func countModelChannels(): Int64 {
        executor.setSql('''
            select count(*) from llm_channel where deleted_at is null
        ''').singleFirst<Int64>() ?? 0
    }

    // ==================== 更新操作 ====================

    func updateModelChannel(entity: ModelChannelPO): Int64 {
        executor.setSql('''
            update llm_channel set
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
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 默认通道 ====================

    func unsetDefaultExcept(code: String): Int64 {
        executor.setSql('''
            update llm_channel set is_default = false where code != ${arg(code)} and is_default = true
        ''').update
    }

    func setDefaultByCode(code: String): Int64 {
        executor.setSql('''
            update llm_channel set is_default = true where code = ${arg(code)}
        ''').update
    }

    // ==================== 探测结果回写（T017 / T026） ====================

    /**
     * 写回三枪探测得到的能力位与健康快照 + 探测时间。
     * 注意：不 bump revision，避免探测导致 ModelInstanceCache 整体失效、
     *       影响进行中会话（V4 drain）。能力/健康变化由 2s 轮询刷新注册表即可在 2s 内可见。
     */
    func updateChannelProbe(code: String, capabilities: String, health: String, probeAt: DateTime): Int64 {
        executor.setSql('''
            update llm_channel set
                capabilities = ${arg(capabilities)},
                health = ${arg(health)},
                probe_at = ${arg(probeAt)}
            where code = ${arg(code)} and deleted_at is null
        ''').update
    }

    /**
     * 周期探活（T026）写回健康状态与探测时间。
     * 连续失败 -> degraded（从 catalog 摘除）；恢复 -> enabled。
     * 不改 revision，理由同上。
     */
    func updateChannelStatusOnly(code: String, status: String, probeAt: DateTime): Int64 {
        executor.setSql('''
            update llm_channel set
                status = ${arg(status)},
                probe_at = ${arg(probeAt)}
            where code = ${arg(code)} and deleted_at is null
        ''').update
    }

    // ==================== 删除操作 ====================

    func softDeleteModelChannelById(id: String): Int64 {
        executor.setSql('''
            update llm_channel set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
}

//#endregion AutoCreateCode
