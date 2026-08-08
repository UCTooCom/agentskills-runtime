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
import magic.app.models.uctoo.ExecutionEvidencesPO
import magic.log.LogUtils

/**
 * ExecutionEvidencesDAO - execution_evidences数据访问接口
 *
 * 提供execution_evidences表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface ExecutionEvidencesDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入execution_evidences（id由数据库自动生成UUID）
     * @param entity ExecutionEvidencesPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertExecutionEvidences(entity: ExecutionEvidencesPO): String {
        executor.setSql('''
            insert into execution_evidences(
                agent_id,
                session_id,
                step_id,
                parent_step_id,
                step_type,
                input,
                output,
                duration_ms,
                side_effects,
                hash,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.agentId)},
                ${arg(entity.sessionId)},
                ${arg(entity.stepId)},
                ${arg(entity.parentStepId)},
                ${arg(entity.stepType)},
                ${arg(entity.input)},
                ${arg(entity.output)},
                ${arg(entity.durationMs)},
                ${arg(entity.sideEffects)},
                ${arg(entity.hash)},
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
     * 根据ID查询execution_evidences
     * @param id execution_evidencesID
     * @return execution_evidences对象（Option类型）
     */
    func findExecutionEvidencesById(id: String): Option<ExecutionEvidencesPO> {
        executor.setSql('''
            select id, agent_id, session_id, step_id, parent_step_id, step_type, input, output, duration_ms, side_effects, hash, creator, created_at, updated_at, deleted_at from execution_evidences where id = ${arg(id)}
        ''').first<ExecutionEvidencesPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新execution_evidences
     * @param entity execution_evidences对象
     * @return 影响行数
     */
    func updateExecutionEvidences(entity: ExecutionEvidencesPO): Int64 {
        executor.setSql('''
            update execution_evidences set
                agent_id = ${arg(entity.agentId)},
                session_id = ${arg(entity.sessionId)},
                step_id = ${arg(entity.stepId)},
                parent_step_id = ${arg(entity.parentStepId)},
                step_type = ${arg(entity.stepType)},
                input = ${arg(entity.input)},
                output = ${arg(entity.output)},
                duration_ms = ${arg(entity.durationMs)},
                side_effects = ${arg(entity.sideEffects)},
                hash = ${arg(entity.hash)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除execution_evidences
     * @param id execution_evidencesID
     * @return 影响行数
     */
    func softDeleteExecutionEvidencesById(id: String): Int64 {
        executor.setSql('''
            update execution_evidences set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的execution_evidences
     * @param id execution_evidencesID
     * @return 影响行数
     */
    func restoreExecutionEvidencesById(id: String): Int64 {
        executor.setSql('''
            update execution_evidences set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除execution_evidences
     * @param id execution_evidencesID
     * @return 影响行数
     */
    func deleteExecutionEvidencesById(id: String): Int64 {
        executor.setSql('''
            delete from execution_evidences where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有execution_evidences
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllExecutionEvidencesPage(page: Int64, size: Int64): Pagination<ExecutionEvidencesPO> {
        executor.page<ExecutionEvidencesPO>('''
            select id, agent_id, session_id, step_id, parent_step_id, step_type, input, output, duration_ms, side_effects, hash, creator, created_at, updated_at, deleted_at from execution_evidences order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询execution_evidences列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findExecutionEvidencesByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<ExecutionEvidencesPO> {
        executor.page<ExecutionEvidencesPO>('''
            select id, agent_id, session_id, step_id, parent_step_id, step_type, input, output, duration_ms, side_effects, hash, creator, created_at, updated_at, deleted_at from execution_evidences where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有execution_evidences（不分页）
     * @return execution_evidences列表
     */
    func listAllExecutionEvidences(): ArrayList<ExecutionEvidencesPO> {
        executor.setSql('''
            select id, agent_id, session_id, step_id, parent_step_id, step_type, input, output, duration_ms, side_effects, hash, creator, created_at, updated_at, deleted_at from execution_evidences order by created_at desc
        ''').list<ExecutionEvidencesPO>()
    }

    /**
     * 批量查询execution_evidences
     * @param ids ID列表
     * @return execution_evidences列表
     */
    func findExecutionEvidencesByIds(ids: ArrayList<String>): ArrayList<ExecutionEvidencesPO> {
        if (ids.isEmpty()) {
            return ArrayList<ExecutionEvidencesPO>()
        }
        executor.setSql('''
            select id, agent_id, session_id, step_id, parent_step_id, step_type, input, output, duration_ms, side_effects, hash, creator, created_at, updated_at, deleted_at from execution_evidences where id ${IN(ids)}
        ''').list<ExecutionEvidencesPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的execution_evidences数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countExecutionEvidencesByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from execution_evidences where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有execution_evidences数量
     * @return 数量
     */
    func countAllExecutionEvidences(): Int64 {
        executor.setSql('''
            select count(*) from execution_evidences
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询execution_evidences列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findExecutionEvidencesByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<ExecutionEvidencesPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, session_id, step_id, parent_step_id, step_type, input, output, duration_ms, side_effects, hash, creator, created_at, updated_at, deleted_at from execution_evidences where 1=1")

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

        executor.page<ExecutionEvidencesPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除execution_evidences
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteExecutionEvidences(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update execution_evidences set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除execution_evidences
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteExecutionEvidences(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from execution_evidences where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询execution_evidences（支持完整查询操作符）
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
    func findExecutionEvidencesByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<ExecutionEvidencesPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, session_id, step_id, parent_step_id, step_type, input, output, duration_ms, side_effects, hash, creator, created_at, updated_at, deleted_at from execution_evidences")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<ExecutionEvidencesPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询execution_evidences
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findExecutionEvidencesByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<ExecutionEvidencesPO> {
        let fromClause = executor.FROM<ExecutionEvidencesPO>()

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
        fromClause.page<ExecutionEvidencesPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的execution_evidences）
     * @return 影响行数
     */
    func emptyRecycleBinExecutionEvidences(): Int64 {
        executor.setSql('''
            delete from execution_evidences where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
