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
import magic.app.models.uctoo.AipInteractionTaskPO
import magic.log.LogUtils

/**
 * AipInteractionTaskDAO - aip_interaction_task数据访问接口
 *
 * 提供aip_interaction_task表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AipInteractionTaskDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入aip_interaction_task（id由数据库自动生成UUID）
     * @param entity AipInteractionTaskPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAipInteractionTask(entity: AipInteractionTaskPO): String {
        executor.setSql('''
            insert into aip_interaction_task(
                task_id,
                session_id,
                service_agent_id,
                service_aic,
                state,
                state_changed_at,
                artifacts,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.taskId)},
                ${arg(entity.sessionId)},
                ${arg(entity.serviceAgentId)},
                ${arg(entity.serviceAic)},
                ${arg(entity.state)},
                ${arg(entity.stateChangedAt)},
                ${arg(entity.artifacts)},
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
     * 根据ID查询aip_interaction_task
     * @param id aip_interaction_taskID
     * @return aip_interaction_task对象（Option类型）
     */
    func findAipInteractionTaskById(id: String): Option<AipInteractionTaskPO> {
        executor.setSql('''
            select id, task_id, session_id, service_agent_id, service_aic, state, state_changed_at, artifacts, creator, created_at, updated_at, deleted_at from aip_interaction_task where id = ${arg(id)}
        ''').first<AipInteractionTaskPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新aip_interaction_task
     * @param entity aip_interaction_task对象
     * @return 影响行数
     */
    func updateAipInteractionTask(entity: AipInteractionTaskPO): Int64 {
        executor.setSql('''
            update aip_interaction_task set
                task_id = ${arg(entity.taskId)},
                session_id = ${arg(entity.sessionId)},
                service_agent_id = ${arg(entity.serviceAgentId)},
                service_aic = ${arg(entity.serviceAic)},
                state = ${arg(entity.state)},
                state_changed_at = ${arg(entity.stateChangedAt)},
                artifacts = ${arg(entity.artifacts)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除aip_interaction_task
     * @param id aip_interaction_taskID
     * @return 影响行数
     */
    func softDeleteAipInteractionTaskById(id: String): Int64 {
        executor.setSql('''
            update aip_interaction_task set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的aip_interaction_task
     * @param id aip_interaction_taskID
     * @return 影响行数
     */
    func restoreAipInteractionTaskById(id: String): Int64 {
        executor.setSql('''
            update aip_interaction_task set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除aip_interaction_task
     * @param id aip_interaction_taskID
     * @return 影响行数
     */
    func deleteAipInteractionTaskById(id: String): Int64 {
        executor.setSql('''
            delete from aip_interaction_task where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有aip_interaction_task
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAipInteractionTaskPage(page: Int64, size: Int64): Pagination<AipInteractionTaskPO> {
        executor.page<AipInteractionTaskPO>('''
            select id, task_id, session_id, service_agent_id, service_aic, state, state_changed_at, artifacts, creator, created_at, updated_at, deleted_at from aip_interaction_task order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询aip_interaction_task列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipInteractionTaskByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AipInteractionTaskPO> {
        executor.page<AipInteractionTaskPO>('''
            select id, task_id, session_id, service_agent_id, service_aic, state, state_changed_at, artifacts, creator, created_at, updated_at, deleted_at from aip_interaction_task where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有aip_interaction_task（不分页）
     * @return aip_interaction_task列表
     */
    func listAllAipInteractionTask(): ArrayList<AipInteractionTaskPO> {
        executor.setSql('''
            select id, task_id, session_id, service_agent_id, service_aic, state, state_changed_at, artifacts, creator, created_at, updated_at, deleted_at from aip_interaction_task order by created_at desc
        ''').list<AipInteractionTaskPO>()
    }

    /**
     * 批量查询aip_interaction_task
     * @param ids ID列表
     * @return aip_interaction_task列表
     */
    func findAipInteractionTaskByIds(ids: ArrayList<String>): ArrayList<AipInteractionTaskPO> {
        if (ids.isEmpty()) {
            return ArrayList<AipInteractionTaskPO>()
        }
        executor.setSql('''
            select id, task_id, session_id, service_agent_id, service_aic, state, state_changed_at, artifacts, creator, created_at, updated_at, deleted_at from aip_interaction_task where id ${IN(ids)}
        ''').list<AipInteractionTaskPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的aip_interaction_task数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAipInteractionTaskByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from aip_interaction_task where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有aip_interaction_task数量
     * @return 数量
     */
    func countAllAipInteractionTask(): Int64 {
        executor.setSql('''
            select count(*) from aip_interaction_task
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询aip_interaction_task列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipInteractionTaskByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AipInteractionTaskPO> {
        let sql = StringBuilder()
        sql.append("select id, task_id, session_id, service_agent_id, service_aic, state, state_changed_at, artifacts, creator, created_at, updated_at, deleted_at from aip_interaction_task where 1=1")

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

        executor.page<AipInteractionTaskPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除aip_interaction_task
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAipInteractionTask(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update aip_interaction_task set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除aip_interaction_task
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAipInteractionTask(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from aip_interaction_task where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询aip_interaction_task（支持完整查询操作符）
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
    func findAipInteractionTaskByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipInteractionTaskPO> {
        let sql = StringBuilder()
        sql.append("select id, task_id, session_id, service_agent_id, service_aic, state, state_changed_at, artifacts, creator, created_at, updated_at, deleted_at from aip_interaction_task")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AipInteractionTaskPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询aip_interaction_task
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAipInteractionTaskByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AipInteractionTaskPO> {
        let fromClause = executor.FROM<AipInteractionTaskPO>()

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
        fromClause.page<AipInteractionTaskPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的aip_interaction_task）
     * @return 影响行数
     */
    func emptyRecycleBinAipInteractionTask(): Int64 {
        executor.setSql('''
            delete from aip_interaction_task where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
