/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.DbInfoPO
import magic.app.models.uctoo.DbConnectionPO
import magic.app.dao.uctoo.DbInfoDAO
import magic.app.dao.uctoo.DbConnectionDAO
import f_orm.sql.SqlExecutor
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.log.LogUtils

/**
 * DbInfoService - db_info服务类
 * 
 * 提供db_info相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class DbInfoService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }
    
    // 查询参数解析服务
    private let requestParser = RequestParserService()
    
    public init() {}

    /**
     * 创建dbInfo
     * @param entity dbInfo对象
     * @return 创建结果
     */
    public func create(entity: DbInfoPO): APIResult<DbInfoPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            // id 由数据库自动生成 UUID
            let id = getExecutor().insertDbInfo(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<DbInfoPO>(entity)
            } else {
                return APIResult<DbInfoPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<DbInfoPO>(false, e.message)
        }
    }
    
    /**
     * 更新dbInfo
     * @param entityId dbInfoID
     * @param entity dbInfo对象（只包含要更新的字段）
     * @return 更新结果
     */
    public func update(entityId: String, entity: DbInfoPO): APIResult<DbInfoPO> {
        try {
            let existing = getExecutor().findDbInfoById(entityId)
            
            if (existing.isNone()) {
                return APIResult<DbInfoPO>(false, "dbInfo不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.tableCatalog.size > 0) {
                existingEntity.tableCatalog = entity.tableCatalog
            }
            if (entity.tableSchema.isSome()) {
                existingEntity.tableSchema = entity.tableSchema
            }
            if (entity.dbTableName.size > 0) {
                existingEntity.dbTableName = entity.dbTableName
            }
            if (entity.columnName.size > 0) {
                existingEntity.columnName = entity.columnName
            }
            if (entity.columnDefault.isSome()) {
                existingEntity.columnDefault = entity.columnDefault
            }
            if (entity.isNullable.size > 0) {
                existingEntity.isNullable = entity.isNullable
            }
            if (entity.dataType.isSome()) {
                existingEntity.dataType = entity.dataType
            }
            if (entity.vueComponentType.isSome()) {
                existingEntity.vueComponentType = entity.vueComponentType
            }
            if (entity.reactComponentType.isSome()) {
                existingEntity.reactComponentType = entity.reactComponentType
            }
            if (entity.arkuiComponentType.isSome()) {
                existingEntity.arkuiComponentType = entity.arkuiComponentType
            }
            if (entity.uniappComponentType.isSome()) {
                existingEntity.uniappComponentType = entity.uniappComponentType
            }
            if (entity.rules.isSome()) {
                existingEntity.rules = entity.rules
            }
            if (entity.pattern.isSome()) {
                existingEntity.pattern = entity.pattern
            }
            existingEntity.weight = entity.weight
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.placeholder.isSome()) {
                existingEntity.placeholder = entity.placeholder
            }
            if (entity.isColumnHidden.size > 0) {
                existingEntity.isColumnHidden = entity.isColumnHidden
            }
            if (entity.isTableHidden.size > 0) {
                existingEntity.isTableHidden = entity.isTableHidden
            }
            if (entity.columnComment.isSome()) {
                existingEntity.columnComment = entity.columnComment
            }
            existingEntity.ordinalPosition = entity.ordinalPosition
            if (entity.migrationId.isSome()) {
                existingEntity.migrationId = entity.migrationId
            }
            existingEntity.characterMaximumLength = entity.characterMaximumLength
            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateDbInfo(existingEntity)
            
            if (rows > 0) {
                return APIResult<DbInfoPO>(existingEntity)
            } else {
                return APIResult<DbInfoPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<DbInfoPO>(false, e.message)
        }
    }
    
    /**
     * 批量更新dbInfo
     * @param entities dbInfo列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<DbInfoPO>): APIResult<ArrayList<DbInfoPO>> {
        try {
            let updatedEntities = ArrayList<DbInfoPO>()
            
            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateDbInfo(entity)
                
                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }
            
            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<DbInfoPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<DbInfoPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<DbInfoPO>>(false, e.message)
        }
    }
    
    /**
     * 删除dbInfo
     * @param entityId dbInfoID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findDbInfoById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "dbInfo不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteDbInfoById(entityId)
            } else {
                rows = getExecutor().softDeleteDbInfoById(entityId)
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
    
    /**
     * 批量删除dbInfo
     * @param ids dbInfoID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                let existing = getExecutor().findDbInfoById(id)
                if (existing.isSome()) {
                    if (force) {
                        rows = rows + getExecutor().deleteDbInfoById(id)
                    } else {
                        rows = rows + getExecutor().softDeleteDbInfoById(id)
                    }
                }
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "批量删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
    
    /**
     * 恢复软删除的dbInfo
     * @param entityId dbInfoID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<DbInfoPO> {
        try {
            let rows = getExecutor().restoreDbInfoById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findDbInfoById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<DbInfoPO>(entity)
                } else {
                    return APIResult<DbInfoPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<DbInfoPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<DbInfoPO>(false, e.message)
        }
    }
    
    /**
     * 批量恢复软删除的dbInfo
     * @param ids dbInfoID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreDbInfoById(id)
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "批量恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
    
    /**
     * 根据ID获取dbInfo
     * 
     * 设计说明：
     * - 通过ID获取dbInfo时，返回该ID对应的数据，无论是否被软删除
     * - 这样API使用方可以实现回收站功能，恢复软删除的数据
     * - 软删除数据是否显示由API使用方根据业务需求决定
     * 
     * @param entityId dbInfoID
     * @return dbInfo对象
     */
    public func getById(entityId: String): APIResult<DbInfoPO> {
        try {
            LogUtils.info("DbInfoService", "=== DbInfoService.getById() called with id: ${entityId} ===")
            let result = getExecutor().findDbInfoById(entityId)
            LogUtils.info("DbInfoService", "=== findDbInfoById result: ${result.isSome()} ===")
            
            if (let Some(entity) <- result) {
                LogUtils.info("DbInfoService", "=== DbInfo found, id: ${entity.id} ===")
                return APIResult<DbInfoPO>(entity)
            } else {
                LogUtils.info("DbInfoService", "=== DbInfo not found for id: ${entityId} ===")
                return APIResult<DbInfoPO>(false, "未找到该dbInfo")
            }
        } catch (e: Exception) {
            LogUtils.error("DbInfoService", "=== DbInfoService.getById() exception: ${e.message} ===")
            return APIResult<DbInfoPO>(false, e.message)
        }
    }
    
    /**
     * 获取dbInfo列表（分页）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return dbInfo列表和总数
     */
    public func getList(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DbInfoPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllDbInfoPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取dbInfo列表（带跳过参数）
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return dbInfo列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DbInfoPO>, Int64) {
        // TODO: filter参数需要实现JSON解析和动态WHERE条件构建
        // 当前版本暂不支持filter，只支持基本的分页查询
        let pagination = getExecutor().findAllDbInfoPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 获取所有dbInfo列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return dbInfo列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<DbInfoPO>, Int64) {
        let pagination = getExecutor().findAllDbInfoPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    /**
     * 批量获取dbInfo
     * @param ids ID列表
     * @return dbInfo列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<DbInfoPO> {
        getExecutor().findDbInfoByIds(ids)
    }
    
    /**
     * 统计用户的dbInfo数量
     * @param userId 用户ID
     * @return dbInfo数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countDbInfoByCreator(userId)
    }
    
    /**
     * 统计所有dbInfo数量
     * @return dbInfo数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllDbInfo()
    }
    
    //#endregion AutoCreateCode

    /**
     * 从数据库结构获取数据库信息并添加到db_info表
     * 参考 backend v3 loadDbInfo.ts 实现
     * @param dbName 数据库名称
     * @return 操作结果
     */
    public func loadDbInfo(dbName: String): APIResult<Int32> {
        try {
            LogUtils.info("DbInfoService", "=== loadDbInfo called with dbName: ${dbName} ===")

            // 优先从db_connection表获取数据库连接信息
            let executor = getExecutor()
            let connectionData = executor.findByDatabaseName(dbName)
            var provider: String = "postgresql"
            var connection: ?DbConnectionPO = None<DbConnectionPO>

            if (connectionData.size > 0) {
                connection = Some<DbConnectionPO>(connectionData[0])
                provider = connection.getOrThrow().provider
                LogUtils.info("DbInfoService", "=== Using connection from db_connection table: ${provider} ===")
            } else {
                LogUtils.info("DbInfoService", "=== Using default connection: ${provider} ===")
            }

            // 连接PostgreSQL数据库读取数据库信息
            if (provider == "postgresql") {
                LogUtils.info("DbInfoService", "=== Connecting to PostgreSQL database: ${dbName} ===")

                let checkDbSql = """
                    SELECT datname FROM pg_catalog.pg_database WHERE lower(datname) = lower('${dbName}')
                """
                let dbExists = executor.setSql(checkDbSql).singleFirst<String>()

                if (dbExists.isNone()) {
                    LogUtils.error("DbInfoService", "=== Database ${dbName} does not exist ===")
                    return APIResult<Int32>(false, "数据库 ${dbName} 不存在")
                }

                // 先清空db_info表
                executor.deleteDbInfoByTableCatalog(dbName)
                LogUtils.info("DbInfoService", "=== Deleted existing db_info records for ${dbName} ===")

                let columnInfoSql = """
                    SELECT
                        c.table_catalog,
                        c.table_schema,
                        c.table_name,
                        c.column_name,
                        c.ordinal_position,
                        c.column_default,
                        c.is_nullable,
                        c.data_type,
                        c.character_maximum_length,
                        pgd.description AS column_comment
                    FROM
                        information_schema.columns c
                    LEFT JOIN
                        pg_catalog.pg_class cl ON (
                            c.table_name = cl.relname
                        )
                    LEFT JOIN
                        pg_catalog.pg_namespace n ON (
                            cl.relnamespace = n.oid
                        )
                    LEFT JOIN
                        pg_catalog.pg_attribute a ON (
                            n.nspname = c.table_schema AND
                            cl.oid = a.attrelid AND
                            c.column_name = a.attname
                        )
                    LEFT JOIN
                        pg_catalog.pg_description pgd ON (
                            pgd.objoid = cl.oid AND
                            pgd.objsubid = a.attnum
                        )
                    WHERE
                        c.table_schema NOT IN ('pg_catalog', 'information_schema')
                    ORDER BY
                        c.table_schema,
                        c.table_name,
                        c.ordinal_position
                """

                let dbInfoList = executor.setSql(columnInfoSql).list<DbInfoPO>()
                LogUtils.info("DbInfoService", "=== Retrieved ${dbInfoList.size} columns from information_schema ===")

                var insertedCount: Int64 = 0
                for (dbInfo in dbInfoList) {
                    // 打印查询结果中的id值
                    LogUtils.info("DbInfoService", "=== Query result - table: ${dbInfo.dbTableName}, column: ${dbInfo.columnName}, id from query: ${dbInfo.id} ===")
                    
                    // 为每条记录生成UUID作为id，确保插入时id字段有值
                    let uuid = generateUUID()
                    LogUtils.info("DbInfoService", "=== Processing column: ${dbInfo.dbTableName}.${dbInfo.columnName}, generated UUID: ${uuid} ===")
                    
                    dbInfo.id = Some<String>(uuid)
                    dbInfo.tableCatalog = dbName
                    dbInfo.createdAt = DateTime.now()
                    dbInfo.updatedAt = DateTime.now()
                    dbInfo.deletedAt = None<DateTime>
                    dbInfo.migrationId = Some<String>("loadDbInfo")
                    dbInfo.isColumnHidden = ""
                    dbInfo.isTableHidden = ""
                    
                    LogUtils.info("DbInfoService", "=== Before insert - id: ${dbInfo.id}, tableCatalog: ${dbInfo.tableCatalog}, tableName: ${dbInfo.dbTableName}, columnName: ${dbInfo.columnName} ===")
                    
                    try {
                        let id = executor.insertDbInfo(dbInfo)
                        LogUtils.info("DbInfoService", "=== Insert result: ${id} ===")
                        if (id != "") {
                            insertedCount = insertedCount + 1
                        }
                    } catch (e: Exception) {
                        LogUtils.error("DbInfoService", "=== Insert failed for ${dbInfo.dbTableName}.${dbInfo.columnName}: ${e.message} ===")
                        LogUtils.error("DbInfoService", "=== Exception stack trace: ${e} ===")
                    }
                }

                LogUtils.info("DbInfoService", "=== Inserted ${insertedCount} records into db_info ===")
                return APIResult<Int32>(Int32(insertedCount))
            }
            // 连接MySQL数据库读取数据库信息
            else if (provider == "mysql") {
                LogUtils.info("DbInfoService", "=== Connecting to MySQL database: ${dbName} ===")

                let checkDbSql = """
                    SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${dbName}'
                """
                let dbExists = executor.setSql(checkDbSql).singleFirst<String>()

                if (dbExists.isNone()) {
                    LogUtils.error("DbInfoService", "=== Database ${dbName} does not exist ===")
                    return APIResult<Int32>(false, "数据库 ${dbName} 不存在")
                }

                // 先清空db_info表
                executor.deleteDbInfoByTableCatalog(dbName)
                LogUtils.info("DbInfoService", "=== Deleted existing db_info records for ${dbName} ===")

                // MySQL查询表结构信息，mysql中的table_schema和table_catalog与对应postgresql中的对换了
                let columnInfoSql = """
                    SELECT
                        TABLE_CATALOG AS table_schema,
                        TABLE_SCHEMA AS table_catalog,
                        TABLE_NAME AS table_name,
                        COLUMN_NAME AS column_name,
                        ORDINAL_POSITION AS ordinal_position,
                        COLUMN_DEFAULT AS column_default,
                        IS_NULLABLE AS is_nullable,
                        DATA_TYPE AS data_type,
                        CHARACTER_MAXIMUM_LENGTH AS character_maximum_length,
                        COLUMN_COMMENT AS column_comment
                    FROM
                        INFORMATION_SCHEMA.COLUMNS
                    WHERE
                        TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
                    ORDER BY
                        TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
                """

                let dbInfoList = executor.setSql(columnInfoSql).list<DbInfoPO>()
                LogUtils.info("DbInfoService", "=== Retrieved ${dbInfoList.size} columns from information_schema ===")

                var insertedCount: Int64 = 0
                for (dbInfo in dbInfoList) {
                    // 为每条记录生成UUID作为id，确保插入时id字段有值
                    let uuid = generateUUID()
                    LogUtils.info("DbInfoService", "=== Processing column: ${dbInfo.dbTableName}.${dbInfo.columnName}, generated UUID: ${uuid} ===")
                    
                    dbInfo.id = Some<String>(uuid)
                    dbInfo.tableCatalog = dbName
                    dbInfo.createdAt = DateTime.now()
                    dbInfo.updatedAt = DateTime.now()
                    dbInfo.deletedAt = None<DateTime>
                    dbInfo.migrationId = Some<String>("loadDbInfo")
                    dbInfo.isColumnHidden = ""
                    dbInfo.isTableHidden = ""
                    
                    LogUtils.info("DbInfoService", "=== Before insert - id: ${dbInfo.id}, tableCatalog: ${dbInfo.tableCatalog}, tableName: ${dbInfo.dbTableName}, columnName: ${dbInfo.columnName} ===")
                    
                    try {
                        let id = executor.insertDbInfo(dbInfo)
                        LogUtils.info("DbInfoService", "=== Insert result: ${id} ===")
                        if (id != "") {
                            insertedCount = insertedCount + 1
                        }
                    } catch (e: Exception) {
                        LogUtils.error("DbInfoService", "=== Insert failed for ${dbInfo.dbTableName}.${dbInfo.columnName}: ${e.message} ===")
                    }
                }

                LogUtils.info("DbInfoService", "=== Inserted ${insertedCount} records into db_info ===")
                return APIResult<Int32>(Int32(insertedCount))
            }
            else {
                return APIResult<Int32>(false, "不支持的数据库类型: ${provider}")
            }
        } catch (e: Exception) {
            LogUtils.error("DbInfoService", "=== loadDbInfo error: ${e.message} ===")
            return APIResult<Int32>(false, e.message)
        }
    }

    /**
     * 获取数据库表列表（从information_schema直接查询，不保存到db_info表）
     * @param dbName 数据库名称
     * @return 表信息列表
     */
    public func getDbTableList(dbName: String): APIResult<ArrayList<DbTableInfo>> {
        try {
            LogUtils.info("DbInfoService", "=== getDbTableList called with dbName: ${dbName} ===")

            let executor = getExecutor()

            let tablesSql = """
                SELECT
                    table_catalog,
                    table_schema,
                    table_name,
                    table_type
                FROM
                    information_schema.tables
                WHERE
                    table_schema NOT IN ('pg_catalog', 'information_schema')
                    AND table_catalog = '${dbName}'
                ORDER BY
                    table_schema,
                    table_name
            """

            let columnsSql = """
                SELECT
                    c.table_catalog,
                    c.table_schema,
                    c.table_name,
                    c.column_name,
                    c.ordinal_position,
                    c.column_default,
                    c.is_nullable,
                    c.data_type,
                    c.character_maximum_length,
                    pgd.description AS column_comment
                FROM
                    information_schema.columns c
                LEFT JOIN
                    pg_catalog.pg_class cl ON (
                        c.table_name = cl.relname
                    )
                LEFT JOIN
                    pg_catalog.pg_namespace n ON (
                        cl.relnamespace = n.oid
                    )
                LEFT JOIN
                    pg_catalog.pg_attribute a ON (
                        n.nspname = c.table_schema AND
                        cl.oid = a.attrelid AND
                        c.column_name = a.attname
                    )
                LEFT JOIN
                    pg_catalog.pg_description pgd ON (
                        pgd.objoid = cl.oid AND
                        pgd.objsubid = a.attnum
                    )
                WHERE
                    c.table_schema NOT IN ('pg_catalog', 'information_schema')
                    AND c.table_catalog = '${dbName}'
                ORDER BY
                    c.table_schema,
                    c.table_name,
                    c.ordinal_position
            """

            let columnsResult = executor.setSql(columnsSql).list<DbInfoPO>()
            LogUtils.info("DbInfoService", "=== Retrieved ${columnsResult.size} columns ===")

            let columnMap = HashMap<String, ArrayList<DbColumnInfo>>()
            for (col in columnsResult) {
                let key = "${col.tableSchema}.${col.dbTableName}"
                if (!columnMap.contains(key)) {
                    columnMap.add(key, ArrayList<DbColumnInfo>())
                }
                let colInfo = DbColumnInfo()
                colInfo.columnName = col.columnName
                colInfo.dataType = col.dataType ?? ""
                colInfo.isNullable = col.isNullable
                colInfo.columnDefault = col.columnDefault ?? ""
                colInfo.ordinalPosition = col.ordinalPosition ?? 0
                colInfo.characterMaximumLength = col.characterMaximumLength ?? 0
                colInfo.columnComment = col.columnComment ?? ""
                columnMap.get(key).getOrThrow().add(colInfo)
            }

            let tableList = executor.setSql(tablesSql).list<DbInfoPO>()
            LogUtils.info("DbInfoService", "=== Retrieved ${tableList.size} tables ===")

            let result = ArrayList<DbTableInfo>()
            for (table in tableList) {
                let tableInfo = DbTableInfo()
                tableInfo.tableCatalog = table.tableCatalog
                tableInfo.tableSchema = table.tableSchema ?? ""
                tableInfo.tableName = table.dbTableName
                tableInfo.tableType = ""

                let key = "${tableInfo.tableSchema}.${tableInfo.tableName}"
                if (columnMap.contains(key)) {
                    tableInfo.children = columnMap.get(key).getOrThrow()
                }

                result.add(tableInfo)
            }

            LogUtils.info("DbInfoService", "=== Returning ${result.size} tables with columns ===")
            return APIResult<ArrayList<DbTableInfo>>(result)
        } catch (e: Exception) {
            LogUtils.error("DbInfoService", "=== getDbTableList error: ${e.message} ===")
            return APIResult<ArrayList<DbTableInfo>>(false, e.message)
        }
    }

    /**
     * 生成UUID字符串
     * 用于为没有id字段的表生成唯一标识符
     * @return UUID字符串
     */
    private func generateUUID(): String {
        // 使用当前时间生成简单的UUID
        let now = DateTime.now()
        // 使用时间的哈希值作为随机种子
        let hash1 = now.hashCode()
        let hash2 = (hash1 * 2654435761) % 2147483647
        let hash3 = (hash2 * 2654435761) % 2147483647
        let hash4 = (hash3 * 2654435761) % 2147483647

        // 格式化为UUID格式: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        let sb = StringBuilder()
        sb.append("${toHex(Int64(hash1), 8)}-")
        sb.append("${toHex(Int64(hash2 >> 16), 4)}-")
        sb.append("${toHex(Int64((hash2 & 0xFFFF) | 0x4000), 4)}-")  // 版本4 UUID
        sb.append("${toHex(Int64((hash3 >> 16) | 0x8000), 4)}-")     // 变体1 UUID
        sb.append("${toHex(Int64(hash3 & 0xFFFF), 4)}")
        sb.append("${toHex(Int64(hash4), 8)}")
        return sb.toString()
    }

    /**
     * 将整数转换为指定长度的十六进制字符串
     * @param value 整数值
     * @param length 目标长度
     * @return 十六进制字符串
     */
    private func toHex(value: Int64, length: Int64): String {
        let hexChars = "0123456789abcdef"
        var result = StringBuilder()
        var v = value
        for (i in 0..length) {
            let index = (v >> ((length - 1 - i) * 4)) & 0xF
            result.append(hexChars[Int64(index)])
        }
        return result.toString()
    }
}
