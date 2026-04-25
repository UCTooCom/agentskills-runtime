/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.DbConnectionPO
import magic.app.dao.uctoo.DbConnectionDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.log.LogUtils

/**
 * DbConnectionService - db_connection服务类
 *
 * 提供db_connection相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class DbConnectionService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建db_connection
     * @param entity DbConnectionPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: DbConnectionPO, creatorId: String): APIResult<DbConnectionPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertDbConnection(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<DbConnectionPO>(entity)
            } else {
                return APIResult<DbConnectionPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<DbConnectionPO>(false, e.message)
        }
    }

    /**
     * 更新db_connection
     * @param entityId ID
     * @param entity DbConnectionPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: DbConnectionPO): APIResult<DbConnectionPO> {
        try {
            let existing = getExecutor().findDbConnectionById(entityId)
            
            if (existing.isNone()) {
                return APIResult<DbConnectionPO>(false, "db_connection不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.user.size > 0) {
                existingEntity.user = entity.user
            }
            if (entity.password.size > 0) {
                existingEntity.password = entity.password
            }
            if (entity.host.size > 0) {
                existingEntity.host = entity.host
            }
            if (entity.port.size > 0) {
                existingEntity.port = entity.port
            }
            if (entity.databaseName.size > 0) {
                existingEntity.databaseName = entity.databaseName
            }
            existingEntity.ssl = entity.ssl
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            if (entity.provider.size > 0) {
                existingEntity.provider = entity.provider
            }
            if (entity.typeVal.isSome()) {
                existingEntity.typeVal = entity.typeVal
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateDbConnection(existingEntity)
            
            if (rows > 0) {
                return APIResult<DbConnectionPO>(existingEntity)
            } else {
                return APIResult<DbConnectionPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<DbConnectionPO>(false, e.message)
        }
    }

    /**
     * 批量更新db_connection
     * @param entities db_connection列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<DbConnectionPO>): APIResult<ArrayList<DbConnectionPO>> {
        try {
            let updatedEntities = ArrayList<DbConnectionPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateDbConnection(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<DbConnectionPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<DbConnectionPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<DbConnectionPO>>(false, e.message)
        }
    }

    /**
     * 删除db_connection
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findDbConnectionById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "db_connection不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteDbConnectionById(entityId)
            } else {
                rows = getExecutor().softDeleteDbConnectionById(entityId)
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
     * 批量删除db_connection
     * @param ids db_connectionID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteDbConnection(ids)
            } else {
                rows = getExecutor().batchSoftDeleteDbConnection(ids)
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
     * 恢复软删除的db_connection
     * @param entityId db_connectionID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<DbConnectionPO> {
        try {
            let rows = getExecutor().restoreDbConnectionById(entityId)

            if (rows > 0) {
                let result = getExecutor().findDbConnectionById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<DbConnectionPO>(entity)
                } else {
                    return APIResult<DbConnectionPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<DbConnectionPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<DbConnectionPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的db_connection
     * @param ids db_connectionID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreDbConnectionById(id)
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
     * 根据ID获取db_connection
     * @param entityId ID
     * @return db_connection对象
     */
    public func getById(entityId: String): APIResult<DbConnectionPO> {
        try {
            let result = getExecutor().findDbConnectionById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<DbConnectionPO>(entity)
            } else {
                return APIResult<DbConnectionPO>(false, "未找到该db_connection")
            }
        } catch (e: Exception) {
            return APIResult<DbConnectionPO>(false, e.message)
        }
    }

    /**
     * 获取db_connection列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return db_connection列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<DbConnectionPO>, Int64) {
        try {
            let pagination = getExecutor().findAllDbConnectionPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("DbConnectionService", "getList error: ${e.message}")
            return (ArrayList<DbConnectionPO>(), 0)
        }
    }

    /**
     * 获取db_connection列表（分页，支持排序和过滤）
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
     * @return db_connection列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DbConnectionPO>, Int64) {
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
            let pagination = getExecutor().findDbConnectionByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("DbConnectionService", "Failed to get list: ${e.message}")
            return (ArrayList<DbConnectionPO>(), 0)
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
     * 获取db_connection列表（带跳过参数）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return db_connection列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<DbConnectionPO>, Int64) {
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
            let pagination = getExecutor().findDbConnectionByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<DbConnectionPO>(), 0)
        }
    }

    /**
     * 获取所有db_connection列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return db_connection列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<DbConnectionPO>, Int64) {
        let pagination = getExecutor().findAllDbConnectionPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取db_connection
     * @param ids ID列表
     * @return db_connection列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<DbConnectionPO> {
        getExecutor().findDbConnectionByIds(ids)
    }

    /**
     * 统计用户的db_connection数量
     * @param userId 用户ID
     * @return db_connection数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countDbConnectionByCreator(userId)
    }

    /**
     * 统计所有db_connection数量
     * @return db_connection数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllDbConnection()
    }

    /**
     * 获取db_connection列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return db_connection列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<DbConnectionPO>, Int64) {
        let pagination = getExecutor().findDbConnectionByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的db_connection）
     * @return 删除结果
     */
    public func emptyRecycleBinDbConnection(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinDbConnection()

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
}