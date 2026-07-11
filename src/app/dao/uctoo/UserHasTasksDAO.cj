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
import magic.app.models.uctoo.UserHasTasksPO
import magic.log.LogUtils

/**
 * UserHasTasksDAO - user_has_tasks数据访问接口
 *
 * 提供user_has_tasks表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UserHasTasksDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入user_has_tasks（id由数据库自动生成UUID）
     * @param entity UserHasTasksPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserHasTasks(entity: UserHasTasksPO): String {
        executor.setSql('''
            insert into user_has_tasks(
                user_id,
                task_id,
                relation_type,
                created_at,
                updated_at,
                deleted_at,
                creator,
                join_status,
                submission_content,
                submission_attachments,
                submitted_at,
                review_status,
                review_comment,
                reviewed_at,
                reviewer_id,
                allocation_ratio,
                points_earned,
                settled_at
            ) values(
${arg(entity.userId)},
                ${arg(entity.taskId)},
                ${arg(entity.relationType)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.creator)},
                ${arg(entity.joinStatus)},
                ${arg(entity.submissionContent)},
                ${arg(entity.submissionAttachments)},
                ${arg(entity.submittedAt)},
                ${arg(entity.reviewStatus)},
                ${arg(entity.reviewComment)},
                ${arg(entity.reviewedAt)},
                ${arg(entity.reviewerId)},
                ${arg(entity.allocationRatio)},
                ${arg(entity.pointsEarned)},
                ${arg(entity.settledAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询user_has_tasks
     * @param id user_has_tasksID
     * @return user_has_tasks对象（Option类型）
     */
    func findUserHasTasksById(id: String): Option<UserHasTasksPO> {
        executor.setSql('''
            select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks where id = ${arg(id)}
        ''').first<UserHasTasksPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新user_has_tasks
     * @param entity user_has_tasks对象
     * @return 影响行数
     */
    func updateUserHasTasks(entity: UserHasTasksPO): Int64 {
        executor.setSql('''
            update user_has_tasks set
                user_id = ${arg(entity.userId)},
                task_id = ${arg(entity.taskId)},
                relation_type = ${arg(entity.relationType)},
                deleted_at = ${arg(entity.deletedAt)},
                creator = ${arg(entity.creator)},
                join_status = ${arg(entity.joinStatus)},
                submission_content = ${arg(entity.submissionContent)},
                submission_attachments = ${arg(entity.submissionAttachments)},
                submitted_at = ${arg(entity.submittedAt)},
                review_status = ${arg(entity.reviewStatus)},
                review_comment = ${arg(entity.reviewComment)},
                reviewed_at = ${arg(entity.reviewedAt)},
                reviewer_id = ${arg(entity.reviewerId)},
                allocation_ratio = ${arg(entity.allocationRatio)},
                points_earned = ${arg(entity.pointsEarned)},
                settled_at = ${arg(entity.settledAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除user_has_tasks
     * @param id user_has_tasksID
     * @return 影响行数
     */
    func softDeleteUserHasTasksById(id: String): Int64 {
        executor.setSql('''
            update user_has_tasks set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的user_has_tasks
     * @param id user_has_tasksID
     * @return 影响行数
     */
    func restoreUserHasTasksById(id: String): Int64 {
        executor.setSql('''
            update user_has_tasks set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除user_has_tasks
     * @param id user_has_tasksID
     * @return 影响行数
     */
    func deleteUserHasTasksById(id: String): Int64 {
        executor.setSql('''
            delete from user_has_tasks where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有user_has_tasks
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserHasTasksPage(page: Int64, size: Int64): Pagination<UserHasTasksPO> {
        executor.page<UserHasTasksPO>('''
            select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询user_has_tasks列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasTasksByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserHasTasksPO> {
        executor.page<UserHasTasksPO>('''
            select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有user_has_tasks（不分页）
     * @return user_has_tasks列表
     */
    func listAllUserHasTasks(): ArrayList<UserHasTasksPO> {
        executor.setSql('''
            select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks order by created_at desc
        ''').list<UserHasTasksPO>()
    }

    /**
     * 批量查询user_has_tasks
     * @param ids ID列表
     * @return user_has_tasks列表
     */
    func findUserHasTasksByIds(ids: ArrayList<String>): ArrayList<UserHasTasksPO> {
        if (ids.isEmpty()) {
            return ArrayList<UserHasTasksPO>()
        }
        executor.setSql('''
            select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks where id ${IN(ids)}
        ''').list<UserHasTasksPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的user_has_tasks数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserHasTasksByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_tasks where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有user_has_tasks数量
     * @return 数量
     */
    func countAllUserHasTasks(): Int64 {
        executor.setSql('''
            select count(*) from user_has_tasks
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询user_has_tasks列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasTasksByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UserHasTasksPO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks where 1=1")

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

        executor.page<UserHasTasksPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除user_has_tasks
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUserHasTasks(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update user_has_tasks set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除user_has_tasks
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUserHasTasks(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from user_has_tasks where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询user_has_tasks（支持完整查询操作符）
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
    func findUserHasTasksByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasTasksPO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UserHasTasksPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询user_has_tasks
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasTasksByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasTasksPO> {
        let fromClause = executor.FROM<UserHasTasksPO>()

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
        fromClause.page<UserHasTasksPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的user_has_tasks）
     * @return 影响行数
     */
    func emptyRecycleBinUserHasTasks(): Int64 {
        executor.setSql('''
            delete from user_has_tasks where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 查询用户与任务的指定关系
     * @param userId 用户ID
     * @param taskId 任务ID
     * @param relationType 关系类型
     * @return 关系记录（若存在）
     */
    func findTaskRelation(userId: String, taskId: String, relationType: String): Option<UserHasTasksPO> {
        executor.setSql('''
            select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks
            where user_id = ${arg(userId)} and task_id = ${arg(taskId)} and relation_type = ${arg(relationType)} and deleted_at is null
        ''').first<UserHasTasksPO>()
    }

    /**
     * 判断用户是否关注了任务
     * @param userId 用户ID
     * @param taskId 任务ID
     * @return true=已关注
     */
    func isFollowing(userId: String, taskId: String): Bool {
        let count = executor.setSql('''
            select count(*) from user_has_tasks
            where user_id = ${arg(userId)} and task_id = ${arg(taskId)} and relation_type = 'follower' and deleted_at is null
        ''').first<Int64>() ?? 0
        count > 0
    }

    /**
     * 判断用户是否参与了任务（participant）
     * @param userId 用户ID
     * @param taskId 任务ID
     * @return true=已参与
     */
    func isParticipant(userId: String, taskId: String): Bool {
        let count = executor.setSql('''
            select count(*) from user_has_tasks
            where user_id = ${arg(userId)} and task_id = ${arg(taskId)} and relation_type = 'participant' and deleted_at is null
        ''').first<Int64>() ?? 0
        count > 0
    }

    /**
     * 查询任务的所有关注者（用于通知）
     * @param taskId 任务ID
     * @return 关注者关系列表
     */
    func findFollowersByTaskId(taskId: String): ArrayList<UserHasTasksPO> {
        executor.setSql('''
            select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks
            where task_id = ${arg(taskId)} and relation_type = 'follower' and deleted_at is null
        ''').list<UserHasTasksPO>()
    }

    /**
     * 查询任务的所有参与者（participant）
     * @param taskId 任务ID
     * @return 参与者关系列表
     */
    func findParticipantsByTaskId(taskId: String): ArrayList<UserHasTasksPO> {
        executor.setSql('''
            select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks
            where task_id = ${arg(taskId)} and relation_type = 'participant' and deleted_at is null
            order by created_at asc
        ''').list<UserHasTasksPO>()
    }

    /**
     * 分页查询用户某关系的任务关联
     * @param userId 用户ID
     * @param relationType 关系类型
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @return 分页结果
     */
    func findTasksByUserIdAndRelation(userId: String, relationType: String, page: Int64, pageSize: Int64): Pagination<UserHasTasksPO> {
        let sql = "select id, user_id, task_id, relation_type, created_at, updated_at, deleted_at, creator, join_status, submission_content, submission_attachments, submitted_at, review_status, review_comment, reviewed_at, reviewer_id, allocation_ratio, points_earned, settled_at from user_has_tasks where user_id = ${arg(userId)} and relation_type = ${arg(relationType)} and deleted_at is null order by created_at desc"
        executor.page<UserHasTasksPO>(sql, pageSize, page: page)
    }

    /**
     * 软删除用户与任务的指定关系
     * @param userId 用户ID
     * @param taskId 任务ID
     * @param relationType 关系类型
     * @return 影响行数
     */
    func softDeleteTaskRelation(userId: String, taskId: String, relationType: String): Int64 {
        executor.setSql('''
            update user_has_tasks set deleted_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())}
            where user_id = ${arg(userId)} and task_id = ${arg(taskId)} and relation_type = ${arg(relationType)} and deleted_at is null
        ''').update
    }

    /**
     * 更新承接者承接状态
     * @param id 关系记录ID
     * @param joinStatus 承接状态
     * @return 影响行数
     */
    func updateJoinStatus(id: String, joinStatus: String): Int64 {
        executor.setSql('''
            update user_has_tasks set join_status = ${arg(joinStatus)}, updated_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 承接者提交成果
     * @param id 关系记录ID
     * @param submissionContent 提交内容
     * @param submissionAttachments 提交附件（JSON字符串）
     * @return 影响行数
     */
    func submitWork(id: String, submissionContent: String, submissionAttachments: String): Int64 {
        executor.setSql('''
            update user_has_tasks set join_status = 'submitted', submission_content = ${arg(submissionContent)},
            submission_attachments = ${arg(submissionAttachments)}, submitted_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())}
            where id = ${arg(id)}
        ''').update
    }

    /**
     * 审核承接者提交
     * @param id 关系记录ID
     * @param reviewStatus 审核状态（approved/rejected）
     * @param reviewComment 审核评论
     * @param reviewerId 审核人ID
     * @return 影响行数
     */
    func reviewSubmission(id: String, reviewStatus: String, reviewComment: String, reviewerId: String): Int64 {
        executor.setSql('''
            update user_has_tasks set review_status = ${arg(reviewStatus)}, review_comment = ${arg(reviewComment)},
            reviewer_id = ${arg(reviewerId)}, reviewed_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())}
            where id = ${arg(id)}
        ''').update
    }

    /**
     * 设置分配比例和已结算积分（多人任务结算）
     * @param id 关系记录ID
     * @param allocationRatio 分配比例（0-100）
     * @param pointsEarned 获得积分
     * @return 影响行数
     */
    func updateAllocationAndPoints(id: String, allocationRatio: Int32, pointsEarned: Int64): Int64 {
        executor.setSql('''
            update user_has_tasks set allocation_ratio = ${arg(allocationRatio)}, points_earned = ${arg(pointsEarned)},
            join_status = 'completed', settled_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())}
            where id = ${arg(id)}
        ''').update
    }

    /**
     * 单人任务结算完成
     * @param id 关系记录ID
     * @param pointsEarned 获得积分
     * @return 影响行数
     */
    func settleSingleParticipant(id: String, pointsEarned: Int64): Int64 {
        executor.setSql('''
            update user_has_tasks set points_earned = ${arg(pointsEarned)}, join_status = 'completed',
            review_status = 'approved', settled_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())}
            where id = ${arg(id)}
        ''').update
    }

    /**
     * 统计任务已承接者数量
     * @param taskId 任务ID
     * @return 已承接者数量
     */
    func countParticipantsByTaskId(taskId: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_tasks
            where task_id = ${arg(taskId)} and relation_type = 'participant' and deleted_at is null
            and join_status in ('applied', 'accepted', 'submitted', 'approved', 'rejected')
        ''').first<Int64>() ?? 0
    }
}
