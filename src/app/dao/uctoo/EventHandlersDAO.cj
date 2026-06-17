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
import magic.app.models.uctoo.EventHandlersPO
import magic.log.LogUtils

/**
 * EventHandlersDAO - event_handlers数据访问接口
 *
 * 提供event_handlers表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface EventHandlersDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入event_handlers（id由数据库自动生成UUID）
     * @param entity EventHandlersPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertEventHandlers(entity: EventHandlersPO): String {
        executor.setSql('''
            insert into event_handlers(
                event_type,
                handler_name,
                handler_class,
                status,
                config,
                description,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.eventType)},
                ${arg(entity.handlerName)},
                ${arg(entity.handlerClass)},
                ${arg(entity.status)},
                ${arg(entity.config)},
                ${arg(entity.description)},
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
     * 根据ID查询event_handlers
     * @param id event_handlersID
     * @return event_handlers对象（Option类型）
     */
    func findEventHandlersById(id: String): Option<EventHandlersPO> {
        executor.setSql('''
            select id, event_type, handler_name, handler_class, status, config, description, creator, created_at, updated_at, deleted_at from event_handlers where id = ${arg(id)}
        ''').first<EventHandlersPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新event_handlers
     * @param entity event_handlers对象
     * @return 影响行数
     */
    func updateEventHandlers(entity: EventHandlersPO): Int64 {
        executor.setSql('''
            update event_handlers set
                event_type = ${arg(entity.eventType)},
                handler_name = ${arg(entity.handlerName)},
                handler_class = ${arg(entity.handlerClass)},
                status = ${arg(entity.status)},
                config = ${arg(entity.config)},
                description = ${arg(entity.description)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除event_handlers
     * @param id event_handlersID
     * @return 影响行数
     */
    func softDeleteEventHandlersById(id: String): Int64 {
        executor.setSql('''
            update event_handlers set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的event_handlers
     * @param id event_handlersID
     * @return 影响行数
     */
    func restoreEventHandlersById(id: String): Int64 {
        executor.setSql('''
            update event_handlers set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除event_handlers
     * @param id event_handlersID
     * @return 影响行数
     */
    func deleteEventHandlersById(id: String): Int64 {
        executor.setSql('''
            delete from event_handlers where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有event_handlers
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllEventHandlersPage(page: Int64, size: Int64): Pagination<EventHandlersPO> {
        executor.page<EventHandlersPO>('''
            select id, event_type, handler_name, handler_class, status, config, description, creator, created_at, updated_at, deleted_at from event_handlers order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询event_handlers列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findEventHandlersByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<EventHandlersPO> {
        executor.page<EventHandlersPO>('''
            select id, event_type, handler_name, handler_class, status, config, description, creator, created_at, updated_at, deleted_at from event_handlers where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有event_handlers（不分页）
     * @return event_handlers列表
     */
    func listAllEventHandlers(): ArrayList<EventHandlersPO> {
        executor.setSql('''
            select id, event_type, handler_name, handler_class, status, config, description, creator, created_at, updated_at, deleted_at from event_handlers order by created_at desc
        ''').list<EventHandlersPO>()
    }

    /**
     * 批量查询event_handlers
     * @param ids ID列表
     * @return event_handlers列表
     */
    func findEventHandlersByIds(ids: ArrayList<String>): ArrayList<EventHandlersPO> {
        if (ids.isEmpty()) {
            return ArrayList<EventHandlersPO>()
        }
        executor.setSql('''
            select id, event_type, handler_name, handler_class, status, config, description, creator, created_at, updated_at, deleted_at from event_handlers where id ${IN(ids)}
        ''').list<EventHandlersPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的event_handlers数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countEventHandlersByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from event_handlers where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有event_handlers数量
     * @return 数量
     */
    func countAllEventHandlers(): Int64 {
        executor.setSql('''
            select count(*) from event_handlers
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询event_handlers列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findEventHandlersByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<EventHandlersPO> {
        let sql = StringBuilder()
        sql.append("select id, event_type, handler_name, handler_class, status, config, description, creator, created_at, updated_at, deleted_at from event_handlers where 1=1")

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

        executor.page<EventHandlersPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除event_handlers
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteEventHandlers(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update event_handlers set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除event_handlers
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteEventHandlers(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from event_handlers where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询event_handlers（支持完整查询操作符）
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
    func findEventHandlersByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<EventHandlersPO> {
        let sql = StringBuilder()
        sql.append("select id, event_type, handler_name, handler_class, status, config, description, creator, created_at, updated_at, deleted_at from event_handlers")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<EventHandlersPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询event_handlers
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findEventHandlersByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<EventHandlersPO> {
        let fromClause = executor.FROM<EventHandlersPO>()

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
        fromClause.page<EventHandlersPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的event_handlers）
     * @return 影响行数
     */
    func emptyRecycleBinEventHandlers(): Int64 {
        executor.setSql('''
            delete from event_handlers where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
