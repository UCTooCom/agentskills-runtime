/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.{{dbName}}

//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.{{dbName}}.{{className}}PO
import magic.app.dao.{{dbName}}.{{className}}DAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.log.LogUtils

/**
 * {{className}}Service - {{tableName}}服务类
 *
 * 提供{{tableName}}相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class {{className}}Service {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建{{tableName}}
     * @param entity {{className}}PO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: {{className}}PO, creatorId: String): APIResult<{{className}}PO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isEmpty()) {
                entity.creator = creatorId
            }
            
            let id = getExecutor().insertEntity(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<{{className}}PO>(entity)
            } else {
                return APIResult<{{className}}PO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<{{className}}PO>(false, e.message)
        }
    }

    /**
     * 创建{{tableName}}（兼容新方法名）
     * @param entity {{className}}PO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func createEntity(entity: {{className}}PO, creatorId: String): APIResult<{{className}}PO> {
        create(entity, creatorId)
    }

    /**
     * 更新{{tableName}}
     * @param entityId ID
     * @param entity {{className}}PO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: {{className}}PO): APIResult<{{className}}PO> {
        try {
            let existing = getExecutor().findEntityById(entityId)
            
            if (existing.isNone()) {
                return APIResult<{{className}}PO>(false, "{{tableName}}不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateEntity(existingEntity)
            
            if (rows > 0) {
                return APIResult<{{className}}PO>(existingEntity)
            } else {
                return APIResult<{{className}}PO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<{{className}}PO>(false, e.message)
        }
    }

    /**
     * 更新{{tableName}}（兼容新方法名）
     * @param entityId {{tableName}}ID
     * @param entity {{className}}PO对象
     * @return 更新结果
     */
    public func updateEntity(entityId: String, entity: {{className}}PO): APIResult<{{className}}PO> {
        update(entityId, entity)
    }

    /**
     * 批量更新{{tableName}}
     * @param entities {{tableName}}列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<{{className}}PO>): APIResult<ArrayList<{{className}}PO>> {
        try {
            let updatedEntities = ArrayList<{{className}}PO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().update{{className}}(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<{{className}}PO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<{{className}}PO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<{{className}}PO>>(false, e.message)
        }
    }

    /**
     * 删除{{tableName}}
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findEntityById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "{{tableName}}不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteEntityById(entityId)
            } else {
                rows = getExecutor().softDeleteEntityById(entityId)
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
     * 删除{{tableName}}（兼容新方法名）
     * @param entityId {{tableName}}ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteEntity(entityId: String, force: Bool): APIResult<Bool> {
        delete(entityId, force)
    }

    /**
     * 批量删除{{tableName}}
     * @param ids {{tableName}}ID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDelete{{className}}(ids)
            } else {
                rows = getExecutor().batchSoftDelete{{className}}(ids)
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
     * 恢复软删除的{{tableName}}
     * @param entityId {{tableName}}ID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<{{className}}PO> {
        try {
            let rows = getExecutor().restoreEntityById(entityId)

            if (rows > 0) {
                let result = getExecutor().findEntityById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<{{className}}PO>(entity)
                } else {
                    return APIResult<{{className}}PO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<{{className}}PO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<{{className}}PO>(false, e.message)
        }
    }

    /**
     * 恢复软删除的{{tableName}}（兼容新方法名）
     * @param entityId {{tableName}}ID
     * @return 恢复结果
     */
    public func restoreEntity(entityId: String): APIResult<{{className}}PO> {
        restore(entityId)
    }

    /**
     * 批量恢复软删除的{{tableName}}
     * @param ids {{tableName}}ID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreEntityById(id)
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
     * 批量恢复软删除的{{tableName}}（兼容新方法名）
     * @param ids {{tableName}}ID列表
     * @return 恢复结果
     */
    public func restoreMultipleEntities(ids: ArrayList<String>): APIResult<Bool> {
        restoreMultiple(ids)
    }

    /**
     * 根据ID获取{{tableName}}
     * @param entityId ID
     * @return {{tableName}}对象
     */
    public func getById(entityId: String): APIResult<{{className}}PO> {
        try {
            let result = getExecutor().findEntityById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<{{className}}PO>(entity)
            } else {
                return APIResult<{{className}}PO>(false, "未找到该{{tableName}}")
            }
        } catch (e: Exception) {
            return APIResult<{{className}}PO>(false, e.message)
        }
    }

    /**
     * 根据ID获取{{tableName}}（兼容新方法名）
     * @param entityId {{tableName}}ID
     * @return {{tableName}}对象
     */
    public func getEntityById(entityId: String): APIResult<{{className}}PO> {
        getById(entityId)
    }

    /**
     * 获取{{tableName}}列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return {{tableName}}列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<{{className}}PO>, Int64) {
        try {
            let pagination = getExecutor().findAllEntityPage(page, pageSize)
            return (pagination.list, pagination.total)
        } catch (e: Exception) {
            LogUtils.error("{{className}}Service", "getList error: ${e.message}")
            return (ArrayList<{{className}}PO>(), 0)
        }
    }

    /**
     * 获取{{tableName}}列表（分页，兼容新方法名）
     * @param page 页码
     * @param pageSize 每页大小
     * @return {{tableName}}列表和总数
     */
    public func getEntityList(page: Int64, pageSize: Int64): (ArrayList<{{className}}PO>, Int64) {
        getList(page, pageSize)
    }

    /**
     * 获取{{tableName}}列表（分页，支持排序和过滤）
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
     * @return {{tableName}}列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<{{className}}PO>, Int64) {
        try {
            LogUtils.info("{{className}}Service", "Raw filter: ${filter}")
            LogUtils.info("{{className}}Service", "Raw sort: ${sort}")

            // 1. 解析查询参数
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))
            LogUtils.info("{{className}}Service", "Parsed query: ${parsedQuery.toString()}")

            // 2. 构建 WHERE 条件
            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                // 将组合条件转换为 WHERE 子句字符串
                whereClause = buildWhereClause(filterCondition)
                LogUtils.info("{{className}}Service", "Generated WHERE clause: ${whereClause}")
            }

            // 3. 构建 ORDER BY 子句
            let orderByClause = buildOrderByClause(parsedQuery.sort)
            LogUtils.info("{{className}}Service", "Generated ORDER BY clause: ${orderByClause}")

            // 4. 执行查询
            LogUtils.info("{{className}}Service", "Executing query with whereClause: '${whereClause}', orderByClause: '${orderByClause}'")
            let pagination = getExecutor().find{{className}}ByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("{{className}}Service", "Failed to get list: ${e.message}")
            return (ArrayList<{{className}}PO>(), 0)
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
     * 获取{{tableName}}列表（带跳过参数）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return {{tableName}}列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<{{className}}PO>, Int64) {
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
            let pagination = getExecutor().find{{className}}ByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<{{className}}PO>(), 0)
        }
    }

    /**
     * 获取所有{{tableName}}列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return {{tableName}}列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<{{className}}PO>, Int64) {
        let pagination = getExecutor().findAll{{className}}Page(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取{{tableName}}
     * @param ids ID列表
     * @return {{tableName}}列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<{{className}}PO> {
        getExecutor().find{{className}}ByIds(ids)
    }

    /**
     * 统计用户的{{tableName}}数量
     * @param userId 用户ID
     * @return {{tableName}}数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().count{{className}}ByCreator(userId)
    }

    /**
     * 统计所有{{tableName}}数量
     * @return {{tableName}}数量
     */
    public func countAll(): Int64 {
        getExecutor().countAll{{className}}()
    }

//#endregion AutoCreateCode

    // ========== 定制开发方法（在此区域添加自定义方法）==========

    /**
     * 获取{{tableName}}列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return {{tableName}}列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<{{className}}PO>, Int64) {
        let pagination = getExecutor().find{{className}}ByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的{{tableName}}）
     * @return 删除结果
     */
    public func emptyRecycleBin(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBin()

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