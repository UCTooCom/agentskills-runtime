/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import magic.app.models.uctoo.DbConnectionPO
import magic.app.dao.uctoo.DbConnectionDAO
import f_orm.sql.SqlExecutor

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.DbInfoPO
import magic.app.dao.uctoo.DbInfoDAO
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
     * 创建db_info
     * @param entity DbInfoPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: DbInfoPO, creatorId: String): APIResult<DbInfoPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
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
     * 更新db_info
     * @param entityId ID
     * @param entity DbInfoPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: DbInfoPO): APIResult<DbInfoPO> {
        try {
            let existing = getExecutor().findDbInfoById(entityId)
            
            if (existing.isNone()) {
                return APIResult<DbInfoPO>(false, "db_info不存在")
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
            if (entity.characterMaximumLength.isSome()) {
                existingEntity.characterMaximumLength = entity.characterMaximumLength
            }

            
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
     * 批量更新db_info
     * @param entities db_info列表
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
     * 删除db_info
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findDbInfoById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "db_info不存在")
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
     * 批量删除db_info
     * @param ids db_infoID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteDbInfo(ids)
            } else {
                rows = getExecutor().batchSoftDeleteDbInfo(ids)
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
     * 恢复软删除的db_info
     * @param entityId db_infoID
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
     * 批量恢复软删除的db_info
     * @param ids db_infoID列表
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
     * 根据ID获取db_info
     * @param entityId ID
     * @return db_info对象
     */
    public func getById(entityId: String): APIResult<DbInfoPO> {
        try {
            let result = getExecutor().findDbInfoById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<DbInfoPO>(entity)
            } else {
                return APIResult<DbInfoPO>(false, "未找到该db_info")
            }
        } catch (e: Exception) {
            return APIResult<DbInfoPO>(false, e.message)
        }
    }

    /**
     * 获取db_info列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return db_info列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<DbInfoPO>, Int64) {
        try {
            let pagination = getExecutor().findAllDbInfoPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("DbInfoService", "getList error: ${e.message}")
            return (ArrayList<DbInfoPO>(), 0)
        }
    }

    /**
     * 获取db_info列表（分页，支持排序和过滤）
     *
     * 支持完整的 Prisma 风格查询：
     * - 排序：sort="-created_at,id"
     * - 过滤：filter={"name":{"contains":"test"},"status":{"equals":"active"}}
     * - 条件组合：filter={"AND":[{"name":{"contains":"test"}},{"status":{"equals":"active"}}]}
     *
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param sort 排序参数（如 "-created_at,id"）
     * @param filter 过滤条件（JSON字符串）
     * @return db_info列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DbInfoPO>, Int64) {
        try {
            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            // 2. 构建 WHERE 条件
            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            // 3. 构建 ORDER BY 子句
            let orderByClause = buildOrderByClause(parsedQuery.sort)

            // 4. 执行查询
            let pagination = getExecutor().findDbInfoByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("DbInfoService", "Failed to get list: ${e.message}")
            return (ArrayList<DbInfoPO>(), 0)
        }
    }

    /**
     * 构建WHERE子句字符串
     *
     * 将组合条件转换为SQL WHERE子句
     */
    private func buildWhereClause(composite: CompositeCondition): String {
        let sb = StringBuilder()

        // 处理字段条件
        let fieldConditions = composite.fieldConditions
        for (fieldCondition in fieldConditions) {
            if (sb.size > 0) {
                match (composite.logic) {
                    case LogicOperator.And => sb.append(" AND ")
                    case LogicOperator.Or => sb.append(" OR ")
                    case LogicOperator.Not => sb.append(" AND ")
                }
            }
            sb.append(buildFieldClause(fieldCondition))
        }

        // 处理嵌套组合条件
        let compositeConditions = composite.compositeConditions
        for (nestedComposite in compositeConditions) {
            if (sb.size > 0) {
                match (composite.logic) {
                    case LogicOperator.And => sb.append(" AND ")
                    case LogicOperator.Or => sb.append(" OR ")
                    case LogicOperator.Not => sb.append(" AND ")
                }
            }
            let nestedClause = buildWhereClause(nestedComposite)
            if (!nestedClause.isEmpty()) {
                sb.append("(${nestedClause})")
            }
        }

        // 处理 NOT 逻辑操作符
        match (composite.logic) {
            case LogicOperator.Not =>
                if (sb.size > 0) {
                    return "NOT(${sb.toString()})"
                } else {
                    return sb.toString()
                }
            case _ =>
                return sb.toString()
        }
    }

    /**
     * 构建单个字段条件的SQL子句
     */
    private func buildFieldClause(fieldCondition: FieldCondition): String {
        let field = fieldCondition.field
        let op = fieldCondition.op
        let value = fieldCondition.value

        match (op) {
            case QueryOperator.Equals => buildEqualsClause(field, value)
            case QueryOperator.Not => buildNotClause(field, value)
            case QueryOperator.Lt => buildLtClause(field, value)
            case QueryOperator.Lte => buildLteClause(field, value)
            case QueryOperator.Gt => buildGtClause(field, value)
            case QueryOperator.Gte => buildGteClause(field, value)
            case QueryOperator.Contains => buildContainsClause(field, value)
            case QueryOperator.StartsWith => buildStartsWithClause(field, value)
            case QueryOperator.EndsWith => buildEndsWithClause(field, value)
            case QueryOperator.In => buildInClauseWrapper(field, value, true)
            case QueryOperator.NotIn => buildInClauseWrapper(field, value, false)
            case QueryOperator.IsSet => buildIsSetClause(field, value)
            case QueryOperator.Between => buildBetweenClauseWrapper(field, value, true)
            case QueryOperator.NotBetween => buildBetweenClauseWrapper(field, value, false)
        }
    }

    private func buildEqualsClause(field: String, value: QueryValue): String {
        if (value.isNull()) {
            return "${field} IS NULL"
        }

        if (let Some(v) <- value.stringValue) {
            return "${field} = '${v}'"
        } else if (let Some(v) <- value.intValue) {
            return "${field} = ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} = ${v}"
        } else if (let Some(v) <- value.boolValue) {
            return "${field} = ${v}"
        }
        return ""
    }

    private func buildNotClause(field: String, value: QueryValue): String {
        if (value.isNull()) {
            return "${field} IS NOT NULL"
        }

        if (let Some(v) <- value.stringValue) {
            return "${field} != '${v}'"
        } else if (let Some(v) <- value.intValue) {
            return "${field} != ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} != ${v}"
        } else if (let Some(v) <- value.boolValue) {
            return "${field} != ${v}"
        }
        return ""
    }

    private func buildLtClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.intValue) {
            return "${field} < ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} < ${v}"
        }
        return ""
    }

    private func buildLteClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.intValue) {
            return "${field} <= ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} <= ${v}"
        }
        return ""
    }

    private func buildGtClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.intValue) {
            return "${field} > ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} > ${v}"
        }
        return ""
    }

    private func buildGteClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.intValue) {
            return "${field} >= ${v}"
        } else if (let Some(v) <- value.floatValue) {
            return "${field} >= ${v}"
        }
        return ""
    }

    private func buildContainsClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.stringValue) {
            return "${field} LIKE '%${v}%'"
        }
        return ""
    }

    private func buildStartsWithClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.stringValue) {
            return "${field} LIKE '${v}%'"
        }
        return ""
    }

    private func buildEndsWithClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.stringValue) {
            return "${field} LIKE '%${v}'"
        }
        return ""
    }

    private func buildInClauseWrapper(field: String, value: QueryValue, isIn: Bool): String {
        if (let Some(arr) <- value.arrayValue) {
            return buildInClause(field, arr, isIn)
        }
        return ""
    }

    private func buildIsSetClause(field: String, value: QueryValue): String {
        if (let Some(v) <- value.boolValue) {
            if (v) {
                return "${field} IS NOT NULL"
            } else {
                return "${field} IS NULL"
            }
        }
        return ""
    }

    private func buildBetweenClauseWrapper(field: String, value: QueryValue, isBetween: Bool): String {
        if (let Some(arr) <- value.arrayValue) {
            if (arr.size >= 2) {
                return buildBetweenClause(field, arr[0], arr[1], isBetween)
            }
        }
        return ""
    }

    private func buildInClause(field: String, values: ArrayList<QueryValue>, isIn: Bool): String {
        let sb = StringBuilder()
        sb.append("${field} ")
        if (!isIn) {
            sb.append("NOT ")
        }
        sb.append("IN (")

        let size = values.size
        for (i in 0..size) {
            if (i > 0) {
                sb.append(", ")
            }
            let v = values[i]
            if (let Some(s) <- v.stringValue) {
                sb.append("'${s}'")
            } else if (let Some(n) <- v.intValue) {
                sb.append("${n}")
            } else if (let Some(f) <- v.floatValue) {
                sb.append("${f}")
            }
        }

        sb.append(")")
        return sb.toString()
    }


    /**
     * 构建BETWEEN子句
     */
    private func buildBetweenClause(field: String, v1: QueryValue, v2: QueryValue, isBetween: Bool): String {
        let sb = StringBuilder()
        sb.append("${field} ")

        if (!isBetween) {
            sb.append("NOT ")
        }
        sb.append("BETWEEN ")

        if (let Some(s) <- v1.stringValue) {
            sb.append("'${s}'")
        } else if (let Some(n) <- v1.intValue) {
            sb.append("${n}")
        } else if (let Some(f) <- v1.floatValue) {
            sb.append("${f}")
        }

        sb.append(" AND ")

        if (let Some(s) <- v2.stringValue) {
            sb.append("'${s}'")
        } else if (let Some(n) <- v2.intValue) {
            sb.append("${n}")
        } else if (let Some(f) <- v2.floatValue) {
            sb.append("${f}")
        }

        return sb.toString()
    }

    /**
     * 构建ORDER BY子句
     */
    private func buildOrderByClause(sort: ArrayList<SortCondition>): String {
        if (sort.isEmpty()) {
            return "created_at DESC"
        }

        let sb = StringBuilder()
        let size = sort.size

        for (i in 0..size) {
            let condition = sort[i]
            if (sb.size > 0) {
                sb.append(", ")
            }
            sb.append("${condition.field} ${if (condition.ascending) { "ASC" } else { "DESC" }}")
        }

        return sb.toString()
    }

    /**
     * 获取db_info列表（带跳过参数）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return db_info列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DbInfoPO>, Int64) {
        try {
            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page + 1), Int64(pageSize))

            // 2. 构建 WHERE 条件
            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            // 3. 构建 ORDER BY 子句
            let orderByClause = buildOrderByClause(parsedQuery.sort)

            // 4. 执行查询（带跳过参数）
            let pagination = getExecutor().findDbInfoByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<DbInfoPO>(), 0)
        }
    }

    /**
     * 获取所有db_info列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return db_info列表和总数
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
     * 批量获取db_info
     * @param ids ID列表
     * @return db_info列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<DbInfoPO> {
        getExecutor().findDbInfoByIds(ids)
    }

    /**
     * 统计用户的db_info数量
     * @param userId 用户ID
     * @return db_info数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countDbInfoByCreator(userId)
    }

    /**
     * 统计所有db_info数量
     * @return db_info数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllDbInfo()
    }

    /**
     * 获取db_info列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return db_info列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<DbInfoPO>, Int64) {
        let pagination = getExecutor().findDbInfoByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的db_info）
     * @return 删除结果
     */
    public func emptyRecycleBinDbInfo(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinDbInfo()

            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "回收站为空")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
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

                executor.deleteDbInfoByTableCatalog(dbName)
                LogUtils.info("DbInfoService", "=== Deleted existing db_info records for ${dbName} ===")

                let insertSql = """
                    INSERT INTO db_info (
                        table_catalog,
                        table_schema,
                        table_name,
                        column_name,
                        ordinal_position,
                        column_default,
                        is_nullable,
                        data_type,
                        character_maximum_length,
                        column_comment,
                        is_column_hidden,
                        is_table_hidden,
                        migration_id,
                        created_at,
                        updated_at
                    )
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
                        pgd.description,
                        'NO',
                        'NO',
                        'loadDbInfo',
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
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

                let rows = executor.setSql(insertSql).update
                LogUtils.info("DbInfoService", "=== Inserted ${rows} records into db_info ===")
                return APIResult<Int32>(Int32(rows))
            }
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

                executor.deleteDbInfoByTableCatalog(dbName)
                LogUtils.info("DbInfoService", "=== Deleted existing db_info records for ${dbName} ===")

                let insertSql = """
                    INSERT INTO db_info (
                        table_catalog,
                        table_schema,
                        table_name,
                        column_name,
                        ordinal_position,
                        column_default,
                        is_nullable,
                        data_type,
                        character_maximum_length,
                        column_comment,
                        is_column_hidden,
                        is_table_hidden,
                        migration_id,
                        created_at,
                        updated_at
                    )
                    SELECT
                        TABLE_SCHEMA,
                        TABLE_CATALOG,
                        TABLE_NAME,
                        COLUMN_NAME,
                        ORDINAL_POSITION,
                        COLUMN_DEFAULT,
                        IS_NULLABLE,
                        DATA_TYPE,
                        CHARACTER_MAXIMUM_LENGTH,
                        COLUMN_COMMENT,
                        'NO',
                        'NO',
                        'loadDbInfo',
                        NOW(),
                        NOW()
                    FROM
                        INFORMATION_SCHEMA.COLUMNS
                    WHERE
                        TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
                    ORDER BY
                        TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
                """

                let rows = executor.setSql(insertSql).update
                LogUtils.info("DbInfoService", "=== Inserted ${rows} records into db_info ===")
                return APIResult<Int32>(Int32(rows))
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
                colInfo.ordinalPosition = col.ordinalPosition
                colInfo.characterMaximumLength = match (col.characterMaximumLength) { case Some(v) => Int32(v) case _ => 0 }
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
