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
import magic.app.models.uctoo.SkillCompositionsPO
import magic.log.LogUtils

/**
 * SkillCompositionsDAO - skill_compositions数据访问接口
 *
 * 提供skill_compositions表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface SkillCompositionsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入skill_compositions（id由数据库自动生成UUID）
     * @param entity SkillCompositionsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertSkillCompositions(entity: SkillCompositionsPO): String {
        executor.setSql('''
            insert into skill_compositions(
                name,
                description,
                definition,
                source_path,
                template_ref,
                is_template,
                sync_status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.name)},
                ${arg(entity.description)},
                ${arg(entity.definition)},
                ${arg(entity.sourcePath)},
                ${arg(entity.templateRef)},
                ${arg(entity.isTemplate)},
                ${arg(entity.syncStatus)},
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
     * 根据ID查询skill_compositions
     * @param id skill_compositionsID
     * @return skill_compositions对象（Option类型）
     */
    func findSkillCompositionsById(id: String): Option<SkillCompositionsPO> {
        executor.setSql('''
            select id, name, description, definition, source_path, template_ref, is_template, sync_status, creator, created_at, updated_at, deleted_at from skill_compositions where id = ${arg(id)}
        ''').first<SkillCompositionsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新skill_compositions
     * @param entity skill_compositions对象
     * @return 影响行数
     */
    func updateSkillCompositions(entity: SkillCompositionsPO): Int64 {
        executor.setSql('''
            update skill_compositions set
                name = ${arg(entity.name)},
                description = ${arg(entity.description)},
                definition = ${arg(entity.definition)},
                source_path = ${arg(entity.sourcePath)},
                template_ref = ${arg(entity.templateRef)},
                is_template = ${arg(entity.isTemplate)},
                sync_status = ${arg(entity.syncStatus)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除skill_compositions
     * @param id skill_compositionsID
     * @return 影响行数
     */
    func softDeleteSkillCompositionsById(id: String): Int64 {
        executor.setSql('''
            update skill_compositions set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的skill_compositions
     * @param id skill_compositionsID
     * @return 影响行数
     */
    func restoreSkillCompositionsById(id: String): Int64 {
        executor.setSql('''
            update skill_compositions set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除skill_compositions
     * @param id skill_compositionsID
     * @return 影响行数
     */
    func deleteSkillCompositionsById(id: String): Int64 {
        executor.setSql('''
            delete from skill_compositions where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有skill_compositions
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllSkillCompositionsPage(page: Int64, size: Int64): Pagination<SkillCompositionsPO> {
        executor.page<SkillCompositionsPO>('''
            select id, name, description, definition, source_path, template_ref, is_template, sync_status, creator, created_at, updated_at, deleted_at from skill_compositions order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询skill_compositions列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSkillCompositionsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<SkillCompositionsPO> {
        executor.page<SkillCompositionsPO>('''
            select id, name, description, definition, source_path, template_ref, is_template, sync_status, creator, created_at, updated_at, deleted_at from skill_compositions where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有skill_compositions（不分页）
     * @return skill_compositions列表
     */
    func listAllSkillCompositions(): ArrayList<SkillCompositionsPO> {
        executor.setSql('''
            select id, name, description, definition, source_path, template_ref, is_template, sync_status, creator, created_at, updated_at, deleted_at from skill_compositions order by created_at desc
        ''').list<SkillCompositionsPO>()
    }

    /**
     * 批量查询skill_compositions
     * @param ids ID列表
     * @return skill_compositions列表
     */
    func findSkillCompositionsByIds(ids: ArrayList<String>): ArrayList<SkillCompositionsPO> {
        if (ids.isEmpty()) {
            return ArrayList<SkillCompositionsPO>()
        }
        executor.setSql('''
            select id, name, description, definition, source_path, template_ref, is_template, sync_status, creator, created_at, updated_at, deleted_at from skill_compositions where id ${IN(ids)}
        ''').list<SkillCompositionsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的skill_compositions数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countSkillCompositionsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from skill_compositions where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有skill_compositions数量
     * @return 数量
     */
    func countAllSkillCompositions(): Int64 {
        executor.setSql('''
            select count(*) from skill_compositions
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询skill_compositions列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSkillCompositionsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<SkillCompositionsPO> {
        let sql = StringBuilder()
        sql.append("select id, name, description, definition, source_path, template_ref, is_template, sync_status, creator, created_at, updated_at, deleted_at from skill_compositions where 1=1")

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

        executor.page<SkillCompositionsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除skill_compositions
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteSkillCompositions(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update skill_compositions set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除skill_compositions
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteSkillCompositions(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from skill_compositions where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询skill_compositions（支持完整查询操作符）
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
    func findSkillCompositionsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SkillCompositionsPO> {
        let sql = StringBuilder()
        sql.append("select id, name, description, definition, source_path, template_ref, is_template, sync_status, creator, created_at, updated_at, deleted_at from skill_compositions")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<SkillCompositionsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询skill_compositions
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findSkillCompositionsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<SkillCompositionsPO> {
        let fromClause = executor.FROM<SkillCompositionsPO>()

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
        fromClause.page<SkillCompositionsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的skill_compositions）
     * @return 影响行数
     */
    func emptyRecycleBinSkillCompositions(): Int64 {
        executor.setSql('''
            delete from skill_compositions where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
