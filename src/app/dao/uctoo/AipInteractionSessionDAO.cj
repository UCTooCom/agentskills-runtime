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
import magic.app.models.uctoo.AipInteractionSessionPO
import magic.log.LogUtils

/**
 * AipInteractionSessionDAO - aip_interaction_session数据访问接口
 *
 * 提供aip_interaction_session表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AipInteractionSessionDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入aip_interaction_session（id由数据库自动生成UUID）
     * @param entity AipInteractionSessionPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAipInteractionSession(entity: AipInteractionSessionPO): String {
        executor.setSql('''
            insert into aip_interaction_session(
                session_id,
                requester_agent_id,
                requester_aic,
                interaction_mode,
                receivers,
                context,
                session_status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.sessionId)},
                ${arg(entity.requesterAgentId)},
                ${arg(entity.requesterAic)},
                ${arg(entity.interactionMode)},
                ${arg(entity.receivers)},
                ${arg(entity.context)},
                ${arg(entity.sessionStatus)},
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
     * 根据ID查询aip_interaction_session
     * @param id aip_interaction_sessionID
     * @return aip_interaction_session对象（Option类型）
     */
    func findAipInteractionSessionById(id: String): Option<AipInteractionSessionPO> {
        executor.setSql('''
            select id, session_id, requester_agent_id, requester_aic, interaction_mode, receivers, context, session_status, creator, created_at, updated_at, deleted_at from aip_interaction_session where id = ${arg(id)}
        ''').first<AipInteractionSessionPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新aip_interaction_session
     * @param entity aip_interaction_session对象
     * @return 影响行数
     */
    func updateAipInteractionSession(entity: AipInteractionSessionPO): Int64 {
        executor.setSql('''
            update aip_interaction_session set
                session_id = ${arg(entity.sessionId)},
                requester_agent_id = ${arg(entity.requesterAgentId)},
                requester_aic = ${arg(entity.requesterAic)},
                interaction_mode = ${arg(entity.interactionMode)},
                receivers = ${arg(entity.receivers)},
                context = ${arg(entity.context)},
                session_status = ${arg(entity.sessionStatus)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除aip_interaction_session
     * @param id aip_interaction_sessionID
     * @return 影响行数
     */
    func softDeleteAipInteractionSessionById(id: String): Int64 {
        executor.setSql('''
            update aip_interaction_session set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的aip_interaction_session
     * @param id aip_interaction_sessionID
     * @return 影响行数
     */
    func restoreAipInteractionSessionById(id: String): Int64 {
        executor.setSql('''
            update aip_interaction_session set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除aip_interaction_session
     * @param id aip_interaction_sessionID
     * @return 影响行数
     */
    func deleteAipInteractionSessionById(id: String): Int64 {
        executor.setSql('''
            delete from aip_interaction_session where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有aip_interaction_session
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAipInteractionSessionPage(page: Int64, size: Int64): Pagination<AipInteractionSessionPO> {
        executor.page<AipInteractionSessionPO>('''
            select id, session_id, requester_agent_id, requester_aic, interaction_mode, receivers, context, session_status, creator, created_at, updated_at, deleted_at from aip_interaction_session order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询aip_interaction_session列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipInteractionSessionByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AipInteractionSessionPO> {
        executor.page<AipInteractionSessionPO>('''
            select id, session_id, requester_agent_id, requester_aic, interaction_mode, receivers, context, session_status, creator, created_at, updated_at, deleted_at from aip_interaction_session where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有aip_interaction_session（不分页）
     * @return aip_interaction_session列表
     */
    func listAllAipInteractionSession(): ArrayList<AipInteractionSessionPO> {
        executor.setSql('''
            select id, session_id, requester_agent_id, requester_aic, interaction_mode, receivers, context, session_status, creator, created_at, updated_at, deleted_at from aip_interaction_session order by created_at desc
        ''').list<AipInteractionSessionPO>()
    }

    /**
     * 批量查询aip_interaction_session
     * @param ids ID列表
     * @return aip_interaction_session列表
     */
    func findAipInteractionSessionByIds(ids: ArrayList<String>): ArrayList<AipInteractionSessionPO> {
        if (ids.isEmpty()) {
            return ArrayList<AipInteractionSessionPO>()
        }
        executor.setSql('''
            select id, session_id, requester_agent_id, requester_aic, interaction_mode, receivers, context, session_status, creator, created_at, updated_at, deleted_at from aip_interaction_session where id ${IN(ids)}
        ''').list<AipInteractionSessionPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的aip_interaction_session数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAipInteractionSessionByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from aip_interaction_session where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有aip_interaction_session数量
     * @return 数量
     */
    func countAllAipInteractionSession(): Int64 {
        executor.setSql('''
            select count(*) from aip_interaction_session
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询aip_interaction_session列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipInteractionSessionByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AipInteractionSessionPO> {
        let sql = StringBuilder()
        sql.append("select id, session_id, requester_agent_id, requester_aic, interaction_mode, receivers, context, session_status, creator, created_at, updated_at, deleted_at from aip_interaction_session where 1=1")

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

        executor.page<AipInteractionSessionPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除aip_interaction_session
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAipInteractionSession(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update aip_interaction_session set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除aip_interaction_session
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAipInteractionSession(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from aip_interaction_session where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询aip_interaction_session（支持完整查询操作符）
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
    func findAipInteractionSessionByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipInteractionSessionPO> {
        let sql = StringBuilder()
        sql.append("select id, session_id, requester_agent_id, requester_aic, interaction_mode, receivers, context, session_status, creator, created_at, updated_at, deleted_at from aip_interaction_session")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AipInteractionSessionPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询aip_interaction_session
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipInteractionSessionByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipInteractionSessionPO> {
        let fromClause = executor.FROM<AipInteractionSessionPO>()

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
        fromClause.page<AipInteractionSessionPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的aip_interaction_session）
     * @return 影响行数
     */
    func emptyRecycleBinAipInteractionSession(): Int64 {
        executor.setSql('''
            delete from aip_interaction_session where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
