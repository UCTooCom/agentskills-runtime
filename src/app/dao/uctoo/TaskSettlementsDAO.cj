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
import magic.app.models.uctoo.TaskSettlementsPO
import magic.log.LogUtils

/**
 * TaskSettlementsDAO - task_settlements数据访问接口
 *
 * 提供task_settlements表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface TaskSettlementsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入task_settlements（id由数据库自动生成UUID）
     * @param entity TaskSettlementsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertTaskSettlements(entity: TaskSettlementsPO): String {
        executor.setSql('''
            insert into task_settlements(
                task_id,
                settler_id,
                company_id,
                settlement_type,
                total_points,
                settlement_status,
                allocations,
                settled_at,
                remark,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.taskId)},
                ${arg(entity.settlerId)},
                ${arg(entity.companyId)},
                ${arg(entity.settlementType)},
                ${arg(entity.totalPoints)},
                ${arg(entity.settlementStatus)},
                ${arg(entity.allocations)},
                ${arg(entity.settledAt)},
                ${arg(entity.remark)},
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
     * 根据ID查询task_settlements
     * @param id task_settlementsID
     * @return task_settlements对象（Option类型）
     */
    func findTaskSettlementsById(id: String): Option<TaskSettlementsPO> {
        executor.setSql('''
            select id, task_id, settler_id, company_id, settlement_type, total_points, settlement_status, allocations, settled_at, remark, creator, created_at, updated_at, deleted_at from task_settlements where id = ${arg(id)}
        ''').first<TaskSettlementsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新task_settlements
     * @param entity task_settlements对象
     * @return 影响行数
     */
    func updateTaskSettlements(entity: TaskSettlementsPO): Int64 {
        executor.setSql('''
            update task_settlements set
                task_id = ${arg(entity.taskId)},
                settler_id = ${arg(entity.settlerId)},
                company_id = ${arg(entity.companyId)},
                settlement_type = ${arg(entity.settlementType)},
                total_points = ${arg(entity.totalPoints)},
                settlement_status = ${arg(entity.settlementStatus)},
                allocations = ${arg(entity.allocations)},
                settled_at = ${arg(entity.settledAt)},
                remark = ${arg(entity.remark)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除task_settlements
     * @param id task_settlementsID
     * @return 影响行数
     */
    func softDeleteTaskSettlementsById(id: String): Int64 {
        executor.setSql('''
            update task_settlements set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的task_settlements
     * @param id task_settlementsID
     * @return 影响行数
     */
    func restoreTaskSettlementsById(id: String): Int64 {
        executor.setSql('''
            update task_settlements set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除task_settlements
     * @param id task_settlementsID
     * @return 影响行数
     */
    func deleteTaskSettlementsById(id: String): Int64 {
        executor.setSql('''
            delete from task_settlements where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有task_settlements
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllTaskSettlementsPage(page: Int64, size: Int64): Pagination<TaskSettlementsPO> {
        executor.page<TaskSettlementsPO>('''
            select id, task_id, settler_id, company_id, settlement_type, total_points, settlement_status, allocations, settled_at, remark, creator, created_at, updated_at, deleted_at from task_settlements order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询task_settlements列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findTaskSettlementsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<TaskSettlementsPO> {
        executor.page<TaskSettlementsPO>('''
            select id, task_id, settler_id, company_id, settlement_type, total_points, settlement_status, allocations, settled_at, remark, creator, created_at, updated_at, deleted_at from task_settlements where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有task_settlements（不分页）
     * @return task_settlements列表
     */
    func listAllTaskSettlements(): ArrayList<TaskSettlementsPO> {
        executor.setSql('''
            select id, task_id, settler_id, company_id, settlement_type, total_points, settlement_status, allocations, settled_at, remark, creator, created_at, updated_at, deleted_at from task_settlements order by created_at desc
        ''').list<TaskSettlementsPO>()
    }

    /**
     * 批量查询task_settlements
     * @param ids ID列表
     * @return task_settlements列表
     */
    func findTaskSettlementsByIds(ids: ArrayList<String>): ArrayList<TaskSettlementsPO> {
        if (ids.isEmpty()) {
            return ArrayList<TaskSettlementsPO>()
        }
        executor.setSql('''
            select id, task_id, settler_id, company_id, settlement_type, total_points, settlement_status, allocations, settled_at, remark, creator, created_at, updated_at, deleted_at from task_settlements where id ${IN(ids)}
        ''').list<TaskSettlementsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的task_settlements数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countTaskSettlementsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from task_settlements where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有task_settlements数量
     * @return 数量
     */
    func countAllTaskSettlements(): Int64 {
        executor.setSql('''
            select count(*) from task_settlements
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询task_settlements列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findTaskSettlementsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<TaskSettlementsPO> {
        let sql = StringBuilder()
        sql.append("select id, task_id, settler_id, company_id, settlement_type, total_points, settlement_status, allocations, settled_at, remark, creator, created_at, updated_at, deleted_at from task_settlements where 1=1")

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

        executor.page<TaskSettlementsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除task_settlements
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteTaskSettlements(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update task_settlements set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除task_settlements
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteTaskSettlements(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from task_settlements where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询task_settlements（支持完整查询操作符）
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
    func findTaskSettlementsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<TaskSettlementsPO> {
        let sql = StringBuilder()
        sql.append("select id, task_id, settler_id, company_id, settlement_type, total_points, settlement_status, allocations, settled_at, remark, creator, created_at, updated_at, deleted_at from task_settlements")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<TaskSettlementsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询task_settlements
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findTaskSettlementsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<TaskSettlementsPO> {
        let fromClause = executor.FROM<TaskSettlementsPO>()

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
        fromClause.page<TaskSettlementsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的task_settlements）
     * @return 影响行数
     */
    func emptyRecycleBinTaskSettlements(): Int64 {
        executor.setSql('''
            delete from task_settlements where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
