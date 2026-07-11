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
import magic.app.models.uctoo.MessagesPO
import magic.log.LogUtils

/**
 * MessagesDAO - messages数据访问接口
 *
 * 提供messages表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface MessagesDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入messages（id由数据库自动生成UUID）
     * @param entity MessagesPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertMessages(entity: MessagesPO): String {
        executor.setSql('''
            insert into messages(
                user_id,
                sender_id,
                message_type,
                title,
                content,
                msg_related_type,
                related_id,
                is_read,
                read_at,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.userId)},
                ${arg(entity.senderId)},
                ${arg(entity.messageType)},
                ${arg(entity.title)},
                ${arg(entity.content)},
                ${arg(entity.msgRelatedType)},
                ${arg(entity.relatedId)},
                ${arg(entity.isRead)},
                ${arg(entity.readAt)},
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
     * 根据ID查询messages
     * @param id messagesID
     * @return messages对象（Option类型）
     */
    func findMessagesById(id: String): Option<MessagesPO> {
        executor.setSql('''
            select id, user_id, sender_id, message_type, title, content, msg_related_type, related_id, is_read, read_at, creator, created_at, updated_at, deleted_at from messages where id = ${arg(id)}
        ''').first<MessagesPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新messages
     * @param entity messages对象
     * @return 影响行数
     */
    func updateMessages(entity: MessagesPO): Int64 {
        executor.setSql('''
            update messages set
                user_id = ${arg(entity.userId)},
                sender_id = ${arg(entity.senderId)},
                message_type = ${arg(entity.messageType)},
                title = ${arg(entity.title)},
                content = ${arg(entity.content)},
                msg_related_type = ${arg(entity.msgRelatedType)},
                related_id = ${arg(entity.relatedId)},
                is_read = ${arg(entity.isRead)},
                read_at = ${arg(entity.readAt)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除messages
     * @param id messagesID
     * @return 影响行数
     */
    func softDeleteMessagesById(id: String): Int64 {
        executor.setSql('''
            update messages set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的messages
     * @param id messagesID
     * @return 影响行数
     */
    func restoreMessagesById(id: String): Int64 {
        executor.setSql('''
            update messages set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除messages
     * @param id messagesID
     * @return 影响行数
     */
    func deleteMessagesById(id: String): Int64 {
        executor.setSql('''
            delete from messages where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有messages
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllMessagesPage(page: Int64, size: Int64): Pagination<MessagesPO> {
        executor.page<MessagesPO>('''
            select id, user_id, sender_id, message_type, title, content, msg_related_type, related_id, is_read, read_at, creator, created_at, updated_at, deleted_at from messages order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询messages列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findMessagesByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<MessagesPO> {
        executor.page<MessagesPO>('''
            select id, user_id, sender_id, message_type, title, content, msg_related_type, related_id, is_read, read_at, creator, created_at, updated_at, deleted_at from messages where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有messages（不分页）
     * @return messages列表
     */
    func listAllMessages(): ArrayList<MessagesPO> {
        executor.setSql('''
            select id, user_id, sender_id, message_type, title, content, msg_related_type, related_id, is_read, read_at, creator, created_at, updated_at, deleted_at from messages order by created_at desc
        ''').list<MessagesPO>()
    }

    /**
     * 批量查询messages
     * @param ids ID列表
     * @return messages列表
     */
    func findMessagesByIds(ids: ArrayList<String>): ArrayList<MessagesPO> {
        if (ids.isEmpty()) {
            return ArrayList<MessagesPO>()
        }
        executor.setSql('''
            select id, user_id, sender_id, message_type, title, content, msg_related_type, related_id, is_read, read_at, creator, created_at, updated_at, deleted_at from messages where id ${IN(ids)}
        ''').list<MessagesPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的messages数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countMessagesByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from messages where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有messages数量
     * @return 数量
     */
    func countAllMessages(): Int64 {
        executor.setSql('''
            select count(*) from messages
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询messages列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findMessagesByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<MessagesPO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, sender_id, message_type, title, content, msg_related_type, related_id, is_read, read_at, creator, created_at, updated_at, deleted_at from messages where 1=1")

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

        executor.page<MessagesPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除messages
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteMessages(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update messages set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除messages
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteMessages(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from messages where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询messages（支持完整查询操作符）
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
    func findMessagesByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<MessagesPO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, sender_id, message_type, title, content, msg_related_type, related_id, is_read, read_at, creator, created_at, updated_at, deleted_at from messages")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<MessagesPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询messages
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findMessagesByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<MessagesPO> {
        let fromClause = executor.FROM<MessagesPO>()

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
        fromClause.page<MessagesPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的messages）
     * @return 影响行数
     */
    func emptyRecycleBinMessages(): Int64 {
        executor.setSql('''
            delete from messages where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 分页查询用户消息（按 created_at DESC 排序）
     * @param userId 用户ID
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param messageType 消息类型筛选（空字符串表示不筛选）
     * @return 分页结果
     */
    func queryMessagesByUserId(userId: String, page: Int64, pageSize: Int64, messageType: String): Pagination<MessagesPO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, sender_id, message_type, title, content, msg_related_type, related_id, is_read, read_at, creator, created_at, updated_at, deleted_at from messages where user_id = ${arg(userId)} and deleted_at is null")
        if (!messageType.isEmpty()) {
            sql.append(" and message_type = ${arg(messageType)}")
        }
        sql.append(" order by created_at desc")
        executor.page<MessagesPO>(sql.toString(), pageSize, page: page)
    }

    /**
     * 统计用户未读消息数
     * @param userId 用户ID
     * @return 未读消息数量
     */
    func countUnread(userId: String): Int64 {
        executor.setSql('''
            select count(*) from messages where user_id = ${arg(userId)} and is_read = false and deleted_at is null
        ''').first<Int64>() ?? 0
    }

    /**
     * 标记单条消息已读
     * @param msgId 消息ID
     * @param userId 用户ID（用于验证消息归属）
     * @return 影响行数
     */
    func markAsRead(msgId: String, userId: String): Int64 {
        executor.setSql('''
            update messages set is_read = true, read_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())}
            where id = ${arg(msgId)} and user_id = ${arg(userId)} and is_read = false and deleted_at is null
        ''').update
    }

    /**
     * 标记用户所有消息为已读
     * @param userId 用户ID
     * @return 影响行数
     */
    func markAllAsRead(userId: String): Int64 {
        executor.setSql('''
            update messages set is_read = true, read_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())}
            where user_id = ${arg(userId)} and is_read = false and deleted_at is null
        ''').update
    }

    /**
     * 查询任务的关注者ID列表（用于批量通知）
     * 通过 user_has_tasks 表查询 relation_type = 'follower' 的用户
     * @param taskId 任务ID
     * @return 关注者ID列表
     */
    func findFollowerIdsByTaskId(taskId: String): ArrayList<String> {
        executor.setSql('''
            select user_id from user_has_tasks where task_id = ${arg(taskId)} and relation_type = 'follower' and deleted_at is null
        ''').list<String>()
    }

    /**
     * 查询组织成员ID列表（用于批量通知）
     * 通过 user_has_company 表查询 owner/admin/member
     * @param companyId 组织ID
     * @return 成员ID列表
     */
    func findMemberIdsByCompanyId(companyId: String): ArrayList<String> {
        executor.setSql('''
            select user_id from user_has_company where company_id = ${arg(companyId)} and member_role in ('owner', 'admin', 'member') and deleted_at is null
        ''').list<String>()
    }
}
