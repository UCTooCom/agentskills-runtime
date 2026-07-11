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
import magic.app.models.uctoo.UserHasCompanyPO
import magic.log.LogUtils

/**
 * UserHasCompanyDAO - user_has_company数据访问接口
 *
 * 提供user_has_company表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UserHasCompanyDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入user_has_company（id由数据库自动生成UUID）
     * @param entity UserHasCompanyPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUserHasCompany(entity: UserHasCompanyPO): String {
        executor.setSql('''
            insert into user_has_company(
                user_id,
                company_id,
                member_role,
                joined_at,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.userId)},
                ${arg(entity.companyId)},
                ${arg(entity.memberRole)},
                ${arg(entity.joinedAt)},
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
     * 根据ID查询user_has_company
     * @param id user_has_companyID
     * @return user_has_company对象（Option类型）
     */
    func findUserHasCompanyById(id: String): Option<UserHasCompanyPO> {
        executor.setSql('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company where id = ${arg(id)}
        ''').first<UserHasCompanyPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新user_has_company
     * @param entity user_has_company对象
     * @return 影响行数
     */
    func updateUserHasCompany(entity: UserHasCompanyPO): Int64 {
        executor.setSql('''
            update user_has_company set
                user_id = ${arg(entity.userId)},
                company_id = ${arg(entity.companyId)},
                member_role = ${arg(entity.memberRole)},
                joined_at = ${arg(entity.joinedAt)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除user_has_company
     * @param id user_has_companyID
     * @return 影响行数
     */
    func softDeleteUserHasCompanyById(id: String): Int64 {
        executor.setSql('''
            update user_has_company set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的user_has_company
     * @param id user_has_companyID
     * @return 影响行数
     */
    func restoreUserHasCompanyById(id: String): Int64 {
        executor.setSql('''
            update user_has_company set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除user_has_company
     * @param id user_has_companyID
     * @return 影响行数
     */
    func deleteUserHasCompanyById(id: String): Int64 {
        executor.setSql('''
            delete from user_has_company where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有user_has_company
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUserHasCompanyPage(page: Int64, size: Int64): Pagination<UserHasCompanyPO> {
        executor.page<UserHasCompanyPO>('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询user_has_company列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasCompanyByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UserHasCompanyPO> {
        executor.page<UserHasCompanyPO>('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有user_has_company（不分页）
     * @return user_has_company列表
     */
    func listAllUserHasCompany(): ArrayList<UserHasCompanyPO> {
        executor.setSql('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company order by created_at desc
        ''').list<UserHasCompanyPO>()
    }

    /**
     * 批量查询user_has_company
     * @param ids ID列表
     * @return user_has_company列表
     */
    func findUserHasCompanyByIds(ids: ArrayList<String>): ArrayList<UserHasCompanyPO> {
        if (ids.isEmpty()) {
            return ArrayList<UserHasCompanyPO>()
        }
        executor.setSql('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company where id ${IN(ids)}
        ''').list<UserHasCompanyPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的user_has_company数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUserHasCompanyByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_company where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有user_has_company数量
     * @return 数量
     */
    func countAllUserHasCompany(): Int64 {
        executor.setSql('''
            select count(*) from user_has_company
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询user_has_company列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasCompanyByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UserHasCompanyPO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company where 1=1")

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

        executor.page<UserHasCompanyPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除user_has_company
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUserHasCompany(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update user_has_company set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除user_has_company
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUserHasCompany(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from user_has_company where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询user_has_company（支持完整查询操作符）
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
    func findUserHasCompanyByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasCompanyPO> {
        let sql = StringBuilder()
        sql.append("select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UserHasCompanyPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询user_has_company
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUserHasCompanyByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UserHasCompanyPO> {
        let fromClause = executor.FROM<UserHasCompanyPO>()

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
        fromClause.page<UserHasCompanyPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的user_has_company）
     * @return 影响行数
     */
    func emptyRecycleBinUserHasCompany(): Int64 {
        executor.setSql('''
            delete from user_has_company where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 查询用户与组织的指定关系
     * @param userId 用户ID
     * @param companyId 组织ID
     * @param memberRole 成员角色
     * @return 关系记录（若存在）
     */
    func findCompanyRelation(userId: String, companyId: String, memberRole: String): Option<UserHasCompanyPO> {
        executor.setSql('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company
            where user_id = ${arg(userId)} and company_id = ${arg(companyId)} and member_role = ${arg(memberRole)} and deleted_at is null
        ''').first<UserHasCompanyPO>()
    }

    /**
     * 查询用户在组织的所有角色记录
     * @param userId 用户ID
     * @param companyId 组织ID
     * @return 角色记录列表
     */
    func findUserRolesInCompany(userId: String, companyId: String): ArrayList<UserHasCompanyPO> {
        executor.setSql('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company
            where user_id = ${arg(userId)} and company_id = ${arg(companyId)} and deleted_at is null
        ''').list<UserHasCompanyPO>()
    }

    /**
     * 判断用户是否为组织成员（owner/admin/member，不含 follower）
     * @param userId 用户ID
     * @param companyId 组织ID
     * @return true=是成员，false=非成员
     */
    func isMember(userId: String, companyId: String): Bool {
        let count = executor.setSql('''
            select count(*) from user_has_company
            where user_id = ${arg(userId)} and company_id = ${arg(companyId)} and member_role in ('owner', 'admin', 'member') and deleted_at is null
        ''').first<Int64>() ?? 0
        count > 0
    }

    /**
     * 判断用户是否为组织管理员（owner/admin）
     * @param userId 用户ID
     * @param companyId 组织ID
     * @return true=是管理员
     */
    func isAdmin(userId: String, companyId: String): Bool {
        let count = executor.setSql('''
            select count(*) from user_has_company
            where user_id = ${arg(userId)} and company_id = ${arg(companyId)} and member_role in ('owner', 'admin') and deleted_at is null
        ''').first<Int64>() ?? 0
        count > 0
    }

    /**
     * 判断用户是否为组织创建者（owner）
     * @param userId 用户ID
     * @param companyId 组织ID
     * @return true=是owner
     */
    func isOwner(userId: String, companyId: String): Bool {
        let count = executor.setSql('''
            select count(*) from user_has_company
            where user_id = ${arg(userId)} and company_id = ${arg(companyId)} and member_role = 'owner' and deleted_at is null
        ''').first<Int64>() ?? 0
        count > 0
    }

    /**
     * 查询组织关注者列表（member_role = 'follower'）
     * @param companyId 组织ID
     * @return 关注者关系列表
     */
    func findFollowersByCompanyId(companyId: String): ArrayList<UserHasCompanyPO> {
        executor.setSql('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company
            where company_id = ${arg(companyId)} and member_role = 'follower' and deleted_at is null
        ''').list<UserHasCompanyPO>()
    }

    /**
     * 查询组织所有成员（owner/admin/member，不含 follower）
     * @param companyId 组织ID
     * @return 成员关系列表
     */
    func findMembersByCompanyId(companyId: String): ArrayList<UserHasCompanyPO> {
        executor.setSql('''
            select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company
            where company_id = ${arg(companyId)} and member_role in ('owner', 'admin', 'member') and deleted_at is null
            order by case member_role when 'owner' then 1 when 'admin' then 2 else 3 end, joined_at asc
        ''').list<UserHasCompanyPO>()
    }

    /**
     * 分页查询用户某角色的组织关联
     * @param userId 用户ID
     * @param memberRole 成员角色
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @return 分页结果
     */
    func findCompaniesByUserIdAndRole(userId: String, memberRole: String, page: Int64, pageSize: Int64): Pagination<UserHasCompanyPO> {
        let sql = "select id, user_id, company_id, member_role, joined_at, creator, created_at, updated_at, deleted_at from user_has_company where user_id = ${arg(userId)} and member_role = ${arg(memberRole)} and deleted_at is null order by created_at desc"
        executor.page<UserHasCompanyPO>(sql, pageSize, page: page)
    }

    /**
     * 软删除用户与组织的指定关系
     * @param userId 用户ID
     * @param companyId 组织ID
     * @param memberRole 成员角色
     * @return 影响行数
     */
    func softDeleteCompanyRelation(userId: String, companyId: String, memberRole: String): Int64 {
        executor.setSql('''
            update user_has_company set deleted_at = ${arg(DateTime.now())}, updated_at = ${arg(DateTime.now())}
            where user_id = ${arg(userId)} and company_id = ${arg(companyId)} and member_role = ${arg(memberRole)} and deleted_at is null
        ''').update
    }

    /**
     * 统计组织成员数（owner/admin/member）
     * @param companyId 组织ID
     * @return 成员数量
     */
    func countMembersByCompanyId(companyId: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_company
            where company_id = ${arg(companyId)} and member_role in ('owner', 'admin', 'member') and deleted_at is null
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计组织关注者数
     * @param companyId 组织ID
     * @return 关注者数量
     */
    func countFollowersByCompanyId(companyId: String): Int64 {
        executor.setSql('''
            select count(*) from user_has_company
            where company_id = ${arg(companyId)} and member_role = 'follower' and deleted_at is null
        ''').first<Int64>() ?? 0
    }
}
