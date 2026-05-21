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
import magic.app.models.uctoo.UserHasGroupPO
import magic.log.LogUtils

/**
 * UserHasGroupDAO - user_has_group数据访问接口
 *
 * 提供user_has_group表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UserHasGroupDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入user_has_group（id由数据库自动生成UUID）
     * @param entity UserHasGroupPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserHasGroup(entity: UserHasGroupPO): String {
        executor.setSql('''
            insert into user_has_group(
                groupable_type,
                group_id,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at,
                groupable_id
            ) values(
${arg(entity.groupableType)},
                ${arg(entity.groupId)},
                ${arg(entity.status)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.groupableId)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询user_has_group
     * @param id user_has_groupID
     * @return user_has_group对象（Option类型）
     */
    func findUserHasGroupById(id: String): Option<UserHasGroupPO> {
        executor.setSql('''
            select * from user_has_group where id = ${arg(id)}
        ''').first<UserHasGroupPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新user_has_group
     * @param entity user_has_group对象
     * @return 影响行数
     */
    func updateUserHasGroup(entity: UserHasGroupPO): Int64 {
        executor.setSql('''
            update user_has_group set
                groupable_type = ${arg(entity.groupableType)},
                group_id = ${arg(entity.groupId)},
                status = ${arg(entity.status)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                groupable_id = ${arg(entity.groupableId)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除user_has_group
     * @param id user_has_groupID
     * @return 影响行数
     */
    func softDeleteUserHasGroupById(id: String): Int64 {
        executor.setSql('''
            update user_has_group set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的user_has_group
     * @param id user_has_groupID
     * @return 影响行数
     */
    func restoreUserHasGroupById(id: String): Int64 {
        executor.setSql('''
            update user_has_group set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除user_has_group
     * @param id user_has_groupID
     * @return 影响行数
     */
    func deleteUserHasGroupById(id: String): Int64 {
        executor.setSql('''
            delete from user_has_group where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有user_has_group
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserHasGroupPage(page: Int64, size: Int64): Pagination<UserHasGroupPO> {
        executor.page<UserHasGroupPO>('''
            select * from user_has_group order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询user_has_group列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasGroupByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserHasGroupPO> {
        executor.page<UserHasGroupPO>('''
            select * from user_has_group where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有user_has_group（不分页）
     * @return user_has_group列表
     */
    func listAllUserHasGroup(): ArrayList<UserHasGroupPO> {
        executor.setSql('''
            select * from user_has_group order by created_at desc
        ''').list<UserHasGroupPO>()
    }

    /**
     * 批量查询user_has_group
     * @param ids ID列表
     * @return user_has_group列表
     */
    func findUserHasGroupByIds(ids: ArrayList<String>): ArrayList<UserHasGroupPO> {
        executor.setSql('''
            select * from user_has_group where id ${IN(ids)}
        ''').list<UserHasGroupPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的user_has_group数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserHasGroupByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_group where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有user_has_group数量
     * @return 数量
     */
    func countAllUserHasGroup(): Int64 {
        executor.setSql('''
            select count(*) from user_has_group
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询user_has_group列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasGroupByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UserHasGroupPO> {
        let sql = StringBuilder()
        sql.append("select * from user_has_group where 1=1")

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

        executor.page<UserHasGroupPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除user_has_group
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUserHasGroup(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            update user_has_group set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除user_has_group
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUserHasGroup(ids: ArrayList<String>): Int64 {
        executor.setSql('''
            delete from user_has_group where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询user_has_group（支持完整查询操作符）
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
    func findUserHasGroupByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasGroupPO> {
        let sql = StringBuilder()
        sql.append("select * from user_has_group")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UserHasGroupPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询user_has_group
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasGroupByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasGroupPO> {
        let fromClause = executor.FROM<UserHasGroupPO>()

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
        fromClause.page<UserHasGroupPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的user_has_group）
     * @return 影响行数
     */
    func emptyRecycleBinUserHasGroup(): Int64 {
        executor.setSql('''
            delete from user_has_group where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
}
