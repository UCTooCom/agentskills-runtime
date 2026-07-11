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
import magic.app.models.uctoo.CompanyPO
import magic.log.LogUtils

/**
 * CompanyDAO - company数据访问接口
 *
 * 提供company表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface CompanyDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入company（id由数据库自动生成UUID）
     * @param entity CompanyPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertCompany(entity: CompanyPO): String {
        executor.setSql('''
            insert into company(
                company_name,
                region,
                social_credit_code,
                established_time,
                registered_capital,
                registered_address,
                mailing_address,
                legal_representative,
                legal_representativemobile,
                legal_representative_email,
                contact_name,
                contact_mobile,
                contact_email,
                contact_title,
                website,
                company_logo,
                associated_project_manager,
                verified,
                company_introduction,
                business_licence,
                creator,
                created_at,
                updated_at,
                deleted_at,
                org_description,
                member_count,
                task_count,
                follower_count,
                is_verified,
                org_type,
                tags,
                points_balance
            ) values(
${arg(entity.companyName)},
                ${arg(entity.region)},
                ${arg(entity.socialCreditCode)},
                ${arg(entity.establishedTime)},
                ${arg(entity.registeredCapital)},
                ${arg(entity.registeredAddress)},
                ${arg(entity.mailingAddress)},
                ${arg(entity.legalRepresentative)},
                ${arg(entity.legalRepresentativemobile)},
                ${arg(entity.legalRepresentativeEmail)},
                ${arg(entity.contactName)},
                ${arg(entity.contactMobile)},
                ${arg(entity.contactEmail)},
                ${arg(entity.contactTitle)},
                ${arg(entity.website)},
                ${arg(entity.companyLogo)},
                ${arg(entity.associatedProjectManager)},
                ${arg(entity.verified)},
                ${arg(entity.companyIntroduction)},
                ${arg(entity.businessLicence)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.orgDescription)},
                ${arg(entity.memberCount)},
                ${arg(entity.taskCount)},
                ${arg(entity.followerCount)},
                ${arg(entity.isVerified)},
                ${arg(entity.orgType)},
                ${arg(entity.tags)},
                ${arg(entity.pointsBalance)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询company
     * @param id companyID
     * @return company对象（Option类型）
     */
    func findCompanyById(id: String): Option<CompanyPO> {
        executor.setSql('''
            select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company where id = ${arg(id)}
        ''').first<CompanyPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新company
     * @param entity company对象
     * @return 影响行数
     */
    func updateCompany(entity: CompanyPO): Int64 {
        executor.setSql('''
            update company set
                company_name = ${arg(entity.companyName)},
                region = ${arg(entity.region)},
                social_credit_code = ${arg(entity.socialCreditCode)},
                established_time = ${arg(entity.establishedTime)},
                registered_capital = ${arg(entity.registeredCapital)},
                registered_address = ${arg(entity.registeredAddress)},
                mailing_address = ${arg(entity.mailingAddress)},
                legal_representative = ${arg(entity.legalRepresentative)},
                legal_representativemobile = ${arg(entity.legalRepresentativemobile)},
                legal_representative_email = ${arg(entity.legalRepresentativeEmail)},
                contact_name = ${arg(entity.contactName)},
                contact_mobile = ${arg(entity.contactMobile)},
                contact_email = ${arg(entity.contactEmail)},
                contact_title = ${arg(entity.contactTitle)},
                website = ${arg(entity.website)},
                company_logo = ${arg(entity.companyLogo)},
                associated_project_manager = ${arg(entity.associatedProjectManager)},
                verified = ${arg(entity.verified)},
                company_introduction = ${arg(entity.companyIntroduction)},
                business_licence = ${arg(entity.businessLicence)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                org_description = ${arg(entity.orgDescription)},
                member_count = ${arg(entity.memberCount)},
                task_count = ${arg(entity.taskCount)},
                follower_count = ${arg(entity.followerCount)},
                is_verified = ${arg(entity.isVerified)},
                org_type = ${arg(entity.orgType)},
                tags = ${arg(entity.tags)},
                points_balance = ${arg(entity.pointsBalance)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除company
     * @param id companyID
     * @return 影响行数
     */
    func softDeleteCompanyById(id: String): Int64 {
        executor.setSql('''
            update company set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的company
     * @param id companyID
     * @return 影响行数
     */
    func restoreCompanyById(id: String): Int64 {
        executor.setSql('''
            update company set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除company
     * @param id companyID
     * @return 影响行数
     */
    func deleteCompanyById(id: String): Int64 {
        executor.setSql('''
            delete from company where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有company
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllCompanyPage(page: Int64, size: Int64): Pagination<CompanyPO> {
        executor.page<CompanyPO>('''
            select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询company列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCompanyByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<CompanyPO> {
        executor.page<CompanyPO>('''
            select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有company（不分页）
     * @return company列表
     */
    func listAllCompany(): ArrayList<CompanyPO> {
        executor.setSql('''
            select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company order by created_at desc
        ''').list<CompanyPO>()
    }

    /**
     * 批量查询company
     * @param ids ID列表
     * @return company列表
     */
    func findCompanyByIds(ids: ArrayList<String>): ArrayList<CompanyPO> {
        if (ids.isEmpty()) {
            return ArrayList<CompanyPO>()
        }
        executor.setSql('''
            select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company where id ${IN(ids)}
        ''').list<CompanyPO>()
    }

    /**
     * 查询组织成员列表
     * @param companyId 组织ID
     * @return 成员列表（包含用户信息）
     */
    func findOrgMembers(companyId: String): ArrayList<HashMap<String, Any>> {
        var result = ArrayList<HashMap<String, Any>>()
        try {
            let rows = executor.setSql('''
                select u.id, u.nickname, u.email, uhc.member_role
                from user_has_company uhc
                join uctoo_user u on uhc.user_id = u.id
                where uhc.company_id = ${arg(companyId)} and uhc.deleted_at is null and u.deleted_at is null
                order by uhc.joined_at desc
            ''').mapList()
            result = rows
        } catch (e: Exception) {
            LogUtils.error("CompanyDAO", "findOrgMembers error: ${e.message}")
        }
        result
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的company数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countCompanyByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from company where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有company数量
     * @return 数量
     */
    func countAllCompany(): Int64 {
        executor.setSql('''
            select count(*) from company
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询company列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCompanyByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<CompanyPO> {
        let sql = StringBuilder()
        sql.append("select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company where 1=1")

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

        executor.page<CompanyPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除company
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteCompany(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update company set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除company
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteCompany(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from company where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询company（支持完整查询操作符）
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
    func findCompanyByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<CompanyPO> {
        let sql = StringBuilder()
        sql.append("select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<CompanyPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询company
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findCompanyByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<CompanyPO> {
        let fromClause = executor.FROM<CompanyPO>()

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
        fromClause.page<CompanyPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的company）
     * @return 影响行数
     */
    func emptyRecycleBinCompany(): Int64 {
        executor.setSql('''
            delete from company where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 公开组织分页查询（仅返回设置了 org_type 的组织）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param orgType 组织类型筛选（空字符串表示不筛选）
     * @param tag 标签筛选（空字符串表示不筛选，JSONB包含查询）
     * @param sortBy 排序方式：latest/popular/tasks
     * @return 分页结果
     */
    func queryPublicCompaniesWithPagination(
        page: Int64,
        pageSize: Int64,
        orgType: String,
        tag: String,
        sortBy: String
    ): Pagination<CompanyPO> {
        let sql = StringBuilder()
        sql.append("select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company where deleted_at is null and org_type is not null and org_type != ''")

        if (!orgType.isEmpty()) {
            sql.append(" and org_type = ${arg(orgType)}")
        }
        if (!tag.isEmpty()) {
            let tagJson = "[\"${tag}\"]"
            sql.append(" and tags @> ${arg(tagJson)}::jsonb")
        }

        // 排序
        var orderBy = " order by created_at desc"
        if (sortBy == "popular") {
            orderBy = " order by follower_count desc nulls last"
        } else if (sortBy == "tasks") {
            orderBy = " order by task_count desc nulls last"
        }
        sql.append(orderBy)

        executor.page<CompanyPO>(sql.toString(), pageSize, page: page)
    }

    /**
     * 查询公开组织详情（仅返回设置了 org_type 的组织）
     * @param companyId 组织ID
     * @return 组织对象
     */
    func findPublicCompanyById(companyId: String): Option<CompanyPO> {
        executor.setSql('''
            select id, company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_logo, associated_project_manager, verified, company_introduction, business_licence, creator, created_at, updated_at, deleted_at, org_description, member_count, task_count, follower_count, is_verified, org_type, tags, points_balance from company
            where id = ${arg(companyId)} and deleted_at is null and org_type is not null and length(org_type) > 0
        ''').first<CompanyPO>()
    }

    /**
     * 增加组织任务数
     * @param companyId 组织ID
     * @return 影响行数
     */
    func incrementTaskCount(companyId: String): Int64 {
        executor.setSql('''
            update company set task_count = coalesce(task_count, 0) + 1, updated_at = ${arg(DateTime.now())} where id = ${arg(companyId)}
        ''').update
    }

    /**
     * 减少组织任务数（不低于0）
     * @param companyId 组织ID
     * @return 影响行数
     */
    func decrementTaskCount(companyId: String): Int64 {
        executor.setSql('''
            update company set task_count = greatest(coalesce(task_count, 0) - 1, 0), updated_at = ${arg(DateTime.now())} where id = ${arg(companyId)}
        ''').update
    }

    /**
     * 增加组织关注者数
     * @param companyId 组织ID
     * @return 影响行数
     */
    func incrementFollowerCount(companyId: String): Int64 {
        executor.setSql('''
            update company set follower_count = coalesce(follower_count, 0) + 1, updated_at = ${arg(DateTime.now())} where id = ${arg(companyId)}
        ''').update
    }

    /**
     * 减少组织关注者数（不低于0）
     * @param companyId 组织ID
     * @return 影响行数
     */
    func decrementFollowerCount(companyId: String): Int64 {
        executor.setSql('''
            update company set follower_count = greatest(coalesce(follower_count, 0) - 1, 0), updated_at = ${arg(DateTime.now())} where id = ${arg(companyId)}
        ''').update
    }

    /**
     * 增加组织成员数
     * @param companyId 组织ID
     * @return 影响行数
     */
    func incrementMemberCount(companyId: String): Int64 {
        executor.setSql('''
            update company set member_count = coalesce(member_count, 0) + 1, updated_at = ${arg(DateTime.now())} where id = ${arg(companyId)}
        ''').update
    }

    /**
     * 减少组织成员数（不低于0）
     * @param companyId 组织ID
     * @return 影响行数
     */
    func decrementMemberCount(companyId: String): Int64 {
        executor.setSql('''
            update company set member_count = greatest(coalesce(member_count, 0) - 1, 0), updated_at = ${arg(DateTime.now())} where id = ${arg(companyId)}
        ''').update
    }

    /**
     * 统计公开组织总数（org_type 非空）
     * @return 组织数量
     */
    func countPublicCompanies(): Int64 {
        executor.setSql('''
            select count(*) from company where deleted_at is null and org_type is not null and length(org_type) > 0
        ''').first<Int64>() ?? 0
    }

    /**
     * 增加公司积分余额（充值/退还时使用）
     * @param companyId 公司ID
     * @param points 增加的积分数
     * @return 影响行数
     */
    func addPointsBalance(companyId: String, points: Int64): Int64 {
        executor.setSql('''
            update company set points_balance = points_balance + ${arg(points)}, updated_at = ${arg(DateTime.now())} where id = ${arg(companyId)}
        ''').update
    }

    /**
     * 扣减公司积分余额（冻结时使用）
     * @param companyId 公司ID
     * @param points 扣减的积分数
     * @return 影响行数
     */
    func deductPointsBalance(companyId: String, points: Int64): Int64 {
        executor.setSql('''
            update company set points_balance = points_balance - ${arg(points)}, updated_at = ${arg(DateTime.now())} where id = ${arg(companyId)} and points_balance >= ${arg(points)}
        ''').update
    }

    /**
     * 查询公司积分余额
     * @param companyId 公司ID
     * @return 积分余额（若公司不存在返回 None）
     */
    func findPointsBalance(companyId: String): Option<Int64> {
        executor.setSql('''
            select points_balance from company where id = ${arg(companyId)} and deleted_at is null
        ''').first<Int64>()
    }
}
