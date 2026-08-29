/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.feedback

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.{ArrayList}
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}

/**
 * FeedbackDAO - feedback数据访问接口
 *
 * 提供feedback表的标准CRUD操作，遵循UCTOO V4 ORM规范。
 * 插件轨实现（plugingen 生成）：与 PO 同包，无跨包 import。
 */
@DAO
public interface FeedbackDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入feedback（id由数据库自动生成UUID）
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertFeedback(entity: FeedbackPO): String {
        executor.setSql('''
            insert into feedback(
                user_id,
                type,
                content,
                images,
                phone,
                remark,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.userId)},
                ${arg(entity.feedbackType)},
                ${arg(entity.content)},
                ${arg(entity.images)},
                ${arg(entity.phone)},
                ${arg(entity.remark)},
                ${arg(entity.status)},
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
     * 根据ID查询feedback
     */
    func findFeedbackById(id: String): Option<FeedbackPO> {
        executor.setSql('''
            select id, user_id, type, content, images, phone, remark, status, creator, created_at, updated_at, deleted_at from feedback where id = ${arg(id)}
        ''').first<FeedbackPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新feedback
     * @return 影响行数
     */
    func updateFeedback(entity: FeedbackPO): Int64 {
        executor.setSql('''
            update feedback set
                user_id = ${arg(entity.userId)},
                type = ${arg(entity.feedbackType)},
                content = ${arg(entity.content)},
                images = ${arg(entity.images)},
                phone = ${arg(entity.phone)},
                remark = ${arg(entity.remark)},
                status = ${arg(entity.status)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除feedback
     */
    func softDeleteFeedbackById(id: String): Int64 {
        executor.setSql('''
            update feedback set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的feedback
     */
    func restoreFeedbackById(id: String): Int64 {
        executor.setSql('''
            update feedback set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除feedback
     */
    func deleteFeedbackById(id: String): Int64 {
        executor.setSql('''
            delete from feedback where id = ${arg(id)}
        ''').delete
    }

    /**
     * 批量软删除feedback
     */
    func batchSoftDeleteFeedback(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update feedback set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除feedback
     */
    func batchDeleteFeedback(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from feedback where id ${IN(ids)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有feedback
     */
    func findAllFeedbackPage(page: Int64, size: Int64): Pagination<FeedbackPO> {
        executor.page<FeedbackPO>('''
            select id, user_id, type, content, images, phone, remark, status, creator, created_at, updated_at, deleted_at from feedback order by created_at desc
        ''', size, page: page)
    }

    /**
     * 批量查询feedback
     */
    func findFeedbackByIds(ids: ArrayList<String>): ArrayList<FeedbackPO> {
        if (ids.isEmpty()) {
            return ArrayList<FeedbackPO>()
        }
        executor.setSql('''
            select id, user_id, type, content, images, phone, remark, status, creator, created_at, updated_at, deleted_at from feedback where id ${IN(ids)}
        ''').list<FeedbackPO>()
    }

    /**
     * 动态条件分页查询feedback（Prisma 风格 filter/sort 构建轨）
     */
    func findFeedbackByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<FeedbackPO> {
        let fromClause = executor.FROM<FeedbackPO>()

        if (!whereClause.isEmpty()) {
            fromClause.WHERE(whereClause)
        }

        if (!orderByClause.isEmpty()) {
            fromClause.ORDER_BY { => orderByClause }
        } else {
            fromClause.ORDER_BY { => "created_at DESC" }
        }

        fromClause.page<FeedbackPO>(size, page: page)
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的feedback数量
     */
    func countFeedbackByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from feedback where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有feedback数量
     */
    func countAllFeedback(): Int64 {
        executor.setSql('''
            select count(*) from feedback
        ''').first<Int64>() ?? 0
    }

    /**
     * 清空回收站（硬删除所有已软删除的feedback）
     * @return 影响行数
     */
    func emptyRecycleBinFeedback(): Int64 {
        executor.setSql('''
            delete from feedback where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
