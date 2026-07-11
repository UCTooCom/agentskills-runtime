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
import magic.app.models.uctoo.UctooUserPO
import magic.log.LogUtils

/**
 * UctooUserDAO - uctoo_user数据访问接口
 *
 * 提供uctoo_user表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UctooUserDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入uctoo_user（id由数据库自动生成UUID）
     * @param entity UctooUserPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUctooUser(entity: UctooUserPO): String {
        let creatorValue = match (entity.creator) {
            case Some(c) => "'${c}'"
            case None => "NULL"
        }
        
        executor.setSql('''
            insert into uctoo_user(
                name,
                username,
                email,
                password,
                avatar,
                created_at,
                last_login,
                auth_provider,
                creator,
                deleted_at,
                last_login_ip,
                last_login_time,
                remember_token,
                status,
                updated_at,
                access_token,
                refresh_token,
                user_type,
                agent_id
            ) values(
${arg(entity.name)},
                ${arg(entity.username)},
                ${arg(entity.email)},
                ${arg(entity.password)},
                ${arg(entity.avatar)},
                ${arg(entity.createdAt)},
                ${arg(entity.lastLogin)},
                ${arg(entity.authProvider)},
                ${creatorValue},
                ${arg(entity.deletedAt)},
                ${arg(entity.lastLoginIp)},
                ${arg(entity.lastLoginTime)},
                ${arg(entity.rememberToken)},
                ${arg(entity.status)},
                ${arg(entity.updatedAt)},
                ${arg(entity.accessToken)},
                ${arg(entity.refreshToken)},
                ${arg(entity.userType)},
                ${arg(entity.agentId)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询uctoo_user
     * @param id uctoo_userID
     * @return uctoo_user对象（Option类型）
     */
    func findUctooUserById(id: String): Option<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where id = ${arg(id)}
        ''').first<UctooUserPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新uctoo_user
     * @param entity uctoo_user对象
     * @return 影响行数
     */
    func updateUctooUser(entity: UctooUserPO): Int64 {
        executor.setSql('''
            update uctoo_user set
                name = ${arg(entity.name)},
                username = ${arg(entity.username)},
                email = ${arg(entity.email)},
                password = ${arg(entity.password)},
                avatar = ${arg(entity.avatar)},
                last_login = ${arg(entity.lastLogin)},
                auth_provider = ${arg(entity.authProvider)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                last_login_ip = ${arg(entity.lastLoginIp)},
                last_login_time = ${arg(entity.lastLoginTime)},
                remember_token = ${arg(entity.rememberToken)},
                status = ${arg(entity.status)},
                access_token = ${arg(entity.accessToken)},
                refresh_token = ${arg(entity.refreshToken)},
                user_type = ${arg(entity.userType)},
                agent_id = ${arg(entity.agentId)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除uctoo_user
     * @param id uctoo_userID
     * @return 影响行数
     */
    func softDeleteUctooUserById(id: String): Int64 {
        executor.setSql('''
            update uctoo_user set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的uctoo_user
     * @param id uctoo_userID
     * @return 影响行数
     */
    func restoreUctooUserById(id: String): Int64 {
        executor.setSql('''
            update uctoo_user set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除uctoo_user
     * @param id uctoo_userID
     * @return 影响行数
     */
    func deleteUctooUserById(id: String): Int64 {
        executor.setSql('''
            delete from uctoo_user where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有uctoo_user
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUctooUserPage(page: Int64, size: Int64): Pagination<UctooUserPO> {
        executor.page<UctooUserPO>('''
            select * from uctoo_user order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询uctoo_user列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUctooUserByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UctooUserPO> {
        executor.page<UctooUserPO>('''
            select * from uctoo_user where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有uctoo_user（不分页）
     * @return uctoo_user列表
     */
    func listAllUctooUser(): ArrayList<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user order by created_at desc
        ''').list<UctooUserPO>()
    }

    /**
     * 批量查询uctoo_user
     * @param ids ID列表
     * @return uctoo_user列表
     */
    func findUctooUserByIds(ids: ArrayList<String>): ArrayList<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where id ${IN(ids)}
        ''').list<UctooUserPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的uctoo_user数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUctooUserByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from uctoo_user where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有uctoo_user数量
     * @return 数量
     */
    func countAllUctooUser(): Int64 {
        executor.setSql('''
            select count(*) from uctoo_user
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询uctoo_user列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUctooUserByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UctooUserPO> {
        let sql = StringBuilder()
        sql.append("select * from uctoo_user where 1=1")

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

        executor.page<UctooUserPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除uctoo_user
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUctooUser(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update uctoo_user set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除uctoo_user
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUctooUser(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from uctoo_user where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询uctoo_user（支持完整查询操作符）
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
    func findUctooUserByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UctooUserPO> {
        let sql = StringBuilder()
        sql.append("select * from uctoo_user")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UctooUserPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询uctoo_user
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUctooUserByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UctooUserPO> {
        let fromClause = executor.FROM<UctooUserPO>()

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
        fromClause.page<UctooUserPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的uctoo_user）
     * @return 影响行数
     */
    func emptyRecycleBinUctooUser(): Int64 {
        executor.setSql('''
            delete from uctoo_user where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
    
    /**
     * 根据用户名查询用户
     * @param username 用户名
     * @return 用户对象
     */
    func findUctooUserByUsername(username: String): Option<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where username = ${arg(username)}
        ''').first<UctooUserPO>()
    }
    
    /**
     * 根据邮箱查询用户
     * @param email 邮箱
     * @return 用户对象
     */
    func findUctooUserByEmail(email: String): Option<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where email = ${arg(email)}
        ''').first<UctooUserPO>()
    }

    func findUctooUserByUserType(userType: String, page: Int64, size: Int64): Pagination<UctooUserPO> {
        executor.page<UctooUserPO>('''
            select * from uctoo_user where user_type = ${arg(userType)} order by created_at desc
        ''', size, page: page)
    }

    func findUctooUserByAgentId(agentId: String): Option<UctooUserPO> {
        executor.setSql('''
            select * from uctoo_user where agent_id = ${arg(agentId)} and user_type = 'agent'
        ''').first<UctooUserPO>()
    }
}
