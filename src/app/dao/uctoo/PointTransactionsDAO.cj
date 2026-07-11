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
import magic.app.models.uctoo.PointTransactionsPO
import magic.log.LogUtils

/**
 * PointTransactionsDAO - point_transactions数据访问接口
 *
 * 提供point_transactions表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface PointTransactionsDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入point_transactions（id由数据库自动生成UUID）
     * @param entity PointTransactionsPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertPointTransactions(entity: PointTransactionsPO): String {
        executor.setSql('''
            insert into point_transactions(
                account_type,
                account_id,
                transaction_type,
                amount,
                balance_before,
                balance_after,
                task_id,
                counterparty_type,
                counterparty_id,
                description,
                remark,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.accountType)},
                ${arg(entity.accountId)},
                ${arg(entity.transactionType)},
                ${arg(entity.amount)},
                ${arg(entity.balanceBefore)},
                ${arg(entity.balanceAfter)},
                ${arg(entity.taskId)},
                ${arg(entity.counterpartyType)},
                ${arg(entity.counterpartyId)},
                ${arg(entity.description)},
                ${arg(entity.remark)},
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
     * 根据ID查询point_transactions
     * @param id point_transactionsID
     * @return point_transactions对象（Option类型）
     */
    func findPointTransactionsById(id: String): Option<PointTransactionsPO> {
        executor.setSql('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions where id = ${arg(id)}
        ''').first<PointTransactionsPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新point_transactions
     * @param entity point_transactions对象
     * @return 影响行数
     */
    func updatePointTransactions(entity: PointTransactionsPO): Int64 {
        executor.setSql('''
            update point_transactions set
                account_type = ${arg(entity.accountType)},
                account_id = ${arg(entity.accountId)},
                transaction_type = ${arg(entity.transactionType)},
                amount = ${arg(entity.amount)},
                balance_before = ${arg(entity.balanceBefore)},
                balance_after = ${arg(entity.balanceAfter)},
                task_id = ${arg(entity.taskId)},
                counterparty_type = ${arg(entity.counterpartyType)},
                counterparty_id = ${arg(entity.counterpartyId)},
                description = ${arg(entity.description)},
                remark = ${arg(entity.remark)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除point_transactions
     * @param id point_transactionsID
     * @return 影响行数
     */
    func softDeletePointTransactionsById(id: String): Int64 {
        executor.setSql('''
            update point_transactions set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的point_transactions
     * @param id point_transactionsID
     * @return 影响行数
     */
    func restorePointTransactionsById(id: String): Int64 {
        executor.setSql('''
            update point_transactions set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除point_transactions
     * @param id point_transactionsID
     * @return 影响行数
     */
    func deletePointTransactionsById(id: String): Int64 {
        executor.setSql('''
            delete from point_transactions where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有point_transactions
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllPointTransactionsPage(page: Int64, size: Int64): Pagination<PointTransactionsPO> {
        executor.page<PointTransactionsPO>('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询point_transactions列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findPointTransactionsByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<PointTransactionsPO> {
        executor.page<PointTransactionsPO>('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有point_transactions（不分页）
     * @return point_transactions列表
     */
    func listAllPointTransactions(): ArrayList<PointTransactionsPO> {
        executor.setSql('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions order by created_at desc
        ''').list<PointTransactionsPO>()
    }

    /**
     * 批量查询point_transactions
     * @param ids ID列表
     * @return point_transactions列表
     */
    func findPointTransactionsByIds(ids: ArrayList<String>): ArrayList<PointTransactionsPO> {
        if (ids.isEmpty()) {
            return ArrayList<PointTransactionsPO>()
        }
        executor.setSql('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions where id ${IN(ids)}
        ''').list<PointTransactionsPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的point_transactions数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countPointTransactionsByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from point_transactions where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有point_transactions数量
     * @return 数量
     */
    func countAllPointTransactions(): Int64 {
        executor.setSql('''
            select count(*) from point_transactions
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询point_transactions列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findPointTransactionsByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<PointTransactionsPO> {
        let sql = StringBuilder()
        sql.append("select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions where 1=1")

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

        executor.page<PointTransactionsPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除point_transactions
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeletePointTransactions(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update point_transactions set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除point_transactions
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeletePointTransactions(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from point_transactions where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询point_transactions（支持完整查询操作符）
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
    func findPointTransactionsByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<PointTransactionsPO> {
        let sql = StringBuilder()
        sql.append("select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<PointTransactionsPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询point_transactions
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findPointTransactionsByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<PointTransactionsPO> {
        let fromClause = executor.FROM<PointTransactionsPO>()

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
        fromClause.page<PointTransactionsPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的point_transactions）
     * @return 影响行数
     */
    func emptyRecycleBinPointTransactions(): Int64 {
        executor.setSql('''
            delete from point_transactions where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    // ==================== 积分系统定制查询方法 ====================

    /**
     * 分页查询账户积分流水（按 accountId + accountType）
     * @param accountId 账户ID（用户ID或公司ID）
     * @param accountType 账户类型（user/company）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @return 分页结果
     */
    func findTransactionsByAccountIdPage(accountId: String, accountType: String, page: Int64, pageSize: Int64): Pagination<PointTransactionsPO> {
        executor.page<PointTransactionsPO>('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions where account_id = ${arg(accountId)} and account_type = ${arg(accountType)} and deleted_at is null order by created_at desc
        ''', pageSize, page: page)
    }

    /**
     * 分页查询账户积分流水（按 accountId + accountType + transactionType）
     * @param accountId 账户ID
     * @param accountType 账户类型
     * @param transactionType 交易类型（freeze/refund/settle_pay/settle/charge等）
     * @param page 页码
     * @param pageSize 每页大小
     * @return 分页结果
     */
    func findTransactionsByAccountIdAndTypePage(accountId: String, accountType: String, transactionType: String, page: Int64, pageSize: Int64): Pagination<PointTransactionsPO> {
        executor.page<PointTransactionsPO>('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions where account_id = ${arg(accountId)} and account_type = ${arg(accountType)} and transaction_type = ${arg(transactionType)} and deleted_at is null order by created_at desc
        ''', pageSize, page: page)
    }

    /**
     * 按任务ID查询积分流水（用于任务结算追溯）
     * @param taskId 任务ID
     * @return 流水列表
     */
    func findTransactionsByTaskId(taskId: String): ArrayList<PointTransactionsPO> {
        executor.setSql('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions where task_id = ${arg(taskId)} and deleted_at is null order by created_at asc
        ''').list<PointTransactionsPO>()
    }

    /**
     * 统计账户流水数量
     * @param accountId 账户ID
     * @param accountType 账户类型
     * @return 数量
     */
    func countTransactionsByAccountId(accountId: String, accountType: String): Int64 {
        executor.setSql('''
            select count(*) from point_transactions where account_id = ${arg(accountId)} and account_type = ${arg(accountType)} and deleted_at is null
        ''').first<Int64>() ?? 0
    }

    /**
     * 查询账户最近一条流水（用于获取 balance_after 作为下次操作的 balance_before）
     * @param accountId 账户ID
     * @param accountType 账户类型
     * @return 最近流水（Option类型）
     */
    func findLatestTransactionByAccountId(accountId: String, accountType: String): Option<PointTransactionsPO> {
        executor.setSql('''
            select id, account_type, account_id, transaction_type, amount, balance_before, balance_after, task_id, counterparty_type, counterparty_id, description, remark, creator, created_at, updated_at, deleted_at from point_transactions where account_id = ${arg(accountId)} and account_type = ${arg(accountType)} and deleted_at is null order by created_at desc limit 1
        ''').first<PointTransactionsPO>()
    }
}
