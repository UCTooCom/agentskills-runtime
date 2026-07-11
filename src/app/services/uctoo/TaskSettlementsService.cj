/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.models.uctoo.UserHasTasksPO
import magic.app.dao.uctoo.{UserHasTasksDAO, TasksDAO}
// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.TaskSettlementsPO
import magic.app.dao.uctoo.TaskSettlementsDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * TaskSettlementsService - task_settlements服务类
 *
 * 提供task_settlements相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class TaskSettlementsService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建task_settlements
     * @param entity TaskSettlementsPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: TaskSettlementsPO, creatorId: String): APIResult<TaskSettlementsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertTaskSettlements(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<TaskSettlementsPO>(entity)
            } else {
                return APIResult<TaskSettlementsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<TaskSettlementsPO>(false, e.message)
        }
    }

    /**
     * 更新task_settlements（无权限检查）
     * @param entityId ID
     * @param entity TaskSettlementsPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: TaskSettlementsPO): APIResult<TaskSettlementsPO> {
        try {
            let existing = getExecutor().findTaskSettlementsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<TaskSettlementsPO>(false, "task_settlements不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.taskId.size > 0) {
                existingEntity.taskId = entity.taskId
            }
            if (entity.settlerId.size > 0) {
                existingEntity.settlerId = entity.settlerId
            }
            if (entity.companyId.isSome()) {
                existingEntity.companyId = entity.companyId
            }
            if (entity.settlementType.size > 0) {
                existingEntity.settlementType = entity.settlementType
            }
            existingEntity.totalPoints = entity.totalPoints
            if (entity.settlementStatus.size > 0) {
                existingEntity.settlementStatus = entity.settlementStatus
            }
            if (entity.allocations.isSome()) {
                existingEntity.allocations = entity.allocations
            }
            if (entity.settledAt.isSome()) {
                existingEntity.settledAt = entity.settledAt
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
            
            let rows = getExecutor().updateTaskSettlements(existingEntity)
            
            if (rows > 0) {
                return APIResult<TaskSettlementsPO>(existingEntity)
            } else {
                return APIResult<TaskSettlementsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<TaskSettlementsPO>(false, e.message)
        }
    }

    /**
     * 批量更新task_settlements
     * @param entities task_settlements列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<TaskSettlementsPO>): APIResult<ArrayList<TaskSettlementsPO>> {
        try {
            let updatedEntities = ArrayList<TaskSettlementsPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateTaskSettlements(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<TaskSettlementsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<TaskSettlementsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<TaskSettlementsPO>>(false, e.message)
        }
    }

    /**
     * 删除task_settlements（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findTaskSettlementsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "task_settlements不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteTaskSettlementsById(entityId)
            } else {
                rows = getExecutor().softDeleteTaskSettlementsById(entityId)
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
     * 批量删除task_settlements
     * @param ids task_settlementsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteTaskSettlements(ids)
            } else {
                rows = getExecutor().batchSoftDeleteTaskSettlements(ids)
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
     * 恢复软删除的task_settlements
     * @param entityId task_settlementsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<TaskSettlementsPO> {
        try {
            let rows = getExecutor().restoreTaskSettlementsById(entityId)

            if (rows > 0) {
                let result = getExecutor().findTaskSettlementsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<TaskSettlementsPO>(entity)
                } else {
                    return APIResult<TaskSettlementsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<TaskSettlementsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<TaskSettlementsPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的task_settlements
     * @param ids task_settlementsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreTaskSettlementsById(id)
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
     * 根据ID获取task_settlements（无权限检查）
     * @param entityId ID
     * @return task_settlements对象
     */
    public func getById(entityId: String): APIResult<TaskSettlementsPO> {
        try {
            let result = getExecutor().findTaskSettlementsById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<TaskSettlementsPO>(entity)
            } else {
                return APIResult<TaskSettlementsPO>(false, "未找到该task_settlements")
            }
        } catch (e: Exception) {
            return APIResult<TaskSettlementsPO>(false, e.message)
        }
    }

    /**
     * 获取task_settlements列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return task_settlements列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<TaskSettlementsPO>, Int64) {
        try {
            let pagination = getExecutor().findAllTaskSettlementsPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TaskSettlementsPO>(), 0)
        }
    }

    /**
     * 获取task_settlements列表（分页，支持排序和过滤，无权限过滤）
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
     * @return task_settlements列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<TaskSettlementsPO>, Int64) {
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
            let pagination = getExecutor().findTaskSettlementsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TaskSettlementsPO>(), 0)
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
     * 获取task_settlements列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return task_settlements列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<TaskSettlementsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "task_settlements")

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
            let pagination = getExecutor().findTaskSettlementsByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TaskSettlementsPO>(), 0)
        }
    }

    /**
     * 获取task_settlements列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return task_settlements列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<TaskSettlementsPO>, Int64) {
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
            let pagination = getExecutor().findTaskSettlementsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TaskSettlementsPO>(), 0)
        }
    }

    /**
     * 获取所有task_settlements列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return task_settlements列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<TaskSettlementsPO>, Int64) {
        let pagination = getExecutor().findAllTaskSettlementsPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取task_settlements
     * @param ids ID列表
     * @return task_settlements列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<TaskSettlementsPO> {
        getExecutor().findTaskSettlementsByIds(ids)
    }

    /**
     * 统计用户的task_settlements数量
     * @param userId 用户ID
     * @return task_settlements数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countTaskSettlementsByCreator(userId)
    }

    /**
     * 统计所有task_settlements数量
     * @return task_settlements数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllTaskSettlements()
    }

    /**
     * 获取task_settlements列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return task_settlements列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<TaskSettlementsPO>, Int64) {
        let pagination = getExecutor().findTaskSettlementsByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的task_settlements）
     * @return 删除结果
     */
    public func emptyRecycleBinTaskSettlements(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinTaskSettlements()

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

    public func createWithPermission(entity: TaskSettlementsPO, creatorId: String): APIResult<TaskSettlementsPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "task_settlements")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<TaskSettlementsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "task_settlements")
            if (!hasPermission) {
                return APIResult<TaskSettlementsPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<TaskSettlementsPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<TaskSettlementsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "task_settlements")

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

            let pagination = getExecutor().findTaskSettlementsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TaskSettlementsPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: TaskSettlementsPO, userId: String): APIResult<TaskSettlementsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "task_settlements")
            if (!hasPermission) {
                return APIResult<TaskSettlementsPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<TaskSettlementsPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "task_settlements")
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

    // ==================== 多人任务结算方法 ====================

    /**
     * 创建多人任务结算单（草稿状态）
     * 所有承接者审核完成后调用
     * @param taskId 任务ID
     * @param companyId 公司ID
     * @param settlerId 结算操作者ID
     * @param totalPoints 总积分（来自任务 points_frozen）
     * @return 创建的结算单
     */
    public func createSettlementDraft(taskId: String, companyId: String, settlerId: String, totalPoints: Int64): APIResult<TaskSettlementsPO> {
        try {
            let entity = TaskSettlementsPO()
            entity.taskId = taskId
            entity.companyId = Some(companyId)
            entity.settlerId = settlerId
            entity.settlementType = "multi"
            entity.totalPoints = totalPoints
            entity.settlementStatus = "draft"
            entity.creator = Some(settlerId)
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            let id = getExecutor().insertTaskSettlements(entity)
            if (id.isEmpty()) {
                return APIResult<TaskSettlementsPO>(false, "创建结算单失败")
            }
            entity.id = id
            return APIResult<TaskSettlementsPO>(entity)
        } catch (e: Exception) {
            return APIResult<TaskSettlementsPO>(false, e.message)
        }
    }

    /**
     * 设置分配比例（公司操作）
     * @param settlementId 结算单ID
     * @param allocations 分配列表，每项包含 (userId, ratio, points)
     * @return 操作结果
     */
    public func setAllocation(settlementId: String, allocations: ArrayList<(String, Int32, Int64)>): APIResult<Bool> {
        try {
            // 校验分配比例总和不超过 100
            var totalRatio: Int32 = 0
            for (allocation in allocations) {
                let (_, ratio, _) = allocation
                if (ratio < 0 || ratio > 100) {
                    return APIResult<Bool>(false, "分配比例必须在0-100之间")
                }
                totalRatio += ratio
            }
            if (totalRatio > 100) {
                return APIResult<Bool>(false, "分配比例总和不能超过100（当前：${totalRatio}）")
            }
            // 更新结算单的 allocations 字段（JSON 格式）
            let allocationsJson = buildAllocationsJson(allocations)
            let executor = getExecutor()
            let existing = executor.findTaskSettlementsById(settlementId)
            if (existing.isNone()) {
                return APIResult<Bool>(false, "结算单不存在")
            }
            let entity = existing.getOrThrow()
            if (entity.settlementStatus != "draft") {
                return APIResult<Bool>(false, "结算单状态不允许设置分配")
            }
            entity.allocations = Some(allocationsJson)
            entity.settlementStatus = "allocating"
            entity.updatedAt = DateTime.now()
            let rows = executor.updateTaskSettlements(entity)
            if (rows > 0) {
                // 同时更新 user_has_tasks 的分配比例
                for (allocation in allocations) {
                    let (userId, ratio, points) = allocation
                    let relOpt = executor.findTaskRelation(userId, entity.taskId, "participant")
                    if (let Some(rel) <- relOpt) {
                        executor.updateAllocationAndPoints(rel.id, ratio, points)
                    }
                }
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "设置分配失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    /**
     * 确认结算（公司最终确认）
     * 1. 调用 PointTransactionsService.settlePointsMulti 按比例结算
     * 2. 未分配部分退还公司
     * 3. 所有承接者 join_status 更新为 completed
     * 4. 任务状态变为 completed
     * @param settlementId 结算单ID
     * @param operatorId 操作者ID
     */
    public func confirmSettlement(settlementId: String, operatorId: String): APIResult<Bool> {
        try {
            let executor = getExecutor()
            let existing = executor.findTaskSettlementsById(settlementId)
            if (existing.isNone()) {
                return APIResult<Bool>(false, "结算单不存在")
            }
            let entity = existing.getOrThrow()
            if (entity.settlementStatus != "allocating") {
                return APIResult<Bool>(false, "结算单状态不允许确认")
            }
            // 解析 allocations
            let allocations = parseAllocations(entity.allocations)
            // 执行批量结算
            let pointService = PointTransactionsService()
            let allocationsList = ArrayList<(String, Int64)>()
            var totalAllocated: Int64 = 0
            for (allocation in allocations) {
                let (userId, _, points) = allocation
                allocationsList.add((userId, points))
                totalAllocated += points
            }
            // 调用批量结算
            let settled = pointService.settlePointsMulti(entity.companyId.getOrThrow(), allocationsList, entity.taskId, operatorId)
            // 未分配部分退还公司
            let unallocated = entity.totalPoints - settled
            if (unallocated > 0) {
                pointService.unfreezeCompanyPoints(entity.companyId.getOrThrow(), unallocated, entity.taskId, operatorId)
            }
            // 更新结算单状态
            entity.settlementStatus = "settled"
            entity.settledAt = Some(DateTime.now())
            entity.updatedAt = DateTime.now()
            executor.updateTaskSettlements(entity)
            // 更新所有承接者状态为 completed
            let participants = executor.findParticipantsByTaskId(entity.taskId)
            for (p in participants) {
                executor.updateJoinStatus(p.id, "completed")
            }
            // 更新任务状态
            executor.updateTaskStatus(entity.taskId, "completed")
            executor.updateSettlementStatus(entity.taskId, "settled", settled)
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            return APIResult<Bool>(false, "确认结算失败：${e.message}")
        }
    }

    /**
     * 内部方法：构建 allocations JSON 字符串
     */
    private func buildAllocationsJson(allocations: ArrayList<(String, Int32, Int64)>): String {
        let sb = StringBuilder()
        sb.append("[")
        var first = true
        for (allocation in allocations) {
            let (userId, ratio, points) = allocation
            if (!first) {
                sb.append(",")
            }
            first = false
            sb.append("{\"userId\":\"${userId}\",\"ratio\":${ratio},\"points\":${points}}")
        }
        sb.append("]")
        return sb.toString()
    }

    /**
     * 内部方法：解析 allocations JSON 字符串
     * 简化实现：按格式 "[{...},{...}]" 解析
     */
    private func parseAllocations(allocationsOpt: Option<String>): ArrayList<(String, Int32, Int64)> {
        let result = ArrayList<(String, Int32, Int64)>()
        if (let Some(json) <- allocationsOpt) {
            // 简化解析：按 "userId":"xxx","ratio":xx,"points":xx 模式提取
            // 实际项目中应使用 JSON 库解析，这里简化处理
            let parts = json.split("},{")
            for (part in parts) {
                let cleaned = part.replace("[", "").replace("]", "").replace("{", "").replace("}", "").replace("\"", "")
                let fields = cleaned.split(",")
                if (fields.size >= 3) {
                    let userId = fields[0].split(":")[1]
                    let ratio = Int32.parse(fields[1].split(":")[1])
                    let points = Int64.parse(fields[2].split(":")[1])
                    result.add((userId, ratio, points))
                }
            }
        }
        return result
    }
}
