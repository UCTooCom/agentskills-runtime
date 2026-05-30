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
import magic.app.models.uctoo.UserGroupPO
import magic.log.LogUtils

/**
 * UserGroupDAO - user_group数据访问接口
 *
 * 提供user_group表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UserGroupDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入user_group（id由数据库自动生成UUID）
     * @param entity UserGroupPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserGroup(entity: UserGroupPO): String {
        executor.setSql('''
            insert into user_group(
                group_name,
                parent_id,
                code,
                intro,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.groupName)},
                ${arg(entity.parentId)},
                ${arg(entity.code)},
                ${arg(entity.intro)},
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
     * 根据ID查询user_group
     * @param id user_groupID
     * @return user_group对象（Option类型）
     */
    func findUserGroupById(id: String): Option<UserGroupPO> {
        executor.setSql('''
            select * from user_group where id = ${arg(id)}
        ''').first<UserGroupPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新user_group
     * @param entity user_group对象
     * @return 影响行数
     */
    func updateUserGroup(entity: UserGroupPO): Int64 {
        executor.setSql('''
            update user_group set
                group_name = ${arg(entity.groupName)},
                parent_id = ${arg(entity.parentId)},
                code = ${arg(entity.code)},
                intro = ${arg(entity.intro)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除user_group
     * @param id user_groupID
     * @return 影响行数
     */
    func softDeleteUserGroupById(id: String): Int64 {
        executor.setSql('''
            update user_group set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的user_group
     * @param id user_groupID
     * @return 影响行数
     */
    func restoreUserGroupById(id: String): Int64 {
        executor.setSql('''
            update user_group set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除user_group
     * @param id user_groupID
     * @return 影响行数
     */
    func deleteUserGroupById(id: String): Int64 {
        executor.setSql('''
            delete from user_group where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有user_group
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserGroupPage(page: Int64, size: Int64): Pagination<UserGroupPO> {
        executor.page<UserGroupPO>('''
            select * from user_group order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询user_group列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserGroupByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserGroupPO> {
        executor.page<UserGroupPO>('''
            select * from user_group where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有user_group（不分页）
     * @return user_group列表
     */
    func listAllUserGroup(): ArrayList<UserGroupPO> {
        executor.setSql('''
            select * from user_group order by created_at desc
        ''').list<UserGroupPO>()
    }

    /**
     * 批量查询user_group
     * @param ids ID列表
     * @return user_group列表
     */
    func findUserGroupByIds(ids: ArrayList<String>): ArrayList<UserGroupPO> {
        executor.setSql('''
            select * from user_group where id ${IN(ids)}
        ''').list<UserGroupPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的user_group数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserGroupByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_group where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有user_group数量
     * @return 数量
     */
    func countAllUserGroup(): Int64 {
        executor.setSql('''
            select count(*) from user_group
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询user_group列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserGroupByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UserGroupPO> {
        let sql = StringBuilder()
        sql.append("select * from user_group where 1=1")

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

        executor.page<UserGroupPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除user_group
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUserGroup(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update user_group set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除user_group
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUserGroup(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from user_group where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询user_group（支持完整查询操作符）
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
    func findUserGroupByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserGroupPO> {
        let sql = StringBuilder()
        sql.append("select * from user_group")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UserGroupPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询user_group
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserGroupByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserGroupPO> {
        let fromClause = executor.FROM<UserGroupPO>()

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
        fromClause.page<UserGroupPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的user_group）
     * @return 影响行数
     */
    func emptyRecycleBinUserGroup(): Int64 {
        executor.setSql('''
            delete from user_group where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
