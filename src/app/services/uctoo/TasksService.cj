/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

// ========== 自定义引入区域（在此区域添加自定义import，不会被覆盖）==========
import magic.app.models.uctoo.UserHasTasksPO
import magic.app.dao.uctoo.UserHasTasksDAO
import magic.app.dao.uctoo.CompanyDAO
import magic.app.models.uctoo.CompanyPO
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonNull}
// ========== 自动生成代码区域（以下代码会被自动生成覆盖）==========
//#region AutoCreateCode

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.TasksPO
import magic.app.dao.uctoo.TasksDAO
import magic.app.core.response.APIResult
import magic.app.core.query.{RequestParserService, ParsedQuery, CompositeCondition, FieldCondition, QueryOperator, LogicOperator, QueryValue, SortCondition}
import magic.app.core.{PermissionLevel, PermissionConfig, hasPermission}
import magic.app.utils.PermissionUtils
import magic.log.LogUtils

/**
 * TasksService - tasks服务类
 *
 * 提供tasks相关的业务逻辑处理，遵循UCTOO V4 ORM规范
 * 使用DAO层进行数据访问
 */
public class TasksService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    // 查询参数解析服务
    private let requestParser = RequestParserService()

    public init() {}

    /**
     * 创建tasks
     * @param entity TasksPO对象
     * @param creatorId 创建者ID
     * @return 创建结果
     */
    public func create(entity: TasksPO, creatorId: String): APIResult<TasksPO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            if (entity.creator.isNone()) {
                entity.creator = Some(creatorId)
            }
            
            let id = getExecutor().insertTasks(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<TasksPO>(entity)
            } else {
                return APIResult<TasksPO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<TasksPO>(false, e.message)
        }
    }

    /**
     * 更新tasks（无权限检查）
     * @param entityId ID
     * @param entity TasksPO对象
     * @return 更新结果
     */
    public func update(entityId: String, entity: TasksPO): APIResult<TasksPO> {
        try {
            let existing = getExecutor().findTasksById(entityId)
            
            if (existing.isNone()) {
                return APIResult<TasksPO>(false, "tasks不存在")
            }
            
            let existingEntity = existing.getOrThrow()
            
            // 合并字段：只更新entity中非默认值的字段
                        if (entity.title.size > 0) {
                existingEntity.title = entity.title
            }
            if (entity.description.size > 0) {
                existingEntity.description = entity.description
            }
            if (entity.taskType.size > 0) {
                existingEntity.taskType = entity.taskType
            }
            if (entity.taskStatus.size > 0) {
                existingEntity.taskStatus = entity.taskStatus
            }
            if (entity.priority.size > 0) {
                existingEntity.priority = entity.priority
            }
            if (entity.companyId.isSome()) {
                existingEntity.companyId = entity.companyId
            }
            if (entity.creatorId.size > 0) {
                existingEntity.creatorId = entity.creatorId
            }
            if (entity.assigneeId.isSome()) {
                existingEntity.assigneeId = entity.assigneeId
            }
            existingEntity.participantCount = entity.participantCount
            existingEntity.followerCount = entity.followerCount
            existingEntity.viewCount = entity.viewCount
            existingEntity.commentCount = entity.commentCount
            if (entity.rewardType.isSome()) {
                existingEntity.rewardType = entity.rewardType
            }
            if (entity.rewardAmount.isSome()) {
                existingEntity.rewardAmount = entity.rewardAmount
            }
            if (entity.deadline.isSome()) {
                existingEntity.deadline = entity.deadline
            }
            if (entity.startedAt.isSome()) {
                existingEntity.startedAt = entity.startedAt
            }
            if (entity.completedAt.isSome()) {
                existingEntity.completedAt = entity.completedAt
            }
            if (entity.tags.isSome()) {
                existingEntity.tags = entity.tags
            }
            if (entity.skillsRequired.isSome()) {
                existingEntity.skillsRequired = entity.skillsRequired
            }
            if (entity.attachments.isSome()) {
                existingEntity.attachments = entity.attachments
            }
            if (entity.extraData.isSome()) {
                existingEntity.extraData = entity.extraData
            }
            if (entity.creator.isSome()) {
                existingEntity.creator = entity.creator
            }
            if (entity.deletedAt.isSome()) {
                existingEntity.deletedAt = entity.deletedAt
            }
            existingEntity.rewardPoints = entity.rewardPoints
            existingEntity.maxParticipants = entity.maxParticipants
            if (entity.acceptDeadline.isSome()) {
                existingEntity.acceptDeadline = entity.acceptDeadline
            }
            if (entity.settlementStatus.size > 0) {
                existingEntity.settlementStatus = entity.settlementStatus
            }
            existingEntity.pointsFrozen = entity.pointsFrozen
            existingEntity.pointsSettled = entity.pointsSettled
            existingEntity.pointsRefunded = entity.pointsRefunded
            if (entity.reviewStatus.size > 0) {
                existingEntity.reviewStatus = entity.reviewStatus
            }

            
            // 设置更新时间和ID
            existingEntity.updatedAt = DateTime.now()
            existingEntity.id = entityId
            
            let rows = getExecutor().updateTasks(existingEntity)
            
            if (rows > 0) {
                return APIResult<TasksPO>(existingEntity)
            } else {
                return APIResult<TasksPO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<TasksPO>(false, e.message)
        }
    }

    /**
     * 批量更新tasks
     * @param entities tasks列表
     * @return 更新结果
     */
    public func updateMultiple(entities: ArrayList<TasksPO>): APIResult<ArrayList<TasksPO>> {
        try {
            let updatedEntities = ArrayList<TasksPO>()

            for (entity in entities) {
                entity.updatedAt = DateTime.now()
                let rows = getExecutor().updateTasks(entity)

                if (rows > 0) {
                    updatedEntities.add(entity)
                }
            }

            if (updatedEntities.size > 0) {
                return APIResult<ArrayList<TasksPO>>(updatedEntities)
            } else {
                return APIResult<ArrayList<TasksPO>>(false, "批量更新失败")
            }
        } catch (e: Exception) {
            return APIResult<ArrayList<TasksPO>>(false, e.message)
        }
    }

    /**
     * 删除tasks（无权限检查）
     * @param entityId ID
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findTasksById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "tasks不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteTasksById(entityId)
            } else {
                rows = getExecutor().softDeleteTasksById(entityId)
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
     * 批量删除tasks
     * @param ids tasksID列表
     * @param force 是否强制删除（true: 硬删除，false: 软删除）
     * @return 删除结果
     */
    public func deleteMultiple(ids: ArrayList<String>, force: Bool): APIResult<Bool> {
        try {
            let rows: Int64
            if (force) {
                rows = getExecutor().batchDeleteTasks(ids)
            } else {
                rows = getExecutor().batchSoftDeleteTasks(ids)
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
     * 恢复软删除的tasks
     * @param entityId tasksID
     * @return 恢复结果
     */
    public func restore(entityId: String): APIResult<TasksPO> {
        try {
            let rows = getExecutor().restoreTasksById(entityId)

            if (rows > 0) {
                let result = getExecutor().findTasksById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<TasksPO>(entity)
                } else {
                    return APIResult<TasksPO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<TasksPO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<TasksPO>(false, e.message)
        }
    }

    /**
     * 批量恢复软删除的tasks
     * @param ids tasksID列表
     * @return 恢复结果
     */
    public func restoreMultiple(ids: ArrayList<String>): APIResult<Bool> {
        try {
            var rows: Int64 = 0
            for (id in ids) {
                rows = rows + getExecutor().restoreTasksById(id)
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
     * 根据ID获取tasks（无权限检查）
     * @param entityId ID
     * @return tasks对象
     */
    public func getById(entityId: String): APIResult<TasksPO> {
        try {
            let result = getExecutor().findTasksById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<TasksPO>(entity)
            } else {
                return APIResult<TasksPO>(false, "未找到该tasks")
            }
        } catch (e: Exception) {
            return APIResult<TasksPO>(false, e.message)
        }
    }

    /**
     * 获取tasks列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return tasks列表和总数
     */
    public func getList(page: Int64, pageSize: Int64): (ArrayList<TasksPO>, Int64) {
        try {
            let pagination = getExecutor().findAllTasksPage(page, pageSize)
            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TasksPO>(), 0)
        }
    }

    /**
     * 获取tasks列表（分页，支持排序和过滤，无权限过滤）
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
     * @return tasks列表和总数
     */
    public func getListWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<TasksPO>, Int64) {
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
            let pagination = getExecutor().findTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TasksPO>(), 0)
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
     * 获取tasks列表（带跳过参数，带权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @param userId 用户ID
     * @return tasks列表和总数
     */
    public func getListWithSkipWithPermission(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<TasksPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithSkip(page, pageSize, skip, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "tasks")

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
            let pagination = getExecutor().findTasksByCondition(
                whereClause,
                orderByClause,
                Int64(pageNum),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TasksPO>(), 0)
        }
    }

    /**
     * 获取tasks列表（带跳过参数，无权限过滤）
     *
     * 支持完整的 Prisma 风格查询
     *
     * @param page 页码（从0开始）
     * @param pageSize 每页大小
     * @param skip 跳过条数
     * @param sort 排序参数
     * @param filter 过滤条件
     * @return tasks列表和总数
     */
    public func getListWithSkip(
        page: Int32,
        pageSize: Int32,
        skip: Int32,
        sort: String,
        filter: String
    ): (ArrayList<TasksPO>, Int64) {
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
            let pagination = getExecutor().findTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TasksPO>(), 0)
        }
    }

    /**
     * 获取所有tasks列表（分页）
     * @param page 页码
     * @param pageSize 每页大小
     * @return tasks列表和总数
     */
    public func getAllList(
        page: Int32,
        pageSize: Int32
    ): (ArrayList<TasksPO>, Int64) {
        let pagination = getExecutor().findAllTasksPage(
            Int64(page + 1),
            Int64(pageSize)
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 批量获取tasks
     * @param ids ID列表
     * @return tasks列表
     */
    public func getByIds(ids: ArrayList<String>): ArrayList<TasksPO> {
        getExecutor().findTasksByIds(ids)
    }

    /**
     * 统计用户的tasks数量
     * @param userId 用户ID
     * @return tasks数量
     */
    public func countByUser(userId: String): Int64 {
        getExecutor().countTasksByCreator(userId)
    }

    /**
     * 统计所有tasks数量
     * @return tasks数量
     */
    public func countAll(): Int64 {
        getExecutor().countAllTasks()
    }

    /**
     * 获取tasks列表（带过滤条件）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param link 链接模糊查询
     * @param description 描述模糊查询
     * @param deletedAt 软删除筛选 (null: 未删除, "not_null": 已删除, None: 不过滤)
     * @return tasks列表和总数
     */
    public func getFilteredList(
        page: Int64,
        pageSize: Int64,
        link: ?String,
        description: ?String,
        deletedAt: ?String
    ): (ArrayList<TasksPO>, Int64) {
        let pagination = getExecutor().findTasksByFilterPage(
            link,
            description,
            deletedAt,
            page,
            pageSize
        )

        return (pagination.list, pagination.rows)
    }

    /**
     * 清空回收站（硬删除所有已软删除的tasks）
     * @return 删除结果
     */
    public func emptyRecycleBinTasks(): APIResult<Bool> {
        try {
            let rows = getExecutor().emptyRecycleBinTasks()

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

    public func createWithPermission(entity: TasksPO, creatorId: String): APIResult<TasksPO> {
        let result = create(entity, creatorId)
        if (result.success) {
            if (result.data.isSome()) {
                let data = result.data.getOrThrow()
                if (!data.id.isEmpty()) {
                    PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "tasks")
                }
            }
        }
        return result
    }

    public func getByIdWithPermission(entityId: String, userId: String): APIResult<TasksPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkReadPermission(userId, entityId, "tasks")
            if (!hasPermission) {
                return APIResult<TasksPO>(false, reason)
            }
            return getById(entityId)
        } catch (e: Exception) {
            return APIResult<TasksPO>(false, e.message)
        }
    }

    public func getListWithPermission(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String,
        userId: String
    ): (ArrayList<TasksPO>, Int64) {
        try {
            if (PermissionUtils.hasWildcardPermission(userId)) {
                return getListWithFilter(page, pageSize, sort, filter)
            }

            let (permFilter, permParams) = PermissionUtils.appendPermissionFilter(userId, "tasks")

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

            let pagination = getExecutor().findTasksByCondition(
                whereClause,
                orderByClause,
                parsedQuery.page,
                parsedQuery.pageSize
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            return (ArrayList<TasksPO>(), 0)
        }
    }

    public func updateWithPermission(entityId: String, entity: TasksPO, userId: String): APIResult<TasksPO> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "tasks")
            if (!hasPermission) {
                return APIResult<TasksPO>(false, reason)
            }
            return update(entityId, entity)
        } catch (e: Exception) {
            return APIResult<TasksPO>(false, e.message)
        }
    }

    public func deleteWithPermission(entityId: String, force: Bool, userId: String): APIResult<Bool> {
        try {
            let (hasPermission, reason) = PermissionUtils.checkWritePermission(userId, entityId, "tasks")
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

    // ==================== 积分系统与状态机集成方法 ====================

    /**
     * 发布任务（含积分冻结逻辑）
     * 如果 reward_points > 0，自动调用 PointTransactionsService.freezeCompanyPoints 冻结积分
     * @param entity 任务对象
     * @param creatorId 创建者ID（公司成员）
     * @return 创建结果
     */
    public func publishTask(entity: TasksPO, creatorId: String): APIResult<TasksPO> {
        try {
            // 校验积分相关字段
            if (entity.rewardPoints > 0) {
                if (entity.companyId.isNone()) {
                    return APIResult<TasksPO>(false, "带积分的任务必须指定公司")
                }
                if (entity.maxParticipants <= 0) {
                    entity.maxParticipants = 1
                }
            }
            // 设置初始状态
            entity.taskStatus = "open"
            entity.settlementStatus = "none"
            entity.reviewStatus = "none"
            if (entity.pointsFrozen == 0 && entity.rewardPoints > 0) {
                entity.pointsFrozen = entity.rewardPoints * Int64(entity.maxParticipants)
            }
            // 创建任务
            let createResult = create(entity, creatorId)
            if (!createResult.success) {
                return createResult
            }
            let createdTask = createResult.data.getOrThrow()
            // 冻结积分
            if (entity.rewardPoints > 0 && entity.pointsFrozen > 0) {
                let cid = entity.companyId.getOrThrow()
                let pointService = PointTransactionsService()
                pointService.freezeCompanyPoints(cid, entity.pointsFrozen, createdTask.id, creatorId)
                // 更新组织任务数
                let executor = getExecutor()
                executor.incrementTaskCount(cid)
            }
            return APIResult<TasksPO>(createdTask)
        } catch (e: Exception) {
            return APIResult<TasksPO>(false, "发布任务失败：${e.message}")
        }
    }

    /**
     * 用户承接任务
     * 1. 校验任务状态为 open
     * 2. 校验承接人数未满 max_participants
     * 3. 创建 user_has_tasks 关系（join_status=accepted）
     * 4. 第一个承接者使任务状态变为 in_progress
     * 5. 达到 max_participants 后不再接受新承接
     * @param taskId 任务ID
     * @param userId 用户ID
     * @return 关系记录ID
     */
    public func joinTask(taskId: String, userId: String): APIResult<String> {
        try {
            let executor = getExecutor()
            // 1. 查询任务
            let taskOpt = executor.findTasksById(taskId)
            if (taskOpt.isNone()) {
                return APIResult<String>(false, "任务不存在")
            }
            let task = taskOpt.getOrThrow()
            if (task.taskStatus != "open") {
                return APIResult<String>(false, "任务状态不允许承接（当前状态：${task.taskStatus}）")
            }
            // 2. 检查是否已承接
            if (executor.isParticipant(userId, taskId)) {
                return APIResult<String>(false, "您已承接该任务")
            }
            // 3. 检查承接人数
            let participantCount = countTaskParticipants(taskId)
            if (task.maxParticipants > 0 && participantCount >= Int64(task.maxParticipants)) {
                return APIResult<String>(false, "任务承接人数已满")
            }
            // 4. 创建关系记录
            let relation = UserHasTasksPO()
            relation.userId = userId
            relation.taskId = taskId
            relation.relationType = "participant"
            relation.joinStatus = "accepted"
            relation.reviewStatus = "pending"
            relation.allocationRatio = 0.0
            relation.pointsEarned = 0
            relation.creator = Some(userId)
            relation.createdAt = DateTime.now()
            relation.updatedAt = DateTime.now()
            let relId = getExecutor().insertUserHasTasks(relation)
            if (relId.isEmpty()) {
                return APIResult<String>(false, "创建承接记录失败")
            }
            // 5. 更新任务参与者计数
            executor.incrementParticipantCount(taskId)
            // 6. 第一个承接者使任务变为 in_progress
            if (participantCount == 0) {
                executor.updateTaskStatus(taskId, "in_progress")
            }
            // 7. 多人任务满员后任务状态变为 reviewing（等待提交）
            // 注：保持 in_progress，等所有参与者提交后进入 reviewing
            return APIResult<String>(relId)
        } catch (e: Exception) {
            return APIResult<String>(false, "承接任务失败：${e.message}")
        }
    }

    /**
     * 用户提交任务成果
     * @param taskId 任务ID
     * @param userId 用户ID
     * @param content 提交内容
     * @param attachments 附件（JSON 字符串）
     * @return 操作结果
     */
    public func submitWork(taskId: String, userId: String, content: String, attachments: String): APIResult<Bool> {
        try {
            let executor = getExecutor()
            // 查询任务
            let taskOpt = executor.findTasksById(taskId)
            if (taskOpt.isNone()) {
                return APIResult<Bool>(false, "任务不存在")
            }
            let task = taskOpt.getOrThrow()
            if (task.taskStatus != "in_progress" && task.taskStatus != "reviewing") {
                return APIResult<Bool>(false, "任务状态不允许提交（当前状态：${task.taskStatus}）")
            }
            // 查询承接关系
            let relOpt = executor.findTaskRelation(userId, taskId, "participant")
            if (relOpt.isNone()) {
                return APIResult<Bool>(false, "您未承接该任务")
            }
            let rel = relOpt.getOrThrow()
            if (rel.joinStatus != "accepted" && rel.joinStatus != "rejected") {
                return APIResult<Bool>(false, "当前承接状态不允许提交（${rel.joinStatus}）")
            }
            // 更新提交信息
            executor.submitWork(rel.id, content, attachments)
            // 检查是否所有参与者都已提交
            let participants = executor.findParticipantsByTaskId(taskId)
            var allSubmitted = true
            for (p in participants) {
                if (p.joinStatus != "submitted" && p.joinStatus != "approved" && p.joinStatus != "completed") {
                    allSubmitted = false
                    break
                }
            }
            if (allSubmitted) {
                executor.updateTaskStatus(taskId, "reviewing")
                executor.updateReviewStatus(taskId, "pending")
            }
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            return APIResult<Bool>(false, "提交成果失败：${e.message}")
        }
    }

    /**
     * 公司审核提交
     * 单人任务审核通过后自动触发结算
     * @param taskId 任务ID
     * @param userId 被审核用户ID
     * @param approved 是否通过
     * @param comment 审核评论
     * @param reviewerId 审核者ID
     * @return 操作结果
     */
    public func reviewSubmission(taskId: String, userId: String, approved: Bool, comment: String, reviewerId: String): APIResult<Bool> {
        try {
            let executor = getExecutor()
            // 查询任务
            let taskOpt = executor.findTasksById(taskId)
            if (taskOpt.isNone()) {
                return APIResult<Bool>(false, "任务不存在")
            }
            let task = taskOpt.getOrThrow()
            if (task.taskStatus != "reviewing") {
                return APIResult<Bool>(false, "任务当前不在审核状态")
            }
            // 查询承接关系
            let relOpt = executor.findTaskRelation(userId, taskId, "participant")
            if (relOpt.isNone()) {
                return APIResult<Bool>(false, "用户未承接该任务")
            }
            let rel = relOpt.getOrThrow()
            if (rel.joinStatus != "submitted") {
                return APIResult<Bool>(false, "该用户未提交成果或已审核")
            }
            // 更新审核结果
            let reviewStatus = if (approved) { "approved" } else { "rejected" }
            executor.reviewSubmission(rel.id, reviewStatus, comment, reviewerId)
            // 单人任务审核通过，自动结算
            if (approved && task.maxParticipants == 1) {
                settleSingleParticipantTask(task, rel, reviewerId)
            }
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            return APIResult<Bool>(false, "审核失败：${e.message}")
        }
    }

    /**
     * 关注/取消关注任务
     */
    public func followTask(taskId: String, userId: String): APIResult<Bool> {
        try {
            let executor = getExecutor()
            if (executor.isFollowing(userId, taskId)) {
                return APIResult<Bool>(false, "已关注该任务")
            }
            let relation = UserHasTasksPO()
            relation.userId = userId
            relation.taskId = taskId
            relation.relationType = "follower"
            relation.creator = Some(userId)
            relation.createdAt = DateTime.now()
            relation.updatedAt = DateTime.now()
            let id = executor.insertUserHasTasks(relation)
            if (id.isEmpty()) {
                return APIResult<Bool>(false, "关注失败")
            }
            executor.incrementTaskFollowerCount(taskId)
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    public func unfollowTask(taskId: String, userId: String): APIResult<Bool> {
        try {
            let executor = getExecutor()
            let relOpt = executor.findTaskRelation(userId, taskId, "follower")
            if (relOpt.isNone()) {
                return APIResult<Bool>(false, "未关注该任务")
            }
            let rel = relOpt.getOrThrow()
            executor.softDeleteUserHasTasksById(rel.id)
            executor.decrementTaskFollowerCount(taskId)
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }

    /**
     * 获取任务承接者列表
     */
    public func getTaskParticipants(taskId: String): ArrayList<UserHasTasksPO> {
        getExecutor().findParticipantsByTaskId(taskId)
    }

    /**
     * 统计任务承接者数量
     */
    public func countTaskParticipants(taskId: String): Int64 {
        getExecutor().countParticipantsByTaskId(taskId)
    }

    /**
     * 公开任务分页查询
     */
    public func listPublicTasks(
        page: Int64,
        pageSize: Int64,
        taskType: String,
        taskStatus: String,
        priority: String,
        companyId: String,
        tag: String,
        sortBy: String
    ): (ArrayList<TasksPO>, Int64) {
        let executor = getExecutor()
        let pagination = executor.queryPublicTasksWithPagination(page, pageSize, taskType, taskStatus, priority, companyId, tag, sortBy)
        return (pagination.list, pagination.rows)
    }

    /**
     * 公开任务分页查询（Prisma风格）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param sort 排序字段
     * @param filter 过滤条件（JSON格式）
     * @return 任务列表和总数
     */
    public func listPublicTasksWithFilter(
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<TasksPO>, Int64) {
        try {
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            var publicWhere = "deleted_at is null"
            if (!whereClause.isEmpty()) {
                publicWhere = publicWhere + " and (" + whereClause + ")"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)
            var finalOrderBy = orderByClause
            if (finalOrderBy.isEmpty()) {
                finalOrderBy = "created_at desc"
            }

            let pagination = getExecutor().findTasksByCondition(
                publicWhere,
                finalOrderBy,
                Int64(page),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("TasksService", "listPublicTasksWithFilter error: ${e.message}")
            return (ArrayList<TasksPO>(), 0)
        }
    }

    /**
     * 某组织下的公开任务分页查询（Prisma风格）
     * @param companyId 组织ID
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @param sort 排序字段
     * @param filter 过滤条件（JSON格式）
     * @return 任务列表和总数
     */
    public func listPublicTasksByCompanyWithFilter(
        companyId: String,
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<TasksPO>, Int64) {
        try {
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            var publicWhere = "deleted_at is null and company_id = '${companyId}'"
            if (!whereClause.isEmpty()) {
                publicWhere = publicWhere + " and (" + whereClause + ")"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)
            var finalOrderBy = orderByClause
            if (finalOrderBy.isEmpty()) {
                finalOrderBy = "order by created_at desc"
            }

            let pagination = getExecutor().findTasksByCondition(
                publicWhere,
                finalOrderBy,
                Int64(page),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("TasksService", "listPublicTasksByCompanyWithFilter error: ${e.message}")
            return (ArrayList<TasksPO>(), 0)
        }
    }

    /**
     * 我的任务列表（Prisma风格）
     * @param userId 用户ID
     * @param relationType 关系类型（participant/follower/creator）
     * @param page 页码
     * @param pageSize 每页数量
     * @param sort 排序字段
     * @param filter 过滤条件
     * @return 任务列表和总数
     */
    public func getMyTasksWithFilter(
        userId: String,
        relationType: String,
        page: Int32,
        pageSize: Int32,
        sort: String,
        filter: String
    ): (ArrayList<TasksPO>, Int64) {
        try {
            let parsedQuery = requestParser.parseQuery(filter, sort, Int64(page), Int64(pageSize))

            var whereClause = ""
            if (let Some(filterCondition) <- parsedQuery.filter) {
                whereClause = buildWhereClause(filterCondition)
            }

            var myWhere = "id in (select task_id from user_has_tasks where user_id = '${userId}' and relation_type = '${relationType}' and deleted_at is null)"
            if (!whereClause.isEmpty()) {
                myWhere = myWhere + " and (" + whereClause + ")"
            }

            let orderByClause = buildOrderByClause(parsedQuery.sort)
            var finalOrderBy = orderByClause
            if (finalOrderBy.isEmpty()) {
                finalOrderBy = "order by created_at desc"
            }

            let pagination = getExecutor().findTasksByCondition(
                myWhere,
                finalOrderBy,
                Int64(page),
                Int64(pageSize)
            )

            return (pagination.list, pagination.rows)
        } catch (e: Exception) {
            LogUtils.error("TasksService", "getMyTasksWithFilter error: ${e.message}")
            return (ArrayList<TasksPO>(), 0)
        }
    }

    /**
     * 公开任务详情（自动累加浏览数）
     */
    public func getPublicTaskDetail(taskId: String): APIResult<TasksPO> {
        try {
            let executor = getExecutor()
            let taskOpt = executor.findTasksById(taskId)
            if (taskOpt.isNone()) {
                return APIResult<TasksPO>(false, "任务不存在")
            }
            let task = taskOpt.getOrThrow()
            if (task.taskStatus != "open" && task.taskStatus != "in_progress" && task.taskStatus != "reviewing" && task.taskStatus != "completed") {
                return APIResult<TasksPO>(false, "任务不可见")
            }
            // 累加浏览数
            executor.incrementViewCount(taskId)
            task.viewCount = task.viewCount + 1
            return APIResult<TasksPO>(task)
        } catch (e: Exception) {
            return APIResult<TasksPO>(false, e.message)
        }
    }

    /**
     * 查询超期未承接的任务（用于定时任务处理）
     * 查询条件：accept_deadline < NOW() 且 task_status = 'open' 且 points_frozen > 0
     * @param limit 单次处理最大数量
     * @return 超期任务列表
     */
    public func findExpiredOpenTasks(limit: Int64): ArrayList<TasksPO> {
        try {
            let executor = getExecutor()
            return executor.findExpiredOpenTasks(limit)
        } catch (e: Exception) {
            LogUtils.error("TasksService", "查询超期任务失败: ${e.message}")
            return ArrayList<TasksPO>()
        }
    }

    /**
     * 将任务标记为已超期（更新task_status、settlement_status、points_refunded）
     * @param taskId 任务ID
     * @param pointsRefunded 已退还积分数
     * @return 影响行数
     */
    public func markTaskExpired(taskId: String, pointsRefunded: Int64): Int64 {
        try {
            let executor = getExecutor()
            executor.updateTaskStatus(taskId, "expired")
            executor.updateSettlementStatus(taskId, "refunded", 0)
            return executor.updatePointsRefunded(taskId, pointsRefunded)
        } catch (e: Exception) {
            LogUtils.error("TasksService", "标记任务超期失败: ${e.message}")
            return 0
        }
    }

    /**
     * 按任务状态统计任务数量
     * @param taskStatus 任务状态（空字符串表示统计全部）
     * @return 任务数量
     */
    public func countTasksByStatus(taskStatus: String): Int64 {
        try {
            let executor = getExecutor()
            return executor.countTasksByStatus(taskStatus)
        } catch (e: Exception) {
            LogUtils.error("TasksService", "统计任务数量失败: ${e.message}")
            return 0
        }
    }

    /**
     * 获取首页统计数据
     * @return 包含各项统计指标的 HashMap
     */
    public func getHomeStats(): HashMap<String, Int64> {
        let stats = HashMap<String, Int64>()
        try {
            stats.add("totalTasks", countAll())
            stats.add("openTasks", countTasksByStatus("open"))
            stats.add("inProgressTasks", countTasksByStatus("in_progress"))
            stats.add("completedTasks", countTasksByStatus("completed"))
        } catch (e: Exception) {
            LogUtils.error("TasksService", "获取任务统计失败: ${e.message}")
        }

        try {
            let executor = getExecutor()
            stats.add("publicOrgs", executor.countAllCompany())
        } catch (e: Exception) {
            LogUtils.error("TasksService", "获取组织统计失败: ${e.message}")
        }

        try {
            let executor = getExecutor()
            let userCount = executor.countUsers()
            stats.add("totalParticipants", userCount)
        } catch (e: Exception) {
            LogUtils.error("TasksService", "获取用户统计失败: ${e.message}")
        }

        stats
    }

    /**
     * 更新任务状态
     * @param taskId 任务ID
     * @param taskStatus 新状态
     * @return 影响行数
     */
    public func updateTaskStatus(taskId: String, taskStatus: String): Int64 {
        try {
            let executor = getExecutor()
            return executor.updateTaskStatus(taskId, taskStatus)
        } catch (e: Exception) {
            LogUtils.error("TasksService", "更新任务状态失败: ${e.message}")
            return 0
        }
    }

    /**
     * 判断用户是否已关注任务
     * @param taskId 任务ID
     * @param userId 用户ID
     * @return true=已关注
     */
    public func isTaskFollowing(taskId: String, userId: String): Bool {
        try {
            let executor = getExecutor()
            return executor.isFollowing(userId, taskId)
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * 内部方法：单人任务审核通过后自动结算
     */
    private func settleSingleParticipantTask(task: TasksPO, rel: UserHasTasksPO, operatorId: String): Unit {
        let executor = getExecutor()
        let pointsToSettle = task.rewardPoints
        if (pointsToSettle <= 0) {
            // 无积分任务，直接完成
            executor.updateTaskStatus(task.id, "completed")
            executor.updateSettlementStatus(task.id, "settled", 0)
            executor.updateReviewStatus(task.id, "approved")
            executor.settleSingleParticipant(rel.id, 0)
            return
        }
        // 调用积分服务结算
        let pointService = PointTransactionsService()
        let cid = match (task.companyId) {
            case Some(c) => c
            case None => ""
        }
        if (cid.isEmpty()) {
            // 无公司信息，仅更新状态
            executor.updateTaskStatus(task.id, "completed")
            executor.updateSettlementStatus(task.id, "settled", 0)
            executor.updateReviewStatus(task.id, "approved")
            executor.settleSingleParticipant(rel.id, 0)
            return
        }
        pointService.settlePointsToUser(cid, rel.userId, pointsToSettle, task.id, operatorId)
        // 更新承接者积分
        executor.settleSingleParticipant(rel.id, pointsToSettle)
        // 更新任务状态
        executor.updateTaskStatus(task.id, "completed")
        executor.updateReviewStatus(task.id, "approved")
    }

    // ==================== 任务列表关联组织名称 ====================

    /**
     * 批量获取 company_name 映射
     * @param taskList 任务列表
     * @return company_id -> company_name 的映射
     */
    public func getCompanyNameMap(taskList: ArrayList<TasksPO>): HashMap<String, String> {
        let companyIds = ArrayList<String>()
        for (task in taskList) {
            if (let Some(cid) <- task.companyId) {
                if (!cid.isEmpty() && !companyIds.contains(cid)) {
                    companyIds.add(cid)
                }
            }
        }
        let nameMap = HashMap<String, String>()
        if (companyIds.isEmpty()) {
            return nameMap
        }
        try {
            let companies = getExecutor().findCompanyByIds(companyIds)
            for (c in companies) {
                nameMap.add(c.id, c.companyName)
            }
        } catch (e: Exception) {
            LogUtils.error("TasksService", "getCompanyNameMap error: ${e.message}")
        }
        return nameMap
    }

    /**
     * 将任务列表序列化为 JSON 数组字符串，并注入 company_name 字段
     * @param taskList 任务列表
     * @return JSON 数组字符串（每个任务对象包含 company_name 字段）
     */
    public func tasksToJsonWithCompanyName(taskList: ArrayList<TasksPO>): String {
        let nameMap = getCompanyNameMap(taskList)
        var entitiesJson = ""
        for (e in taskList) {
            var taskJson = e.toJson()
            // 在 JSON 对象的最后一个 } 之前插入 company_name 字段
            var companyName = ""
            if (let Some(cid) <- e.companyId) {
                if (nameMap.contains(cid)) {
                    companyName = nameMap.get(cid).getOrThrow()
                }
            }
            // JSON 转义 company_name
            let escapedName = companyName.replace("\\", "\\\\").replace("\"", "\\\"")
            if (taskJson.endsWith("}")) {
                taskJson = taskJson[0..taskJson.size - 1] + ",\"company_name\":\"" + escapedName + "\"}"
            }
            if (entitiesJson.isEmpty()) {
                entitiesJson = taskJson
            } else {
                entitiesJson = entitiesJson + "," + taskJson
            }
        }
        return "[" + entitiesJson + "]"
    }

    /**
     * 将单个任务序列化为 JSON 字符串，并注入 company_name 字段
     * @param task 任务对象
     * @return JSON 字符串（包含 company_name 字段）
     */
    public func taskToJsonWithCompanyName(task: TasksPO): String {
        let taskList = ArrayList<TasksPO>()
        taskList.add(task)
        let nameMap = getCompanyNameMap(taskList)
        var taskJson = task.toJson()
        var companyName = ""
        if (let Some(cid) <- task.companyId) {
            if (nameMap.contains(cid)) {
                companyName = nameMap.get(cid).getOrThrow()
            }
        }
        let escapedName = companyName.replace("\\", "\\\\").replace("\"", "\\\"")
        if (taskJson.endsWith("}")) {
            taskJson = taskJson[0..taskJson.size - 1] + ",\"company_name\":\"" + escapedName + "\"}"
        }
        return taskJson
    }
}
