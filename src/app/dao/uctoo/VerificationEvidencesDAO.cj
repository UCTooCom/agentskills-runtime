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
import magic.app.models.uctoo.VerificationEvidencesPO
import magic.log.LogUtils

/**
 * VerificationEvidencesDAO - verification_evidences数据访问接口
 *
 * 提供verification_evidences表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface VerificationEvidencesDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入verification_evidences（id由数据库自动生成UUID）
     * @param entity VerificationEvidencesPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertVerificationEvidences(entity: VerificationEvidencesPO): String {
        executor.setSql('''
            insert into verification_evidences(
                agent_id,
                session_id,
                verification_type,
                scope,
                command,
                status,
                exit_code,
                output_summary,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.agentId)},
                ${arg(entity.sessionId)},
                ${arg(entity.verificationType)},
                ${arg(entity.scope)},
                ${arg(entity.command)},
                ${arg(entity.status)},
                ${arg(entity.exitCode)},
                ${arg(entity.outputSummary)},
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
     * 根据ID查询verification_evidences
     * @param id verification_evidencesID
     * @return verification_evidences对象（Option类型）
     */
    func findVerificationEvidencesById(id: String): Option<VerificationEvidencesPO> {
        executor.setSql('''
            select id, agent_id, session_id, verification_type, scope, command, status, exit_code, output_summary, creator, created_at, updated_at, deleted_at from verification_evidences where id = ${arg(id)}
        ''').first<VerificationEvidencesPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新verification_evidences
     * @param entity verification_evidences对象
     * @return 影响行数
     */
    func updateVerificationEvidences(entity: VerificationEvidencesPO): Int64 {
        executor.setSql('''
            update verification_evidences set
                agent_id = ${arg(entity.agentId)},
                session_id = ${arg(entity.sessionId)},
                verification_type = ${arg(entity.verificationType)},
                scope = ${arg(entity.scope)},
                command = ${arg(entity.command)},
                status = ${arg(entity.status)},
                exit_code = ${arg(entity.exitCode)},
                output_summary = ${arg(entity.outputSummary)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除verification_evidences
     * @param id verification_evidencesID
     * @return 影响行数
     */
    func softDeleteVerificationEvidencesById(id: String): Int64 {
        executor.setSql('''
            update verification_evidences set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的verification_evidences
     * @param id verification_evidencesID
     * @return 影响行数
     */
    func restoreVerificationEvidencesById(id: String): Int64 {
        executor.setSql('''
            update verification_evidences set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除verification_evidences
     * @param id verification_evidencesID
     * @return 影响行数
     */
    func deleteVerificationEvidencesById(id: String): Int64 {
        executor.setSql('''
            delete from verification_evidences where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有verification_evidences
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllVerificationEvidencesPage(page: Int64, size: Int64): Pagination<VerificationEvidencesPO> {
        executor.page<VerificationEvidencesPO>('''
            select id, agent_id, session_id, verification_type, scope, command, status, exit_code, output_summary, creator, created_at, updated_at, deleted_at from verification_evidences order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询verification_evidences列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findVerificationEvidencesByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<VerificationEvidencesPO> {
        executor.page<VerificationEvidencesPO>('''
            select id, agent_id, session_id, verification_type, scope, command, status, exit_code, output_summary, creator, created_at, updated_at, deleted_at from verification_evidences where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有verification_evidences（不分页）
     * @return verification_evidences列表
     */
    func listAllVerificationEvidences(): ArrayList<VerificationEvidencesPO> {
        executor.setSql('''
            select id, agent_id, session_id, verification_type, scope, command, status, exit_code, output_summary, creator, created_at, updated_at, deleted_at from verification_evidences order by created_at desc
        ''').list<VerificationEvidencesPO>()
    }

    /**
     * 批量查询verification_evidences
     * @param ids ID列表
     * @return verification_evidences列表
     */
    func findVerificationEvidencesByIds(ids: ArrayList<String>): ArrayList<VerificationEvidencesPO> {
        if (ids.isEmpty()) {
            return ArrayList<VerificationEvidencesPO>()
        }
        executor.setSql('''
            select id, agent_id, session_id, verification_type, scope, command, status, exit_code, output_summary, creator, created_at, updated_at, deleted_at from verification_evidences where id ${IN(ids)}
        ''').list<VerificationEvidencesPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的verification_evidences数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countVerificationEvidencesByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from verification_evidences where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有verification_evidences数量
     * @return 数量
     */
    func countAllVerificationEvidences(): Int64 {
        executor.setSql('''
            select count(*) from verification_evidences
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询verification_evidences列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findVerificationEvidencesByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<VerificationEvidencesPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, session_id, verification_type, scope, command, status, exit_code, output_summary, creator, created_at, updated_at, deleted_at from verification_evidences where 1=1")

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

        executor.page<VerificationEvidencesPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除verification_evidences
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteVerificationEvidences(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update verification_evidences set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除verification_evidences
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteVerificationEvidences(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from verification_evidences where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询verification_evidences（支持完整查询操作符）
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
    func findVerificationEvidencesByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<VerificationEvidencesPO> {
        let sql = StringBuilder()
        sql.append("select id, agent_id, session_id, verification_type, scope, command, status, exit_code, output_summary, creator, created_at, updated_at, deleted_at from verification_evidences")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<VerificationEvidencesPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询verification_evidences
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findVerificationEvidencesByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<VerificationEvidencesPO> {
        let fromClause = executor.FROM<VerificationEvidencesPO>()

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
        fromClause.page<VerificationEvidencesPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的verification_evidences）
     * @return 影响行数
     */
    func emptyRecycleBinVerificationEvidences(): Int64 {
        executor.setSql('''
            delete from verification_evidences where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
