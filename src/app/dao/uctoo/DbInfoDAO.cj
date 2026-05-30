/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.uctoo.DbInfoPO

/**
 * DbInfoDAO - db_info数据访问接口
 *
 * 提供db_info表的标准CRUD操作，遵循UCTOO V4 ORM规范
 *
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface DbInfoDAO <: RootDAO {
    prop executor: SqlExecutor

    // ==================== 插入操作 ====================

    /**
     * 插入db_info（id由数据库自动生成UUID）
     * @param entity DbInfoPO对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertDbInfo(entity: DbInfoPO): String {
        executor.setSql('''
            insert into db_info(
                table_catalog,
                table_schema,
                table_name,
                column_name,
                column_default,
                is_nullable,
                data_type,
                vue_component_type,
                react_component_type,
                arkui_component_type,
                uniapp_component_type,
                rules,
                pattern,
                weight,
                creator,
                created_at,
                updated_at,
                deleted_at,
                placeholder,
                is_column_hidden,
                is_table_hidden,
                column_comment,
                ordinal_position,
                migration_id,
                character_maximum_length
            ) values(
${arg(entity.tableCatalog)},
                ${arg(entity.tableSchema)},
                ${arg(entity.dbTableName)},
                ${arg(entity.columnName)},
                ${arg(entity.columnDefault)},
                ${arg(entity.isNullable)},
                ${arg(entity.dataType)},
                ${arg(entity.vueComponentType)},
                ${arg(entity.reactComponentType)},
                ${arg(entity.arkuiComponentType)},
                ${arg(entity.uniappComponentType)},
                ${arg(entity.rules)},
                ${arg(entity.pattern)},
                ${arg(entity.weight)},
                ${arg(entity.creator)},
                ${arg(entity.createdAt)},
                ${arg(entity.updatedAt)},
                ${arg(entity.deletedAt)},
                ${arg(entity.placeholder)},
                ${arg(entity.isColumnHidden)},
                ${arg(entity.isTableHidden)},
                ${arg(entity.columnComment)},
                ${arg(entity.ordinalPosition)},
                ${arg(entity.migrationId)},
                ${arg(entity.characterMaximumLength)}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }

    // ==================== 单条查询 ====================

    /**
     * 根据ID查询db_info
     * @param id db_infoID
     * @return db_info对象（Option类型）
     */
    func findDbInfoById(id: String): Option<DbInfoPO> {
        executor.setSql('''
            select * from db_info where id = ${arg(id)}
        ''').first<DbInfoPO>()
    }

    // ==================== 更新操作 ====================

    /**
     * 更新db_info
     * @param entity db_info对象
     * @return 影响行数
     */
    func updateDbInfo(entity: DbInfoPO): Int64 {
        executor.setSql('''
            update db_info set
                table_catalog = ${arg(entity.tableCatalog)},
                table_schema = ${arg(entity.tableSchema)},
                table_name = ${arg(entity.dbTableName)},
                column_name = ${arg(entity.columnName)},
                column_default = ${arg(entity.columnDefault)},
                is_nullable = ${arg(entity.isNullable)},
                data_type = ${arg(entity.dataType)},
                vue_component_type = ${arg(entity.vueComponentType)},
                react_component_type = ${arg(entity.reactComponentType)},
                arkui_component_type = ${arg(entity.arkuiComponentType)},
                uniapp_component_type = ${arg(entity.uniappComponentType)},
                rules = ${arg(entity.rules)},
                pattern = ${arg(entity.pattern)},
                weight = ${arg(entity.weight)},
                creator = ${arg(entity.creator)},
                deleted_at = ${arg(entity.deletedAt)},
                placeholder = ${arg(entity.placeholder)},
                is_column_hidden = ${arg(entity.isColumnHidden)},
                is_table_hidden = ${arg(entity.isTableHidden)},
                column_comment = ${arg(entity.columnComment)},
                ordinal_position = ${arg(entity.ordinalPosition)},
                migration_id = ${arg(entity.migrationId)},
                character_maximum_length = ${arg(entity.characterMaximumLength)},
                updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    // ==================== 删除操作 ====================

    /**
     * 软删除db_info
     * @param id db_infoID
     * @return 影响行数
     */
    func softDeleteDbInfoById(id: String): Int64 {
        executor.setSql('''
            update db_info set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }

    /**
     * 恢复软删除的db_info
     * @param id db_infoID
     * @return 影响行数
     */
    func restoreDbInfoById(id: String): Int64 {
        executor.setSql('''
            update db_info set deleted_at = null where id = ${arg(id)}
        ''').update
    }

    /**
     * 硬删除db_info
     * @param id db_infoID
     * @return 影响行数
     */
    func deleteDbInfoById(id: String): Int64 {
        executor.setSql('''
            delete from db_info where id = ${arg(id)}
        ''').delete
    }

    // ==================== 列表查询 ====================

    /**
     * 分页查询所有db_info
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllDbInfoPage(page: Int64, size: Int64): Pagination<DbInfoPO> {
        executor.page<DbInfoPO>('''
            select * from db_info order by created_at desc
        ''', size, page: page)
    }

    /**
     * 分页查询db_info列表（按创建者）
     * @param creator 创建者ID
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDbInfoByCreatorPage(creator: String, page: Int64, size: Int64): Pagination<DbInfoPO> {
        executor.page<DbInfoPO>('''
            select * from db_info where creator = ${arg(creator)} order by created_at desc
        ''', size, page: page)
    }

    /**
     * 查询所有db_info（不分页）
     * @return db_info列表
     */
    func listAllDbInfo(): ArrayList<DbInfoPO> {
        executor.setSql('''
            select * from db_info order by created_at desc
        ''').list<DbInfoPO>()
    }

    /**
     * 批量查询db_info
     * @param ids ID列表
     * @return db_info列表
     */
    func findDbInfoByIds(ids: ArrayList<String>): ArrayList<DbInfoPO> {
        executor.setSql('''
            select * from db_info where id ${IN(ids)}
        ''').list<DbInfoPO>()
    }

    // ==================== 统计操作 ====================

    /**
     * 统计创建者的db_info数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countDbInfoByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from db_info where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }

    /**
     * 统计所有db_info数量
     * @return 数量
     */
    func countAllDbInfo(): Int64 {
        executor.setSql('''
            select count(*) from db_info
        ''').first<Int64>() ?? 0
    }


    /**
     * 分页查询db_info列表（带过滤条件）
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDbInfoByFilterPage(link: ?String, description: ?String, deletedAt: ?String, page: Int64, size: Int64): Pagination<DbInfoPO> {
        let sql = StringBuilder()
        sql.append("select * from db_info where 1=1")

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

        executor.page<DbInfoPO>(sql.toString(), size, page: page)
    }

    /**
     * 批量软删除db_info
     * @param ids ID列表
     * @return 影响行数
     */
    func batchSoftDeleteDbInfo(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            update db_info set deleted_at = ${arg(DateTime.now())} where id ${IN(ids)}
        ''').update
    }

    /**
     * 批量硬删除db_info
     * @param ids ID列表
     * @return 影响行数
     */
    func batchDeleteDbInfo(ids: ArrayList<String>): Int64 {
        if (ids.isEmpty()) {
            return 0
        }
        executor.setSql('''
            delete from db_info where id ${IN(ids)}
        ''').delete
    }

    /**
     * 动态条件查询db_info（支持完整查询操作符）
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
    func findDbInfoByDynamicCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<DbInfoPO> {
        let sql = StringBuilder()
        sql.append("select * from db_info")

        if (!whereClause.isEmpty()) {
            sql.append(" where ${whereClause}")
        }

        if (!orderByClause.isEmpty()) {
            sql.append(" order by ${orderByClause}")
        } else {
            sql.append(" order by created_at desc")
        }

        executor.page<DbInfoPO>(sql.toString(), size, page: page)
    }

    /**
     * 使用 f_orm Condition API 查询db_info
     *
     * @param whereClause WHERE 子句字符串
     * @param orderByClause ORDER BY 子句字符串
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findDbInfoByCondition(whereClause: String, orderByClause: String, page: Int64, size: Int64): Pagination<DbInfoPO> {
        let fromClause = executor.FROM<DbInfoPO>()

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
        fromClause.page<DbInfoPO>(size, page: page)
    }

    /**
     * 清空回收站（硬删除所有已软删除的db_info）
     * @return 影响行数
     */
    func emptyRecycleBinDbInfo(): Int64 {
        executor.setSql('''
            delete from db_info where deleted_at is not null
        ''').delete
    }

//#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 根据table_catalog删除dbInfo记录
     * @param tableCatalog 数据库名称
     * @return 删除的行数
     */
    func deleteDbInfoByTableCatalog(tableCatalog: String): Int64 {
        executor.setSql('''
            delete from db_info where table_catalog = ${arg(tableCatalog)}
        ''').delete
    }

    /**
     * 批量插入dbInfo记录（用于loadDbInfo）
     * @param entities dbInfo列表
     * @return 插入的行数
     */
    func batchInsertDbInfo(entities: ArrayList<DbInfoPO>): Int64 {
        var count: Int64 = 0
        for (entity in entities) {
            let id = executor.setSql('''
                insert into db_info(
                    table_catalog,
                    table_schema,
                    table_name,
                    column_name,
                    column_default,
                    is_nullable,
                    data_type,
                    vue_component_type,
                    react_component_type,
                    arkui_component_type,
                    uniapp_component_type,
                    rules,
                    pattern,
                    weight,
                    creator,
                    created_at,
                    updated_at,
                    deleted_at,
                    placeholder,
                    is_column_hidden,
                    is_table_hidden,
                    column_comment,
                    ordinal_position,
                    migration_id,
                    character_maximum_length
                ) values(
                    ${arg(entity.tableCatalog)},
                    ${arg(entity.tableSchema)},
                    ${arg(entity.dbTableName)},
                    ${arg(entity.columnName)},
                    ${arg(entity.columnDefault)},
                    ${arg(entity.isNullable)},
                    ${arg(entity.dataType)},
                    ${arg(entity.vueComponentType)},
                    ${arg(entity.reactComponentType)},
                    ${arg(entity.arkuiComponentType)},
                    ${arg(entity.uniappComponentType)},
                    ${arg(entity.rules)},
                    ${arg(entity.pattern)},
                    ${arg(entity.weight)},
                    ${arg(entity.creator)},
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP,
                    ${arg(entity.deletedAt)},
                    ${arg(entity.placeholder)},
                    ${arg(entity.isColumnHidden)},
                    ${arg(entity.isTableHidden)},
                    ${arg(entity.columnComment)},
                    ${arg(entity.ordinalPosition)},
                    ${arg(entity.migrationId)},
                    ${arg(entity.characterMaximumLength)}
                )
                returning id
            ''').singleFirst<String>()
            if (id.isSome()) {
                count = count + 1
            }
        }
        return count
    }
}
