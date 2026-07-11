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
import magic.app.models.uctoo.TasksPO
import magic.log.LogUtils

/**
 * TasksDAO - tasks数据访问接口
 *
 * 提供tasks表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface TasksDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入tasks（id由数据库自动生成UUID）
     * @param entity TasksPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertTasks(entity: TasksPO): String {
        executor.setSql('''
            insert into tasks(
                title,
                description,
                task_type,
                task_status,
                priority,
                company_id,
                creator_id,
                assignee_id,
                participant_count,
                follower_count,
                view_count,
                comment_count,
                reward_type,
                reward_amount,
                deadline,
                started_at,
                completed_at,
                tags,
                skills_required,
                attachments,
                extra_data,
                creator,
                created_at,
                updated_at,
                deleted_at,
                reward_points,
                max_participants,
                accept_deadline,
                settlement_status,
                points_frozen,
                points_settled,
                points_refunded,
                review_status
            ) values(
${arg(entity.title)},
                ${arg(entity.description)},
                ${arg(entity.taskType)},
                ${arg(entity.taskStatus)},
                ${arg(entity.priority)},
                ${arg(entity.companyId)},
                ${arg(entity.creatorId)},
                ${arg(entity.assigneeId)},
                ${arg(entity.participantCount)},
                ${arg(entity.followerCount)},
                ${arg(entity.viewCount)},
                ${arg(entity.commentCount)},
                ${arg(entity.rewardType)},
                ${arg(entity.rewardAmount)},
                ${arg(entity.deadline)},
                ${arg(entity.startedAt)},
                ${arg(entity.completedAt)},
                ${arg(entity.tags)},
                ${arg(entity.skillsRequired)},
                ${arg(entity.attachments)},
                ${arg(entity.extraData)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.rewardPoints)},
                ${arg(entity.maxParticipants)},
                ${arg(entity.acceptDeadline)},
                ${arg(entity.settlementStatus)},
                ${arg(entity.pointsFrozen)},
                ${arg(entity.pointsSettled)},
                ${arg(entity.pointsRefunded)},
                ${arg(entity.reviewStatus)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询tasks
     * @param id tasksID
     * @return tasks对象（Option类型）
     */
    func findTasksById(id: String): Option<TasksPO> {
        executor.setSql('''
            select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks where id = ${arg(id)}
        ''').first<TasksPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新tasks
     * @param entity tasks对象
     * @return 影响行数
     */
    func updateTasks(entity: TasksPO): Int64 {
        executor.setSql('''
            update tasks set
                title = ${arg(entity.title)},
                description = ${arg(entity.description)},
                task_type = ${arg(entity.taskType)},
                task_status = ${arg(entity.taskStatus)},
                priority = ${arg(entity.priority)},
                company_id = ${arg(entity.companyId)},
                creator_id = ${arg(entity.creatorId)},
                assignee_id = ${arg(entity.assigneeId)},
                participant_count = ${arg(entity.participantCount)},
                follower_count = ${arg(entity.followerCount)},
                view_count = ${arg(entity.viewCount)},
                comment_count = ${arg(entity.commentCount)},
                reward_type = ${arg(entity.rewardType)},
                reward_amount = ${arg(entity.rewardAmount)},
                deadline = ${arg(entity.deadline)},
                started_at = ${arg(entity.startedAt)},
                completed_at = ${arg(entity.completedAt)},
                tags = ${arg(entity.tags)},
                skills_required = ${arg(entity.skillsRequired)},
                attachments = ${arg(entity.attachments)},
                extra_data = ${arg(entity.extraData)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                reward_points = ${arg(entity.rewardPoints)},
                max_participants = ${arg(entity.maxParticipants)},
                accept_deadline = ${arg(entity.acceptDeadline)},
                settlement_status = ${arg(entity.settlementStatus)},
                points_frozen = ${arg(entity.pointsFrozen)},
                points_settled = ${arg(entity.pointsSettled)},
                points_refunded = ${arg(entity.pointsRefunded)},
                review_status = ${arg(entity.reviewStatus)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除tasks
     * @param id tasksID
     * @return 影响行数
     */
    func softDeleteTasksById(id: String): Int64 {
        executor.setSql('''
            update tasks set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的tasks
     * @param id tasksID
     * @return 影响行数
     */
    func restoreTasksById(id: String): Int64 {
        executor.setSql('''
            update tasks set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除tasks
     * @param id tasksID
     * @return 影响行数
     */
    func deleteTasksById(id: String): Int64 {
        executor.setSql('''
            delete from tasks where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有tasks
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllTasksPage(page: Int64, size: Int64): Pagination<TasksPO> {
        executor.page<TasksPO>('''
            select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询tasks列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findTasksByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<TasksPO> {
        executor.page<TasksPO>('''
            select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有tasks（不分页）
     * @return tasks列表
     */
    func listAllTasks(): ArrayList<TasksPO> {
        executor.setSql('''
            select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks order by created_at desc
        ''').list<TasksPO>()
    }

    /**
     * 批量查询tasks
     * @param ids ID列表
     * @return tasks列表
     */
    func findTasksByIds(ids: ArrayList<String>): ArrayList<TasksPO> {
        if (ids.isEmpty()) {
            return ArrayList<TasksPO>()
        }
        executor.setSql('''
            select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks where id ${IN(ids)}
        ''').list<TasksPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的tasks数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countTasksByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from tasks where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有tasks数量
     * @return 数量
     */
    func countAllTasks(): Int64 {
        executor.setSql('''
            select count(*) from tasks
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询tasks列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findTasksByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<TasksPO> {
        let sql = StringBuilder()
        sql.append("select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks where 1=1")

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

        executor.page<TasksPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除tasks
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteTasks(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update tasks set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除tasks
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteTasks(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from tasks where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询tasks（支持完整查询操作符）
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
    func findTasksByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<TasksPO> {
        let sql = StringBuilder()
        sql.append("select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<TasksPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询tasks
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findTasksByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<TasksPO> {
        let fromClause = executor.FROM<TasksPO>()

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
        fromClause.page<TasksPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的tasks）
     * @return 影响行数
     */
    func emptyRecycleBinTasks(): Int64 {
        executor.setSql('''
            delete from tasks where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 公开任务分页查询（支持筛选和排序）
     * 仅返回未软删除的任务
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param taskType 任务类型筛选（空字符串表示不筛选）
     * @param taskStatus 任务状态筛选（空字符串表示不筛选）
     * @param priority 优先级筛选（空字符串表示不筛选）
     * @param companyId 组织ID筛选（空字符串表示不筛选）
     * @param tag 标签筛选（空字符串表示不筛选，使用JSONB包含查询）
     * @param sortBy 排序方式：latest/popular/deadline
     * @return 分页结果
     */
    func queryPublicTasksWithPagination(
        page: Int64,
        pageSize: Int64,
        taskType: String,
        taskStatus: String,
        priority: String,
        companyId: String,
        tag: String,
        sortBy: String
    ): Pagination<TasksPO> {
        let sql = StringBuilder()
        sql.append("select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks where deleted_at is null")

        if (!taskType.isEmpty()) {
            sql.append(" and task_type = ${arg(taskType)}")
        }
        if (!taskStatus.isEmpty()) {
            sql.append(" and task_status = ${arg(taskStatus)}")
        } else {
            // 公开列表默认排除 expired/closed 状态
            sql.append(" and task_status not in ('expired', 'closed')")
        }
        if (!priority.isEmpty()) {
            sql.append(" and priority = ${arg(priority)}")
        }
        if (!companyId.isEmpty()) {
            sql.append(" and company_id = ${arg(companyId)}")
        }
        if (!tag.isEmpty()) {
            // JSONB 数组包含查询：tags @> '["tag"]'
            let tagJson = "[\"${tag}\"]"
            sql.append(" and tags @> ${arg(tagJson)}::jsonb")
        }

        // 排序
        var orderBy = " order by created_at desc"
        if (sortBy == "popular") {
            orderBy = " order by follower_count desc, view_count desc"
        } else if (sortBy == "deadline") {
            orderBy = " order by deadline asc nulls last"
        }
        sql.append(orderBy)

        executor.page<TasksPO>(sql.toString(), pageSize, page: page)
    }

    /**
     * 增加任务浏览数
     * @param taskId 任务ID
     * @return 影响行数
     */
    func incrementViewCount(taskId: String): Int64 {
        executor.setSql('''
            update tasks set view_count = view_count + 1 where id = ${arg(taskId)} and deleted_at is null
        ''').update
    }

    /**
     * 增加任务关注者数
     * @param taskId 任务ID
     * @return 影响行数
     */
    func incrementTaskFollowerCount(taskId: String): Int64 {
        executor.setSql('''
            update tasks set follower_count = follower_count + 1 where id = ${arg(taskId)}
        ''').update
    }

    /**
     * 减少任务关注者数（不低于0）
     * @param taskId 任务ID
     * @return 影响行数
     */
    func decrementTaskFollowerCount(taskId: String): Int64 {
        executor.setSql('''
            update tasks set follower_count = greatest(follower_count - 1, 0) where id = ${arg(taskId)}
        ''').update
    }

    /**
     * 增加任务参与者数
     * @param taskId 任务ID
     * @return 影响行数
     */
    func incrementParticipantCount(taskId: String): Int64 {
        executor.setSql('''
            update tasks set participant_count = participant_count + 1 where id = ${arg(taskId)}
        ''').update
    }

    /**
     * 减少任务参与者数（不低于0）
     * @param taskId 任务ID
     * @return 影响行数
     */
    func decrementParticipantCount(taskId: String): Int64 {
        executor.setSql('''
            update tasks set participant_count = greatest(participant_count - 1, 0) where id = ${arg(taskId)}
        ''').update
    }

    /**
     * 更新任务状态（同时维护 started_at/completed_at）
     * @param taskId 任务ID
     * @param taskStatus 新状态
     * @return 影响行数
     */
    func updateTaskStatus(taskId: String, taskStatus: String): Int64 {
        if (taskStatus == "in_progress") {
            executor.setSql('''
                update tasks set task_status = ${arg(taskStatus)}, started_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())} where id = ${arg(taskId)}
            ''').update
        } else if (taskStatus == "completed") {
            executor.setSql('''
                update tasks set task_status = ${arg(taskStatus)}, completed_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())} where id = ${arg(taskId)}
            ''').update
        } else {
            executor.setSql('''
                update tasks set task_status = ${arg(taskStatus)}, updated_at = ${arg(DateTime.now())} where id = ${arg(taskId)}
            ''').update
        }
    }

    /**
     * 统计指定状态的任务总数
     * @param taskStatus 任务状态（空字符串表示统计所有未删除任务）
     * @return 任务数量
     */
    func countTasksByStatus(taskStatus: String): Int64 {
        if (taskStatus.isEmpty()) {
            executor.setSql('''
                select count(*) from tasks where deleted_at is null
            ''').first<Int64>() ?? 0
        } else {
            executor.setSql('''
                select count(*) from tasks where deleted_at is null and task_status = ${arg(taskStatus)}
            ''').first<Int64>() ?? 0
        }
    }

    /**
     * 统计用户总数（uctoo_user表）
     * @return 用户数量
     */
    func countUsers(): Int64 {
        executor.setSql('''
            select count(*) from uctoo_user where deleted_at is null
        ''').first<Int64>() ?? 0
    }

    /**
     * 查询组织下的公开任务（分页）
     * @param companyId 组织ID
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @return 分页结果
     */
    func findTasksByCompanyId(companyId: String, page: Int64, pageSize: Int64): Pagination<TasksPO> {
        let sql = "select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks where deleted_at is null and company_id = ${arg(companyId)} and task_status not in ('expired', 'closed') order by created_at desc"
        executor.page<TasksPO>(sql, pageSize, page: page)
    }

    /**
     * 查询超期未承接的任务（用于定时任务处理）
     * 查询条件：accept_deadline < NOW() 且 task_status = 'open' 且 points_frozen > 0
     * @param limit 单次处理最大数量
     * @return 超期任务列表
     */
    func findExpiredOpenTasks(limit: Int64): ArrayList<TasksPO> {
        let sql = "select id, title, description, task_type, task_status, priority, company_id, creator_id, assignee_id, participant_count, follower_count, view_count, comment_count, reward_type, reward_amount, deadline, started_at, completed_at, tags, skills_required, attachments, extra_data, creator, created_at, updated_at, deleted_at, reward_points, max_participants, accept_deadline, settlement_status, points_frozen, points_settled, points_refunded, review_status from tasks where deleted_at is null and task_status = 'open' and points_frozen > 0 and accept_deadline is not null and accept_deadline < ${arg(DateTime.now())} order by accept_deadline asc limit ${arg(limit)}"
        executor.setSql(sql).list<TasksPO>()
    }

    /**
     * 更新任务积分冻结数（发布任务时冻结积分）
     * @param taskId 任务ID
     * @param pointsFrozen 冻结积分数
     * @return 影响行数
     */
    func updatePointsFrozen(taskId: String, pointsFrozen: Int64): Int64 {
        executor.setSql('''
            update tasks set points_frozen = ${arg(pointsFrozen)}, updated_at = ${arg(DateTime.now())} where id = ${arg(taskId)}
        ''').update
    }

    /**
     * 更新任务结算状态和积分结算数
     * @param taskId 任务ID
     * @param settlementStatus 结算状态
     * @param pointsSettled 已结算积分
     * @return 影响行数
     */
    func updateSettlementStatus(taskId: String, settlementStatus: String, pointsSettled: Int64): Int64 {
        executor.setSql('''
            update tasks set settlement_status = ${arg(settlementStatus)}, points_settled = ${arg(pointsSettled)}, updated_at = ${arg(DateTime.now())} where id = ${arg(taskId)}
        ''').update
    }

    /**
     * 更新任务退还积分数（超期退还时使用）
     * @param taskId 任务ID
     * @param pointsRefunded 已退还积分
     * @return 影响行数
     */
    func updatePointsRefunded(taskId: String, pointsRefunded: Int64): Int64 {
        executor.setSql('''
            update tasks set points_refunded = ${arg(pointsRefunded)}, updated_at = ${arg(DateTime.now())} where id = ${arg(taskId)}
        ''').update
    }

    /**
     * 更新任务审核状态
     * @param taskId 任务ID
     * @param reviewStatus 审核状态
     * @return 影响行数
     */
    func updateReviewStatus(taskId: String, reviewStatus: String): Int64 {
        executor.setSql('''
            update tasks set review_status = ${arg(reviewStatus)}, updated_at = ${arg(DateTime.now())} where id = ${arg(taskId)}
        ''').update
    }
}
