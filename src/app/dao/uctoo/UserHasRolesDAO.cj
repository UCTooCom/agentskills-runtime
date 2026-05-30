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
import magic.app.models.uctoo.UserHasRolesPO
import magic.log.LogUtils

/**
 * UserHasRolesDAO - user_has_roles数据访问接口
 *
 * 提供user_has_roles表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UserHasRolesDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入user_has_roles（id由数据库自动生成UUID）
     * @param entity UserHasRolesPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserHasRoles(entity: UserHasRolesPO): String {
        executor.setSql('''
            insert into user_has_roles(
                user_id,
                role_id,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.userId)},
                ${arg(entity.roleId)},
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
     * 根据ID查询user_has_roles
     * @param id user_has_rolesID
     * @return user_has_roles对象（Option类型）
     */
    func findUserHasRolesById(id: String): Option<UserHasRolesPO> {
        executor.setSql('''
            select * from user_has_roles where id = ${arg(id)}
        ''').first<UserHasRolesPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新user_has_roles
     * @param entity user_has_roles对象
     * @return 影响行数
     */
    func updateUserHasRoles(entity: UserHasRolesPO): Int64 {
        executor.setSql('''
            update user_has_roles set
                user_id = ${arg(entity.userId)},
                role_id = ${arg(entity.roleId)},
                status = ${arg(entity.status)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除user_has_roles
     * @param id user_has_rolesID
     * @return 影响行数
     */
    func softDeleteUserHasRolesById(id: String): Int64 {
        executor.setSql('''
            update user_has_roles set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的user_has_roles
     * @param id user_has_rolesID
     * @return 影响行数
     */
    func restoreUserHasRolesById(id: String): Int64 {
        executor.setSql('''
            update user_has_roles set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除user_has_roles
     * @param id user_has_rolesID
     * @return 影响行数
     */
    func deleteUserHasRolesById(id: String): Int64 {
        executor.setSql('''
            delete from user_has_roles where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有user_has_roles
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserHasRolesPage(page: Int64, size: Int64): Pagination<UserHasRolesPO> {
        executor.page<UserHasRolesPO>('''
            select * from user_has_roles order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询user_has_roles列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasRolesByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserHasRolesPO> {
        executor.page<UserHasRolesPO>('''
            select * from user_has_roles where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有user_has_roles（不分页）
     * @return user_has_roles列表
     */
    func listAllUserHasRoles(): ArrayList<UserHasRolesPO> {
        executor.setSql('''
            select * from user_has_roles order by created_at desc
        ''').list<UserHasRolesPO>()
    }

    /**
     * 批量查询user_has_roles
     * @param ids ID列表
     * @return user_has_roles列表
     */
    func findUserHasRolesByIds(ids: ArrayList<String>): ArrayList<UserHasRolesPO> {
        executor.setSql('''
            select * from user_has_roles where id ${IN(ids)}
        ''').list<UserHasRolesPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的user_has_roles数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserHasRolesByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_roles where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有user_has_roles数量
     * @return 数量
     */
    func countAllUserHasRoles(): Int64 {
        executor.setSql('''
            select count(*) from user_has_roles
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询user_has_roles列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasRolesByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UserHasRolesPO> {
        let sql = StringBuilder()
        sql.append("select * from user_has_roles where 1=1")

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

        executor.page<UserHasRolesPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除user_has_roles
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUserHasRoles(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update user_has_roles set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除user_has_roles
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUserHasRoles(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from user_has_roles where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询user_has_roles（支持完整查询操作符）
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
    func findUserHasRolesByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasRolesPO> {
        let sql = StringBuilder()
        sql.append("select * from user_has_roles")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UserHasRolesPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询user_has_roles
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasRolesByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasRolesPO> {
        let fromClause = executor.FROM<UserHasRolesPO>()

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
        fromClause.page<UserHasRolesPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的user_has_roles）
     * @return 影响行数
     */
    func emptyRecycleBinUserHasRoles(): Int64 {
        executor.setSql('''
            delete from user_has_roles where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode

    // ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 根据用户ID查询用户角色关联
     * @param userId 用户ID
     * @return 用户角色关联列表
     */
    func findUserHasRolesByUserId(userId: String): ArrayList<UserHasRolesPO> {
        executor.setSql('''
            SELECT * FROM user_has_roles
            WHERE user_id = ${arg(userId)} AND deleted_at IS NULL
        ''').list<UserHasRolesPO>()
    }

    func deleteUserHasRolesByUserId(userId: String): Int64 {
        executor.setSql('''
            DELETE FROM user_has_roles WHERE user_id = ${arg(userId)}
        ''').delete
    }
}
