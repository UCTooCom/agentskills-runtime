/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.dao.uctoo.{CompanyDAO, TasksDAO}
import magic.app.models.uctoo.{CompanyPO, TasksPO}

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.PointTransactionsPO
import magic.app.dao.uctoo.PointTransactionsDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * PointTransactionsService - point_transactions服务类
 *
 * 提供point_transactions相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class PointTransactionsService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建point_transactions
     * @param entity PointTransactionsPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: PointTransactionsPO, creatorId: String): APIResult<PointTransactionsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertPointTransactions(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<PointTransactionsPO>(entity)
            } else {
                return APIResult<PointTransactionsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<PointTransactionsPO>(false, e.message)
        }
    }

    /**
     * 更新point_transactions（无权限检查）
     * @param entityId ID
     * @param entity PointTransactionsPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: PointTransactionsPO): APIResult<PointTransactionsPO> {
        try {
            let existing = getExecutor().findPointTransactionsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<PointTransactionsPO>(false, "point_transactions不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.accountType.size > 0) {
                existingEntity.accountType = entity.accountType
            }
            if (entity.accountId.size > 0) {
                existingEntity.accountId = entity.accountId
            }
            if (entity.transactionType.size > 0) {
                existingEntity.transactionType = entity.transactionType
            }
            existingEntity.amount = entity.amount
            existingEntity.balanceBefore = entity.balanceBefore
            existingEntity.balanceAfter = entity.balanceAfter
            if (entity.taskId.isSome()) {
                existingEntity.taskId = entity.taskId
            }
            if (entity.counterpartyType.isSome()) {
                existingEntity.counterpartyType = entity.counterpartyType
            }
            if (entity.counterpartyId.isSome()) {
                existingEntity.counterpartyId = entity.counterpartyId
            }
            if (entity.description.isSome()) {
                existingEntity.description = entity.description
            }
            if (entity.remark.isSome()) {
                existingEntity.remark = entity.remark
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updatePointTransactions(existingEntity)
            
            if (rows > 0) {
                return APIResult<PointTransactionsPO>(existingEntity)
            } else {
                return APIResult<PointTransactionsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<PointTransactionsPO>(false, e.message)
        }
    }

    /**
     * 批量更新point_transactions
     * @param entities point_transactions列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<PointTransactionsPO>): APIResult<ArrayList<PointTransactionsPO>> {
        try {
            let updatedEntities = ArrayList<PointTransactionsPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updatePointTransactions(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<PointTransactionsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<PointTransactionsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<PointTransactionsPO>>(false, e.message)
        }
    }

    /**
     * 删除point_transactions（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findPointTransactionsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "point_transactions不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deletePointTransactionsById(entityId)
            } else {
                rows = getExecutor().softDeletePointTransactionsById(entityId)
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
     * 批量删除point_transactions
     * @param ids point_transactionsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeletePointTransactions(ids)
            } else {
                rows = getExecutor().batchSoftDeletePointTransactions(ids)
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
     * 恢复软删除的point_transactions
     * @param entityId point_transactionsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<PointTransactionsPO> {
        try {
            let rows = getExecutor().restorePointTransactionsById(entityId)

            if (rows > 0) {
                let result = getExecutor().findPointTransactionsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<PointTransactionsPO>(entity)
                } else {
                    return APIResult<PointTransactionsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<PointTransactionsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<PointTransactionsPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的point_transactions
     * @param ids point_transactionsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restorePointTransactionsById(id)
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
     * 根据ID获取point_transactions（无权限检查）
     * @param entityId ID
     * @return point_transactions对象
     */
    public func getById(entityId: String): APIResult<PointTransactionsPO> {
        try {
            let result = getExecutor().findPointTransactionsById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<PointTransactionsPO>(entity)
            } else {
                return APIResult<PointTransactionsPO>(false, "未找到该point_transactions")
            }
        } catch (e: Exception) {
            return APIResult<PointTransactionsPO>(false, e.message)
        }
    }

    /**
     * 获取point_transactions列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return point_transactions列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<PointTransactionsPO>, Int64) {
        try {
            let pagination = getExecutor().findAllPointTransactionsPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<PointTransactionsPO>(), 0)
        }
    }

    /**
     * 获取point_transactions列表（分页，支持排序和过滤，无权限过滤）
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
     * @return point_transactions列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<PointTransactionsPO>, Int64) {
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
            let pagination = getExecutor().findPointTransactionsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<PointTransactionsPO>(), 0)
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
     * 获取point_transactions列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return point_transactions列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<PointTransactionsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "point_transactions")

            if (permFilter == "1=1" || permFilter.isEmpty()) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            if (whereClause.isEmpty()) {
                whereClause = permFilter
            } else {
                whereClause = "(${whereClause}) AND ${permFilter}"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)

            let pageNum = if (pageSize > 0) { (skip / pageSize) + 1 } else { Int32(1) }
            let pagination = getExecutor().findPointTransactionsByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<PointTransactionsPO>(), 0)
        }
    }

    /**
     * 获取point_transactions列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return point_transactions列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<PointTransactionsPO>, Int64) {
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
            let pagination = getExecutor().findPointTransactionsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<PointTransactionsPO>(), 0)
        }
    }

    /**
     * 获取所有point_transactions列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return point_transactions列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<PointTransactionsPO>, Int64) {
        let pagination = getExecutor().findAllPointTransactionsPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取point_transactions
     * @param ids ID列表
     * @return point_transactions列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<PointTransactionsPO> {
        getExecutor().findPointTransactionsByIds(ids)
    }

    /**
     * 统计用户的point_transactions数量
     * @param userId 用户ID
     * @return point_transactions数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countPointTransactionsByCreator(userId)
    }

    /**
     * 统计所有point_transactions数量
     * @return point_transactions数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllPointTransactions()
    }

    /**
     * 获取point_transactions列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return point_transactions列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<PointTransactionsPO>, Int64) {
        let pagination = getExecutor().findPointTransactionsByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的point_transactions）
     * @return 删除结果
     */
    public func emptyRecycleBinPointTransactions(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinPointTransactions()

            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "回收站为空")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    // ==================== 行级权限集成方法（每个表都需要的标准化代码） ====================

    public func createWithPermission(entity: PointTransactionsPO, creatorId: String): APIResult<PointTransactionsPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "point_transactions")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<PointTransactionsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "point_transactions")
            if (!hasPermission) {
                return APIResult<PointTransactionsPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<PointTransactionsPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<PointTransactionsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "point_transactions")

            if (permFilter == "1=1" || permFilter.isEmpty()) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            if (whereClause.isEmpty()) {
                whereClause = permFilter
            } else {
                whereClause = "(${whereClause}) AND ${permFilter}"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)

            let pagination = getExecutor().findPointTransactionsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<PointTransactionsPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: PointTransactionsPO, userId: String): APIResult<PointTransactionsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "point_transactions")
            if (!hasPermission) {
                return APIResult<PointTransactionsPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<PointTransactionsPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "point_transactions")
            if (!hasPermission) {
                return APIResult<Bool>(false, reason)
            }
            return delete(entityId, force)
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

//#endregion AutoCreateCode
// ========== 定制开发方法（在此区域添加自定义方法）==========

    // ==================== 积分系统核心方法 ====================

    // 积分账户类型常量
    public static let ACCOUNT_TYPE_USER = "user"
    public static let ACCOUNT_TYPE_COMPANY = "company"

    // 积分交易类型常量
    public static let TXN_TYPE_FREEZE = "freeze"            // 冻结积分（公司发布任务）
    public static let TXN_TYPE_REFUND = "refund"            // 退还积分（超期或取消）
    public static let TXN_TYPE_SETTLE_PAY = "settle_pay"    // 结算支出（公司→用户）
    public static let TXN_TYPE_SETTLE = "settle"            // 结算收入（用户收到）
    public static let TXN_TYPE_CHARGE = "charge"            // 充值（公司）
    public static let TXN_TYPE_UNFREEZE = "unfreeze"        // 解冻（不涉及资金流动，仅记录）

    /**
     * 冻结公司积分（发布任务时调用）
     * 1. 检查公司积分余额是否充足
     * 2. 扣减 company.points_balance
     * 3. 设置 tasks.points_frozen
     * 4. 记录 freeze 流水
     * @param companyId 公司ID
     * @param points 冻结积分数
     * @param taskId 任务ID
     * @param operatorId 操作者ID
     * @return 公司最新余额
     */
    public func freezeCompanyPoints(companyId: String, points: Int64, taskId: String, operatorId: String): Int64 {
        if (points <= 0) {
            throw Exception("冻结积分必须大于0")
        }
        let executor = getExecutor()
        // 1. 查询当前余额
        let currentBalanceOpt = executor.findPointsBalance(companyId)
        let currentBalance = match (currentBalanceOpt) {
            case Some(b) => b
            case None => throw Exception("公司不存在或已删除")
        }
        if (currentBalance < points) {
            throw Exception("公司积分余额不足，当前余额：${currentBalance}，需要冻结：${points}")
        }
        // 2. 扣减公司余额（带余额检查，防止并发问题）
        let deductRows = executor.deductPointsBalance(companyId, points)
        if (deductRows == 0) {
            throw Exception("扣减公司积分失败，可能余额不足")
        }
        // 3. 更新任务的 points_frozen
        let frozenRows = executor.updatePointsFrozen(taskId, points)
        if (frozenRows == 0) {
            // 回滚公司积分（虽然不是严格事务，但通过补偿操作恢复）
            executor.addPointsBalance(companyId, points)
            throw Exception("更新任务冻结积分失败")
        }
        // 4. 记录冻结流水
        let newBalance = currentBalance - points
        recordTransaction(
            PointTransactionsService.ACCOUNT_TYPE_COMPANY,
            companyId,
            PointTransactionsService.TXN_TYPE_FREEZE,
            points,
            currentBalance,
            newBalance,
            Some(taskId),
            None<String>,
            None<String>,
            Some("发布任务冻结积分"),
            None<String>,
            operatorId
        )
        return newBalance
    }

    /**
     * 解冻/退还公司积分（任务超期或取消时调用）
     * 1. 增加公司积分余额
     * 2. 累加 tasks.points_refunded
     * 3. 记录 refund 流水
     * @param companyId 公司ID
     * @param points 退还积分数
     * @param taskId 任务ID
     * @param operatorId 操作者ID
     * @return 公司最新余额
     */
    public func unfreezeCompanyPoints(companyId: String, points: Int64, taskId: String, operatorId: String): Int64 {
        if (points <= 0) {
            throw Exception("退还积分必须大于0")
        }
        let executor = getExecutor()
        // 1. 查询当前余额
        let currentBalanceOpt = executor.findPointsBalance(companyId)
        let currentBalance = match (currentBalanceOpt) {
            case Some(b) => b
            case None => throw Exception("公司不存在或已删除")
        }
        // 2. 增加公司余额
        let addRows = executor.addPointsBalance(companyId, points)
        if (addRows == 0) {
            throw Exception("退还公司积分失败")
        }
        // 3. 累加任务的 points_refunded
        executor.updatePointsRefunded(taskId, points)
        // 4. 记录退还流水
        let newBalance = currentBalance + points
        recordTransaction(
            PointTransactionsService.ACCOUNT_TYPE_COMPANY,
            companyId,
            PointTransactionsService.TXN_TYPE_REFUND,
            points,
            currentBalance,
            newBalance,
            Some(taskId),
            None<String>,
            None<String>,
            Some("任务超期退还积分"),
            None<String>,
            operatorId
        )
        return newBalance
    }

    /**
     * 单人结算（任务审核通过后调用）
     * 1. 调用 UserScoreService.addUserScore 增加用户积分
     * 2. 累加 tasks.points_settled
     * 3. 记录公司 settle_pay 流水（counterparty 为用户）
     * 4. 记录用户 settle 流水（counterparty 为公司）
     * @param companyId 公司ID
     * @param userId 用户ID
     * @param points 结算积分数
     * @param taskId 任务ID
     * @param operatorId 操作者ID
     * @return 用户最新积分余额
     */
    public func settlePointsToUser(companyId: String, userId: String, points: Int64, taskId: String, operatorId: String): Int32 {
        if (points <= 0) {
            throw Exception("结算积分必须大于0")
        }
        let executor = getExecutor()
        // 1. 查询公司当前余额
        let companyBalanceOpt = executor.findPointsBalance(companyId)
        let companyBalanceBefore = match (companyBalanceOpt) {
            case Some(b) => b
            case None => throw Exception("公司不存在")
        }
        // 2. 增加用户积分（会自动创建 user_score 记录）
        let userScoreService = UserScoreService()
        let userBalanceAfter = userScoreService.addUserScore(userId, Int32(points))
        let userBalanceBefore = userBalanceAfter - Int32(points)
        // 3. 累加任务的 points_settled
        executor.updateSettlementStatus(taskId, "settled", points)
        // 4. 记录公司结算支出流水
        recordTransaction(
            PointTransactionsService.ACCOUNT_TYPE_COMPANY,
            companyId,
            PointTransactionsService.TXN_TYPE_SETTLE_PAY,
            points,
            companyBalanceBefore,
            companyBalanceBefore,  // 公司余额不变（已冻结时不减少），仅记录资金去向
            Some(taskId),
            Some(PointTransactionsService.ACCOUNT_TYPE_USER),
            Some(userId),
            Some("任务结算支出（给用户）"),
            None<String>,
            operatorId
        )
        // 5. 记录用户结算收入流水
        recordTransaction(
            PointTransactionsService.ACCOUNT_TYPE_USER,
            userId,
            PointTransactionsService.TXN_TYPE_SETTLE,
            points,
            Int64(userBalanceBefore),
            Int64(userBalanceAfter),
            Some(taskId),
            Some(PointTransactionsService.ACCOUNT_TYPE_COMPANY),
            Some(companyId),
            Some("任务结算收入"),
            None<String>,
            operatorId
        )
        return userBalanceAfter
    }

    /**
     * 多人结算（按分配比例批量结算）
     * 对每个分配项调用 settlePointsToUser，未分配部分退还公司
     * @param companyId 公司ID
     * @param allocations 分配列表，每项包含 userId 和 points
     * @param taskId 任务ID
     * @param operatorId 操作者ID
     * @return 实际结算总额
     */
    public func settlePointsMulti(companyId: String, allocations: ArrayList<(String, Int64)>, taskId: String, operatorId: String): Int64 {
        var totalSettled: Int64 = 0
        for (allocation in allocations) {
            let (userId, points) = allocation
            if (points > 0) {
                settlePointsToUser(companyId, userId, points, taskId, operatorId)
                totalSettled += points
            }
        }
        return totalSettled
    }

    /**
     * 超期任务退还积分
     * 简单委托 unfreezeCompanyPoints
     * @param taskId 任务ID
     * @param companyId 公司ID
     * @param points 退还积分数
     * @param operatorId 操作者ID（系统自动时为 "system"）
     * @return 公司最新余额
     */
    public func refundExpiredTaskPoints(taskId: String, companyId: String, points: Int64, operatorId: String): Int64 {
        unfreezeCompanyPoints(companyId, points, taskId, operatorId)
    }

    /**
     * 查询用户积分余额
     * @param userId 用户ID
     * @return 积分余额
     */
    public func getUserPointsBalance(userId: String): Int32 {
        let userScoreService = UserScoreService()
        return userScoreService.getUserTotalScore(userId)
    }

    /**
     * 查询公司积分余额
     * @param companyId 公司ID
     * @return 积分余额（公司不存在返回0）
     */
    public func getCompanyPointsBalance(companyId: String): Int64 {
        let executor = getExecutor()
        let balanceOpt = executor.findPointsBalance(companyId)
        match (balanceOpt) {
            case Some(b) => return b
            case None => return 0
        }
    }

    /**
     * 查询用户积分流水
     * @param userId 用户ID
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @return 流水列表和总数
     */
    public func getUserTransactions(userId: String, page: Int64, pageSize: Int64): (ArrayList<PointTransactionsPO>, Int64) {
        let executor = getExecutor()
        let pagination = executor.findTransactionsByAccountIdPage(userId, PointTransactionsService.ACCOUNT_TYPE_USER, page, pageSize)
        return (pagination.list, pagination.rows)
    }

    /**
     * 查询公司积分流水
     * @param companyId 公司ID
     * @param page 页码
     * @param pageSize 每页大小
     * @return 流水列表和总数
     */
    public func getCompanyTransactions(companyId: String, page: Int64, pageSize: Int64): (ArrayList<PointTransactionsPO>, Int64) {
        let executor = getExecutor()
        let pagination = executor.findTransactionsByAccountIdPage(companyId, PointTransactionsService.ACCOUNT_TYPE_COMPANY, page, pageSize)
        return (pagination.list, pagination.rows)
    }

    /**
     * 公开方法：记录充值流水（供 CompanyService.rechargePoints 调用）
     * @param companyId 公司ID
     * @param points 充值积分
     * @param balanceBefore 充值前余额
     * @param balanceAfter 充值后余额
     * @param operatorId 操作者ID
     */
    public func recordChargeTransaction(companyId: String, points: Int64, balanceBefore: Int64, balanceAfter: Int64, operatorId: String): Unit {
        recordTransaction(
            PointTransactionsService.ACCOUNT_TYPE_COMPANY,
            companyId,
            PointTransactionsService.TXN_TYPE_CHARGE,
            points,
            balanceBefore,
            balanceAfter,
            None<String>,
            None<String>,
            None<String>,
            Some("组织积分充值"),
            None<String>,
            operatorId
        )
    }

    /**
     * 内部辅助方法：记录积分流水
     */
    private func recordTransaction(
        accountType: String,
        accountId: String,
        transactionType: String,
        amount: Int64,
        balanceBefore: Int64,
        balanceAfter: Int64,
        taskId: Option<String>,
        counterpartyType: Option<String>,
        counterpartyId: Option<String>,
        description: Option<String>,
        remark: Option<String>,
        creator: String
    ): Unit {
        let entity = PointTransactionsPO()
        entity.accountType = accountType
        entity.accountId = accountId
        entity.transactionType = transactionType
        entity.amount = amount
        entity.balanceBefore = balanceBefore
        entity.balanceAfter = balanceAfter
        entity.taskId = taskId
        entity.counterpartyType = counterpartyType
        entity.counterpartyId = counterpartyId
        entity.description = description
        entity.remark = remark
        entity.creator = Some(creator)
        entity.createdAt = DateTime.now()
        entity.updatedAt = DateTime.now()
        let id = getExecutor().insertPointTransactions(entity)
        if (id.isEmpty()) {
            LogUtils.warn("记录积分流水失败：account=${accountId}, type=${transactionType}, amount=${amount}")
        }
    }
}
