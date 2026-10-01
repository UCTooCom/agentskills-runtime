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
import magic.app.models.uctoo.LrtVerifyJobPO
import magic.log.LogUtils

/**
 * LrtVerifyJobDAO - lrt_verify_job数据访问接口
 *
 * 提供lrt_verify_job表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface LrtVerifyJobDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入lrt_verify_job（id由数据库自动生成UUID）
     * @param entity LrtVerifyJobPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertLrtVerifyJob(entity: LrtVerifyJobPO): String {
        executor.setSql('''
            insert into lrt_verify_job(
                task_id,
                round,
                status,
                result,
                creator,
                owner_user_id,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.taskId)},
                ${arg(entity.round)},
                ${arg(entity.status)},
                ${arg(entity.result)},
                ${arg(entity.creator)},
                ${arg(entity.ownerUserId)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询lrt_verify_job
     * @param id lrt_verify_jobID
     * @return lrt_verify_job对象（Option类型）
     */
    func findLrtVerifyJobById(id: String): Option<LrtVerifyJobPO> {
        executor.setSql('''
            select id, task_id, round, status, result, creator, owner_user_id, created_at, updated_at, deleted_at from lrt_verify_job where id = ${arg(id)}
        ''').first<LrtVerifyJobPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新lrt_verify_job
     * @param entity lrt_verify_job对象
     * @return 影响行数
     */
    func updateLrtVerifyJob(entity: LrtVerifyJobPO): Int64 {
        executor.setSql('''
            update lrt_verify_job set
                task_id = ${arg(entity.taskId)},
                round = ${arg(entity.round)},
                status = ${arg(entity.status)},
                result = ${arg(entity.result)},
                creator = ${arg(entity.creator)},
                owner_user_id = ${arg(entity.ownerUserId)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除lrt_verify_job
     * @param id lrt_verify_jobID
     * @return 影响行数
     */
    func softDeleteLrtVerifyJobById(id: String): Int64 {
        executor.setSql('''
            update lrt_verify_job set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的lrt_verify_job
     * @param id lrt_verify_jobID
     * @return 影响行数
     */
    func restoreLrtVerifyJobById(id: String): Int64 {
        executor.setSql('''
            update lrt_verify_job set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除lrt_verify_job
     * @param id lrt_verify_jobID
     * @return 影响行数
     */
    func deleteLrtVerifyJobById(id: String): Int64 {
        executor.setSql('''
            delete from lrt_verify_job where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有lrt_verify_job
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllLrtVerifyJobPage(page: Int64, size: Int64): Pagination<LrtVerifyJobPO> {
        executor.page<LrtVerifyJobPO>('''
            select id, task_id, round, status, result, creator, owner_user_id, created_at, updated_at, deleted_at from lrt_verify_job order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询lrt_verify_job列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLrtVerifyJobByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<LrtVerifyJobPO> {
        executor.page<LrtVerifyJobPO>('''
            select id, task_id, round, status, result, creator, owner_user_id, created_at, updated_at, deleted_at from lrt_verify_job where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有lrt_verify_job（不分页）
     * @return lrt_verify_job列表
     */
    func listAllLrtVerifyJob(): ArrayList<LrtVerifyJobPO> {
        executor.setSql('''
            select id, task_id, round, status, result, creator, owner_user_id, created_at, updated_at, deleted_at from lrt_verify_job order by created_at desc
        ''').list<LrtVerifyJobPO>()
    }

    /**
     * 批量查询lrt_verify_job
     * @param ids ID列表
     * @return lrt_verify_job列表
     */
    func findLrtVerifyJobByIds(ids: ArrayList<String>): ArrayList<LrtVerifyJobPO> {
        if (ids.isEmpty()) {
            return ArrayList<LrtVerifyJobPO>()
        }
        executor.setSql('''
            select id, task_id, round, status, result, creator, owner_user_id, created_at, updated_at, deleted_at from lrt_verify_job where id ${IN(ids)}
        ''').list<LrtVerifyJobPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的lrt_verify_job数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countLrtVerifyJobByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from lrt_verify_job where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有lrt_verify_job数量
     * @return 数量
     */
    func countAllLrtVerifyJob(): Int64 {
        executor.setSql('''
            select count(*) from lrt_verify_job
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询lrt_verify_job列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLrtVerifyJobByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<LrtVerifyJobPO> {
        let sql = StringBuilder()
        sql.append("select id, task_id, round, status, result, creator, owner_user_id, created_at, updated_at, deleted_at from lrt_verify_job where 1=1")

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

        executor.page<LrtVerifyJobPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除lrt_verify_job
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteLrtVerifyJob(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update lrt_verify_job set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除lrt_verify_job
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteLrtVerifyJob(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from lrt_verify_job where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询lrt_verify_job（支持完整查询操作符）
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
    func findLrtVerifyJobByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LrtVerifyJobPO> {
        let sql = StringBuilder()
        sql.append("select id, task_id, round, status, result, creator, owner_user_id, created_at, updated_at, deleted_at from lrt_verify_job")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<LrtVerifyJobPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询lrt_verify_job
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findLrtVerifyJobByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<LrtVerifyJobPO> {
        let fromClause = executor.FROM<LrtVerifyJobPO>()

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
        fromClause.page<LrtVerifyJobPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的lrt_verify_job）
     * @return 影响行数
     */
    func emptyRecycleBinLrtVerifyJob(): Int64 {
        executor.setSql('''
            delete from lrt_verify_job where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
