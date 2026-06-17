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
import magic.app.models.uctoo.UsageQuotasPO
import magic.log.LogUtils

/**
 * UsageQuotasDAO - usage_quotas数据访问接口
 *
 * 提供usage_quotas表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface UsageQuotasDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入usage_quotas（id由数据库自动生成UUID）
     * @param entity UsageQuotasPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertUsageQuotas(entity: UsageQuotasPO): String {
        executor.setSql('''
            insert into usage_quotas(
                target_type,
                target_id,
                quota_type,
                quota_limit,
                quota_used,
                quota_period_start,
                is_hard_limit,
                alert_threshold,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.targetType)},
                ${arg(entity.targetId)},
                ${arg(entity.quotaType)},
                ${arg(entity.quotaLimit)},
                ${arg(entity.quotaUsed)},
                ${arg(entity.quotaPeriodStart)},
                ${arg(entity.isHardLimit)},
                ${arg(entity.alertThreshold)},
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
     * 根据ID查询usage_quotas
     * @param id usage_quotasID
     * @return usage_quotas对象（Option类型）
     */
    func findUsageQuotasById(id: String): Option<UsageQuotasPO> {
        executor.setSql('''
            select id, target_type, target_id, quota_type, quota_limit, quota_used, quota_period_start, is_hard_limit, alert_threshold, creator, created_at, updated_at, deleted_at from usage_quotas where id = ${arg(id)}
        ''').first<UsageQuotasPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新usage_quotas
     * @param entity usage_quotas对象
     * @return 影响行数
     */
    func updateUsageQuotas(entity: UsageQuotasPO): Int64 {
        executor.setSql('''
            update usage_quotas set
                target_type = ${arg(entity.targetType)},
                target_id = ${arg(entity.targetId)},
                quota_type = ${arg(entity.quotaType)},
                quota_limit = ${arg(entity.quotaLimit)},
                quota_used = ${arg(entity.quotaUsed)},
                quota_period_start = ${arg(entity.quotaPeriodStart)},
                is_hard_limit = ${arg(entity.isHardLimit)},
                alert_threshold = ${arg(entity.alertThreshold)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除usage_quotas
     * @param id usage_quotasID
     * @return 影响行数
     */
    func softDeleteUsageQuotasById(id: String): Int64 {
        executor.setSql('''
            update usage_quotas set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的usage_quotas
     * @param id usage_quotasID
     * @return 影响行数
     */
    func restoreUsageQuotasById(id: String): Int64 {
        executor.setSql('''
            update usage_quotas set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除usage_quotas
     * @param id usage_quotasID
     * @return 影响行数
     */
    func deleteUsageQuotasById(id: String): Int64 {
        executor.setSql('''
            delete from usage_quotas where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有usage_quotas
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllUsageQuotasPage(page: Int64, size: Int64): Pagination<UsageQuotasPO> {
        executor.page<UsageQuotasPO>('''
            select id, target_type, target_id, quota_type, quota_limit, quota_used, quota_period_start, is_hard_limit, alert_threshold, creator, created_at, updated_at, deleted_at from usage_quotas order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询usage_quotas列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUsageQuotasByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<UsageQuotasPO> {
        executor.page<UsageQuotasPO>('''
            select id, target_type, target_id, quota_type, quota_limit, quota_used, quota_period_start, is_hard_limit, alert_threshold, creator, created_at, updated_at, deleted_at from usage_quotas where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有usage_quotas（不分页）
     * @return usage_quotas列表
     */
    func listAllUsageQuotas(): ArrayList<UsageQuotasPO> {
        executor.setSql('''
            select id, target_type, target_id, quota_type, quota_limit, quota_used, quota_period_start, is_hard_limit, alert_threshold, creator, created_at, updated_at, deleted_at from usage_quotas order by created_at desc
        ''').list<UsageQuotasPO>()
    }

    /**
     * 批量查询usage_quotas
     * @param ids ID列表
     * @return usage_quotas列表
     */
    func findUsageQuotasByIds(ids: ArrayList<String>): ArrayList<UsageQuotasPO> {
        if (ids.isEmpty()) {
            return ArrayList<UsageQuotasPO>()
        }
        executor.setSql('''
            select id, target_type, target_id, quota_type, quota_limit, quota_used, quota_period_start, is_hard_limit, alert_threshold, creator, created_at, updated_at, deleted_at from usage_quotas where id ${IN(ids)}
        ''').list<UsageQuotasPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的usage_quotas数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countUsageQuotasByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from usage_quotas where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有usage_quotas数量
     * @return 数量
     */
    func countAllUsageQuotas(): Int64 {
        executor.setSql('''
            select count(*) from usage_quotas
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询usage_quotas列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUsageQuotasByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<UsageQuotasPO> {
        let sql = StringBuilder()
        sql.append("select id, target_type, target_id, quota_type, quota_limit, quota_used, quota_period_start, is_hard_limit, alert_threshold, creator, created_at, updated_at, deleted_at from usage_quotas where 1=1")

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

        executor.page<UsageQuotasPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除usage_quotas
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteUsageQuotas(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update usage_quotas set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除usage_quotas
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteUsageQuotas(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from usage_quotas where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询usage_quotas（支持完整查询操作符）
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
    func findUsageQuotasByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UsageQuotasPO> {
        let sql = StringBuilder()
        sql.append("select id, target_type, target_id, quota_type, quota_limit, quota_used, quota_period_start, is_hard_limit, alert_threshold, creator, created_at, updated_at, deleted_at from usage_quotas")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<UsageQuotasPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询usage_quotas
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findUsageQuotasByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<UsageQuotasPO> {
        let fromClause = executor.FROM<UsageQuotasPO>()

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
        fromClause.page<UsageQuotasPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的usage_quotas）
     * @return 影响行数
     */
    func emptyRecycleBinUsageQuotas(): Int64 {
        executor.setSql('''
            delete from usage_quotas where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
