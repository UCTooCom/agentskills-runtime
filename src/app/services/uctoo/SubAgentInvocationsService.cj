/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.SubAgentInvocationsPO
import magic.app.dao.uctoo.SubAgentInvocationsDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * SubAgentInvocationsService - sub_agent_invocations服务类
 *
 * 提供sub_agent_invocations相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class SubAgentInvocationsService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建sub_agent_invocations
     * @param entity SubAgentInvocationsPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: SubAgentInvocationsPO, creatorId: String): APIResult<SubAgentInvocationsPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertSubAgentInvocations(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<SubAgentInvocationsPO>(entity)
            } else {
                return APIResult<SubAgentInvocationsPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<SubAgentInvocationsPO>(false, e.message)
        }
    }

    /**
     * 更新sub_agent_invocations（无权限检查）
     * @param entityId ID
     * @param entity SubAgentInvocationsPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: SubAgentInvocationsPO): APIResult<SubAgentInvocationsPO> {
        try {
            let existing = getExecutor().findSubAgentInvocationsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<SubAgentInvocationsPO>(false, "sub_agent_invocations不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.parentTaskId.isSome()) {
                existingEntity.parentTaskId = entity.parentTaskId
            }
            if (entity.taskId.isSome()) {
                existingEntity.taskId = entity.taskId
            }
            if (entity.agentId.size > 0) {
                existingEntity.agentId = entity.agentId
            }
            if (entity.skillName.isSome()) {
                existingEntity.skillName = entity.skillName
            }
            if (entity.stage.isSome()) {
                existingEntity.stage = entity.stage
            }
            if (entity.mode.size > 0) {
                existingEntity.mode = entity.mode
            }
            if (entity.inputJson.size > 0) {
                existingEntity.inputJson = entity.inputJson
            }
            if (entity.outputJson.isSome()) {
                existingEntity.outputJson = entity.outputJson
            }
            if (entity.status.size > 0) {
                existingEntity.status = entity.status
            }
            if (entity.durationMs.isSome()) {
                existingEntity.durationMs = entity.durationMs
            }
            if (entity.errorMessage.isSome()) {
                existingEntity.errorMessage = entity.errorMessage
            }
            if (entity.contractType.isSome()) {
                existingEntity.contractType = entity.contractType
            }
            if (entity.verifyPassed.isSome()) {
                existingEntity.verifyPassed = entity.verifyPassed
            }
            if (entity.verifyErrors.isSome()) {
                existingEntity.verifyErrors = entity.verifyErrors
            }
            existingEntity.attempt = entity.attempt
            existingEntity.promptTokens = entity.promptTokens
            existingEntity.completionTokens = entity.completionTokens
            existingEntity.totalTokens = entity.totalTokens
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateSubAgentInvocations(existingEntity)
            
            if (rows > 0) {
                return APIResult<SubAgentInvocationsPO>(existingEntity)
            } else {
                return APIResult<SubAgentInvocationsPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<SubAgentInvocationsPO>(false, e.message)
        }
    }

    /**
     * 批量更新sub_agent_invocations
     * @param entities sub_agent_invocations列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<SubAgentInvocationsPO>): APIResult<ArrayList<SubAgentInvocationsPO>> {
        try {
            let updatedEntities = ArrayList<SubAgentInvocationsPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateSubAgentInvocations(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<SubAgentInvocationsPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<SubAgentInvocationsPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<SubAgentInvocationsPO>>(false, e.message)
        }
    }

    /**
     * 删除sub_agent_invocations（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findSubAgentInvocationsById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "sub_agent_invocations不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteSubAgentInvocationsById(entityId)
            } else {
                rows = getExecutor().softDeleteSubAgentInvocationsById(entityId)
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
     * 批量删除sub_agent_invocations
     * @param ids sub_agent_invocationsID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteSubAgentInvocations(ids)
            } else {
                rows = getExecutor().batchSoftDeleteSubAgentInvocations(ids)
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
     * 恢复软删除的sub_agent_invocations
     * @param entityId sub_agent_invocationsID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<SubAgentInvocationsPO> {
        try {
            let rows = getExecutor().restoreSubAgentInvocationsById(entityId)

            if (rows > 0) {
                let result = getExecutor().findSubAgentInvocationsById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<SubAgentInvocationsPO>(entity)
                } else {
                    return APIResult<SubAgentInvocationsPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<SubAgentInvocationsPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<SubAgentInvocationsPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的sub_agent_invocations
     * @param ids sub_agent_invocationsID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreSubAgentInvocationsById(id)
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
     * 根据ID获取sub_agent_invocations（无权限检查）
     * @param entityId ID
     * @return sub_agent_invocations对象
     */
    public func getById(entityId: String): APIResult<SubAgentInvocationsPO> {
        try {
            let result = getExecutor().findSubAgentInvocationsById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<SubAgentInvocationsPO>(entity)
            } else {
                return APIResult<SubAgentInvocationsPO>(false, "未找到该sub_agent_invocations")
            }
        } catch (e: Exception) {
            return APIResult<SubAgentInvocationsPO>(false, e.message)
        }
    }

    /**
     * 获取sub_agent_invocations列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return sub_agent_invocations列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<SubAgentInvocationsPO>, Int64) {
        try {
            let pagination = getExecutor().findAllSubAgentInvocationsPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SubAgentInvocationsPO>(), 0)
        }
    }

    /**
     * 获取sub_agent_invocations列表（分页，支持排序和过滤，无权限过滤）
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
     * @return sub_agent_invocations列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<SubAgentInvocationsPO>, Int64) {
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
            let pagination = getExecutor().findSubAgentInvocationsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SubAgentInvocationsPO>(), 0)
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
     * 获取sub_agent_invocations列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return sub_agent_invocations列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<SubAgentInvocationsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "sub_agent_invocations")

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
            let pagination = getExecutor().findSubAgentInvocationsByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SubAgentInvocationsPO>(), 0)
        }
    }

    /**
     * 获取sub_agent_invocations列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return sub_agent_invocations列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<SubAgentInvocationsPO>, Int64) {
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
            let pagination = getExecutor().findSubAgentInvocationsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SubAgentInvocationsPO>(), 0)
        }
    }

    /**
     * 获取所有sub_agent_invocations列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return sub_agent_invocations列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<SubAgentInvocationsPO>, Int64) {
        let pagination = getExecutor().findAllSubAgentInvocationsPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取sub_agent_invocations
     * @param ids ID列表
     * @return sub_agent_invocations列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<SubAgentInvocationsPO> {
        getExecutor().findSubAgentInvocationsByIds(ids)
    }

    /**
     * 统计用户的sub_agent_invocations数量
     * @param userId 用户ID
     * @return sub_agent_invocations数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countSubAgentInvocationsByCreator(userId)
    }

    /**
     * 统计所有sub_agent_invocations数量
     * @return sub_agent_invocations数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllSubAgentInvocations()
    }

    /**
     * 获取sub_agent_invocations列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return sub_agent_invocations列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<SubAgentInvocationsPO>, Int64) {
        let pagination = getExecutor().findSubAgentInvocationsByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的sub_agent_invocations）
     * @return 删除结果
     */
    public func emptyRecycleBinSubAgentInvocations(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinSubAgentInvocations()

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

    public func createWithPermission(entity: SubAgentInvocationsPO, creatorId: String): APIResult<SubAgentInvocationsPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "sub_agent_invocations")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<SubAgentInvocationsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "sub_agent_invocations")
            if (!hasPermission) {
                return APIResult<SubAgentInvocationsPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<SubAgentInvocationsPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<SubAgentInvocationsPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "sub_agent_invocations")

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

            let pagination = getExecutor().findSubAgentInvocationsByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<SubAgentInvocationsPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: SubAgentInvocationsPO, userId: String): APIResult<SubAgentInvocationsPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "sub_agent_invocations")
            if (!hasPermission) {
                return APIResult<SubAgentInvocationsPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<SubAgentInvocationsPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "sub_agent_invocations")
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

// ==================== SDD 子 agent 派单语义化方法（ADR-001：业务走语义化，禁直调通用 update）===================

/**
 * 派单开始：写一条 running 状态的 sub_agent_invocations 记录。
 * @param agentId 目标 agent 的 DB id（必填）
 * @param skillName 所属技能名（可选）
 * @param stage 阶段/子 agent 名（可选，用于成本聚合）
 * @param mode 派生模式（如 isolated）
 * @param inputJson 派单输入（JSON 字符串）
 * @param parentTaskId 父工程任务 id（可选，用于分组）
 * @param taskId 任务 id（可选）
 * @param creatorId 创建者/调用者用户 id
 * @return 新建的派单记录
 */
public func beginInvocation(
    agentId: String,
    skillName: Option<String>,
    stage: Option<String>,
    mode: String,
    inputJson: String,
    parentTaskId: Option<String>,
    taskId: Option<String>,
    creatorId: String
): APIResult<SubAgentInvocationsPO> {
    let po = SubAgentInvocationsPO()
    po.agentId = agentId
    po.skillName = skillName
    po.stage = stage
    po.mode = mode
    po.inputJson = inputJson
    po.parentTaskId = parentTaskId
    po.taskId = taskId
    po.status = "running"
    po.attempt = 1
    po.creator = if (creatorId.isEmpty()) { None<String> } else { Some(creatorId) }
    return create(po, creatorId)
}

/**
 * 派单结束：回写输出、耗时与状态（completed / failed）。
 * 仅回写本次关心的字段，未提供的 Option 字段保持既有值（update 合并逻辑）。
 * 注意：attempt 在 begin 时已置 1，此处维持 1（重派递增由 T-21 契约校验器负责）。
 */
public func finishInvocation(
    invocationId: String,
    outputJson: Option<String>,
    durationMs: Option<Int64>,
    status: String,
    errorMessage: Option<String>
): APIResult<SubAgentInvocationsPO> {
    let po = SubAgentInvocationsPO()
    po.outputJson = outputJson
    po.durationMs = durationMs
    po.status = status
    po.errorMessage = errorMessage
    po.attempt = 1
    return update(invocationId, po)
}

/**
 * T-21（REQ-SDD-012-A）：回写契约校验结果。
 *
 * 四个字段一次写齐：contract_type（json/markdown/text/contract_absent）、
 * verify_passed、verify_errors（结构化 JSON 数组文本）、attempt（1 首次 / 2 重派）。
 *
 * 为什么不塞进 finishInvocation：校验发生在**输出采信之前**，是独立的一次判定；
 * 且 attempt 递增只发生在重派场景，与"派单结束"不是同一次写入。
 */
public func recordVerification(
    invocationId: String,
    contractType: String,
    passed: Bool,
    errors: String,
    attempt: Int32
): APIResult<SubAgentInvocationsPO> {
    let po = SubAgentInvocationsPO()
    po.contractType = if (contractType.isEmpty()) { None<String> } else { Some(contractType) }
    po.verifyPassed = Some<Bool>(passed)
    po.verifyErrors = if (errors.isEmpty()) { None<String> } else { Some(errors) }
    po.attempt = attempt
    return update(invocationId, po)
}

/**
 * T-22（REQ-SDD-012-B）：回写本次派单的模型成本（三段 token）。
 *
 * 口径铁律：**取不到 usage 就记 0 并在 error_message 追加 token_missing，
 * 禁止用字符数折算冒充实测**。成本账本的意义在于可比，估算值混进来就全废了。
 *
 * @param errorMessage 由调用方拼好（通常是在原错误后追加 token_missing）；留空表示不改动该字段
 */
public func recordCost(
    invocationId: String,
    promptTokens: Int64,
    completionTokens: Int64,
    totalTokens: Int64,
    errorMessage: Option<String>
): APIResult<SubAgentInvocationsPO> {
    let po = SubAgentInvocationsPO()
    po.promptTokens = promptTokens
    po.completionTokens = completionTokens
    po.totalTokens = totalTokens
    po.errorMessage = errorMessage
    return update(invocationId, po)
}
}
