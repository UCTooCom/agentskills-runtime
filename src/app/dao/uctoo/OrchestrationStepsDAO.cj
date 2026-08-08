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
import magic.app.models.uctoo.OrchestrationStepsPO
import magic.log.LogUtils

/**
 * OrchestrationStepsDAO - orchestration_steps数据访问接口
 *
 * 提供orchestration_steps表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface OrchestrationStepsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入orchestration_steps（id由数据库自动生成UUID）
     * @param entity OrchestrationStepsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertOrchestrationSteps(entity: OrchestrationStepsPO): String {
        executor.setSql('''
            insert into orchestration_steps(
                plan_id,
                step_name,
                step_type,
                target_ref,
                input_mapping,
                condition,
                depends_on,
                status,
                result,
                side_effects,
                started_at,
                completed_at,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.planId)},
                ${arg(entity.stepName)},
                ${arg(entity.stepType)},
                ${arg(entity.targetRef)},
                ${arg(entity.inputMapping)},
                ${arg(entity.condition)},
                ${arg(entity.dependsOn)},
                ${arg(entity.status)},
                ${arg(entity.result)},
                ${arg(entity.sideEffects)},
                ${arg(entity.startedAt)},
                ${arg(entity.completedAt)},
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
     * 根据ID查询orchestration_steps
     * @param id orchestration_stepsID
     * @return orchestration_steps对象（Option类型）
     */
    func findOrchestrationStepsById(id: String): Option<OrchestrationStepsPO> {
        executor.setSql('''
            select id, plan_id, step_name, step_type, target_ref, input_mapping, condition, depends_on, status, result, side_effects, started_at, completed_at, creator, created_at, updated_at, deleted_at from orchestration_steps where id = ${arg(id)}
        ''').first<OrchestrationStepsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新orchestration_steps
     * @param entity orchestration_steps对象
     * @return 影响行数
     */
    func updateOrchestrationSteps(entity: OrchestrationStepsPO): Int64 {
        executor.setSql('''
            update orchestration_steps set
                plan_id = ${arg(entity.planId)},
                step_name = ${arg(entity.stepName)},
                step_type = ${arg(entity.stepType)},
                target_ref = ${arg(entity.targetRef)},
                input_mapping = ${arg(entity.inputMapping)},
                condition = ${arg(entity.condition)},
                depends_on = ${arg(entity.dependsOn)},
                status = ${arg(entity.status)},
                result = ${arg(entity.result)},
                side_effects = ${arg(entity.sideEffects)},
                started_at = ${arg(entity.startedAt)},
                completed_at = ${arg(entity.completedAt)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除orchestration_steps
     * @param id orchestration_stepsID
     * @return 影响行数
     */
    func softDeleteOrchestrationStepsById(id: String): Int64 {
        executor.setSql('''
            update orchestration_steps set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的orchestration_steps
     * @param id orchestration_stepsID
     * @return 影响行数
     */
    func restoreOrchestrationStepsById(id: String): Int64 {
        executor.setSql('''
            update orchestration_steps set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除orchestration_steps
     * @param id orchestration_stepsID
     * @return 影响行数
     */
    func deleteOrchestrationStepsById(id: String): Int64 {
        executor.setSql('''
            delete from orchestration_steps where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有orchestration_steps
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllOrchestrationStepsPage(page: Int64, size: Int64): Pagination<OrchestrationStepsPO> {
        executor.page<OrchestrationStepsPO>('''
            select id, plan_id, step_name, step_type, target_ref, input_mapping, condition, depends_on, status, result, side_effects, started_at, completed_at, creator, created_at, updated_at, deleted_at from orchestration_steps order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询orchestration_steps列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findOrchestrationStepsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<OrchestrationStepsPO> {
        executor.page<OrchestrationStepsPO>('''
            select id, plan_id, step_name, step_type, target_ref, input_mapping, condition, depends_on, status, result, side_effects, started_at, completed_at, creator, created_at, updated_at, deleted_at from orchestration_steps where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有orchestration_steps（不分页）
     * @return orchestration_steps列表
     */
    func listAllOrchestrationSteps(): ArrayList<OrchestrationStepsPO> {
        executor.setSql('''
            select id, plan_id, step_name, step_type, target_ref, input_mapping, condition, depends_on, status, result, side_effects, started_at, completed_at, creator, created_at, updated_at, deleted_at from orchestration_steps order by created_at desc
        ''').list<OrchestrationStepsPO>()
    }

    /**
     * 批量查询orchestration_steps
     * @param ids ID列表
     * @return orchestration_steps列表
     */
    func findOrchestrationStepsByIds(ids: ArrayList<String>): ArrayList<OrchestrationStepsPO> {
        if (ids.isEmpty()) {
            return ArrayList<OrchestrationStepsPO>()
        }
        executor.setSql('''
            select id, plan_id, step_name, step_type, target_ref, input_mapping, condition, depends_on, status, result, side_effects, started_at, completed_at, creator, created_at, updated_at, deleted_at from orchestration_steps where id ${IN(ids)}
        ''').list<OrchestrationStepsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的orchestration_steps数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countOrchestrationStepsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from orchestration_steps where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有orchestration_steps数量
     * @return 数量
     */
    func countAllOrchestrationSteps(): Int64 {
        executor.setSql('''
            select count(*) from orchestration_steps
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询orchestration_steps列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findOrchestrationStepsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<OrchestrationStepsPO> {
        let sql = StringBuilder()
        sql.append("select id, plan_id, step_name, step_type, target_ref, input_mapping, condition, depends_on, status, result, side_effects, started_at, completed_at, creator, created_at, updated_at, deleted_at from orchestration_steps where 1=1")

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

        executor.page<OrchestrationStepsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除orchestration_steps
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteOrchestrationSteps(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update orchestration_steps set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除orchestration_steps
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteOrchestrationSteps(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from orchestration_steps where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询orchestration_steps（支持完整查询操作符）
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
    func findOrchestrationStepsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<OrchestrationStepsPO> {
        let sql = StringBuilder()
        sql.append("select id, plan_id, step_name, step_type, target_ref, input_mapping, condition, depends_on, status, result, side_effects, started_at, completed_at, creator, created_at, updated_at, deleted_at from orchestration_steps")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<OrchestrationStepsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询orchestration_steps
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findOrchestrationStepsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<OrchestrationStepsPO> {
        let fromClause = executor.FROM<OrchestrationStepsPO>()

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
        fromClause.page<OrchestrationStepsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的orchestration_steps）
     * @return 影响行数
     */
    func emptyRecycleBinOrchestrationSteps(): Int64 {
        executor.setSql('''
            delete from orchestration_steps where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
