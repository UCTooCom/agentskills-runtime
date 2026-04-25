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
import magic.log.LogUtils

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========


/**
 * DbInfoDAO - db_info数据访问接口
 * 
 * 提供标准CRUD操作，遵循UCTOO V4 ORM规范
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
     * 插入dbInfo（id由数据库自动生成UUID）
     * @param entity dbInfo对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insertDbInfo(entity: DbInfoPO): String {
        let idStr = entity.id ?? ""
        let idValue = if (idStr.isEmpty()) {
            "DEFAULT"
        } else {
            "'${idStr}'"
        }
        let sqlPrefix = '''
            insert into db_info(
                id,
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
                '''
        let sqlSuffix = '''
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
        '''
        executor.setSql(sqlPrefix + idValue + sqlSuffix).singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询dbInfo
     * @param id dbInfoID
     * @return dbInfo对象（Option类型）
     */
    func findDbInfoById(id: String): Option<DbInfoPO> {
        executor.setSql('''
            select * from db_info where id = ${arg(id)}
        ''').first<DbInfoPO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新dbInfo
     * @param entity dbInfo对象
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
     * 软删除dbInfo
     * @param id dbInfoID
     * @return 影响行数
     */
    func softDeleteDbInfoById(id: String): Int64 {
        executor.setSql('''
            update db_info set deleted_at = ${arg(DateTime.now())} where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的dbInfo
     * @param id dbInfoID
     * @return 影响行数
     */
    func restoreDbInfoById(id: String): Int64 {
        executor.setSql('''
            update db_info set deleted_at = null where id = ${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除dbInfo
     * @param id dbInfoID
     * @return 影响行数
     */
    func deleteDbInfoById(id: String): Int64 {
        executor.setSql('''
            delete from db_info where id = ${arg(id)}
        ''').delete
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有dbInfo
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
     * 分页查询dbInfo列表（按创建者）
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
     * 查询所有dbInfo（不分页）
     * @return dbInfo列表
     */
    func listAllDbInfo(): ArrayList<DbInfoPO> {
        executor.setSql('''
            select * from db_info order by created_at desc
        ''').list<DbInfoPO>()
    }
    
    /**
     * 批量查询dbInfo
     * @param ids ID列表
     * @return dbInfo列表
     */
    func findDbInfoByIds(ids: ArrayList<String>): ArrayList<DbInfoPO> {
        executor.setSql('''
            select * from db_info where id ${IN(ids)}
        ''').list<DbInfoPO>()
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计创建者的dbInfo数量
     * @param creator 创建者ID
     * @return 数量
     */
    func countDbInfoByCreator(creator: String): Int64 {
        executor.setSql('''
            select count(*) from db_info where creator = ${arg(creator)}
        ''').first<Int64>() ?? 0
    }
    
    /**
     * 统计所有dbInfo数量
     * @return 数量
     */
    func countAllDbInfo(): Int64 {
        executor.setSql('''
            select count(*) from db_info
        ''').first<Int64>() ?? 0
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
            ''').singleFirst<String>()
            if (id.isSome()) {
                count = count + 1
            }
        }
        return count
    }
}
