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
import magic.app.models.uctoo.ModelPricingPO
import magic.log.LogUtils

/**
 * ModelPricingDAO - model_pricing数据访问接口
 *
 * 提供model_pricing表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface ModelPricingDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入model_pricing（id由数据库自动生成UUID）
     * @param entity ModelPricingPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertModelPricing(entity: ModelPricingPO): String {
        executor.setSql('''
            insert into model_pricing(
                provider,
                model,
                model_id,
                rate_prompt_per_million,
                rate_completion_per_million,
                rate_currency,
                rate_unit,
                is_active,
                effective_from,
                effective_to,
                source,
                remark,
                creator,
                created_at,
                updated_at,
                deleted_at
            ) values(
${arg(entity.provider)},
                ${arg(entity.model)},
                ${arg(entity.modelId)},
                ${arg(entity.ratePromptPerMillion)},
                ${arg(entity.rateCompletionPerMillion)},
                ${arg(entity.rateCurrency)},
                ${arg(entity.rateUnit)},
                ${arg(entity.isActive)},
                ${arg(entity.effectiveFrom)},
                ${arg(entity.effectiveTo)},
                ${arg(entity.source)},
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
     * 根据ID查询model_pricing
     * @param id model_pricingID
     * @return model_pricing对象（Option类型）
     */
    func findModelPricingById(id: String): Option<ModelPricingPO> {
        executor.setSql('''
            select id, provider, model, model_id, rate_prompt_per_million, rate_completion_per_million, rate_currency, rate_unit, is_active, effective_from, effective_to, source, remark, creator, created_at, updated_at, deleted_at from model_pricing where id = ${arg(id)}
        ''').first<ModelPricingPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新model_pricing
     * @param entity model_pricing对象
     * @return 影响行数
     */
    func updateModelPricing(entity: ModelPricingPO): Int64 {
        executor.setSql('''
            update model_pricing set
                provider = ${arg(entity.provider)},
                model = ${arg(entity.model)},
                model_id = ${arg(entity.modelId)},
                rate_prompt_per_million = ${arg(entity.ratePromptPerMillion)},
                rate_completion_per_million = ${arg(entity.rateCompletionPerMillion)},
                rate_currency = ${arg(entity.rateCurrency)},
                rate_unit = ${arg(entity.rateUnit)},
                is_active = ${arg(entity.isActive)},
                effective_from = ${arg(entity.effectiveFrom)},
                effective_to = ${arg(entity.effectiveTo)},
                source = ${arg(entity.source)},
                remark = ${arg(entity.remark)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除model_pricing
     * @param id model_pricingID
     * @return 影响行数
     */
    func softDeleteModelPricingById(id: String): Int64 {
        executor.setSql('''
            update model_pricing set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的model_pricing
     * @param id model_pricingID
     * @return 影响行数
     */
    func restoreModelPricingById(id: String): Int64 {
        executor.setSql('''
            update model_pricing set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除model_pricing
     * @param id model_pricingID
     * @return 影响行数
     */
    func deleteModelPricingById(id: String): Int64 {
        executor.setSql('''
            delete from model_pricing where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有model_pricing
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllModelPricingPage(page: Int64, size: Int64): Pagination<ModelPricingPO> {
        executor.page<ModelPricingPO>('''
            select id, provider, model, model_id, rate_prompt_per_million, rate_completion_per_million, rate_currency, rate_unit, is_active, effective_from, effective_to, source, remark, creator, created_at, updated_at, deleted_at from model_pricing order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询model_pricing列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findModelPricingByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<ModelPricingPO> {
        executor.page<ModelPricingPO>('''
            select id, provider, model, model_id, rate_prompt_per_million, rate_completion_per_million, rate_currency, rate_unit, is_active, effective_from, effective_to, source, remark, creator, created_at, updated_at, deleted_at from model_pricing where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有model_pricing（不分页）
     * @return model_pricing列表
     */
    func listAllModelPricing(): ArrayList<ModelPricingPO> {
        executor.setSql('''
            select id, provider, model, model_id, rate_prompt_per_million, rate_completion_per_million, rate_currency, rate_unit, is_active, effective_from, effective_to, source, remark, creator, created_at, updated_at, deleted_at from model_pricing order by created_at desc
        ''').list<ModelPricingPO>()
    }

    /**
     * 批量查询model_pricing
     * @param ids ID列表
     * @return model_pricing列表
     */
    func findModelPricingByIds(ids: ArrayList<String>): ArrayList<ModelPricingPO> {
        if (ids.isEmpty()) {
            return ArrayList<ModelPricingPO>()
        }
        executor.setSql('''
            select id, provider, model, model_id, rate_prompt_per_million, rate_completion_per_million, rate_currency, rate_unit, is_active, effective_from, effective_to, source, remark, creator, created_at, updated_at, deleted_at from model_pricing where id ${IN(ids)}
        ''').list<ModelPricingPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的model_pricing数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countModelPricingByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from model_pricing where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有model_pricing数量
     * @return 数量
     */
    func countAllModelPricing(): Int64 {
        executor.setSql('''
            select count(*) from model_pricing
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询model_pricing列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findModelPricingByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<ModelPricingPO> {
        let sql = StringBuilder()
        sql.append("select id, provider, model, model_id, rate_prompt_per_million, rate_completion_per_million, rate_currency, rate_unit, is_active, effective_from, effective_to, source, remark, creator, created_at, updated_at, deleted_at from model_pricing where 1=1")

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

        executor.page<ModelPricingPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除model_pricing
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteModelPricing(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update model_pricing set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除model_pricing
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteModelPricing(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from model_pricing where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询model_pricing（支持完整查询操作符）
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
    func findModelPricingByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<ModelPricingPO> {
        let sql = StringBuilder()
        sql.append("select id, provider, model, model_id, rate_prompt_per_million, rate_completion_per_million, rate_currency, rate_unit, is_active, effective_from, effective_to, source, remark, creator, created_at, updated_at, deleted_at from model_pricing")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<ModelPricingPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询model_pricing
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findModelPricingByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<ModelPricingPO> {
        let fromClause = executor.FROM<ModelPricingPO>()

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
        fromClause.page<ModelPricingPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的model_pricing）
     * @return 影响行数
     */
    func emptyRecycleBinModelPricing(): Int64 {
        executor.setSql('''
            delete from model_pricing where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========
}
