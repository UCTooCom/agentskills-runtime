/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
// Ch9.3：任务树序列化需要 JSON 类型（TaskTreeNode.toJson）
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray, JsonNull}

// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.AgentTasksPO
import magic.app.dao.uctoo.AgentTasksDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * AgentTasksService - agent_tasks服务类
 *
 * 提供agent_tasks相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class AgentTasksService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建agent_tasks
     * @param entity AgentTasksPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: AgentTasksPO, creatorId: String): APIResult<AgentTasksPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertAgentTasks(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<AgentTasksPO>(entity)
            } else {
                return APIResult<AgentTasksPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentTasksPO>(false, e.message)
        }
    }

    /**
     * 更新agent_tasks（无权限检查）
     * @param entityId ID
     * @param entity AgentTasksPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: AgentTasksPO): APIResult<AgentTasksPO> {
        try {
            let existing = getExecutor().findAgentTasksById(entityId)
            
            if (existing.isNone()) {
                return APIResult<AgentTasksPO>(false, "agent_tasks不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.agentId.size > 0) {
                existingEntity.agentId = entity.agentId
            }
            if (entity.parentTaskId.isSome()) {
                existingEntity.parentTaskId = entity.parentTaskId
            }
            if (entity.status.isSome()) {
                existingEntity.status = entity.status
            }
            if (entity.priority.isSome()) {
                existingEntity.priority = entity.priority
            }
            if (entity.payload.isSome()) {
                existingEntity.payload = entity.payload
            }
            if (entity.result.isSome()) {
                existingEntity.result = entity.result
            }
            if (entity.errorMessage.isSome()) {
                existingEntity.errorMessage = entity.errorMessage
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.completedAt.isSome()) {
                existingEntity.completedAt = entity.completedAt
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateAgentTasks(existingEntity)
            
            if (rows > 0) {
                return APIResult<AgentTasksPO>(existingEntity)
            } else {
                return APIResult<AgentTasksPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentTasksPO>(false, e.message)
        }
    }

    /**
     * 批量更新agent_tasks
     * @param entities agent_tasks列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<AgentTasksPO>): APIResult<ArrayList<AgentTasksPO>> {
        try {
            let updatedEntities = ArrayList<AgentTasksPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateAgentTasks(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<AgentTasksPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<AgentTasksPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<AgentTasksPO>>(false, e.message)
        }
    }

    /**
     * 删除agent_tasks（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findAgentTasksById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "agent_tasks不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteAgentTasksById(entityId)
            } else {
                rows = getExecutor().softDeleteAgentTasksById(entityId)
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
     * 批量删除agent_tasks
     * @param ids agent_tasksID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteAgentTasks(ids)
            } else {
                rows = getExecutor().batchSoftDeleteAgentTasks(ids)
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
     * 恢复软删除的agent_tasks
     * @param entityId agent_tasksID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<AgentTasksPO> {
        try {
            let rows = getExecutor().restoreAgentTasksById(entityId)

            if (rows > 0) {
                let result = getExecutor().findAgentTasksById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<AgentTasksPO>(entity)
                } else {
                    return APIResult<AgentTasksPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<AgentTasksPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<AgentTasksPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的agent_tasks
     * @param ids agent_tasksID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreAgentTasksById(id)
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
     * 根据ID获取agent_tasks（无权限检查）
     * @param entityId ID
     * @return agent_tasks对象
     */
    public func getById(entityId: String): APIResult<AgentTasksPO> {
        try {
            let result = getExecutor().findAgentTasksById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<AgentTasksPO>(entity)
            } else {
                return APIResult<AgentTasksPO>(false, "未找到该agent_tasks")
            }
        } catch (e: Exception) {
            return APIResult<AgentTasksPO>(false, e.message)
        }
    }

    /**
     * 获取agent_tasks列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agent_tasks列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<AgentTasksPO>, Int64) {
        try {
            let pagination = getExecutor().findAllAgentTasksPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentTasksPO>(), 0)
        }
    }

    /**
     * 获取agent_tasks列表（分页，支持排序和过滤，无权限过滤）
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
     * @return agent_tasks列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentTasksPO>, Int64) {
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
            let pagination = getExecutor().findAgentTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentTasksPO>(), 0)
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
     * 获取agent_tasks列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return agent_tasks列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AgentTasksPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "agent_tasks")

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
            let pagination = getExecutor().findAgentTasksByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentTasksPO>(), 0)
        }
    }

    /**
     * 获取agent_tasks列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return agent_tasks列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<AgentTasksPO>, Int64) {
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
            let pagination = getExecutor().findAgentTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentTasksPO>(), 0)
        }
    }

    /**
     * 获取所有agent_tasks列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return agent_tasks列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<AgentTasksPO>, Int64) {
        let pagination = getExecutor().findAllAgentTasksPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取agent_tasks
     * @param ids ID列表
     * @return agent_tasks列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<AgentTasksPO> {
        getExecutor().findAgentTasksByIds(ids)
    }

    /**
     * 统计用户的agent_tasks数量
     * @param userId 用户ID
     * @return agent_tasks数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countAgentTasksByCreator(userId)
    }

    /**
     * 统计所有agent_tasks数量
     * @return agent_tasks数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllAgentTasks()
    }

    /**
     * 获取agent_tasks列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return agent_tasks列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<AgentTasksPO>, Int64) {
        let pagination = getExecutor().findAgentTasksByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的agent_tasks）
     * @return 删除结果
     */
    public func emptyRecycleBinAgentTasks(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinAgentTasks()

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

    public func createWithPermission(entity: AgentTasksPO, creatorId: String): APIResult<AgentTasksPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "agent_tasks")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<AgentTasksPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "agent_tasks")
            if (!hasPermission) {
                return APIResult<AgentTasksPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<AgentTasksPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<AgentTasksPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "agent_tasks")

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

            let pagination = getExecutor().findAgentTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<AgentTasksPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: AgentTasksPO, userId: String): APIResult<AgentTasksPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "agent_tasks")
            if (!hasPermission) {
                return APIResult<AgentTasksPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<AgentTasksPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "agent_tasks")
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

    /**
     * 查询任务树（Ch9.3，供长程任务 `/long_running_task/tree/:rootId` 使用）
     *
     * 从根任务出发，按 `agent_tasks.parent_task_id` 逐层展开全部子任务。
     *
     * 实现取舍：
     * - **层级 BFS + 已访问集合**，而不是递归查询。理由有二：
     *   ① 递归对每次 `parent_task_id` 单独发 SQL 会产生 N+1 查询，任务树稍大即放大；
     *      这里改成**按当前层批量查**（`parent_task_id IN (...)`），查询次数由层数决定。
     *   ② 数据若因异常写入形成环（A 的父是 B、B 的父是 A），递归会栈溢出或死循环；
     *      visited 集合保证每个任务最多展开一次，环只是被截断而不会打爆进程。
     * - **单层子任务数 ≤ 100 时查询延迟 ≤ 100ms**（tasks 9.3 验收条件）：
     *   层内批量 IN 查询把"每节点一条 SQL"降为"每层一条 SQL"，
     *   `parent_task_id` 上有索引（见 DDL）时该目标可达。
     * - **节点用可变 HashMap<String, JsonValue> 承载，children 是 ArrayList 而非 JsonArray**：
     *   层序遍历是"边发现边挂载"，若 children 用 `JsonArray`（一旦转为 JsonValue 就
     *   失去可写视图），挂载只能靠"深挖 JSON 对象再替换"的方式，既脆弱又低效。
     *   改用 `HashMap<String, JsonValue>` + `ArrayList<HashMap<...>>` 后，
     *   **兄弟节点之间共享同一个 children 列表引用**，挂载是 O(1)；
     *   仅在最终序列化时一次性转 JsonArray，转换次数 = 节点数。
     *
     * @param rootTaskId 根任务 ID
     * @param userId 当前用户 ID（行级权限过滤，与其它方法一致）
     * @return 树形结构（单元素数组，元素为根节点；根不存在时返回空数组）
     */
    public func getTaskTree(rootTaskId: String, userId: String): ArrayList<TaskTreeNode> {
        let result = ArrayList<TaskTreeNode>()
        if (rootTaskId.isEmpty()) {
            return result
        }

        // 根节点
        let rootOpt = getExecutor().findAgentTasksById(rootTaskId)
        if (rootOpt.isNone()) {
            LogUtils.warn("[AgentTasksService] getTaskTree: 根任务不存在 rootTaskId=${rootTaskId}")
            return result
        }

        // 已访问集合：防环 + 防重复展开（一个任务被错误地挂到两个父节点上也只展开一次）
        let visited = HashSet<String>()
        visited.add(rootTaskId)

        let rootNode = buildTreeNode(rootOpt.getOrThrow())
        result.add(rootNode)

        // 索引：taskId → 节点，用于 O(1) 找到父节点并挂载子节点
        let nodeIndex = HashMap<String, TaskTreeNode>()
        nodeIndex.add(rootTaskId, rootNode)

        // 当前层待展开的父任务 ID；逐层向下
        let currentLevel = ArrayList<String>()
        currentLevel.add(rootTaskId)
        // 深度上限：任务树深度异常时兜底，避免病态数据导致长时间循环
        let maxDepth: Int64 = 32

        var depth: Int64 = 0
        while (currentLevel.size > 0 && depth < maxDepth) {
            let nextLevel = ArrayList<String>()
            // 按层批量查询：parent_task_id IN ('a','b',...)
            let children = queryChildrenBatch(currentLevel, userId)
            for (child in children) {
                if (visited.contains(child.id)) {
                    continue
                }
                visited.add(child.id)

                let parentId = match (child.parentTaskId) {
                    case Some(p) => p
                    case None => ""
                }
                let childNode = buildTreeNode(child)
                // O(1) 定位父节点后直接挂载（列表是引用语义，无需回写）
                match (nodeIndex.get(parentId)) {
                    case Some(parentNode) =>
                        parentNode.children.add(childNode)
                        nodeIndex.add(child.id, childNode)
                        nextLevel.add(child.id)
                    case None =>
                        // 父节点不在已展开树中：可能是父任务被软删、或权限过滤掉了父任务。
                        // 此时丢弃该分支并记日志——静默丢弃会让"任务树少一层"难以排查。
                        LogUtils.warn("[AgentTasksService] 子任务的父节点不在已展开树中，已丢弃: childId=${child.id}, parentId=${parentId}")
                }
            }
            currentLevel.clear()
            for (id in nextLevel) {
                currentLevel.add(id)
            }
            depth = depth + 1
        }

        if (currentLevel.size > 0) {
            LogUtils.warn("[AgentTasksService] getTaskTree 达到深度上限 ${maxDepth}，可能存在异常深的任务树: rootTaskId=${rootTaskId}")
        }
        return result
    }

    /**
     * 按层批量查询子任务（单层一条 SQL，避免 N+1）
     *
     * 行级权限复用 `PermissionUtils.appendPermissionFilter`（与其它 WithPermission
     * 方法同一套实现，不另起第二套权限逻辑）。
     */
    private func queryChildrenBatch(parentIds: ArrayList<String>, userId: String): ArrayList<AgentTasksPO> {
        let all = ArrayList<AgentTasksPO>()
        if (parentIds.size == 0) {
            return all
        }
        try {
            let sb = StringBuilder()
            var first = true
            for (pid in parentIds) {
                if (!first) {
                    sb.append(", ")
                }
                // 单引号转义，与插件侧 LrtHelpers_joinQuoted 同一约定
                sb.append("'")
                sb.append(pid.replace("'", "''"))
                sb.append("'")
                first = false
            }

            var whereClause = "parent_task_id IN (${sb.toString()}) AND deleted_at IS NULL"
            if (!PermissionUtils.hasWildcardPermission(userId)) {
                let (permFilter, _) = PermissionUtils.appendPermissionFilter(userId, "agent_tasks")
                if (permFilter != "1=1" && !permFilter.isEmpty()) {
                    whereClause = "(${whereClause}) AND ${permFilter}"
                }
            }

            // 单层上限 100 与 tasks 9.3 的验收条件对齐；超出时按 created_at 升序稳定截断，
            // 并记日志（截断不静默，否则"任务树少节点"难以排查）。
            // 注意 rows 是**过滤后的总数**，用它判断是否发生截断。
            let pagination = getExecutor().findAgentTasksByCondition(whereClause, "created_at ASC", Int64(1), Int64(100))
            for (po in pagination.list) {
                all.add(po)
            }
            if (Int64(pagination.rows) > Int64(pagination.list.size)) {
                LogUtils.warn("[AgentTasksService] 单层子任务数超过单次上限，已截断: total=${pagination.rows}, returned=${pagination.list.size}")
            }
        } catch (e: Exception) {
            LogUtils.error("[AgentTasksService] queryChildrenBatch 失败: ${e.message}")
        }
        return all
    }

    /// 把 PO 转为树节点（children 初始为空列表，后续按层挂载）
    private func buildTreeNode(po: AgentTasksPO): TaskTreeNode {
        let node = TaskTreeNode(po.id)
        node.agentId = po.agentId
        match (po.parentTaskId) {
            case Some(p) => node.parentTaskId = Some(p)
            case None => node.parentTaskId = None
        }
        node.status = po.status
        node.priority = po.priority
        match (po.payload) {
            case Some(p) => node.payload = Some(p)
            case None => node.payload = None
        }
        match (po.result) {
            case Some(r) => node.result = Some(r)
            case None => node.result = None
        }
        match (po.errorMessage) {
            case Some(e) => node.errorMessage = Some(e)
            case None => node.errorMessage = None
        }
        node.createdAt = po.createdAt.toString()
        node.updatedAt = po.updatedAt.toString()
        node
    }
}

/**
 * 任务树节点（Ch9.3）
 *
 * 单独成类而不是直接用 `HashMap<String, JsonValue>` 的理由：
 * 层序挂载需要 children 是**可变容器**（ArrayList），而 `JsonValue` 一旦装箱即失去
 * 可写视图，只能靠"深挖 JSON 再替换"完成挂载。用显式类后 children 是普通
 * ArrayList 引用，挂载 O(1)，且字段类型由编译器保证（不必到处 match 解包）。
 */
public class TaskTreeNode {
    public let taskId: String
    public var agentId: String = ""
    public var parentTaskId: Option<String> = None
    public var status: Option<Int32> = None
    public var priority: Option<Int32> = None
    public var payload: Option<String> = None
    public var result: Option<String> = None
    public var errorMessage: Option<String> = None
    public var createdAt: String = ""
    public var updatedAt: String = ""
    public let children = ArrayList<TaskTreeNode>()

    public init(taskId: String) {
        this.taskId = taskId
    }

    /// 递归序列化为 JSON（children 在此处一次性转为 JsonArray）
    public func toJson(): JsonObject {
        let obj = JsonObject()
        obj.put("id", JsonString(this.taskId))
        obj.put("agentId", JsonString(this.agentId))
        obj.put("parentTaskId", TaskTreeNode.optStr(this.parentTaskId))
        obj.put("status", TaskTreeNode.optInt(this.status))
        obj.put("priority", TaskTreeNode.optInt(this.priority))
        obj.put("payload", TaskTreeNode.optStr(this.payload))
        obj.put("result", TaskTreeNode.optStr(this.result))
        obj.put("errorMessage", TaskTreeNode.optStr(this.errorMessage))
        obj.put("createdAt", JsonString(this.createdAt))
        obj.put("updatedAt", JsonString(this.updatedAt))
        let arr = JsonArray()
        for (child in this.children) {
            arr.add(child.toJson())
        }
        obj.put("children", arr)
        obj
    }

    /// Option<String> → JsonValue（None 显式输出 null，而非空串）
    private static func optStr(v: Option<String>): JsonValue {
        match (v) {
            case Some(s) => JsonString(s)
            case None => JsonNull()
        }
    }

    /// Option<Int32> → JsonValue
    private static func optInt(v: Option<Int32>): JsonValue {
        match (v) {
            case Some(n) => JsonInt(Int64(n))
            case None => JsonNull()
        }
    }
}
