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
import magic.app.models.uctoo.AttachmentsPO
import magic.log.LogUtils

/**
 * AttachmentsDAO - attachments数据访问接口
 *
 * 提供attachments表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface AttachmentsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入attachments（id由数据库自动生成UUID）
     * @param entity AttachmentsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertAttachments(entity: AttachmentsPO): String {
        executor.setSql('''
            insert into attachments(
                path,
                url,
                mime_type,
                file_ext,
                filesize,
                filename,
                driver,
                scene,
                type,
                sc_id,
                ai_task_id,
                created_at,
                updated_at,
                deleted_at,
                creator
            ) values(
${arg(entity.path)},
                ${arg(entity.url)},
                ${arg(entity.mimeType)},
                ${arg(entity.fileExt)},
                ${arg(entity.filesize)},
                ${arg(entity.filename)},
                ${arg(entity.driver)},
                ${arg(entity.scene)},
                ${arg(entity.typeVal)},
                ${arg(entity.scId)},
                ${arg(entity.aiTaskId)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.creator)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询attachments
     * @param id attachmentsID
     * @return attachments对象（Option类型）
     */
    func findAttachmentsById(id: String): Option<AttachmentsPO> {
        executor.setSql('''
            select id, path, url, mime_type, file_ext, filesize, filename, driver, scene, type, sc_id, ai_task_id, created_at, updated_at, deleted_at, creator from attachments where id = ${arg(id)}
        ''').first<AttachmentsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新attachments
     * @param entity attachments对象
     * @return 影响行数
     */
    func updateAttachments(entity: AttachmentsPO): Int64 {
        executor.setSql('''
            update attachments set
                path = ${arg(entity.path)},
                url = ${arg(entity.url)},
                mime_type = ${arg(entity.mimeType)},
                file_ext = ${arg(entity.fileExt)},
                filesize = ${arg(entity.filesize)},
                filename = ${arg(entity.filename)},
                driver = ${arg(entity.driver)},
                scene = ${arg(entity.scene)},
                type = ${arg(entity.typeVal)},
                sc_id = ${arg(entity.scId)},
                ai_task_id = ${arg(entity.aiTaskId)},
                deleted_at = ${arg(entity.deletedAt)},
                creator = ${arg(entity.creator)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除attachments
     * @param id attachmentsID
     * @return 影响行数
     */
    func softDeleteAttachmentsById(id: String): Int64 {
        executor.setSql('''
            update attachments set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的attachments
     * @param id attachmentsID
     * @return 影响行数
     */
    func restoreAttachmentsById(id: String): Int64 {
        executor.setSql('''
            update attachments set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除attachments
     * @param id attachmentsID
     * @return 影响行数
     */
    func deleteAttachmentsById(id: String): Int64 {
        executor.setSql('''
            delete from attachments where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有attachments
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllAttachmentsPage(page: Int64, size: Int64): Pagination<AttachmentsPO> {
        executor.page<AttachmentsPO>('''
            select id, path, url, mime_type, file_ext, filesize, filename, driver, scene, type, sc_id, ai_task_id, created_at, updated_at, deleted_at, creator from attachments order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询attachments列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAttachmentsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<AttachmentsPO> {
        executor.page<AttachmentsPO>('''
            select id, path, url, mime_type, file_ext, filesize, filename, driver, scene, type, sc_id, ai_task_id, created_at, updated_at, deleted_at, creator from attachments where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有attachments（不分页）
     * @return attachments列表
     */
    func listAllAttachments(): ArrayList<AttachmentsPO> {
        executor.setSql('''
            select id, path, url, mime_type, file_ext, filesize, filename, driver, scene, type, sc_id, ai_task_id, created_at, updated_at, deleted_at, creator from attachments order by created_at desc
        ''').list<AttachmentsPO>()
    }

    /**
     * 批量查询attachments
     * @param ids ID列表
     * @return attachments列表
     */
    func findAttachmentsByIds(ids: ArrayList<String>): ArrayList<AttachmentsPO> {
        if (ids.isEmpty()) {
            return ArrayList<AttachmentsPO>()
        }
        executor.setSql('''
            select id, path, url, mime_type, file_ext, filesize, filename, driver, scene, type, sc_id, ai_task_id, created_at, updated_at, deleted_at, creator from attachments where id ${IN(ids)}
        ''').list<AttachmentsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的attachments数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countAttachmentsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from attachments where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有attachments数量
     * @return 数量
     */
    func countAllAttachments(): Int64 {
        executor.setSql('''
            select count(*) from attachments
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询attachments列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAttachmentsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<AttachmentsPO> {
        let sql = StringBuilder()
        sql.append("select id, path, url, mime_type, file_ext, filesize, filename, driver, scene, type, sc_id, ai_task_id, created_at, updated_at, deleted_at, creator from attachments where 1=1")

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

        executor.page<AttachmentsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除attachments
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteAttachments(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update attachments set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除attachments
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteAttachments(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from attachments where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询attachments（支持完整查询操作符）
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
    func findAttachmentsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AttachmentsPO> {
        let sql = StringBuilder()
        sql.append("select id, path, url, mime_type, file_ext, filesize, filename, driver, scene, type, sc_id, ai_task_id, created_at, updated_at, deleted_at, creator from attachments")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<AttachmentsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询attachments
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAttachmentsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<AttachmentsPO> {
        let fromClause = executor.FROM<AttachmentsPO>()

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
        fromClause.page<AttachmentsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的attachments）
     * @return 影响行数
     */
    func emptyRecycleBinAttachments(): Int64 {
        executor.setSql('''
            delete from attachments where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
