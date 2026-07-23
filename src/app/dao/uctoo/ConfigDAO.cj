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
import magic.app.models.uctoo.ConfigPO
import magic.log.LogUtils

/**
 * ConfigDAO - config数据访问接口
 *
 * 提供config表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface ConfigDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入config（id由数据库自动生成UUID）
     * @param entity ConfigPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertConfig(entity: ConfigPO): String {
        executor.setSql('''
            insert into config(
                name,
                parent_id,
                component,
                "key",
                value,
                status,
                creator,
                created_at,
                updated_at,
                deleted_at,
                env_key,
                config_group,
                config_type,
                is_sensitive,
                default_value,
                validation_rule,
                description,
                display_order,
                editable,
                last_synced_at
            ) values(
${arg(entity.name)},
                ${arg(entity.parentId)},
                ${arg(entity.component)},
                ${arg(entity.key)},
                ${arg(entity.value)},
                ${arg(entity.status)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.envKey)},
                ${arg(entity.configGroup)},
                ${arg(entity.configType)},
                ${arg(entity.isSensitive)},
                ${arg(entity.defaultValue)},
                ${arg(entity.validationRule)},
                ${arg(entity.description)},
                ${arg(entity.displayOrder)},
                ${arg(entity.editable)},
                ${arg(entity.lastSyncedAt)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询config
     * @param id configID
     * @return config对象（Option类型）
     */
    func findConfigById(id: String): Option<ConfigPO> {
        executor.setSql('''
            select id, name, parent_id, component, coalesce("key", '') as "key", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config where id = ${arg(id)}
        ''').first<ConfigPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新config
     * @param entity config对象
     * @return 影响行数
     */
    func updateConfig(entity: ConfigPO): Int64 {
        executor.setSql('''
            update config set
                name = ${arg(entity.name)},
                parent_id = ${arg(entity.parentId)},
                component = ${arg(entity.component)},
                "key" = ${arg(entity.key)},
                value = ${arg(entity.value)},
                status = ${arg(entity.status)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                env_key = ${arg(entity.envKey)},
                config_group = ${arg(entity.configGroup)},
                config_type = ${arg(entity.configType)},
                is_sensitive = ${arg(entity.isSensitive)},
                default_value = ${arg(entity.defaultValue)},
                validation_rule = ${arg(entity.validationRule)},
                description = ${arg(entity.description)},
                display_order = ${arg(entity.displayOrder)},
                editable = ${arg(entity.editable)},
                last_synced_at = ${arg(entity.lastSyncedAt)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除config
     * @param id configID
     * @return 影响行数
     */
    func softDeleteConfigById(id: String): Int64 {
        executor.setSql('''
            update config set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的config
     * @param id configID
     * @return 影响行数
     */
    func restoreConfigById(id: String): Int64 {
        executor.setSql('''
            update config set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除config
     * @param id configID
     * @return 影响行数
     */
    func deleteConfigById(id: String): Int64 {
        executor.setSql('''
            delete from config where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有config
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllConfigPage(page: Int64, size: Int64): Pagination<ConfigPO> {
        executor.page<ConfigPO>('''
            select id, name, parent_id, component, coalesce("key", '') as "key", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询config列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findConfigByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<ConfigPO> {
        executor.page<ConfigPO>('''
            select id, name, parent_id, component, coalesce("key", '') as "key", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有config（不分页）
     * @return config列表
     */
    func listAllConfig(): ArrayList<ConfigPO> {
        executor.setSql('''
            select id, name, parent_id, component, coalesce("key", '') as "key", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config order by created_at desc
        ''').list<ConfigPO>()
    }

    /**
     * 批量查询config
     * @param ids ID列表
     * @return config列表
     */
    func findConfigByIds(ids: ArrayList<String>): ArrayList<ConfigPO> {
        if (ids.isEmpty()) {
            return ArrayList<ConfigPO>()
        }
        executor.setSql('''
            select id, name, parent_id, component, coalesce("key", '') as "key", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config where id ${IN(ids)}
        ''').list<ConfigPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的config数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countConfigByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from config where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有config数量
     * @return 数量
     */
    func countAllConfig(): Int64 {
        executor.setSql('''
            select count(*) from config
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询config列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findConfigByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<ConfigPO> {
        let sql = StringBuilder()
        sql.append("select id, name, parent_id, component, coalesce(\"key\", '') as \"key\", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config where 1=1")

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

        executor.page<ConfigPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除config
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteConfig(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update config set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除config
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteConfig(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from config where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询config（支持完整查询操作符）
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
    func findConfigByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<ConfigPO> {
        let sql = StringBuilder()
        sql.append("select id, name, parent_id, component, coalesce(\"key\", '') as \"key\", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<ConfigPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询config
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findConfigByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<ConfigPO> {
        let fromClause = executor.FROM<ConfigPO>()

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
        fromClause.page<ConfigPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的config）
     * @return 影响行数
     */
    func emptyRecycleBinConfig(): Int64 {
        executor.setSql('''
            delete from config where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    func findConfigByEnvKey(envKey: String): Option<ConfigPO> {
        executor.setSql('''
            select id, name, parent_id, component, coalesce("key", '') as "key", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config where env_key = ${arg(envKey)} and deleted_at is null
        ''').first<ConfigPO>()
    }

    func findConfigsByGroup(configGroup: String): ArrayList<ConfigPO> {
        executor.setSql('''
            select id, name, parent_id, component, coalesce("key", '') as "key", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config where config_group = ${arg(configGroup)} and deleted_at is null order by display_order, created_at
        ''').list<ConfigPO>()
    }

    func findAllEnvConfigs(): ArrayList<ConfigPO> {
        executor.setSql('''
            select id, name, parent_id, component, coalesce("key", '') as "key", value, status, creator, created_at, updated_at, deleted_at, env_key, config_group, config_type, is_sensitive, default_value, validation_rule, description, display_order, editable, last_synced_at from config where env_key is not null and deleted_at is null order by config_group, display_order
        ''').list<ConfigPO>()
    }

    func upsertByEnvKey(entity: ConfigPO): Int64 {
        let existing = findConfigByEnvKey(entity.envKey.getOrThrow())
        match (existing) {
            case Some(_) =>
                updateConfig(entity)
            case None =>
                let id = insertConfig(entity)
                if (id.isEmpty()) { 0 } else { 1 }
        }
    }
}
