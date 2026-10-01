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
import magic.app.models.uctoo.SddProjectsPO
import magic.log.LogUtils

/**
 * SddProjectsDAO - sdd_projects数据访问接口
 *
 * 提供sdd_projects表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface SddProjectsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入sdd_projects（id由数据库自动生成UUID）
     * @param entity SddProjectsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertSddProjects(entity: SddProjectsPO): String {
        executor.setSql('''
            insert into sdd_projects(
                feature_name,
                title,
                task_id,
                current_stage,
                status,
                enable_research,
                round,
                payload,
                creator,
                owner_user_id,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.featureName)},
                ${arg(entity.title)},
                ${arg(entity.taskId)},
                ${arg(entity.currentStage)},
                ${arg(entity.status)},
                ${arg(entity.enableResearch)},
                ${arg(entity.round)},
                ${arg(entity.payload)},
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
     * 根据ID查询sdd_projects
     * @param id sdd_projectsID
     * @return sdd_projects对象（Option类型）
     */
    func findSddProjectsById(id: String): Option<SddProjectsPO> {
        executor.setSql('''
            select id, feature_name, title, task_id, current_stage, status, enable_research, round, payload, creator, owner_user_id, created_at, updated_at, deleted_at from sdd_projects where id = ${arg(id)}
        ''').first<SddProjectsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新sdd_projects
     * @param entity sdd_projects对象
     * @return 影响行数
     */
    func updateSddProjects(entity: SddProjectsPO): Int64 {
        executor.setSql('''
            update sdd_projects set
                feature_name = ${arg(entity.featureName)},
                title = ${arg(entity.title)},
                task_id = ${arg(entity.taskId)},
                current_stage = ${arg(entity.currentStage)},
                status = ${arg(entity.status)},
                enable_research = ${arg(entity.enableResearch)},
                round = ${arg(entity.round)},
                payload = ${arg(entity.payload)},
                creator = ${arg(entity.creator)},
                owner_user_id = ${arg(entity.ownerUserId)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除sdd_projects
     * @param id sdd_projectsID
     * @return 影响行数
     */
    func softDeleteSddProjectsById(id: String): Int64 {
        executor.setSql('''
            update sdd_projects set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的sdd_projects
     * @param id sdd_projectsID
     * @return 影响行数
     */
    func restoreSddProjectsById(id: String): Int64 {
        executor.setSql('''
            update sdd_projects set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除sdd_projects
     * @param id sdd_projectsID
     * @return 影响行数
     */
    func deleteSddProjectsById(id: String): Int64 {
        executor.setSql('''
            delete from sdd_projects where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有sdd_projects
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllSddProjectsPage(page: Int64, size: Int64): Pagination<SddProjectsPO> {
        executor.page<SddProjectsPO>('''
            select id, feature_name, title, task_id, current_stage, status, enable_research, round, payload, creator, owner_user_id, created_at, updated_at, deleted_at from sdd_projects order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询sdd_projects列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSddProjectsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<SddProjectsPO> {
        executor.page<SddProjectsPO>('''
            select id, feature_name, title, task_id, current_stage, status, enable_research, round, payload, creator, owner_user_id, created_at, updated_at, deleted_at from sdd_projects where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有sdd_projects（不分页）
     * @return sdd_projects列表
     */
    func listAllSddProjects(): ArrayList<SddProjectsPO> {
        executor.setSql('''
            select id, feature_name, title, task_id, current_stage, status, enable_research, round, payload, creator, owner_user_id, created_at, updated_at, deleted_at from sdd_projects order by created_at desc
        ''').list<SddProjectsPO>()
    }

    /**
     * 批量查询sdd_projects
     * @param ids ID列表
     * @return sdd_projects列表
     */
    func findSddProjectsByIds(ids: ArrayList<String>): ArrayList<SddProjectsPO> {
        if (ids.isEmpty()) {
            return ArrayList<SddProjectsPO>()
        }
        executor.setSql('''
            select id, feature_name, title, task_id, current_stage, status, enable_research, round, payload, creator, owner_user_id, created_at, updated_at, deleted_at from sdd_projects where id ${IN(ids)}
        ''').list<SddProjectsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的sdd_projects数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countSddProjectsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from sdd_projects where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有sdd_projects数量
     * @return 数量
     */
    func countAllSddProjects(): Int64 {
        executor.setSql('''
            select count(*) from sdd_projects
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询sdd_projects列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSddProjectsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<SddProjectsPO> {
        let sql = StringBuilder()
        sql.append("select id, feature_name, title, task_id, current_stage, status, enable_research, round, payload, creator, owner_user_id, created_at, updated_at, deleted_at from sdd_projects where 1=1")

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

        executor.page<SddProjectsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除sdd_projects
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteSddProjects(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update sdd_projects set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除sdd_projects
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteSddProjects(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from sdd_projects where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询sdd_projects（支持完整查询操作符）
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
    func findSddProjectsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SddProjectsPO> {
        let sql = StringBuilder()
        sql.append("select id, feature_name, title, task_id, current_stage, status, enable_research, round, payload, creator, owner_user_id, created_at, updated_at, deleted_at from sdd_projects")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<SddProjectsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询sdd_projects
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSddProjectsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SddProjectsPO> {
        let fromClause = executor.FROM<SddProjectsPO>()

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
        fromClause.page<SddProjectsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的sdd_projects）
     * @return 影响行数
     */
    func emptyRecycleBinSddProjects(): Int64 {
        executor.setSql('''
            delete from sdd_projects where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
